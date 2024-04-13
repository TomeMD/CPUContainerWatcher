#!/bin/bash

if [ $# -ne 3 ]; then
  echo "Error: Missing some arguments"
  echo "Usage: $0 <CORES_LIST> <INFLUXDB_HOST> <INFLUXDB_BUCKET>"
  exit 1
fi

CORES_LIST=$1
IFS=',' read -ra CORES_ARRAY <<< "${CORES_LIST}"
INFLUXDB_HOST=$2
INFLUXDB_BUCKET=$3

function compute_core_utilization() {
  declare -a CPU_TIMES=($(echo "${PROC_LINES}" | grep "^cpu${CORE} "))
  local TOTAL_TIME=0
  for TIME in "${CPU_TIMES[@]}"; do
    TOTAL_TIME=$((TOTAL_TIME + TIME))
  done

  local DIFF_USER=$((CPU_TIMES[1] - PREV_USER[CORE]))
  local DIFF_SYSTEM=$((CPU_TIMES[3] - PREV_SYSTEM[CORE]))
  local DIFF_IOWAIT=$((CPU_TIMES[5] - PREV_IOWAIT[CORE]))
  local DIFF_TOTAL=$((TOTAL_TIME - PREV_TOTAL[CORE]))

  USER_UTIL_CORE=$((100 * DIFF_USER / DIFF_TOTAL))
  SYSTEM_UTIL_CORE=$((100 * DIFF_SYSTEM / DIFF_TOTAL))
  IOWAIT_UTIL_CORE=$((100 * DIFF_IOWAIT / DIFF_TOTAL))

  PREV_USER[$CORE]=${CPU_TIMES[1]}
  PREV_SYSTEM[$CORE]=${CPU_TIMES[3]}
  PREV_IOWAIT[$CORE]=${CPU_TIMES[5]}
  PREV_TOTAL[$CORE]=${TOTAL_TIME}
}

function read_cpu_temperature() {

    for FILE in /sys/class/thermal/thermal_zone*/temp; do
        TEMP=$(cat "$FILE")
        TOTAL_TEMP=$((TOTAL_TEMP + TEMP))
    done
    TOTAL_TEMP=$((TOTAL_TEMP / 1000))
}


declare -a PREV_USER
declare -a PREV_SYSTEM
declare -a PREV_IOWAIT
declare -a PREV_TOTAL

for CORE in "${CORES_ARRAY[@]}"; do
  PREV_USER[${CORE}]=0
  PREV_SYSTEM[${CORE}]=0
  PREV_IOWAIT[${CORE}]=0
  PREV_TOTAL[${CORE}]=0
done


while true; do
    TOTAL_FREQ=0
    TOTAL_TEMP=0
    USER_UTIL=0
    SYSTEM_UTIL=0
    IOWAIT_UTIL=0
    PROC_LINES=$(cat /proc/stat)
    read_cpu_temperature
    for CORE in "${CORES_ARRAY[@]}"; do
      FREQ_CORE=$(<"/sys/devices/system/cpu/cpu${CORE}/cpufreq/scaling_cur_freq")
      compute_core_utilization
      TOTAL_FREQ=$((TOTAL_FREQ + FREQ_CORE))
      USER_UTIL=$((USER_UTIL + USER_UTIL_CORE))
      SYSTEM_UTIL=$((SYSTEM_UTIL + SYSTEM_UTIL_CORE))
      IOWAIT_UTIL=$((IOWAIT_UTIL + IOWAIT_UTIL_CORE))
    done
    AVG_FREQ=$((TOTAL_FREQ / ${#CORES_ARRAY[@]} / 1000))

    # Send data to InfluxDB
    TIMESTAMP=$(date +%s%N)
    DATA="cpu_metrics freq=${AVG_FREQ} user=${USER_UTIL} system=${SYSTEM_UTIL} iowait=${IOWAIT_UTIL} temp=${TOTAL_TEMP} ${TIMESTAMP}"
    curl -s -XPOST "http://${INFLUXDB_HOST}:8086/api/v2/write?org=MyOrg&bucket=${INFLUXDB_BUCKET}" --header "Authorization: Token MyToken" --data-binary "${DATA}"
    sleep 1
done