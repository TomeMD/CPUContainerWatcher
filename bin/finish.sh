#!/bin/bash

m_echo "Closing environment"
if [ "$OS_VIRT" == "docker" ]; then
	docker stop smartwatts hwpc-sensor mongodb
	docker rm smartwatts hwpc-sensor mongodb
else
	sudo apptainer instance stop smartwatts && sudo apptainer instance stop hwpc-sensor && sudo apptainer instance stop mongodb
fi

tmux kill-session -t "power_sender"
tmux kill-session -t "usage_sender"

if [ "${ADD_IO_NOISE}" -ne 0 ]; then
  if [ "${OS_VIRT}" == "docker" ]; then
    docker stop fio_noise
    docker rm fio_noise
  else
    sudo apptainer instance stop fio_noise
  fi
  rm -rf "${FIO_TARGET}"/fio_job*
fi

m_echo "Environment succesfully closed"