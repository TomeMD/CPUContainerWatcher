#!/bin/bash
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE}")")
export PYTHONPATH=${PYTHONPATH}:${SCRIPT_DIR}

if [ -z "$1" ]
then
      echo "1 argument is needed"
      echo "1 -> InfluxDB Bucket"
      exit 1
fi
INFLUXDB_BUCKET=${1}

python3 "${SCRIPT_DIR}"/src/usage_sender.py "${INFLUXDB_BUCKET}"