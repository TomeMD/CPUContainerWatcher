# ContainerPowerWatcher: Collect Container Time Series while Running Workloads

Ansible project to automate container monitoring and time series storage while running workloads. Options:

## Requirements

If you don't have installed Ansible, please install it. Here you have the instructions to [install Ansible on specific operating systems](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html).
Update Git Submodules to get the necessary tools under the ./tool directory:

## Quickstart
Modify `ansible/provisioning/config/config.yml` to set your environment. Then run:

```shell
bash ./ansible/provisioning/scripts/start_all.sh
```

Once the execution has finished you can see the timestamps corresponding to each of the experiments executed under the `./timestamps` directory. The name of the directory depends on the stressors and type of load specified. The latter being only included when 'cpu' stressor is used. For example, with the following configuration:
```yaml
# Stress tests workload
workload: stress-system

# If stress-system is used it can be configured here
stressors: cpu,sysinfo
load_types: all # Only relevant when using cpu as stressor
```
The timestamps files will be stored at `./timestamps/cpu_sysinfo_all/`. Note that there will be one timestamps file for each of the cores distribution used.


## Slurm
As this project is intended to be run on two nodes, one monitoring node and one monitored (target) node, you can easily run this project on a cluster through slurm jobs. Under the `./slurm` directory you will find an example script to run this tool with 4 different configurations in an automated way. Run:

```shell
sbatch -t HH:MM:SS -p <your-node-partition> -o <your-log-file> ./slurm/slurmJob.sh
```

Afterwards you will only have to wait until the experiments are finished. All the metrics obtained will be stored as time series in the InfluxDB database you have previously specified and its corresponding timestamps under `./timestamps` directory. 

*NOTE: If you use the default provided database, please use the bucket named `public`.*
