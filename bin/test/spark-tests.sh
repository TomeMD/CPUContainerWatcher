#!/bin/bash

. "${TEST_DIR}"/get-sequential-cores-list.sh

# Initial wait
sleep 30

START=$(date +%s%N)

NAME="SMUSKET"
TIMESTAMPS_FILE=${LOG_DIR}/Spark_Smusket.timestamps
run_spark "${SEQUENTIAL_CORES[@]}"

END=$(date +%s%N)
NAME="TOTAL"
print_time START END