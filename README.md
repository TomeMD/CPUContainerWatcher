# CPUPowerWatcher: Collect CPU Time Series while Running Workloads

Set of scripts to automate CPU monitoring and time series storage while running workloads. Options:

# Quickstart

Update Git Submodules to get the necessary tools under the ./tool directory:

```shell
git submodule update --init --recursive
```

Then you can CPUPowerWatcher using `run.sh`.

## Options

````shell
~$ ./run.sh --help

Usage: run.sh [OPTIONS]
  -v, --os-virt             Technology for OS-level virtualization. [Default]
                                docker
                                apptainer
  -i, --influxdb-host       InfluxDB host to send metrics. [Default: montoxo.des.udc.es]
  -b, --influxdb-bucket     InfluxDB bucket to store metrics. [Default: public]
  -w, --workload            Workload to stress the system with. [Default: stress-system]
                              npb                 Run NPB kenerls.
                              sysbench            Run Sysbench kernels.
                              geekbench           Run Geekbench kenerls.
                              fio                 Run fio to make random reads/writes over specified target with
                                                  different numbers of threads.
                                --fio-target      Directory to make random reads/writes. [Default: /tmp/fio]

                              spark               Run Spark-based DNA error correction algorithm (SMusket) using
                                                  Spark Standalone.
                                --spark-data-dir  Directory to store Spark temporary files and Spark Smusket input.
                                                  Input must be a FASTQ file named "input.fastq".

                              stress-system       Run stress tests using stress-system tool. Options:
                                --stressors              Comma-separated list of stressors to run with stress-system.
                                                         [Default: cpu]
                                --stress-load-types      Comma-separated list of types of load to stress the CPU.
                                                         Used together with CPU stressor. [Default: all]
                                --other-options          Comma-separated list of other stress-ng options specified
                                                         in key=value format.

  -o, --output <dir>       Directory (absolute path) to store log files. [Default: ./log]
  --add-io-noise           Run fio to make random reads/writes over specified target while running the specified
                           workload. Use --fio-target to specify target directory. This option is not compatible with
                           fio tests.
  --custom-tests <file>    Use custom tests file to create custom lists of cores to stress.
                           [Default: ./tests/custom-tests.sh]
  -h, --help               Show this help and exit
````





