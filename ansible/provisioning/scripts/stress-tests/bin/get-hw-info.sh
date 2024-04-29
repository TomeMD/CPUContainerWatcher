#!/bin/bash

export PHY_CORES_PER_CPU=$(lscpu | grep "Core(s) per socket:" | awk '{print $4}')
export SOCKETS=$(lscpu | grep "Socket(s):" | awk '{print $2}')
export THREADS=$((PHY_CORES_PER_CPU * SOCKETS * 2))

# CORES_DICT stores each physical core as key and its logical cores as value
declare -A CORES_DICT
output=$(lscpu -e | awk 'NR > 1 { print $1, $4 }')
while read -r cpu core; do
    if [ -z "${CORES_DICT[$core]}" ]; then
        CORES_DICT["$core"]="$cpu"
    else
        CORES_DICT["$core"]="${CORES_DICT[$core]},$cpu"
    fi
done <<< "$output"