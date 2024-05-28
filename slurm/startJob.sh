#!/bin/bash

SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
PROJECT_DIR=$(dirname -- "${SCRIPT_DIR}")
SLURM_DIR="${PROJECT_DIR}/slurm"
TIMESTAMPS_DIR="${PROJECT_DIR}/timestamps/$(date -u +%Y_%m_%d_%H-%M-%S)"
ANSIBLE_CONFIG_FILE="${PROJECT_DIR}/ansible/provisioning/config/config.yml"
ANSIBLE_VARS_FILE="${PROJECT_DIR}/ansible/provisioning/vars/main.yml"

mkdir -p "${TIMESTAMPS_DIR}"
echo "Setting up base directory for project timestamps: ${TIMESTAMPS_DIR}"
sed -i "s|^project_timestamps_base_dir: .*|project_timestamps_base_dir: \"${TIMESTAMPS_DIR}\"|" "${ANSIBLE_VARS_FILE}"

CONFIGS=("cpu_config" "sysinfo_config" "cpu_sysinfo_config" "iomix_config")

for CURRENT_CONFIG in "${CONFIGS[@]}"; do

  CURRENT_CONFIG_FILE="${SLURM_DIR}/config/${CURRENT_CONFIG}.yml"
  cp "${CURRENT_CONFIG_FILE}" "${ANSIBLE_CONFIG_FILE}"

  echo "Current config is: ${CURRENT_CONFIG_FILE}"
  bash ${PROJECT_DIR}/ansible/provisioning/scripts/start_all.sh
  sleep 120 # Wait 2 minutes before stoping all

  bash ${PROJECT_DIR}/ansible/provisioning/scripts/stop_all.sh
  sleep 300 # Wait 5 minutes between workloads executions

done