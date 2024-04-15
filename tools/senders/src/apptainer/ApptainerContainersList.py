import subprocess
import json

MAX_FOUND_TRIES = 3


class ApptainerContainersList:

    def __init__(self, privileged=False):
        self.container_names_by_pid = {}
        self.container_not_found_times = {}
        self.privileged = privileged

    def _update_container_names_by_pid(self):
        container_info_json = self.get_running_containers()
        for instance in container_info_json['instances']:
            pid = instance['pid']
            name = instance['instance']
            if pid not in self.container_names_by_pid:
                self.container_names_by_pid[pid] = name
        return self.container_names_by_pid

    def init_container_names_by_pid(self):
        self._update_container_names_by_pid()

    def get_container_list(self):
        return self.container_names_by_pid

    def get_running_containers(self):
        if self.privileged:
            cmd_list = ["sudo", "apptainer", "instance", "list", "-j"]
        else:
            cmd_list = ["apptainer", "instance", "list", "-j"]
        process = subprocess.Popen(cmd_list, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        return json.loads(stdout)

    def get_container_name_by_pid(self, pid):
        if pid in self.container_names_by_pid:
            return self.container_names_by_pid[pid]
        else:
            if pid in self.container_not_found_times:
                self.container_not_found_times[pid] += 1
            else:
                self.container_not_found_times[pid] = 1

            # If container is not found and max tries not exceeded, update containers list
            if self.container_not_found_times[pid] < MAX_FOUND_TRIES:
                self._update_container_names_by_pid()

            return None
