#!/bin/bash

. "${TEST_DIR}"/get-sequential-cores-list.sh

# Initial wait
sleep 30

START=$(date +%s%N)

NAME="STRESS-IO"
TIMESTAMPS_FILE=${LOG_DIR}/fio.timestamps
run_fio "${SEQUENTIAL_CORES[@]}"

END=$(date +%s%N)
NAME="TOTAL"
print_time START END