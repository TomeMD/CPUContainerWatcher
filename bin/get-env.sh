#!/bin/bash

# Global directories
export BIN_DIR="${GLOBAL_HOME}"/bin
export TEST_DIR="${BIN_DIR}"/test
export CONF_DIR="${GLOBAL_HOME}"/etc
export TOOLS_DIR="${GLOBAL_HOME}"/tools
export LOG_FILE=${LOG_DIR}/${WORKLOAD}.log

# CPUCollector
export GLANCES_HOME="${TOOLS_DIR}"/CPUCollector/glances
export CPUFREQ_HOME="${TOOLS_DIR}"/CPUCollector/cpufreq
export RAPL_HOME="${TOOLS_DIR}"/CPUCollector/rapl

# stress-system
export STRESS_HOME="${TOOLS_DIR}"/stress-system
export STRESS_CONTAINER_DIR="${STRESS_HOME}"/container

# NPB
export NPB_HOME="${TOOLS_DIR}"/NPB3.4.2
export NPB_OMP_HOME="${NPB_HOME}"/NPB3.4-OMP
export NPB_MPI_HOME="${NPB_HOME}"/NPB3.4-MPI

# Spark Smusket
export SPARK_HOME="${TOOLS_DIR}"/spark-${SPARK_VERSION}-bin-hadoop"${SPARK_VERSION:0:1}"
export SMUSKET_HOME="${TOOLS_DIR}"/smusket
export PYTHON_HOME="$(which python3)"
export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which java))))"

# Sysbench
export SYSBENCH_HOME="${TOOLS_DIR}"/sysbench

# Fio
export FIO_HOME="${TOOLS_DIR}"/fio

# Geekbench
export GEEKBENCH_HOME="${TOOLS_DIR}"/Geekbench-"${GEEKBENCH_VERSION}"-Linux

. "${BIN_DIR}"/get-hw-info.sh