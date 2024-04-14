import os
import re
import time
import yaml
from datetime import datetime, timezone, timedelta
from influxdb_client import InfluxDBClient
from influxdb_client.client.exceptions import InfluxDBError
from influxdb_client.client.write_api import SYNCHRONOUS

from apptainer.ApptainerContainersList import ApptainerContainersList

POLLING_FREQUENCY = 5
MIN_BATCH_SIZE = 50

CGROUP_BASE_PATH = "/sys/fs/cgroup/cpu/system.slice/"
SCRIPT_PATH = os.path.abspath(__file__)
SCRIPT_DIR = os.path.dirname(SCRIPT_PATH)
INFLUXDB_CONFIG_FILE = f"{SCRIPT_DIR}/influxdb/config.yml"


def read_cgroup_file_value(path):
    try:
        if os.path.isfile(path) and os.access(path, os.R_OK):
            with open(path, 'r') as f:
                value = int(f.readline().strip().replace("\n", ""))
            return value
        else:
            print(f"Couldn't access file: {path}")
    except IOError as e:
        print(f"Error while reading {path}: {str(e)}")


if __name__ == "__main__":

    if not os.path.exists(CGROUP_BASE_PATH):
        print(f"{CGROUP_BASE_PATH} doesn't exist. Make sure you are using cgroups v1"
              " and there is at least one apptainer container running")

    with open(INFLUXDB_CONFIG_FILE, "r") as f:
        influxdb_config = yaml.load(f, Loader=yaml.FullLoader)

    # Get running containers on node
    containers_list = ApptainerContainersList()
    containers_list.init_container_names_by_pid()
    print(containers_list.get_container_list())

    # Get session to InfluxDB
    influxdb_url = f"http://{influxdb_config['influxdb_host']}:8086"
    client = InfluxDBClient(url=influxdb_url, token=influxdb_config['influxdb_token'], org=influxdb_config['influxdb_org'])

    # Initialize t_stop to compute delay in first iteration properly
    t_stop = time.perf_counter_ns()

    current_batch = []
    while True:
        new_targets = False
        for target_dir in os.listdir(CGROUP_BASE_PATH):

            # Ignore other running processes
            if not re.match(r"apptainer-.*\.scope", target_dir):
                continue

            # Get container name from pid
            pid = re.search(r'\d+', target_dir).group()
            target_name = containers_list.get_container_name_by_pid(pid)
            if target_name is None:
                continue

            t_start = time.perf_counter_ns()
            # This value represents the total delay since t_stop from previous iteration was computed
            delay = (t_start - t_stop) / 1e9
            user_time_start = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/cpuacct.usage_user")
            system_time_start = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/cpuacct.usage_sys")

            time.sleep(POLLING_FREQUENCY - delay)

            t_stop = time.perf_counter_ns()
            user_time_stop = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/cpuacct.usage_user")
            system_time_stop = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/cpuacct.usage_sys")

            elapsed_time = t_stop - t_start
            user_usage = ((user_time_stop - user_time_start) / elapsed_time) * 100
            system_usage = ((system_time_stop - system_time_start) / elapsed_time) * 100
            timestamp = datetime.now(timezone.utc) + timedelta(hours=2)  # UTC+02:00

            data = f"usage,host={target_name} user={user_usage} system={system_usage}  {timestamp}"
            current_batch.append(data)

        # If current batch has at least MIN_BATCH_SIZE data points, send and clear the batch
        if len(current_batch) >= MIN_BATCH_SIZE:
            try:
                client.write_api(write_options=SYNCHRONOUS).write(bucket=influxdb_config['influxdb_bucket'], record=current_batch)
            except InfluxDBError as e:
                print(f"Error while sending data to InfluxDB: {e}")
            except Exception as e:
                print(f"Unexpected error while sending data to InfluxDB: {e}")
            finally:
                current_batch.clear()
