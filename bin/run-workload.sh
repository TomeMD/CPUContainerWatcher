#!/bin/bash

m_echo "Running ${WORKLOAD} tests..."

if [ "${CUSTOM_TESTS}" -ne "0" ];then
  m_echo "Custom tests mode is active. Running custom tests from ${CUSTOM_TESTS_FILE}"
  . "${CUSTOM_TESTS_FILE}"
elif [ "${WORKLOAD}" == "npb" ]; then
  . "${TEST_DIR}"/npb-tests.sh
elif [ "${WORKLOAD}" == "spark" ]; then
  . "${TEST_DIR}"/spark-tests.sh
elif [ "${WORKLOAD}" == "fio" ]; then
  . "${TEST_DIR}"/fio-tests.sh
else
  if [ "${SOCKETS}" -eq "1" ]; then
    . "${TEST_DIR}"/tests-singlesocket.sh
  elif [ "${SOCKETS}" -eq "2" ]; then
    . "${TEST_DIR}"/tests-multisocket.sh
  else
    m_echo "Number of sockets (${SOCKETS}) not supported"
    m_echo "Aborting tests..."
  fi
fi