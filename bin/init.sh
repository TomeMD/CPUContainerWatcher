#!/bin/bash

# Start monitoring environment
if [ "${OS_VIRT}" == "docker" ]; then
  #	docker run -d --name glances --pid host --privileged --network host --restart=unless-stopped -e GLANCES_OPT="-q --export influxdb2 --time 1" glances "${INFLUXDB_HOST}" "${INFLUXDB_BUCKET}"
  #	docker run -d --name rapl --pid host --privileged --network host --restart=unless-stopped rapl "${INFLUXDB_HOST}" "${INFLUXDB_BUCKET}"
  m_echo "Not yet supported. Nothing to do"
else
  sudo apptainer instance start -C --bind "${MONGODB_HOME}"/data:/data/db "${MONGODB_HOME}"/mongodb.sif mongodb
  sudo apptainer instance start -C --bind /sys:/sys --bind "${SENSOR_REPORTING_DIR}":/reporting "${HWPC_SENSOR_HOME}"/hwpc-sensor.sif hwpc-sensor
	sudo apptainer instance start -C --bind "${SMARTWATTS_HOME}"/output:/sensor-output "${SMARTWATTS_HOME}"/smartwatts.sif smartwatts
fi

# Start Senders
m_echo "Starting senders..."
bash "${SENDERS_HOME}"/start_power_sender_tmux.sh
bash "${SENDERS_HOME}"/start_usage_sender_tmux.sh

if [ "${ADD_IO_NOISE}" -ne 0 ]; then
  FIO_OPTIONS="--name=fio_job --directory=/tmp --bs=4k --size=10g --rw=randrw --numjobs=1 --runtime=30h --time_based"
  if [ "${OS_VIRT}" == "docker" ]; then
    docker run -d --cpuset-cpus "0" --name fio_noise --pid host --privileged --network host --restart=unless-stopped -v "${FIO_TARGET}":/tmp ljishen/fio:latest ${FIO_OPTIONS}
  else
    sudo apptainer instance start --cpuset-cpus "0" -B "${FIO_TARGET}":/tmp "${FIO_HOME}"/fio.sif fio_noise ${FIO_OPTIONS}
  fi
fi
