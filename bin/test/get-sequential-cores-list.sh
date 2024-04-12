#!/bin/bash

export SEQUENTIAL_CORES=()

for ((CORE = 0; CORE < "${THREADS}"; CORE += 1)); do
    SEQUENTIAL_CORES+=("${CORE}")
done