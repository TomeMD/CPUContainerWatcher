#!/bin/bash

export GLOBAL_HOME=`cd $(dirname "$0"); pwd`

# Get initial configuration
. "${GLOBAL_HOME}"/etc/default-conf.sh
. "${GLOBAL_HOME}"/bin/parse-arguments.sh
. "${GLOBAL_HOME}"/bin/get-env.sh
. "${BIN_DIR}"/functions.sh
. "${BIN_DIR}"/check-arguments.sh

print_conf

# Run workload
. "${BIN_DIR}"/run-workload.sh

