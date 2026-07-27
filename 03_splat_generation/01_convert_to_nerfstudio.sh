#!/usr/bin/env bash

PROJECT=../00_data
COLMAP_WORKSPACE=workspace
OUTPUT_DIR=nerfstudio_input

echo "PROJECT: $PROJECT"

mkdir -p "$PROJECT/$OUTPUT_DIR"

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

# --- Execute ---
docker run "${DOCKER_ARGS[@]}" \
  klaxalk/nerfstudio:latest \
  ns-process-data images \
  --data /working/images \
  --output-dir "/working/$OUTPUT_DIR" \
  --skip-colmap \
  --colmap-model-path "/working/$COLMAP_WORKSPACE/sparse/0"
