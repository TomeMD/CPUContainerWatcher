#!/bin/bash

SUPPORTED_WORKLOADS=("stress-system" "npb" "fio" "spark" "sysbench" "geekbench")
SUPPORTED=0

if [ "${OS_VIRT}" != "docker" ] && [ "${OS_VIRT}" != "apptainer" ]; then
  m_err "OS Virtualization Technology (${OS_VIRT}) not supported. Use 'docker' or 'apptainer'"
  exit 1
fi

if ! [ -x "$(command -v ${OS_VIRT})" ]; then
  m_err "OS Virtualization Technology (${OS_VIRT}) is not installed"
  exit 1
fi

if ! ping -c 1 "${INFLUXDB_HOST}" &> /dev/null; then
  m_err "InfluxDB host (${INFLUXDB_HOST}) is not reachable"
  exit 1
fi

if [ "${CUSTOM_TESTS}" -eq "1" ] && [ ! -f "${CUSTOM_TESTS_FILE}" ]; then
  m_err "Provided custom tests file doesn't exists: ${CUSTOM_TESTS_FILE}"
  exit 1
fi

if [ "${SOCKETS}" -gt "2" ] ; then
  m_err "Number of sockets (${SOCKETS}) not supported. Number of sockets must be 1 or 2"
  exit 1
fi

for SUP_WORKLOAD in "${SUPPORTED_WORKLOADS[@]}"; do
    if [ "${SUP_WORKLOAD}" = "${WORKLOAD}" ]; then
        SUPPORTED=1
        break
    fi
done

if [ "${SUPPORTED}" -eq  "0" ]; then
    m_err "Workload (${WORKLOAD}) not supported. Supported workloads [${SUPPORTED_WORKLOADS[*]}]"
    exit 1
fi

if [ "${WORKLOAD}" == "spark" ]; then
  if [ ! -d "${SPARK_DATA_DIR}" ]; then
    m_err "Specified Spark Data directory doesn't exist: ${SPARK_DATA_DIR}"
    exit 1
  fi
  if [ -z "${JAVA_HOME}" ]; then
    m_err "JAVA_HOME is not set. You must set JAVA_HOME to use Spark"
    exit 1
  fi
  if [ -z "${PYTHON_HOME}" ]; then
    m_err "Python 3 is not installed. You must install Python 3 to use Spark"
    exit 1
  fi
fi

if [ "${WORKLOAD}" == "fio" ] && [ "${ADD_IO_NOISE}" -ne 0 ]; then
  m_warn "It's not consistent to use fio with I/O noise because both run fio"
  sleep 2
fi