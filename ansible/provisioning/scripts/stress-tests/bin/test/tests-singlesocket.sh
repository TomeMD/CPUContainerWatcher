#!/bin/bash

. "${TEST_DIR}"/get-cores-lists-singlesocket.sh

# Initial wait
sleep 30

# Start tests
START=$(date +%s%N)

################################################################################################
# Only_P: Only physical cores in order
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Only_P.timestamps
run_experiment "Only_P" "run_${WORKLOAD}" "${ONLY_P_CORES[@]}"

################################################################################################
# Test_P&L: Load by pairs of physical and logical cores
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Test_P_and_L.timestamps
run_experiment "Test_P&L" "run_${WORKLOAD}" "${TEST_P_AND_L_CORES[@]}"

################################################################################################
# Test_1P_2L: First physical cores, then logical cores.
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Test_1P_2L.timestamps
run_experiment "Test_1P_2L" "run_${WORKLOAD}" "${TEST_1P_2L_CORES[@]}"

################################################################################################
END=$(date +%s%N)
NAME="TOTAL"
print_time START END