import os
import sys
import time
import yaml
import logging
import pandas as pd
from datetime import datetime, timezone, timedelta
from influxdb_client import InfluxDBClient
from influxdb_client.client.write_api import SYNCHRONOUS
from ansible.parsing.dataloader import DataLoader
from ansible.inventory.manager import InventoryManager

from src.apptainer.ApptainerHandler import ApptainerHandler
from src.utils.MyUtils import create_dir, clean_log_file

POLLING_FREQUENCY = 5

SCRIPT_PATH = os.path.abspath(__file__)
SCRIPT_DIR = os.path.dirname(SCRIPT_PATH)
SENDERS_DIR = os.path.dirname(SCRIPT_DIR)
INFLUXDB_CONFIG_FILE = f"{SENDERS_DIR}/influxdb/config.yml"
LOG_DIR = f"{SENDERS_DIR}/log"
LOG_FILE = f"{LOG_DIR}/power_sender.log"

logger = logging.getLogger("power_sender")

def get_target_node(ansible_inventory_file):
    loader = DataLoader()
    ansible_inventory = InventoryManager(loader=loader, sources=ansible_inventory_file)
    return ansible_inventory.get_groups_dict()['target'][0]

if __name__ == "__main__":

    if len(sys.argv) < 4:
        raise Exception("Missing some arguments: power_sender.py <INFLUXDB_BUCKET> <SMARTWATTS_OUTPUT> <ANSIBLE_INVENTORY_FILE>")

    influxdb_bucket = sys.argv[1]
    smartwatts_output = sys.argv[2]
    ansible_inventory_file = sys.argv[3]

    create_dir(LOG_DIR)
    clean_log_file(LOG_DIR, LOG_FILE)
    logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='%(levelname)s (%(name)s): %(asctime)s %(message)s')

    with open(INFLUXDB_CONFIG_FILE, "r") as f:
        influxdb_config = yaml.load(f, Loader=yaml.FullLoader)

    # Get running containers on node
    apptainer_handler = ApptainerHandler(privileged=True)

    # Get current timestamp UTC
    start_timestamp = datetime.now(timezone.utc)
    logger.info(f"Start time: {start_timestamp}")

    # Get session to InfluxDB
    influxdb_url = f"http://{influxdb_config['influxdb_host']}:8086"
    client = InfluxDBClient(url=influxdb_url, token=influxdb_config['influxdb_token'], org=influxdb_config['influxdb_org'])

    # Read SmartWatts output and get targets
    output_file = {}
    last_read_position = {}
    target_node = get_target_node(ansible_inventory_file)
    while True:
        try:
            iter_count = {"targets": 0, "lines": 0}
            t_start = time.perf_counter_ns()
            for container in apptainer_handler.get_running_containers_list(target_node):

                cont_pid = container["pid"] 
                cont_name = container["name"]

                # If target is not registered, initialize it
                if cont_pid not in output_file:
                    logger.info(f"Found new target with name {cont_name} and pid {cont_pid}. Registered.")
                    output_file[cont_pid] = f"{smartwatts_output}/sensor-apptainer-{cont_pid}/PowerReport.csv"
                    last_read_position[cont_pid] = 0

                if not os.path.isfile(output_file[cont_pid]) or not os.access(output_file[cont_pid], os.R_OK):
                    logger.warning(f"Couldn't access file from target {container['name']}: {output_file[cont_pid]}")
                    continue

                # Read target output
                with open(output_file[cont_pid], 'r') as file:
                    # If file is empty, skip
                    if os.path.getsize(output_file[cont_pid]) <= 0:
                        logger.warning(f"Target {cont_name} file is empty: {output_file[cont_pid]}")
                        continue

                    # Go to last read position
                    file.seek(last_read_position[cont_pid])

                    # Skip header
                    if last_read_position[cont_pid] == 0:
                        next(file)

                    lines = file.readlines()
                    if len(lines) == 0:
                        logger.warning(f"There aren't new lines to process for target {cont_name}")
                        continue

                    iter_count["targets"] += 1
                    iter_count["lines"] += len(lines)
                    last_read_position[cont_pid] = file.tell()

                    # Gather data from target output
                    bulk_data = []
                    for line in lines:
                        # line example: <timestamp> <sensor> <target> <value> ...
                        fields = line.strip().split(',')
                        num_fields = len(fields)
                        if num_fields < 4:
                            raise Exception(f"Missing some fields in SmartWatts output for "
                                            f"target {cont_name} ({num_fields} out of 4 expected fields)")
                        # SmartWatts timestamps are 2 hours ahead from UTC (UTC-02:00)
                        # Normalize timestamps to UTC (actually UTC-02:00) and add 2 hours to get real UTC
                        data = {
                            "timestamp": datetime.fromtimestamp(int(fields[0]) / 1000, timezone.utc) + timedelta(hours=2),
                            "value": float(fields[3]),
                            "cpu": int(fields[4])
                        }
                        # Only data obtained after the start of this program are sent
                        if data["timestamp"] < start_timestamp:
                            continue
                        bulk_data.append(data)

                    # Aggregate data by cpu (mean) and timestamp (sum)
                    if len(bulk_data) > 0:
                        agg_data = pd.DataFrame(bulk_data).groupby(['timestamp', 'cpu']).agg({'value': 'mean'}).reset_index().groupby('timestamp').agg({'value': 'sum'}).reset_index()

                        # Format data to InfluxDB line protocol
                        target_metrics = []
                        for _, row in agg_data .iterrows():
                            data = f"power,host={cont_name} value={row['value']} {int(row['timestamp'].timestamp() * 1e9)}"
                            target_metrics.append(data)

                        # Send data to InfluxDB
                        try:
                            client.write_api(write_options=SYNCHRONOUS).write(bucket=influxdb_bucket, record=target_metrics)
                        except Exception as e:
                            logger.error(f"Error sending data to InfluxDB: {e}")

            t_stop = time.perf_counter_ns()
            delay = (t_stop - t_start) / 1e9
            logger.info(f"Processed {iter_count['targets']} targets and {iter_count['lines']} lines causing a delay of {delay} seconds")

            # Avoids negative sleep times when there is a high delay
            if delay > POLLING_FREQUENCY:
                logger.warning(f"High delay ({delay}) causing negative sleep times. Waiting until the next {POLLING_FREQUENCY}s cycle")
                delay = delay % POLLING_FREQUENCY
            time.sleep(POLLING_FREQUENCY - delay)

        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")