import os
import re
import time
import yaml
from datetime import datetime, timezone, timedelta
from influxdb_client import InfluxDBClient
from influxdb_client.client.exceptions import InfluxDBError
from influxdb_client.client.write_api import SYNCHRONOUS

from src.apptainer.ApptainerContainersList import ApptainerContainersList

POLLING_FREQUENCY = 5
MIN_BATCH_SIZE = 10

CGROUP_BASE_PATH = "/sys/fs/cgroup/cpu/system.slice/"
SCRIPT_PATH = os.path.abspath(__file__)
SCRIPT_DIR = os.path.dirname(SCRIPT_PATH)
SENDERS_DIR = os.path.dirname(SCRIPT_DIR)
INFLUXDB_CONFIG_FILE = f"{SENDERS_DIR}/influxdb/config.yml"


def read_cgroup_file_value(path):
    try:
        if os.path.isfile(path) and os.access(path, os.R_OK):
            with open(path, 'r') as f:
                value = int(f.readline().strip().replace("\n", ""))
            return value
        else:
            print(f"Couldn't access file: {path}")
            return None
    except IOError as e:
        print(f"Error while reading {path}: {str(e)}")
        return None



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
        # Ignore other running processes
        filtered_dirs = [d for d in os.listdir(CGROUP_BASE_PATH) if re.match(r"apptainer-\d+\.scope", d)]

        # Filter and initialize valid targets to process
        valid_targets = []
        for target_dir in filtered_dirs:
            # Get container name from pid
            pid = int(re.search(r'\d+', target_dir).group())
            target_name = containers_list.get_container_name_by_pid(pid)
            if target_name is not None:
                valid_targets.append({"name": target_name, "dir": target_dir})

        # Setup start counters
        for target in valid_targets:
            target["start"] = time.perf_counter_ns()
            target["user_start"] = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/{target['dir']}/cpuacct.usage_user")
            target["sys_start"] = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/{target['dir']}/cpuacct.usage_sys")
            if target["user_start"] is None or target["sys_start"] is None:
                print(f"Target {target['name']} doesn't exist, it will be removed")
                valid_targets.remove(target)


        t_start = time.perf_counter_ns()

        # This value represents the total delay since t_stop from previous iteration was computed
        delay = (t_start - t_stop) / 1e9
        time.sleep(POLLING_FREQUENCY - delay)

        t_stop = time.perf_counter_ns()
        timestamp = int(datetime.now(timezone.utc).timestamp() * 1e9)

        #Setup stop counters
        for target in valid_targets:
            target["stop"] = time.perf_counter_ns()
            target["user_stop"] = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/{target['dir']}/cpuacct.usage_user")
            target["sys_stop"] = read_cgroup_file_value(f"{CGROUP_BASE_PATH}/{target['dir']}/cpuacct.usage_sys")

            if target["user_stop"] is None or target["sys_stop"] is None:
                print(f"Target {target['name']} doesn't exist, it will be removed")
                valid_targets.remove(target)
                continue

            # Process target data ¡¡¡VOY POR AQUI!!!
            elapsed_time = target["stop"] - target["start"]
            user_usage = ((target["user_stop"] - target["user_start"]) / elapsed_time) * 100
            system_usage = ((target["sys_stop"] - target["sys_start"]) / elapsed_time) * 100

            data = f"usage,host={target['name']} user={user_usage},system={system_usage} {timestamp}"
            current_batch.append(data)

        print("[Iteration Completed] Current batch size is {0}. Last iteration delay: {1} seconds".format(len(current_batch), delay))

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
