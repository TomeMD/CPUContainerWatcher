#!/bin/bash

function get_date {
    DATE=`date '+%d/%m/%Y %H:%M:%S'`
}

export -f get_date

function date_echo() {
    get_date
    echo -e "[$DATE] $@" >> "${OUTPUT_DIR}/cpu-metrics.out"
}

export -f date_echo

function print_microbatch_header() {
  local HEADER="\n"
  for VAR in "${ALL_VARS[@]}"; do
    if [ "${#VAR}" -lt 8 ]; then
      HEADER+="${VAR}\t\t"
    else
      HEADER+="${VAR}\t"
    fi
  done
  echo -e "${HEADER}"
}

export -f print_microbatch_header

function print_output_file_header() {
  date_echo $(print_microbatch_header)
}

export -f print_output_file_header

function print_iter_metrics() {
  local MESSAGE=""
  for VAR in "${ALL_VARS[@]}"; do
    MESSAGE+="${ITER_CPU_METRICS["${VAR}"]}\t\t"
  done
  echo -e "${MESSAGE}"
  date_echo "${MESSAGE}"
}

export -f print_iter_metrics

function encode_json_microbatch() {
  JSON_BATCH="{"
  for VAR in "${MODEL_VARS[@]}"; do
    JSON_BATCH+=" \"${VAR}\": [${CPU_METRICS[${VAR}]}],"
  done
  JSON_BATCH+=" \"power\": [${CPU_METRICS["power"]}]}"
}

export -f encode_json_microbatch

function update_microbatch() {
  local SEPARATOR
  if [ "${CPU_METRICS_EMPTY}" -eq 1 ]; then
    SEPARATOR=""
    CPU_METRICS_EMPTY=0
  elif [ "${CPU_METRICS_EMPTY}" -eq 0 ]; then
    SEPARATOR=","
  fi
  for VAR in "${MODEL_VARS[@]}"; do
    CPU_METRICS["${VAR}"]+="${SEPARATOR}${ITER_CPU_METRICS["${VAR}"]}"
  done
  CPU_METRICS["power"]+="${SEPARATOR}${ITER_CPU_METRICS["power"]}"
}

export -f update_microbatch

function init_all_vars_array() {
  ALL_VARS=("${MODEL_VARS[@]}")
  ALL_VARS+=("power")
  for METHOD in "${PREDICTION_METHODS[@]}"; do
    ALL_VARS+=("${METHOD}")
  done
}

export -f init_all_vars_array

function init_prev_cores_arrays() {
  for CORE in "${CORES_ARRAY[@]}"; do
    PREV_USER[${CORE}]=0
    PREV_SYSTEM[${CORE}]=0
    PREV_IOWAIT[${CORE}]=0
    PREV_TOTAL[${CORE}]=0
  done
}

export -f init_prev_cores_arrays

function reset_cpu_metrics_dict() {
  for VAR in "${MODEL_VARS[@]}"; do
      CPU_METRICS[${VAR}]=""
  done
  CPU_METRICS["power"]=""
  CPU_METRICS_EMPTY=1
}

export -f reset_cpu_metrics_dict

function init_rapl() {
  # Create FIFO pipe to read power values from RAPL container
  if [ ! -f "${RAPL_PIPE}" ]; then
    rm -f ${RAPL_PIPE}
  fi
  mkfifo -m 777 "${RAPL_PIPE}"

  # Build RAPL
  if [ ! -f "${RAPL_HOME}"/rapl.sif ]; then
    echo "Building RAPL..."
    cd "${RAPL_HOME}" && apptainer build -F rapl.sif rapl.def
    cd "${GLOBAL_HOME}"
  else
    echo "RAPL image already exists. Skipping build."
    if sudo apptainer instance list | grep -q "rapl"; then
      echo "There exists a RAPL instance already running. Removing..."
      sudo apptainer instance stop rapl
    fi
  fi
}

export -f init_rapl

function get_core_utilization() {
  declare -a CPU_TIMES=($(echo "${1}" | grep "^cpu${CORE} "))

  # Get total CPU time spent on this core
  local TOTAL_TIME=0
  for TIME in "${CPU_TIMES[@]}"; do
    TOTAL_TIME=$((TOTAL_TIME + TIME))
  done

  # Get time difference with previous sample
  local DIFF_USER=$((CPU_TIMES[1] - PREV_USER[CORE]))
  local DIFF_SYSTEM=$((CPU_TIMES[3] - PREV_SYSTEM[CORE]))
  local DIFF_IOWAIT=$((CPU_TIMES[5] - PREV_IOWAIT[CORE]))
  local DIFF_TOTAL=$((TOTAL_TIME - PREV_TOTAL[CORE]))

  # Get each CPU utilization type percentage
  local USER_UTIL_CORE=$((100 * DIFF_USER / DIFF_TOTAL))
  local SYSTEM_UTIL_CORE=$((100 * DIFF_SYSTEM / DIFF_TOTAL))
  local IOWAIT_UTIL_CORE=$((100 * DIFF_IOWAIT / DIFF_TOTAL))

  # Update total values
  ITER_CPU_METRICS["user_load"]=$((ITER_CPU_METRICS["user_load"] + USER_UTIL_CORE))
  ITER_CPU_METRICS["system_load"]=$((ITER_CPU_METRICS["system_load"] + SYSTEM_UTIL_CORE))
  ITER_CPU_METRICS["wait_load"]=$((ITER_CPU_METRICS["wait_load"] + IOWAIT_UTIL_CORE))

  # Update previous core values for next iteration
  PREV_USER[$CORE]=${CPU_TIMES[1]}
  PREV_SYSTEM[$CORE]=${CPU_TIMES[3]}
  PREV_IOWAIT[$CORE]=${CPU_TIMES[5]}
  PREV_TOTAL[$CORE]=${TOTAL_TIME}
}

export -f get_core_utilization

function get_core_frequency() {
  local FREQ_CORE=$(<"/sys/devices/system/cpu/cpu${CORE}/cpufreq/scaling_cur_freq")
  ITER_CPU_METRICS["sumfreq"]=$((ITER_CPU_METRICS["sumfreq"] + FREQ_CORE))
}

export -f get_core_frequency

function get_cpu_temperature() {
    TOTAL_TEMP=0
    for FILE in /sys/class/thermal/thermal_zone*/temp; do
        TEMP=$(cat "$FILE")
        TOTAL_TEMP=$((TOTAL_TEMP + TEMP))
    done
    TOTAL_TEMP=$((TOTAL_TEMP / 1000))
}

export -f get_cpu_temperature

function get_predicted_power() {
  for METHOD in "${PREDICTION_METHODS[@]}"; do
    # If utilization is low enough get inferred idle consumption instead of model predicted consumption
    if [[ ${ITER_CPU_METRICS["user_load"]} -lt "${LOW_UTIL_THRESHOLD}" ]] && [[ ${ITER_CPU_METRICS["system_load"]} -lt "${LOW_UTIL_THRESHOLD}" ]]; then
      PREDICTED_DATA=$(curl -G -s "${URL_SERVER}/idle-consumption/${METHOD}" )
    else
      # Get model prediction
      PREDICT_URL="${URL_SERVER}/predict/${METHOD}?"
      for VAR in "${MODEL_VARS[@]}"; do
        PREDICT_URL+="${VAR}=${ITER_CPU_METRICS[${VAR}]}&"
      done
      PREDICT_URL="${PREDICT_URL%?}" # Remove last &
      PREDICTED_DATA=$(curl -G -s "${PREDICT_URL}") 
    fi
    PREDICTED_DATA=$(echo "$PREDICTED_DATA" | sed 's/e+/*10^/') # Replace 'e+X' with '*10^X' to make it suitable for awk
    PREDICTED_POWER=$(awk -F'[:}]' '{print $2}' <<< "${PREDICTED_DATA}")
    LC_ALL=C ITER_CPU_METRICS["${METHOD}"]=$(printf "%.3f\n" "${PREDICTED_POWER}") # Set C locale to accept points as decimal separators
    #ITER_CPU_METRICS["error"]=$(echo "${ITER_CPU_METRICS["power"]} - ${ITER_CPU_METRICS["predicted"]}" | bc -l)
    #echo "${METHOD}: Real ${ITER_CPU_METRICS["power"]} | Predicted ${PREDICTED_POWER} | Error $(echo "${ITER_CPU_METRICS["power"]} - ${PREDICTED_POWER}" | bc -l)"
  done
}

export -f get_predicted_power

function get_cpu_metrics() {
    local PROC_LINES

    ITER_CPU_METRICS=( ["sumfreq"]=0 ["freq"]=0 ["user_load"]=0 ["system_load"]=0 ["wait_load"]=0 ["power"]=0)
    for METHOD in "${PREDICTION_METHODS[@]}"; do
      ITER_CPU_METRICS["${METHOD}"]=0
    done
    
    # Get proc info one time to get each core utilization from same times info
    PROC_LINES=$(cat /proc/stat)

    # Get CPU power consumption
    read POWER_PKG0 POWER_PKG1 < "${RAPL_PIPE}"
    ITER_CPU_METRICS["power"]=$(echo "${POWER_PKG0} + ${POWER_PKG1}" | bc -l)

    # Get CPU utilization and frequency for each core
    for CORE in "${CORES_ARRAY[@]}"; do
      get_core_utilization "${PROC_LINES}"
      get_core_frequency
    done

    # Compute frequency sum and average in MHz
    ITER_CPU_METRICS["sumfreq"]=$((ITER_CPU_METRICS["sumfreq"] / 1000))
    ITER_CPU_METRICS["freq"]=$((ITER_CPU_METRICS["sumfreq"] / ${#CORES_ARRAY[@]}))

    # Get model(s) prediction(s)
    get_predicted_power

    # Print model(s) variables and prediction(s)
    print_iter_metrics

    # Update JSON microbatch
    update_microbatch 
}

export -f get_cpu_metrics