#!/bin/bash

# Global directories
export BIN_DIR="${GLOBAL_HOME}"/bin
export TEST_DIR="${BIN_DIR}"/test
export CONF_DIR="${GLOBAL_HOME}"/etc
export LOG_FILE=${LOG_DIR}/${WORKLOAD}.log

# stress-system
export STRESS_HOME="${TOOLS_DIR}"/stress-system
export STRESS_CONTAINER_DIR="${STRESS_HOME}"/container

. "${BIN_DIR}"/get-hw-info.sh