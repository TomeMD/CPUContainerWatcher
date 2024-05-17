import os
import sys
import time
from datetime import datetime, timezone

from src.Sender import Sender
from src.apptainer.ApptainerHandler import ApptainerHandler
from src.containers_socket.ContainersSender import ContainersSender
from src.utils.MyUtils import MyUtils

# Configuration
POLLING_FREQUENCY = 2
MIN_BATCH_SIZE = 10
CGROUP_BASE_PATH = "/sys/fs/cgroup/cpu/system.slice/"

# Hardware info
TICKS_PER_SECOND = os.sysconf(os.sysconf_names['SC_CLK_TCK'])
NS_PER_TICK = 1e9 / TICKS_PER_SECOND


class UsageSender(Sender):

    def __init__(self, influxdb_bucket, monitoring_node_ip, cgroup_base_path=None):
        super().__init__(influxdb_bucket, "usage_sender")
        self.valid_targets = []
        self.current_batch = []
        self.current_batch_length = 0
        self.monitoring_node_ip = monitoring_node_ip
        self.apptainer_handler = ApptainerHandler(privileged=True)
        self.containers_sender = ContainersSender(self.monitoring_node_ip, self.logger)
        self.cgroup_base_path = cgroup_base_path if cgroup_base_path else CGROUP_BASE_PATH
        self.__check_cgroup_base_path()

    def __check_cgroup_base_path(self):
        if not os.path.exists(self.cgroup_base_path):
            msg = f"{self.cgroup_base_path} doesn't exist. Make sure you are using cgroups v1 "
            msg += "and there is at least one apptainer container running"
            self.logger.error(msg)
            raise FileNotFoundError(msg)

    def __add_data_to_batch(self, data):
        self.current_batch.append(data)
        self.current_batch_length += 1

    def __clear_current_batch(self):
        self.current_batch.clear()
        self.current_batch_length = 0

    def get_batch_length(self):
        return self.current_batch_length

    def read_cgroup_file_stat(self, target_dir):
        path = f"{target_dir}/cpuacct.stat"
        values = {"user": None, "system": None}
        try:
            if os.path.isfile(path) and os.access(path, os.R_OK):
                with open(path, 'r') as f:
                    for line in f:
                        fields = line.split()
                        values[fields[0]] = int(fields[1])
            else:
                self.logger.error(f"Couldn't access file: {path}")
        except IOError as e:
            self.logger.error(f"Error while reading {path}: {str(e)}")
        finally:
            return values

    def compute_delay(self, t_start, t_stop):
        delay = (t_start - t_stop) / 1e9
        if delay > POLLING_FREQUENCY:
            self.logger.warning(f"High delay ({delay}) causing negative sleep times. Waiting until the next {POLLING_FREQUENCY}s cycle")
            delay = delay % POLLING_FREQUENCY
        return delay

    def update_valid_targets(self, containers):
        new_targets = []
        for container in containers:
            target_dir = f"{self.cgroup_base_path}/apptainer-{container['pid']}.scope"
            if os.path.isdir(target_dir) and os.access(target_dir, os.R_OK):
                new_targets.append({"name": container["name"], "dir": target_dir})
        self.valid_targets = new_targets

    def setup_counters(self, counter_type):
        if counter_type != "start" and counter_type != "stop":
            raise ValueError("Invalid type. Must be 'start' or 'stop'")

        for target in self.valid_targets:
            target[counter_type] = time.perf_counter_ns()
            tick_values = self.read_cgroup_file_stat(target["dir"])
            if tick_values["user"] is None or tick_values["system"] is None:
                self.valid_targets.remove(target)
            else:
                target[f"user_ticks_{counter_type}"] = tick_values["user"]
                target[f"sys_ticks_{counter_type}"] = tick_values["system"]


    def process_targets_data(self, timestamp):
        for target in self.valid_targets:
            elapsed_time = target["stop"] - target["start"]
            user_usage = ((target["user_ticks_stop"] - target["user_ticks_start"]) * NS_PER_TICK / elapsed_time) * 100
            system_usage = ((target["sys_ticks_stop"] - target["sys_ticks_start"]) * NS_PER_TICK / elapsed_time) * 100

            data = f"usage,host={target['name']} user={user_usage},system={system_usage} {timestamp}"
            self.__add_data_to_batch(data)

    def send_usage(self):
        # Create log files and set logger
        self._init_logging_config()

        # Get session to InfluxDB
        self._start_influxdb_client()

        # Initialize t_stop to compute delay in first iteration properly
        t_stop = time.perf_counter_ns()
        previous_containers = []
        try:
            while True:

                # Get current containers and send them to monitoring node if they have changed
                current_containers = self.apptainer_handler.get_running_containers_list()
                if not MyUtils.dict_lists_are_equal(current_containers, previous_containers, key='pid'):
                    self.containers_sender.send_containers_to_monitoring_node(current_containers)
                    previous_containers = current_containers.copy()

                # Filter and initialize valid targets to process
                self.update_valid_targets(current_containers)

                # Setup start counters for each target
                self.setup_counters(counter_type="start")

                t_start = time.perf_counter_ns()

                # This value represents the total delay since t_stop from previous iteration was computed
                delay = self.compute_delay(t_start, t_stop)
                time.sleep(POLLING_FREQUENCY - delay)

                t_stop = time.perf_counter_ns()
                timestamp = int(datetime.now(timezone.utc).timestamp() * 1e9)

                # Setup stop counters for each target
                self.setup_counters(counter_type="stop")

                # Process target data
                self.process_targets_data(timestamp)
                self.logger.info(f"Current batch size is {self.get_batch_length()}. "
                                 f"Last iteration delay: {delay} seconds")



                # If current batch has at least MIN_BATCH_SIZE data points, send and clear the batch
                if self.get_batch_length() >= MIN_BATCH_SIZE:
                    self.send_data_to_influxdb(self.current_batch)
                    self.__clear_current_batch()

        except Exception as e:
            self.logger.error(f"Unexpected error: {str(e)}")

        finally:
            self._stop_influxdb_client()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise Exception("Missing some arguments: usage_sender.py <INFLUXDB_BUCKET> <MONITORING_NODE_IP>")

    influxdb_bucket = sys.argv[1]
    monitoring_node_ip = sys.argv[2]

    try:
        usage_sender = UsageSender(influxdb_bucket, monitoring_node_ip)
        usage_sender.send_usage()
    except Exception as e:
        raise Exception(f"Error while trying to create UsageSender instance: {str(e)}")