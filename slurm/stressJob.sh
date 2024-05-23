#!/bin/bash
#SBATCH --nodes=2
#SBATCH --exclusive

module load gnu8
module load openmpi4

# If a STORE directory doesn't exist in your cluster, define it manually.
# STORE=<dir-containing-this-project>

PROJECT_DIR="${STORE}/ContainerPowerWatcher"
SLURM_DIR="${PROJECT_DIR}/slurm"
ANSIBLE_CONFIG_FILE="${PROJECT_DIR}/ansible/provisioning/config/config.yml"

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