#!/bin/bash

export GLOBAL_HOME=`cd $(dirname "$0"); pwd`

# Load default values
. "${GLOBAL_HOME}"/default-values.sh

# Parse arguments
. "${GLOBAL_HOME}"/parse-arguments.sh

# Load aux functions
. "${GLOBAL_HOME}"/functions.sh

# Init variables and tools to get and store CPU metrics
init_prev_cores_arrays
init_all_vars_array
reset_cpu_metrics_dict
init_rapl
print_output_file_header

# Start RAPL
sudo apptainer instance start -B "${RAPL_FIFO_DIR}":"${RAPL_FIFO_DIR}" "${RAPL_HOME}"/rapl.sif rapl "${RAPL_FIFO_DIR}" ${RAPL_FREQUENCY}

while true; do

  print_microbatch_header

  # Collect microbatch
  for ((i = 1; i <= MICROBATCH_SIZE; i++)); do
    get_cpu_metrics
    sleep "${SAMPLING_FREQUENCY}"
  done

  # Encode JSON microbatch
  encode_json_microbatch

  # POST data to train the model
  echo -e "JSON Batch: ${JSON_BATCH}"
  for METHOD in "${PREDICTION_METHODS[@]}"; do
    if [[ "${IS_STATIC["${METHOD}"]}" -eq "0" ]]; then
      echo -n "Response to ${METHOD} train request: "
      curl -X POST -H "Content-Type: application/json" -d "${JSON_BATCH}" "${URL_SERVER}/train/${METHOD}"
    fi
  done

  # Remove microbatch
  reset_cpu_metrics_dict
done

sudo apptainer instance stop rapl
