import os
import sys
import time
import yaml
import logging
from datetime import datetime, timezone
from influxdb_client import InfluxDBClient
from influxdb_client.client.exceptions import InfluxDBError
from influxdb_client.client.write_api import SYNCHRONOUS

from src.apptainer.ApptainerHandler import ApptainerHandler
from src.utils.MyUtils import create_dir, clean_log_file

POLLING_FREQUENCY = 2
MIN_BATCH_SIZE = 10
TICKS_PER_SECOND = os.sysconf(os.sysconf_names['SC_CLK_TCK'])
NS_PER_TICK = 1e9 / TICKS_PER_SECOND

CGROUP_BASE_PATH = "/sys/fs/cgroup/cpu/system.slice/"
SCRIPT_PATH = os.path.abspath(__file__)
SCRIPT_DIR = os.path.dirname(SCRIPT_PATH)
SENDERS_DIR = os.path.dirname(SCRIPT_DIR)
INFLUXDB_CONFIG_FILE = f"{SENDERS_DIR}/influxdb/config.yml"
LOG_DIR = f"{SENDERS_DIR}/log"
LOG_FILE = f"{LOG_DIR}/usage_sender.log"

logger = logging.getLogger("usage_sender")


def read_cgroup_file_stat(target_dir):
    path = f"{target_dir}/cpuacct.stat"
    values = {"user": 0, "system": 0}
    try:
        if os.path.isfile(path) and os.access(path, os.R_OK):
            with open(path, 'r') as f:
                for line in f:
                    fields = line.split()
                    values[fields[0]] = int(fields[1])
            return values
        else:
            logger.error(f"Couldn't access file: {path}")
            return None
    except IOError as e:
        logger.error(f"Error while reading {path}: {str(e)}")
        return None


if __name__ == "__main__":

    if len(sys.argv) < 2:
        raise Exception("Missing some arguments: usage_sender.py <INFLUXDB_BUCKET>")

    influxdb_bucket = sys.argv[1]

    create_dir(LOG_DIR)
    clean_log_file(LOG_DIR, LOG_FILE)
    logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format='%(levelname)s (%(name)s): %(asctime)s %(message)s')

    if not os.path.exists(CGROUP_BASE_PATH):
        logger.error(f"{CGROUP_BASE_PATH} doesn't exist. Make sure you are using cgroups v1"
              " and there is at least one apptainer container running")
        exit(1)

    with open(INFLUXDB_CONFIG_FILE, "r") as f:
        influxdb_config = yaml.load(f, Loader=yaml.FullLoader)

    # Get running containers on node
    apptainer_handler = ApptainerHandler(privileged=True)

    # Get session to InfluxDB
    influxdb_url = f"http://{influxdb_config['influxdb_host']}:8086"
    client = InfluxDBClient(url=influxdb_url, token=influxdb_config['influxdb_token'], org=influxdb_config['influxdb_org'])

    # Initialize t_stop to compute delay in first iteration properly
    t_stop = time.perf_counter_ns()
    current_batch = []
    while True:
        try:
            # Filter and initialize valid targets to process
            valid_targets = []
            for container in apptainer_handler.get_running_containers_list():
                target_dir = f"{CGROUP_BASE_PATH}/apptainer-{container['pid']}.scope"
                if os.path.isdir(target_dir) and os.access(target_dir, os.R_OK):
                    valid_targets.append({"name": container["name"], "dir": target_dir})

            # Setup start counters
            for target in valid_targets:
                target["start"] = time.perf_counter_ns()
                tick_values = read_cgroup_file_stat(target["dir"])
                target["user_ticks_start"] = tick_values["user"]
                target["sys_ticks_start"] = tick_values["system"]
                if target["user_ticks_start"] is None or target["sys_ticks_start"] is None:
                    valid_targets.remove(target)

            t_start = time.perf_counter_ns()

            # This value represents the total delay since t_stop from previous iteration was computed
            delay = (t_start - t_stop) / 1e9
            if delay > POLLING_FREQUENCY:
                logger.warning(f"High delay ({delay}) causing negative sleep times. Waiting until the next {POLLING_FREQUENCY}s cycle")
                delay = delay % POLLING_FREQUENCY
            time.sleep(POLLING_FREQUENCY - delay)

            t_stop = time.perf_counter_ns()
            timestamp = int(datetime.now(timezone.utc).timestamp() * 1e9)

            #Setup stop counters
            for target in valid_targets:
                target["stop"] = time.perf_counter_ns()
                tick_values = read_cgroup_file_stat(target["dir"])
                target["user_ticks_stop"] = tick_values["user"]
                target["sys_ticks_stop"] = tick_values["system"] 
                if target["user_ticks_stop"] is None or target["sys_ticks_stop"] is None:
                    valid_targets.remove(target)
                    continue

                # Process target data
                elapsed_time = target["stop"] - target["start"]
                user_usage = ((target["user_ticks_stop"] - target["user_ticks_start"]) * NS_PER_TICK / elapsed_time) * 100
                system_usage = ((target["sys_ticks_stop"] - target["sys_ticks_start"]) * NS_PER_TICK / elapsed_time) * 100

                data = f"usage,host={target['name']} user={user_usage},system={system_usage} {timestamp}"
                current_batch.append(data)

            logger.info(f"Current batch size is {len(current_batch)}. Last iteration delay: {delay} seconds")

            # If current batch has at least MIN_BATCH_SIZE data points, send and clear the batch
            if len(current_batch) >= MIN_BATCH_SIZE:
                try:
                    client.write_api(write_options=SYNCHRONOUS).write(bucket=influxdb_bucket, record=current_batch)
                except InfluxDBError as e:
                    logger.error(f"Error while sending data to InfluxDB: {e}")
                except Exception as e:
                    logger.error(f"Unexpected error while sending data to InfluxDB: {e}")
                finally:
                    current_batch.clear()

        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")