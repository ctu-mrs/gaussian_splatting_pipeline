#!/bin/bash

# Path to your main data folder
PROJECT=../00_data

echo "Searching for the most recently trained model configuration..."

# 1. Automatically find the newest config.yml inside the project directory
LATEST_CONFIG=$(find $PROJECT -name "config.yml" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

if [ -z "$LATEST_CONFIG" ]; then
    echo "Error: Could not find any config.yml file in $PROJECT. Have you trained a model yet?"
    exit 1
fi

# 2. Strip the host project path so it is relative to the Docker container's /working folder
RELATIVE_CONFIG=${LATEST_CONFIG#"$PROJECT/"}

echo "Found latest model config: $RELATIVE_CONFIG"
echo "Starting ns-viewer..."
echo "========================================================"
echo "🌐 Once the server starts, open your browser and go to:"
echo "🌐 http://127.0.0.1:7007"
echo "========================================================"

DOCKER_ARGS=(
    -it --rm
    --gpus all
    --user "$(id -u):$(id -g)"
    --ipc=host
    -p 7007:7007
    -e HOME=/home/user
    -v "./$PROJECT:/working"
    -v "/home/$USER/.cache/:/home/user/.cache/"
)

docker run "${DOCKER_ARGS[@]}" \
  klaxalk/nerfstudio:latest \
  ns-viewer --load-config /working/$RELATIVE_CONFIG
