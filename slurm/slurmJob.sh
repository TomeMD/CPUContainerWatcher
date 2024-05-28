#!/bin/bash
#SBATCH --job-name=ContainerPowerWatcher
#SBATCH --nodes=2
#SBATCH --exclusive

module load gnu8
module load openmpi4

bash startJob.sh

if [ $? -eq 0 ]; then
    echo "Job script executed successfully"
else
    echo "Job script failed"
fi