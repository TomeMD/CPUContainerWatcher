import os
import sys
import time
import pandas as pd
from datetime import datetime, timezone, timedelta
from ansible.parsing.dataloader import DataLoader
from ansible.inventory.manager import InventoryManager

from src.Sender import Sender
from src.containers_socket.ContainersReceiver import ContainersReceiver

POLLING_FREQUENCY = 5
GLOBAL_TARGETS = ["rapl", "global"]


class PowerSender(Sender):

    def __init__(self, influxdb_bucket, smartwatts_output, ansible_inventory_file):
        super().__init__(influxdb_bucket, "power_sender")
        self.output_file = {}
        self.last_read_position = {}
        self.start_timestamp = datetime.now(timezone.utc)
        self.smartwatts_output = smartwatts_output
        self.target_node = self.get_target_node(ansible_inventory_file)
        self.containers_receiver = ContainersReceiver(self.logger, self.target_node)

    @staticmethod
    def get_target_node(ansible_inventory_file):
        loader = DataLoader()
        ansible_inventory = InventoryManager(loader=loader, sources=ansible_inventory_file)
        return ansible_inventory.get_groups_dict()['target'][0]

    def __start_containers_receiver(self):
        self.containers_receiver.create_thread()

    def __stop_containers_receiver(self):
        self.containers_receiver.stop_thread()

    def aggregate_and_send_data(self, bulk_data, host):
        # Aggregate data by cpu (mean) and timestamp (sum)
        if len(bulk_data) > 0:
            agg_data = pd.DataFrame(bulk_data).groupby(['timestamp', 'cpu']).agg({'value': 'mean'}).reset_index().groupby('timestamp').agg({'value': 'sum'}).reset_index()

            # Format data to InfluxDB line protocol
            target_metrics = []
            for _, row in agg_data .iterrows():
                data = f"power,host={host} value={row['value']} {int(row['timestamp'].timestamp() * 1e9)}"
                target_metrics.append(data)

            # Send data to InfluxDB
            self.send_data_to_influxdb(target_metrics)

    def get_data_from_lines(self, lines, target):
        bulk_data = []
        for line in lines:
            # line example: <timestamp> <sensor> <target> <value> ...
            fields = line.strip().split(',')
            num_fields = len(fields)
            if num_fields < 4:
                raise Exception(f"Missing some fields in SmartWatts output for "
                                f"target {target} ({num_fields} out of 4 expected fields)")

            # SmartWatts timestamps are 2 hours ahead from UTC (UTC-02:00)
            # Normalize timestamps to UTC (actually UTC-02:00) and add 2 hours to get real UTC
            data = {
                "timestamp": datetime.fromtimestamp(int(fields[0]) / 1000, timezone.utc) + timedelta(hours=2),
                "value": float(fields[3]),
                "cpu": int(fields[4])
            }

            # Only data obtained after the start of this program are sent
            if data["timestamp"] < self.start_timestamp:
                continue
            bulk_data.append(data)
        return bulk_data

    def read_and_send_target_output(self, output_path, current_position, target):
        num_lines = 0
        new_position = None
        try:
            if os.path.isfile(output_path) and os.access(output_path, os.R_OK):
                # Read target output
                with open(output_path, 'r') as file:
                    # If file is empty, skip
                    if os.path.getsize(output_path) <= 0:
                        self.logger.warning(f"Target {target} file is empty: {output_path}")
                        return num_lines, new_position

                    # Go to last read position
                    file.seek(current_position)

                    # Skip header
                    if current_position == 0:
                        next(file)

                    lines = file.readlines()
                    num_lines = len(lines)
                    if num_lines == 0:
                        self.logger.warning(f"There aren't new lines to process for target {target}")
                        return num_lines, new_position

                    new_position = file.tell()

                    # Gather data from target output
                    bulk_data = self.get_data_from_lines(lines, target)

                    # Aggregate data by cpu (mean) and timestamp (sum)
                    self.aggregate_and_send_data(bulk_data, target)
            else:
                self.logger.error(f"Couldn't access file: {output_path}")

        except IOError as e:
            self.logger.error(f"Error while reading {output_path}: {str(e)}")

        finally:
            return num_lines, new_position

    def process_containers(self):

        iter_count = {"targets": 0, "lines": 0}

        for container in self.containers_receiver.get_running_containers():

            cont_pid = container["pid"]
            cont_name = container["name"]

            # If target is not registered, initialize it
            if cont_pid not in self.output_file:
                self.logger.info(f"Found new target with name {cont_name} and pid {cont_pid}. Registered.")
                self.output_file[cont_pid] = f"{self.smartwatts_output}/sensor-apptainer-{cont_pid}/PowerReport.csv"
                self.last_read_position[cont_pid] = 0

            if not os.path.isfile(self.output_file[cont_pid]) or not os.access(self.output_file[cont_pid], os.R_OK):
                self.logger.warning(f"Couldn't access file from target {container['name']}: {self.output_file[cont_pid]}")
                continue

            processed_lines, new_position = self.read_and_send_target_output(self.output_file[cont_pid],
                                                                    self.last_read_position[cont_pid],
                                                                    cont_name)

            if processed_lines > 0:
                iter_count["targets"] += 1
                iter_count["lines"] += processed_lines

            if new_position is not None:
                self.last_read_position[cont_pid] = new_position

        return iter_count

    def init_global_target_files(self):
        for target in GLOBAL_TARGETS:
            self.output_file[target] = f"{self.smartwatts_output}/sensor-{target}/PowerReport.csv"
            self.last_read_position[target] = 0

    def process_global_targets(self):
        iter_count = {"targets": 0, "lines": 0}

        for target in GLOBAL_TARGETS:

            if not os.path.isfile(self.output_file[target]) or not os.access(self.output_file[target], os.R_OK):
                self.logger.warning(f"Couldn't access file from target {target}: {self.output_file[target]}")
                continue

            processed_lines, new_position = self.read_and_send_target_output(self.output_file[target],
                                                                    self.last_read_position[target],
                                                                    target)
            if processed_lines > 0:
                iter_count["targets"] += 1
                iter_count["lines"] += processed_lines

            if new_position is not None:
                self.last_read_position[target] = new_position

        return iter_count

    def send_power(self):
        # Create log files and set logger
        self._init_logging_config()

        # Get InfluxDB session
        self._start_influxdb_client()

        # Start ContainersReceiver thread
        self.__start_containers_receiver()

        # Initialize global target files as they are previously known
        self.init_global_target_files()

        # Read SmartWatts output and get targets
        try:
            while True:
                t_start = time.perf_counter_ns()

                iter_count = self.process_containers()
                global_iter_count = self.process_global_targets()

                t_stop = time.perf_counter_ns()
                delay = (t_stop - t_start) / 1e9
                self.logger.info(f"Processed {iter_count['targets'] + global_iter_count ['targets']} targets "
                                 f"({iter_count['targets']} containers + {global_iter_count ['targets']} global) "
                                 f"and {iter_count['lines'] + global_iter_count ['lines']} lines "
                                 f"causing a delay of {delay} seconds")

                # Avoids negative sleep times when there is a high delay
                if delay > POLLING_FREQUENCY:
                    self.logger.warning(f"High delay ({delay}) causing negative sleep times. "
                                        f"Waiting until the next {POLLING_FREQUENCY}s cycle")
                    delay = delay % POLLING_FREQUENCY
                time.sleep(POLLING_FREQUENCY - delay)

        except Exception as e:
            self.logger.error(f"Unexpected error: {str(e)}")

        finally:
            self._stop_influxdb_client()
            self.__stop_containers_receiver()


if __name__ == "__main__":
    if len(sys.argv) < 4:
        raise Exception("Missing some arguments: power_sender.py <INFLUXDB_BUCKET> <SMARTWATTS_OUTPUT> <ANSIBLE_INVENTORY_FILE>")

    influxdb_bucket = sys.argv[1]
    smartwatts_output = sys.argv[2]
    ansible_inventory_file = sys.argv[3]

    try:
        power_sender = PowerSender(influxdb_bucket, smartwatts_output, ansible_inventory_file)
        power_sender.send_power()
    except Exception as e:
        raise Exception(f"Error while trying to create PowerSender instance: {str(e)}")
