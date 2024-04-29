#!/bin/bash

export GROUP_P_CORES=()

for ((CORE = 0; CORE < ${#CORES_DICT[@]}; CORE += 1)); do
    IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
    GROUP_P_CORES+=("${LOGICAL_CORES[0]}")
done

export SPREAD_P_CORES=()

for ((i = 0; i < (${#CORES_DICT[@]} / 2); i += 2)); do
    for CORE in $i $((i + 1)) $((i + PHY_CORES_PER_CPU)) $((i + PHY_CORES_PER_CPU + 1)); do
      IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
      SPREAD_P_CORES+=("${LOGICAL_CORES[0]}")
    done
done

export GROUP_P_AND_L_CORES=()

for ((CORE = 0; CORE < ${#CORES_DICT[@]}; CORE += 1)); do
    IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
    GROUP_P_AND_L_CORES+=("${LOGICAL_CORES[0]}")
    if [ -n "${LOGICAL_CORES[1]}" ];then
      GROUP_P_AND_L_CORES+=("${LOGICAL_CORES[1]}")
    fi
done

export GROUP_1P_2L_CORES=()
for ((OFFSET = 0; OFFSET <= PHY_CORES_PER_CPU; OFFSET += PHY_CORES_PER_CPU)); do # First CPU0 then CPU1
  for LOGICAL_CORE in 0 1; do # First physical cores then logical cores
    for ((CORE = OFFSET; CORE < (OFFSET + PHY_CORES_PER_CPU); CORE += 1)); do
        IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
        if [ -n "${LOGICAL_CORES[${LOGICAL_CORE}]}" ];then
          GROUP_1P_2L_CORES+=("${LOGICAL_CORES[${LOGICAL_CORE}]}")
        fi
    done
  done
done

export GROUP_PP_LL_CORES=()

for LOGICAL_CORE in 0 1; do # First physical cores then logical cores
  for ((CORE = 0; CORE < ${#CORES_DICT[@]}; CORE += 1)); do
      IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
      if [ -n "${LOGICAL_CORES[${LOGICAL_CORE}]}" ];then
        GROUP_PP_LL_CORES+=("${LOGICAL_CORES[${LOGICAL_CORE}]}")
      fi
  done
done

export SPREAD_P_AND_L_CORES=()

for ((i = 0; i < (${#CORES_DICT[@]} / 2); i += 1)); do
    for CORE in $i $((i + PHY_CORES_PER_CPU)); do
      IFS=',' read -ra LOGICAL_CORES <<< "${CORES_DICT[$CORE]}"
      SPREAD_P_AND_L_CORES+=("${LOGICAL_CORES[0]}")
      if [ -n "${LOGICAL_CORES[1]}" ];then
        SPREAD_P_AND_L_CORES+=("${LOGICAL_CORES[1]}")
      fi
    done
done