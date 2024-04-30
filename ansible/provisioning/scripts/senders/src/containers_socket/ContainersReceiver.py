import threading
import socket
import json

LISTENING_PORT = 22222
MAX_CONNECTIONS = 10

class ContainersReceiver:

    logger = None
    target_node_ip = None
    listening_port = None
    running_containers = None
    keep_running = None
    thread = None

    def __init__(self, logger, target_node):
        self.logger = logger
        self.listening_port = LISTENING_PORT
        self.running_containers = []
        self.keep_running = True
        try:
            self.target_node_ip = socket.gethostbyname(target_node)
        except socket.gaierror as e:
            self.logger.error(f"Error resolving target node hostname '{target_node}': {e}")

    def get_running_containers(self):
        return self.running_containers

    def update_running_containers(self, containers):
        self.running_containers.clear()
        self.running_containers.extend(containers)

    def listen_target_node(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('0.0.0.0', self.listening_port))
            s.listen(MAX_CONNECTIONS)

            while self.keep_running:
                conn, addr = s.accept()
                if addr[0] != self.target_node_ip:
                    self.logger.warning(f"Connection attempt from unauthorized IP: {addr[0]}")
                    conn.close()
                    continue

                with conn:
                    data_buffer = b''
                    while True:
                        data_fragment = conn.recv(1024)
                        if not data_fragment:
                            break
                        data_buffer += data_fragment

                    if data_buffer:
                        try:
                            data = json.loads(data_buffer.decode('utf-8'))
                            self.update_running_containers(data)
                            self.logger.info(f"Updated running containers by {addr}. Current containers: {self.running_containers}")
                        except json.JSONDecodeError as e:
                            self.logger.error(f"Received data couldn't be decoded as JSON: {str(e)}")
                            self.logger.error(f"Data buffer: {data_buffer}")

    def create_thread(self):
        self.thread = threading.Thread(target=self.listen_target_node)
        self.thread.daemon = True
        self.thread.start()
    
    def stop_thread(self):
        self.keep_running = False
        self.thread.join()