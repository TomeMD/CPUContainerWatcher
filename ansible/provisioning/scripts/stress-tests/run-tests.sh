#!/bin/bash

OUTPUT_FILE="${SLURM_JOB_PARTITION}.log"

sleep 10

# All
OUTPUT_DIR=log/${SLURM_JOB_PARTITION}/all/dft
mkdir -p $OUTPUT_DIR
./run.sh -b ${SLURM_JOB_PARTITION} -o $OUTPUT_DIR -v apptainer -w stress-system
cp $OUTPUT_FILE $OUTPUT_DIR
cat /dev/null > $OUTPUT_FILE
sleep 600

# Sysinfo
OUTPUT_DIR=log/${SLURM_JOB_PARTITION}/sysinfo/dft
mkdir -p $OUTPUT_DIR
./run.sh -b ${SLURM_JOB_PARTITION} -o $OUTPUT_DIR -v apptainer -w stress-system --stressors sysinfo
cp $OUTPUT_FILE $OUTPUT_DIR
cat /dev/null > $OUTPUT_FILE
sleep 600

# Sysinfo+All
OUTPUT_DIR=log/${SLURM_JOB_PARTITION}/sysinfo/all
mkdir -p $OUTPUT_DIR
./run.sh -b ${SLURM_JOB_PARTITION} -o $OUTPUT_DIR -v apptainer -w stress-system --stressors cpu,sysinfo
cp $OUTPUT_FILE $OUTPUT_DIR
cat /dev/null > $OUTPUT_FILE
sleep 600

# Iomix SSD
OUTPUT_DIR=log/${SLURM_JOB_PARTITION}/iomix/ssd
mkdir -p $OUTPUT_DIR
./run.sh -b ${SLURM_JOB_PARTITION} -o $OUTPUT_DIR -v apptainer -w stress-system --stressors iomix --other-options temp-path=/scratch2
cp $OUTPUT_FILE $OUTPUT_DIR
cat /dev/null > $OUTPUT_FILE