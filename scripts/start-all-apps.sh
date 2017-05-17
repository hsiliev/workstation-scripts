#!/bin/bash
set -e

PARALLEL_JOBS=10
if [ -n "$1" ]; then
  PARALLEL_JOBS=$1
fi

SCRIPT_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$SCRIPT_DIR" ]]; then
  SCRIPT_DIR="$PWD";
fi

echo "Using $PARALLEL_JOBS parallel jobs."

echo "Listing applications ..."
cf apps | tail -n +5 | awk '{print $1}' | xargs -P ${PARALLEL_JOBS} -n 1 ${SCRIPT_DIR}/start-app.sh
