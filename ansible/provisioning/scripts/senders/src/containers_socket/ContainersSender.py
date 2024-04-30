import socket
import json

MONITORING_NODE_PORT = 22222

class ContainersSender:

    monitoring_node_ip = None
    logger = None

    def __init__(self, monitoring_node_ip, logger):
        self.monitoring_node_ip = monitoring_node_ip
        self.monitoring_node_port = MONITORING_NODE_PORT 
        self.logger = logger

    def send_containers_to_monitoring_node(self, containers):
        self.logger.info(f"Container list updated. Sending data to monitoring node {self.monitoring_node_ip}")
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            try:
                sock.connect((self.monitoring_node_ip, self.monitoring_node_port))
                sock.sendall(json.dumps(containers).encode('utf-8'))
            except Exception as e:
                self.logger.error(f"Error while sending containers data to monitoring node: {str(e)}")
                self.logger.error(f"Container data: {containers}")