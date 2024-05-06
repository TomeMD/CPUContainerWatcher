#!/bin/bash
#SBATCH --nodes=2
#SBATCH --exclusive

module load gnu8
module load openmpi4

cleanup()
{
    echo "Cleanup called at $(date)" 
    bash ./ansible/provisioning/scripts/stop_all.sh
}

# Save sbatch job PID
echo $$ > /tmp/${SLURM_JOB_ID}_pid
sleep 10

bash ./ansible/provisioning/scripts/start_all.sh

trap 'cleanup' SIGCONT SIGTERM USR1

TIME_LIMIT=`squeue -j $SLURM_JOB_ID --Format=timelimit -h`
IFS='-' read -r DAYS OTHER <<< "${TIME_LIMIT}"
IFS=':' read -r HOURS MINUTES SECONDS <<< "${OTHER}"
SLEEP_TIME=$(( DAYS*86400 + HOURS*3600 + MINUTES*60 + SECONDS ))

echo "Going to sleep for ${SLEEP_TIME} seconds"

# Hold job until timeout or a scancel is sent
sleep ${SLEEP_TIME} &
wait