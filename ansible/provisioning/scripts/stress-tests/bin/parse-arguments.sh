#!/bin/bash

function usage {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]
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
EOF
exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--os-virt)
      OS_VIRT="$2"
      shift 2
      ;;
    -i|--influxdb-host)
      INFLUXDB_HOST="$2"
      shift 2
      ;;
    -b|--influxdb-bucket)
      INFLUXDB_BUCKET="$2"
      shift 2
      ;;
    -w|--workload)
      WORKLOAD="$2"
      shift 2
      ;;
    --fio-target)
      FIO_TARGET="$2"
      shift 2
      ;;
    --spark-data-dir)
      SPARK_DATA_DIR="$2"
      shift 2
      ;;
    --stressors)
      STRESSORS="$2"
      shift 2
      ;;
    --stress-load-types)
      LOAD_TYPES="$2"
      shift 2
      ;;
    --other-options)
      OTHER_OPTIONS="--other ${2} "
      shift 2
      ;;
    -o|--output)
      LOG_DIR="$2"
      shift 2
      ;;
    --add-io-noise)
      ADD_IO_NOISE=1
      shift 1
      ;;
    --custom-tests)
      CUSTOM_TESTS=1
      if [ -n "$2" ];then
        CUSTOM_TESTS_FILE="$2"
        shift 2
      else
        shift 1
      fi
      ;;
    -h|--help)
      usage
      ;;
    *)
    echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

mkdir -p "${LOG_DIR}"