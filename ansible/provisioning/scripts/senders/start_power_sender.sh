#!/bin/bash
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE}")")
export PYTHONPATH=${PYTHONPATH}:${SCRIPT_DIR}

if [ -z "$1" ]
then
      echo "2 arguments are needed"
      echo "1 -> InfluxDB Bucket"
      echo "2 -> SmartWatts output directory"
      exit 1
fi
INFLUXDB_BUCKET=${1}
SMARTWATTS_OUTPUT=${2}

python3 "${SCRIPT_DIR}"/src/power_sender.py "${INFLUXDB_BUCKET}" "${SMARTWATTS_OUTPUT}"