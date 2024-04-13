#!/bin/bash

function usage {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]
  -c, --cores-list          List of cores to monitor. [Default: 0,1]
  -v, --vars                Comma-separated list of model variables (CPU metrics) used by the models to predict power 
                            consumption. [Default: "user_load","system_load"]
                            Supported vars: "user_load", "system_load", "wait_load","freq"
  -p, --prediction-methods  Comma-separated list of methods used to predict CPU power consumption. [Default: sgdregressor]
                            Supported prediction methods: "mlpregressor", "sgdregressor", "polyreg"
  -o, --output <dir>       Directory (absolute path) to store output files. [Default: ./out]
  -h, --help               Show this help and exit
EOF
exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--cores-list)
      IFS=',' read -ra CORES_ARRAY <<< "${2}"
      shift 2
      ;;
    -v|--vars)
      IFS=',' read -ra MODEL_VARS <<< "${2}"
      shift 2
      ;;
    -p|--prediction-methods)
      IFS=',' read -ra PREDICTION_METHODS <<< "${2}"
      shift 2
      ;;
    -o|--output)
      OUTPUT_DIR="${2}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
    echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

mkdir -p "${OUTPUT_DIR}"