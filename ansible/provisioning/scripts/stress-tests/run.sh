#!/bin/bash

export GLOBAL_HOME=`cd $(dirname "$0"); pwd`

# Get initial configuration
. "${GLOBAL_HOME}"/etc/default-conf.sh
. "${GLOBAL_HOME}"/bin/parse-arguments.sh
. "${GLOBAL_HOME}"/bin/get-env.sh
. "${BIN_DIR}"/functions.sh
. "${BIN_DIR}"/check-arguments.sh

# Run workload
. "${BIN_DIR}"/run-workload.sh

# Close environment
. "${BIN_DIR}"/finish.sh

