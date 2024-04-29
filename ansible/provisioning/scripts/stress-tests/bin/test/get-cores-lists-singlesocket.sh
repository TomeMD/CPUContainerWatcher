#!/bin/bash

export ONLY_P_CORES=()

for ((CORE = 0; CORE < ${#CORES_DICT[@]}; CORE += 1)); do
    IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
    ONLY_P_CORES+=("${LOGICAL_CORES[0]}")
done

export TEST_P_AND_L_CORES=()

for ((CORE = 0; CORE < ${#CORES_DICT[@]}; CORE += 1)); do
    IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
    TEST_P_AND_L_CORES+=("${LOGICAL_CORES[0]}")
    if [ -n "${LOGICAL_CORES[1]}" ];then
      TEST_P_AND_L_CORES+=("${LOGICAL_CORES[1]}")
    fi
done

export TEST_1P_2L_CORES=()

for LOGICAL_CORE in 0 1; do # First physical cores then logical cores
  for ((CORE = 0; CORE < ${#CORES_DICT[@]}; CORE += 1)); do
      IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
      if [ -n "${LOGICAL_CORES[${LOGICAL_CORE}]}" ];then
        TEST_1P_2L_CORES+=("${LOGICAL_CORES[${LOGICAL_CORE}]}")
      fi
  done
done