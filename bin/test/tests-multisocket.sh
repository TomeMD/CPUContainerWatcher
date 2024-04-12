#!/bin/bash

. "${TEST_DIR}"/get-cores-lists-multisocket.sh

# Initial wait
sleep 30

# Start tests
START=$(date +%s%N)

################################################################################################
# Group_P: First CPU0 physical cores, then CPU1 physical cores
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Group_P.timestamps
run_experiment "Group_P" "run_${WORKLOAD}" "${GROUP_P_CORES[@]}"

################################################################################################
# Spread_P: Switching CPU cores, 2 cores from CPU0, then 2 cores from CPU1, then 2 from CPU0...
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Spread_P.timestamps
run_experiment "Spread_P" "run_${WORKLOAD}" "${SPREAD_P_CORES[@]}"

################################################################################################
# Group_P&L: Load by pairs of physical and logical cores, first CPU0, then CPU1.
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Group_P_and_L.timestamps
run_experiment "Group_P&L" "run_${WORKLOAD}" "${GROUP_P_AND_L_CORES[@]}"

################################################################################################
# Group_1P_2L: First physical cores, then logical cores. First load CPU0 until all physical and 
# logical cores are loaded at 100%, then do the same with CPU1.
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Group_1P_2L.timestamps
run_experiment "Group_1P_2L" "run_${WORKLOAD}" "${GROUP_1P_2L_CORES[@]}"

################################################################################################
# Group_PP_LL: First physical cores from both CPUs, then logical cores from both CPUs.
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Group_PP_LL.timestamps
run_experiment "Group_PP_LL" "run_${WORKLOAD}" "${GROUP_PP_LL_CORES[@]}"

################################################################################################
# Spread_P&L: Load by pairs switching CPUs. One pair (physical core + logical core) from CPU0, 
# then from CPU1, then from CPU0...
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Spread_P_and_L.timestamps
run_experiment "Spread_P&L" "run_${WORKLOAD}" "${SPREAD_P_AND_L_CORES[@]}"

################################################################################################
END=$(date +%s%N)
NAME="TOTAL"
print_time START END