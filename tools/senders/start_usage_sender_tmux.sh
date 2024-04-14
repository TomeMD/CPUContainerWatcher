#!/bin/bash
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE}")")

tmux new -d -s "usage_sender" "bash ${SCRIPT_DIR}/start_usage_sender.sh"