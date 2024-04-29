#!/bin/bash
# Custom tests file to stress only 1 CPU from a multisocket server with 2 CPUs
# Core numbering of the target server is:
#   0-15 physical cores CPU0
#   16-31 physical cores CPU1
#   32-47 logical cores CPU0
#   48-63 logical cores CPU1

# Initial wait
sleep 30

# Start tests
START=$(date +%s%N)

################################################################################################
# Only_P: Only CPU0 physical cores in order
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Only_P.timestamps
CORES_ARRAY=("0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15")
run_experiment "Only_P" "run_${WORKLOAD}" "${CORES_ARRAY[@]}"

################################################################################################
# Test_P&L: Load by pairs of physical and logical cores from CPU0
################################################################################################
TIMESTAMPS_FILE=${LOG_DIR}/Test_P_and_L.timestamps
CORES_ARRAY=("0" "32" "1" "33" "2" "34" "3" "35" "4" "36" "5" "37" "6" "38" "7" "39" "8" "40" "9" "41" "10" "42" "11" "43" "12" "44" "13" "45" "14" "46" "15" "47")
run_experiment "Test_P&L" "run_${WORKLOAD}" "${CORES_ARRAY[@]}"

################################################################################################
# Test_1P_2L: First CPU0 physical cores, then CPU0 logical cores.
################################################################################################
CORES_ARRAY=("0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "32" "33" "34" "35" "36" "37" "38" "39" "40" "41" "42" "43" "44" "45" "46" "47")
TIMESTAMPS_FILE=${LOG_DIR}/Test_1P_2L.timestamps
run_experiment "Test_1P_2L" "run_${WORKLOAD}" "${CORES_ARRAY[@]}"
################################################################################################
END=$(date +%s%N)
NAME="TOTAL"
print_time START END