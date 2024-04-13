#!/bin/bash

URL_SERVER="http://localhost:5000"

if [ $# -lt 2 ]; then
    echo "Error: Missing some arguments"
    echo "Usage: $0 <ACTION> <PREDICTION_METHOD> [<PREDICT_VALUES>]"
    exit 1
fi
ACTION=${1}
PRED_METHOD=${2}

if [ "${ACTION}" == "get-attributes" ]; then 
    # Get model attributes
    curl -G -s GET "${URL_SERVER}/model-attributes/${PRED_METHOD}"

elif [ "${ACTION}" == "get-idle-consumption" ]; then
    # Get idle consumption
    curl -G -s GET "${URL_SERVER}/idle-consumption/${PRED_METHOD}" 

elif [ "${ACTION}" == "predict" ]; then 
    USER=$2
    SYSTEM=$3
    FREQ=$4
    # Get predictions
    curl -G "${URL_SERVER}/predict/${PRED_METHOD}" --data-urlencode "user_load=${USER}" --data-urlencode "system_load=${SYSTEM}" --data-urlencode "freq=${FREQ}"   

elif [ "${ACTION}" == "restart-model" ]; then 
    # Restart the model
    curl -X DELETE "${URL_SERVER}/restart-model/${PRED_METHOD}"
fi