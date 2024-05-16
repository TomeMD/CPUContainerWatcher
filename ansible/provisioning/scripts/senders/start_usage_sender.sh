#!/bin/bash
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE}")")
export PYTHONPATH=${PYTHONPATH}:${SCRIPT_DIR}

if [ -z "$2" ]
then
      echo "2 arguments are needed"
      echo "1 -> InfluxDB Bucket"
      echo "2 -> Monitoring node IP address"
      exit 1
fi

INFLUXDB_BUCKET=${1}
MONITORING_NODE_IP=${2}

python3 "${SCRIPT_DIR}"/src/UsageSender.py "${INFLUXDB_BUCKET}" "${MONITORING_NODE_IP}"