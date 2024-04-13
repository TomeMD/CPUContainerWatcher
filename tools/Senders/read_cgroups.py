import os
import subprocess

CGROUP_PATH = "/sys/fs/cgroup"


def get_cgroup_file_path(container_id, resource, cgroup_file, container_engine):

    if container_engine == "apptainer":
        container_pid = container_id
        return "/".join([CGROUP_PATH, resource, "system.slice", "apptainer-{0}.scope".format(container_pid), cgroup_file])
    elif container_engine == "docker":
        print("Pending to implement")
    else:
        raise Exception("Error: a non-valid container engine was specified")


def read_cgroup_file_value(file_path):
    # Read only 1 line for these files as they are 'virtual' files
    try:
        if os.path.isfile(file_path) and os.access(file_path, os.R_OK):
            with open(file_path, 'r') as file_handler:
                value = file_handler.readline().rstrip("\n")
            return {"success": True, "data": value}
        else:
            return {"success": False, "error": "Couldn't access file: {0}".format(file_path)}
    except IOError as e:
        return {"success": False, "error": str(e)}