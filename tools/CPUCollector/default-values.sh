export OUTPUT_DIR="${GLOBAL_HOME}"/out
export URL_SERVER="http://localhost:5000"
export SAMPLING_FREQUENCY=1
export MICROBATCH_SIZE=5
export LOW_UTIL_THRESHOLD=0 # If cpu user and system utilization are below this threshold idle consumption from train time series is used to predict
export CORES_ARRAY=(0 1)

export PREDICTION_METHODS=("sgdregressor")
declare -A IS_STATIC=(["sgdregressor"]=0 ["polyreg"]=1 ["mlpregressor"]=0)

export MODEL_VARS=("user_load" "system_load")
export ALL_VARS=()

export RAPL_HOME="${GLOBAL_HOME}"/rapl
export RAPL_FIFO_DIR=/tmp
export RAPL_PIPE="${RAPL_FIFO_DIR}"/power_pipe
export RAPL_FREQUENCY=1 # It is recommended to be higher than sampling frequency but lower than microbath size

export CPU_METRICS_EMPTY=1
declare -A CPU_METRICS
declare -A ITER_CPU_METRICS

export JSON_BATCH=""

export PREV_USER=()
export PREV_SYSTEM=()
export PREV_IOWAIT=()
export PREV_TOTAL=()

