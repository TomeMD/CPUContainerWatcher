#!/bin/bash
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "${BASH_SOURCE}")")
export PYTHONPATH=${PYTHONPATH}:${SCRIPT_DIR}

python3 "${SCRIPT_DIR}"/src/usage_sender.py