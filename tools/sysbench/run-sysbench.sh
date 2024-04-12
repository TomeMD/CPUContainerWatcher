#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Cores list not specified. Aborting..."
  exit 1
fi

CORES_LIST=$1
IFS=',' read -ra CORES_ARRAY <<< "${CORES_LIST}"
NUM_THREADS=${#CORES_ARRAY[@]}

taskset -c "${CORES_LIST}" sysbench --threads="${NUM_THREADS}" cpu run --cpu-max-prime=100000000
