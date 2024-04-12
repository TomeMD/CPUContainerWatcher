#!/bin/bash

print_conf

m_echo "Building monitoring environment"

# Build monitoring environment
if [ "${OS_VIRT}" == "docker" ]; then
  if [ -z "$(docker image ls -q glances)" ]; then
    m_echo "Building Glances..."
    docker build -t glances "${GLANCES_HOME}"
  else
    m_echo "Glances image already exists. Skipping build."
  fi
  if [ -z "$(docker image ls -q rapl)" ]; then
    m_echo "Building RAPL..."
    docker build -t rapl "${RAPL_HOME}"
  else
    m_echo "RAPL image already exists. Skipping build."
  fi
elif [ "${OS_VIRT}" == "apptainer" ]; then
  if [ ! -f "${GLANCES_HOME}"/glances.sif ]; then
    m_echo "Building Glances..."
    cd "${GLANCES_HOME}" && apptainer build -F glances.sif glances.def
  else
    m_echo "Glances image already exists. Skipping build."
  fi
  if [ ! -f "${RAPL_HOME}"/rapl.sif ]; then
    m_echo "Building RAPL..."
    cd "${RAPL_HOME}" && apptainer build -F rapl.sif rapl.def
  else
    m_echo "RAPL image already exists. Skipping build."
  fi
fi
chmod +x "${CPUFREQ_HOME}"/get-freq-core.sh


# Compile workloads
if [ "${WORKLOAD}" == "stress-system" ]; then # STRESS-SYSTEM
  chmod +x "${STRESS_HOME}"/run.sh
  if [ "$OS_VIRT" == "docker" ]; then
    if [ -z "$(docker image ls -q stress-system)" ]; then
      m_echo "Building stress-system..."
      cd "${STRESS_HOME}" && docker build -t stress-system -f "${STRESS_CONTAINER_DIR}"/Dockerfile .
    else
      m_echo "Stress-system image already exists. Skipping build."
    fi
  elif [ "${OS_VIRT}" == "apptainer" ]; then
    if [ ! -f "${STRESS_CONTAINER_DIR}"/stress.sif ]; then
      m_echo "Building stress-system..."
      cd "${STRESS_CONTAINER_DIR}" && apptainer build -F stress.sif stress.def > /dev/null
    else
      m_echo "Stress-system image already exists. Skipping build."
    fi
  fi

elif [ "${WORKLOAD}" == "npb" ]; then # NPB KERNELS
	if [ ! -d "${NPB_HOME}" ]; then
		m_echo "Downloading NPB kernels..."
		wget https://www.nas.nasa.gov/assets/npb/NPB3.4.2.tar.gz
		tar -xf NPB3.4.2.tar.gz -C "${TOOLS_DIR}"
		rm NPB3.4.2.tar.gz
		cd "${NPB_OMP_HOME}"
		cp config/make.def.template config/make.def
		make clean
		make is CLASS=C
		make ft CLASS=C
		make mg CLASS=C
		make cg CLASS=C
		make bt CLASS=C
		cd "${NPB_MPI_HOME}"
		cp config/make.def.template config/make.def
		make clean
		make bt CLASS=C SUBTYPE=epio # epio means each process writes to a different file
	else
		m_echo "NPB kernels were already downloaded"
	fi

elif [ "${WORKLOAD}" == "sysbench" ]; then # SYSBENCH
  if [ "$OS_VIRT" == "docker" ]; then
    if [ -z "$(docker image ls -q sysbench)" ]; then
      m_echo "Building sysbench..."
      cd "${SYSBENCH_HOME}" && docker build -t sysbench .
    else
      m_echo "Sysbench image already exists. Skipping build."
    fi
  elif [ "${OS_VIRT}" == "apptainer" ]; then
    if [ ! -f "${SYSBENCH_HOME}"/sysbench.sif ]; then
      m_echo "Building sysbench..."
      cd "${SYSBENCH_HOME}" && apptainer build -F sysbench.sif sysbench.def > /dev/null
    else
      m_echo "Sysbench image already exists. Skipping build."
    fi
  fi

elif [ "${WORKLOAD}" == "geekbench" ]; then # GEEKBENCH
	if [ ! -d "${GEEKBENCH_HOME}" ]; then
		m_echo "Downloading Geekbench..."
		wget https://cdn.geekbench.com/Geekbench-"${GEEKBENCH_VERSION}"-Linux.tar.gz
		tar -xf Geekbench-"${GEEKBENCH_VERSION}"-Linux.tar.gz -C "${TOOLS_DIR}"
		rm Geekbench-"${GEEKBENCH_VERSION}"-Linux.tar.gz
	else
		m_echo "Geekbench was already downloaded"
	fi

elif [ "${WORKLOAD}" == "spark" ]; then # APACHE SPARK
	if [ ! -d "${SPARK_HOME}" ]; then
	  # Install Spark
		m_echo "Downloading Apache Spark..."
		wget https://dlcdn.apache.org/spark/spark-"${SPARK_VERSION}"/spark-"${SPARK_VERSION}"-bin-hadoop"${SPARK_VERSION:0:1}".tgz
		tar -xf spark-"${SPARK_VERSION}"-bin-hadoop"${SPARK_VERSION:0:1}".tgz -C "${TOOLS_DIR}"
		rm spark-"${SPARK_VERSION}"-bin-hadoop"${SPARK_VERSION:0:1}".tgz
    # Install smusket
    git clone https://github.com/UDC-GAC/smusket.git "${SMUSKET_HOME}"
    sed -i 's/^MERGE_OUTPUT=.*/MERGE_OUTPUT=true/' "${SMUSKET_HOME}"/etc/smusket.conf
    sed -i 's/^SERIALIZED_RDD=.*/SERIALIZED_RDD=false/' "${SMUSKET_HOME}"/etc/smusket.conf
    sed -i 's/^HDFS_BASE_PATH=.*/HDFS_BASE_PATH=\/scratch\/ssd/' "${SMUSKET_HOME}"/etc/smusket.conf
	else
		m_echo "Apache Spark was already downloaded"
	fi
fi

if [ "${WORKLOAD}" == "fio" ] || [ "${ADD_IO_NOISE}" -ne 0 ]; then # FIO
  mkdir -p "${FIO_TARGET}"
  if [ "${OS_VIRT}" == "apptainer" ]; then
    if [ ! -f "${FIO_HOME}"/fio.sif ]; then
      m_echo "Building fio..."
      cd "${FIO_HOME}" && apptainer build -F fio.sif fio.def
    else
      m_echo "fio image already exists. Skipping build."
    fi
  fi
fi

cd "${GLOBAL_HOME}"
