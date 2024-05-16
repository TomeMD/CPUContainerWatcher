#!/usr/bin/python

from pathlib import Path
from ruamel.yaml import YAML
import os
import subprocess
import socket


def getHostsInfo():
    config = {"monitoring": {}, "target": {}}
    rc = subprocess.Popen(["scontrol", "show", "hostnames"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = rc.communicate()
    hostlist = output.decode().splitlines()
    if len(hostlist) >= 2:
        config["monitoring"]["name"] = hostlist[0]
        config["monitoring"]["ip"] = socket.gethostbyname(hostlist[0])
        config["target"]["name"] = hostlist[1]
        config["target"]["ip"] = socket.gethostbyname(hostlist[1])
    else:
        raise Exception("Not enough nodes. At least 2 nodes are required: "
                        "One monitoring node and one target (monitored) node")

    print(config)

    return config


def getNodeMemory_scontrol(node):
    rc = subprocess.Popen(["scontrol", "-o", "show", "nodes", node], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output, err = rc.communicate()
    itemlist = output.decode().split(" ")

    allocMem = ""
    for item in itemlist:
        if "AllocMem" in item:
            # We assume that it has format: AllocMem=40960
            allocMem = int(item.split("=")[1])
    if allocMem == "":
        raise Exception("Can't get node Memory")

    return allocMem


def update_ansible_config(config_file, monitoring_node_ip, target_node_ip):
    yaml_utils = YAML()
    yaml_utils.default_flow_style = False
    yaml_utils.preserve_quotes = True
    out = Path(config_file)
    data = yaml_utils.load(out)

    data["monitoring_node_ip"] = monitoring_node_ip
    data["target_node_ip"] = target_node_ip

    yaml_utils.dump(data, out)

def update_inventory_file(inventory_file, monitoring_node, target_node):

    # Server
    with open(inventory_file, 'w') as f:
        content = ["[monitoring]", monitoring_node, "[target]", target_node]
        f.write("\n".join(content))


if __name__ == "__main__":

    scriptDir = os.path.realpath(os.path.dirname(__file__))
    ansible_config_file = scriptDir + "/../config/config.yml"
    inventory_file = scriptDir + "/../../ansible.inventory"

    # Get config values
    config = getHostsInfo()

    # Update ansible config file
    update_ansible_config(ansible_config_file, config["monitoring"]["ip"], config["target"]["ip"])

    # Update ansible inventory file
    update_inventory_file(inventory_file, config["monitoring"]["name"], config["target"]["name"])
