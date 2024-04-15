#!/bin/bash
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE}")")

tmux new -d -s "power_sender" "bash ${SCRIPT_DIR}/start_power_sender.sh ${INFLUXDB_BUCKET} ${SMARTWATTS_HOME}/output"