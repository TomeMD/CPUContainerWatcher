import os
import yaml
import logging
from influxdb_client import InfluxDBClient
from influxdb_client.client.exceptions import InfluxDBError
from influxdb_client.client.write_api import SYNCHRONOUS

from src.utils.MyUtils import MyUtils


SCRIPT_PATH = os.path.abspath(__file__)
SCRIPT_DIR = os.path.dirname(SCRIPT_PATH)
SENDERS_DIR = os.path.dirname(SCRIPT_DIR)
INFLUXDB_CONFIG_FILE = f"{SENDERS_DIR}/influxdb/config.yml"
LOG_DIR = f"{SENDERS_DIR}/log"


class Sender:

    def __init__(self, influxdb_bucket, sender_name):

        # InfluxDB configuration
        self.influxdb_bucket = influxdb_bucket
        self.influxdb_config_file = INFLUXDB_CONFIG_FILE
        self.influxdb_client = None

        # Logging configuration
        self.sender_name = sender_name
        self.log_dir = LOG_DIR
        self.log_file = f"{LOG_DIR}/{self.sender_name}.log"
        self.logger = logging.getLogger(self.sender_name)

    def __start_influxdb_client(self):
        with open(self.influxdb_config_file, "r") as f:
            influxdb_config = yaml.load(f, Loader=yaml.FullLoader)
        # Get session to InfluxDB
        influxdb_url = f"http://{influxdb_config['influxdb_host']}:8086"
        self.influxdb_client = InfluxDBClient(url=influxdb_url,
                                              token=influxdb_config['influxdb_token'],
                                              org=influxdb_config['influxdb_org'])

    def __stop_influxdb_client(self):
        self.influxdb_client.close()

    def __init_logging_config(self):
        MyUtils.create_dir(self.log_dir)
        MyUtils.clean_log_file(self.log_dir, self.log_file)
        logging.basicConfig(filename=self.log_file,
                            level=logging.INFO,
                            format='%(levelname)s (%(name)s): %(asctime)s %(message)s')

    def send_data_to_influxdb(self, data):
        try:
            self.influxdb_client.write_api(write_options=SYNCHRONOUS).write(bucket=self.influxdb_bucket, record=data)
        except InfluxDBError as e:
            self.logger.error(f"Error while sending data to InfluxDB: {e}")
        except Exception as e:
            self.logger.error(f"Unexpected error while sending data to InfluxDB: {e}")