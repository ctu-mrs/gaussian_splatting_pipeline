#!/bin/bash

PROJECT=../00_data
INPUT=nerfstudio_output
OUTPUT=splat_export

mkdir -p $PROJECT/$OUTPUT

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
  ns-export gaussian-splat \
  --load-config /working/$INPUT/nerfstudio_input/splatfacto/config.yml \
  --output-dir /working/$OUTPUT
