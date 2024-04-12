#!/bin/sh

function get_date {
    DATE=`date '+%d/%m/%Y %H:%M:%S'`
}

export -f get_date

function m_echo() {
    get_date
    echo -e "\e[48;5;2m[$DATE INFO]\e[0m $@"
    echo "$DATE > $@" >> "${LOG_FILE}"
}

export -f m_echo

function m_err() {
    get_date
    echo -e "\e[48;5;1m[$DATE ERR]\e[0m $@" >&2
    echo "$DATE > $@" >> "${LOG_FILE}"
}

export -f m_err

function m_warn() {
    get_date
    echo -e "\e[48;5;208m[$DATE WARN]\e[0m $@"
    echo "$DATE > $@" >> "${LOG_FILE}"
}

export -f m_warn

function show_logo() {
	echo "                                                                   "
	echo " ____                      __        __    _       _               "
	echo "|  _ \ _____      _____ _ _\ \      / /_ _| |_ ___| |__   ___ _ __ "
	echo "| |_) / _ \ \ /\ / / _ \  __\ \ /\ / / _  | __/ __| |_ \ / _ \  __|"
	echo "|  __/ (_) \ V  V /  __/ |   \ V  V / (_| | || (__| | | |  __/ |   "
	echo "|_|   \___/ \_/\_/ \___|_|    \_/\_/ \__,_|\__\___|_| |_|\___|_|   "
	echo ""
}

export -f show_logo

function print_conf() {
    show_logo
    m_echo "InfluxDB host = ${INFLUXDB_HOST}"
    m_echo "InfluxDB bucket = ${INFLUXDB_BUCKET}"
    m_echo "OS Virtualization Technology = ${OS_VIRT}"
    m_echo "Workload = ${WORKLOAD}"
    if [ "${WORKLOAD}" == "stress-system" ]; then
      m_echo "Stress-system stressors = [${STRESSORS}]"
      m_echo "CPU Stressor Load Types = [${LOAD_TYPES}]"
    fi
    if [ "${ADD_IO_NOISE}" -ne 0 ]; then
      m_echo "Fio target = ${FIO_TARGET}"
    fi
    m_echo "Writing output to ${LOG_FILE}"
}

export -f print_conf

function print_time() {
	m_echo "${NAME} CPU TIME: $(bc <<< "scale=9; $(($2 - $1)) / 1000000000")" | tee -a "${LOG_FILE}"
}

export -f print_time

function print_timestamp() {
	local DESCRIPTION=$1
	m_echo "${NAME} ${DESCRIPTION}: $(date -u "+%Y-%m-%d %H:%M:%S%z")"
	echo "${NAME} ${DESCRIPTION}: $(date -u "+%Y-%m-%d %H:%M:%S%z")" >> "${TIMESTAMPS_FILE}"
}

export -f print_timestamp

function set_n_cores() {
  NUM_THREADS=$1
  CURRENT_CORES=""
  for (( i=0; i<NUM_THREADS; i++ )); do
    if [ "$i" -ne 0 ]; then
      CURRENT_CORES+=","
    fi
    CURRENT_CORES+="${CORES_ARRAY[i]}"
  done
}

export -f set_n_cores

function start_cpufreq_core() {
	CPUFREQ_STARTED=0
	while [ "${CPUFREQ_STARTED}" -eq 0 ]
	do
  		"${CPUFREQ_HOME}"/get-freq-core.sh "${CURRENT_CORES}" "${INFLUXDB_HOST}" "${INFLUXDB_BUCKET}" > /dev/null 2>&1 &
  		CORE_CPUFREQ_PID=$!
  		sleep 1
  		if ps -p "${CORE_CPUFREQ_PID}" > /dev/null; then
    			CPUFREQ_STARTED=1
    			m_echo "CPUfreq per core succesfully started. (PID = ${CORE_CPUFREQ_PID})"
  		else
    			m_err "Error while starting CPUfreq per core. Trying again."
  		fi
	done
}

export -f start_cpufreq_core

function stop_cpufreq_core() {
  kill "${CORE_CPUFREQ_PID}" > /dev/null 2>&1

  if ps -p "${CORE_CPUFREQ_PID}" > /dev/null; then
     m_err "Error while killing CPUfreq per core process. (PID = ${CORE_CPUFREQ_PID})"
  else
     m_echo "CPUfreq per core process succesfully stopped. (PID = ${CORE_CPUFREQ_PID})"
  fi
}

export -f stop_cpufreq_core

function run_stress-system() {
	print_timestamp "STRESS-TEST (CORES = ${CURRENT_CORES}) START"
	if [ "${OS_VIRT}" == "docker" ]; then
		docker run --rm --name stress-system -it stress-system ${OTHER_OPTIONS}-l "${LOAD}" -s "${STRESSORS}" --cpu-load-types "${LOAD_TYPES}" -c "${CURRENT_CORES}" -t 4m >> "${LOG_FILE}" 2>&1
	else
		apptainer run "${STRESS_CONTAINER_DIR}"/stress.sif ${OTHER_OPTIONS}-l "${LOAD}" -s "${STRESSORS}" --cpu-load-types "${LOAD_TYPES}" -c "${CURRENT_CORES}" -t 4m >> "${LOG_FILE}" 2>&1
	fi
	print_timestamp "STRESS-TEST (CORES = ${CURRENT_CORES}) STOP"
	sleep 15
}

export -f run_stress-system

function run_sysbench() {
	print_timestamp "SYSBENCH (CORES = ${CURRENT_CORES}) START"
	if [ "${OS_VIRT}" == "docker" ]; then
		docker run --rm --name sysbench -it sysbench "${CURRENT_CORES}" >> "${LOG_FILE}" 2>&1
	else
		apptainer run "${SYSBENCH_HOME}"/sysbench.sif "${CURRENT_CORES}" >> "${LOG_FILE}" 2>&1
	fi
	print_timestamp "SYSBENCH (CORES = ${CURRENT_CORES}) STOP"
	sleep 15
}

export -f run_sysbench

function run_geekbench() {
	print_timestamp "GEEKBENCH (CORES = ${CURRENT_CORES}) START"
	taskset -c "${CURRENT_CORES}" "${GEEKBENCH_HOME}"/geekbench_x86_64 | tee -a "${LOG_FILE}"
	print_timestamp "GEEKBENCH (CORES = ${CURRENT_CORES}) STOP"
	sleep 15
}

export -f run_geekbench

function run_npb_omp_kernel() {
	local COMMAND="while true; do ${NPB_OMP_HOME}/${1} | tee -a ${LOG_FILE}; done"
	shift 1
	CORES_ARRAY=("$@")
	NUM_THREADS=1
	while [ "${NUM_THREADS}" -le "${THREADS}" ]
	do
      set_n_cores ${NUM_THREADS}
	    start_cpufreq_core
	    print_timestamp "NPB (CORES = ${CURRENT_CORES}) START"
	    export OMP_NUM_THREADS="${NUM_THREADS}"
	    taskset -c "${CURRENT_CORES}" timeout 5m bash -c "${COMMAND}"
	    print_timestamp "NPB (CORES = ${CURRENT_CORES}) STOP"
	    stop_cpufreq_core
	    NUM_THREADS=$(( NUM_THREADS * 2 ))
	    sleep 30
	done
}

export -f run_npb_omp_kernel

function run_npb_mpi_kernel() {
	local COMMAND=""
	local NPB_KERNEL=${1}
	shift 1
	CORES_ARRAY=("$@")
	BASE=1
	NUM_THREADS=$(( BASE * BASE ))
	while [ "${NUM_THREADS}" -le "${THREADS}" ]
	do
	    COMMAND="while true; do rm -f ${GLOBAL_HOME}/btio.epio.out*; mpirun -np ${NUM_THREADS} --bind-to none --mca btl ^openib ${NPB_MPI_HOME}/${NPB_KERNEL} | tee -a ${LOG_FILE}; done"
      set_n_cores ${NUM_THREADS}
	    start_cpufreq_core
	    print_timestamp "NPB (CORES = ${CURRENT_CORES}) START"
	    taskset -c "${CURRENT_CORES}" timeout 5m bash -c "${COMMAND}"
	    print_timestamp "NPB (CORES = ${CURRENT_CORES}) STOP"
	    stop_cpufreq_core
	    BASE=$(( BASE + 1))
	    NUM_THREADS=$(( BASE * BASE )) # BT I/O needs an square number of processes
	    sleep 30
	done
	rm -f "${GLOBAL_HOME}"/btio.epio.out* # Remove BT I/O generated files
}

export -f run_npb_mpi_kernel

function run_spark() {
  CORES_ARRAY=("$@")
	NUM_THREADS=1
	while [ "${NUM_THREADS}" -le "${THREADS}" ]
	do
		set_n_cores ${NUM_THREADS}
		start_cpufreq_core
		print_timestamp "SPARK (CORES = ${CURRENT_CORES}) START"
		taskset -c "${CURRENT_CORES}" "${SMUSKET_HOME}"/bin/smusketrun -sm "-i ${SPARK_DATA_DIR}/ERR031558.fastq -n 64 -k 25" --conf "spark.local.dir=${SPARK_DATA_DIR}" --master local["${NUM_THREADS}"] --driver-memory 200g
		print_timestamp "SPARK (CORES = ${CURRENT_CORES}) STOP"
		stop_cpufreq_core
		rm -rf "${SPARK_DATA_DIR}"/blockmgr* "${SPARK_DATA_DIR}"/spark-*
		NUM_THREADS=$(( NUM_THREADS * 2 ))
		sleep 20
	done
}

export -f run_spark

function run_fio() {
  CORES_ARRAY=("$@")
	NUM_THREADS=1
	MAX_THREADS=8
	while [ "${NUM_THREADS}" -le "${MAX_THREADS}" ]
	do
	  FIO_OPTIONS="--name=fio_job --directory=/tmp --bs=4k --size=10g --rw=randrw --iodepth=64 --numjobs=${NUM_THREADS} --runtime=30h --time_based"
		set_n_cores ${NUM_THREADS}
		start_cpufreq_core
		print_timestamp "FIO (CORES = ${CURRENT_CORES}) START"
    if [ "${OS_VIRT}" == "docker" ]; then
      docker run -d --rm --cpuset-cpus "${CURRENT_CORES}" --name fio -v "${FIO_TARGET}":/tmp ljishen/fio:latest ${FIO_OPTIONS}
    else
      sudo apptainer instance start --cpuset-cpus "${CURRENT_CORES}" -B "${FIO_TARGET}":/tmp "${FIO_HOME}"/fio.sif fio ${FIO_OPTIONS}
    fi
    sleep 300
		print_timestamp "FIO (CORES = ${CURRENT_CORES}) STOP"
    if [ "${OS_VIRT}" == "docker" ]; then
      docker stop fio
    else
      sudo apptainer instance stop fio
    fi
		stop_cpufreq_core
		rm -rf "${FIO_TARGET}"/fio_job*
		NUM_THREADS=$(( NUM_THREADS * 2 ))
		sleep 30
	done
}

export -f run_fio

function idle_cpu() {
	print_timestamp "IDLE START"
	sleep 30
	print_timestamp "IDLE STOP"
	sleep 5
}

export -f idle_cpu

function run_seq_experiment() {
  TEST_FUNCTION=$1
  CURRENT_CORES="0"
  LOAD=50
	while [ "${LOAD}" -le "100" ]; do
    start_cpufreq_core
    "${TEST_FUNCTION}"
    idle_cpu
    stop_cpufreq_core
    LOAD=$((LOAD + 50))
  done
}

export -f run_seq_experiment

function run_experiment() { 
	NAME=$1
	TEST_FUNCTION=$2
	shift 2
	CORES_ARRAY=("$@")

	local START_TEST=$(date +%s%N)
	run_seq_experiment "${TEST_FUNCTION}"
  CURRENT_CORES=""
	LOAD=200
	for ((i = 0; i < ${#CORES_ARRAY[@]}; i += 2)); do
      if [ -z "${CURRENT_CORES}" ]; then
          CURRENT_CORES+="${CORES_ARRAY[i]},${CORES_ARRAY[i+1]}"
      else
          CURRENT_CORES+=",${CORES_ARRAY[i]},${CORES_ARRAY[i+1]}"
      fi
	    start_cpufreq_core
	    "${TEST_FUNCTION}"
	    idle_cpu
	    stop_cpufreq_core
	    LOAD=$((LOAD + 200))
	done
	local END_TEST=$(date +%s%N)
  print_time "${START_TEST}" "${END_TEST}"
}

export -f run_experiment
