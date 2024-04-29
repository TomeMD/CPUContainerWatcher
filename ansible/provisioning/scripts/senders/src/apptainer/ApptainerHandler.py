import subprocess
import json

MAX_FOUND_TRIES = 3


class ApptainerHandler:

    def __init__(self, privileged=False):
        self.privileged = privileged 

    def get_remote_running_containers(self, node):
        if self.privileged:
            cmd_list = ["ssh", node, "sudo", "apptainer", "instance", "list", "-j"]
        else:
            cmd_list = ["ssh", node, "apptainer", "instance", "list", "-j"]
        process = subprocess.Popen(cmd_list, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        return json.loads(stdout)

    def get_running_containers(self):
        if self.privileged:
            cmd_list = ["sudo", "apptainer", "instance", "list", "-j"]
        else:
            cmd_list = ["apptainer", "instance", "list", "-j"]
        process = subprocess.Popen(cmd_list, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        return json.loads(stdout)

    def get_running_containers_list(self, node=None):
        running_containers = []
        if node:
            container_info_json = self.get_remote_running_containers(node)
        else:
            container_info_json = self.get_running_containers()
        
        for instance in container_info_json['instances']:
            container = {"name": instance['instance'], "pid": instance['pid']}
            running_containers.append(container)
        return running_containers
