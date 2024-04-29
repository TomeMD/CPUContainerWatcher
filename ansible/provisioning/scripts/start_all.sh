#!/usr/bin/env bash
set -e

scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")

export ANSIBLE_INVENTORY=${scriptDir}/../../ansible.inventory

## Copy ansible.cfg to $HOME
cp ${scriptDir}/../../ansible.cfg ~/.ansible.cfg

if [ ! -z ${SLURM_JOB_ID} ]
then
    pip3 install ruamel.yaml
    echo "Loading ansible inventory from SLURM config"
    python3 ${scriptDir}/load_config_from_slurm.py
fi

# This is useful in case we need to use a newer version of ansible installed in $HOME/.local/bin
export PATH=$HOME/.local/bin:$PATH

## Install required ansible collections
ansible-galaxy collection install ansible.posix:==1.5.0

echo ""
echo "Installing necessary services and programs..."
ansible-playbook ${scriptDir}/../install_playbook.yml -i $ANSIBLE_INVENTORY
echo "Install Done!"

source /etc/environment
# Repeat the export command in case the /etc/environment file overwrites the PATH variable
export PATH=$HOME/.local/bin:$PATH

echo "Launching services..."
ansible-playbook ${scriptDir}/../launch_playbook.yml -i $ANSIBLE_INVENTORY
echo "Launch Done!"