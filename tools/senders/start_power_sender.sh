#!/bin/bash
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE}")")
export PYTHONPATH=${PYTHONPATH}:${SCRIPT_DIR}

if [ -z "$1" ]
then
      echo "1 arguments is needed"
      echo "1 -> SmartWatts output directory"
      exit 1
fi
SMARTWATTS_OUTPUT=${1}

python3 "${SCRIPT_DIR}"/src/power_sender.py "${SMARTWATTS_OUTPUT}"