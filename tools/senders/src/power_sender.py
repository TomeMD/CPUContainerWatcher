import os
import sys
import time
import yaml
import pandas as pd
from datetime import datetime, timezone, timedelta
from influxdb_client import InfluxDBClient
from influxdb_client.client.write_api import SYNCHRONOUS

from apptainer.ApptainerContainersList import ApptainerContainersList

POLLING_FREQUENCY = 5

SCRIPT_PATH = os.path.abspath(__file__)
SCRIPT_DIR = os.path.dirname(SCRIPT_PATH)
SENDERS_DIR = os.path.dirname(SCRIPT_DIR)
INFLUXDB_CONFIG_FILE = f"{SENDERS_DIR}/influxdb/config.yml"


if __name__ == "__main__":

    if len(sys.argv) < 2:
        raise Exception("Missing some arguments: send_power_opentsdb.py <SMARTWATTS_OUTPUT>")

    smartwatts_output = sys.argv[1]

    with open(INFLUXDB_CONFIG_FILE, "r") as f:
        influxdb_config = yaml.load(f, Loader=yaml.FullLoader)

    # Get running containers on node
    containers_list = ApptainerContainersList()
    containers_list.init_container_names_by_pid()
    print(containers_list.get_container_list())

    # Get current timestamp UTC
    start_timestamp = datetime.now(timezone.utc)

    # Get session to InfluxDB
    influxdb_url = f"http://{influxdb_config['influxdb_host']}:8086"
    client = InfluxDBClient(url=influxdb_url, token=influxdb_config['influxdb_token'], org=influxdb_config['influxdb_org'])

    # Read SmartWatts output and get targets
    output_file = {}
    last_read_position = {}
    while True:
        iter_count = {"targets": 0, "lines": 0}
        t_start = time.perf_counter_ns()
        for target_dir in os.listdir(smartwatts_output):
            target_name = target_dir[7:]  # Remove "sensor-"

            # Ignore other running processes
            if not target_name.startswith("apptainer"):
                continue

            # Get container name from pid
            pid = int(target_name[10:])
            target_name = containers_list.get_container_name_by_pid(pid)
            if target_name is None:
                continue

            # If target is not registered, initialize it
            if target_name not in output_file:
                print(f"Found new target with name {target_name}. Registered.")
                output_file[target_name] = f"{smartwatts_output}/{target_dir}/PowerReport.csv"
                last_read_position[target_name] = 0

            # Read target output
            with open(output_file[target_name], 'r') as file:
                # If file is empty, skip
                if os.path.getsize(output_file[target_name]) <= 0:
                    continue

                # Go to last read position
                file.seek(last_read_position[target_name])

                # Skip header
                if last_read_position[target_name] == 0:
                    next(file)

                lines = file.readlines()
                if len(lines) == 0:
                    print("There aren't new lines to process for target {0}".format(target_name))
                    continue

                iter_count["targets"] += 1
                iter_count["lines"] += len(lines)
                last_read_position[target_name] = file.tell()

                # Gather data from target output
                bulk_data = []
                for line in lines:
                    # line example: <timestamp> <sensor> <target> <value> ...
                    fields = line.strip().split(',')
                    num_fields = len(fields)
                    if num_fields < 4:
                        raise Exception("Missing some fields in SmartWatts output for "
                                        "target {0} ({1} out of 4 expected fields)".format(target_name, num_fields))
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
                        data = f"power,host={target_name} value={row['value']} {int(row['timestamp'].timestamp() * 1e9)}"
                        target_metrics.append(data)

                    # Send data to InfluxDB
                    try:
                        client.write_api(write_options=SYNCHRONOUS).write(bucket=influxdb_config['influxdb_bucket'], record=target_metrics)
                    except Exception as e:
                        print(f"Error sending data to InfluxDB: {e}")

        t_stop = time.perf_counter_ns()
        delay = (t_stop - t_start) / 1e9
        print("[Iteration Completed] Processed {0} targets and {1} lines causing a delay of {2} seconds".format(iter_count["targets"], iter_count["lines"], delay))
        time.sleep(POLLING_FREQUENCY - delay)
