#!/bin/bash

PROJECT=../00_data
INPUT=nerfstudio_input
OUTPUT=nerfstudio_output

DOWNSCALE_FACTOR=2 # {1, 2, 3, 4}, how much to downscale images, default is 4
MODEL_CMD=splatfacto
ITERATIONS=30000 # default = 30000
# MODEL_CMD=splatfacto-big > 12 GB VRAM

mkdir -p $PROJECT/$OUTPUT

DOCKER_ARGS=(
    -it --rm
    --gpus all
    --user "$(id -u):$(id -g)"
    -v /etc/passwd:/etc/passwd:ro
    -v /etc/group:/etc/group:ro
    --ipc=host
    -p 7007:7007
    -e HOME=/home/user
    -v "./$PROJECT:/working"
    -v "/home/$USER/.cache/:/home/user/.cache/"
)

# Run the docker container
docker run "${DOCKER_ARGS[@]}" \
  klaxalk/nerfstudio:latest \
  ns-train $MODEL_CMD \
  --max-num-iterations $ITERATIONS \
  --timestamp "" \
  --output-dir /working/$OUTPUT \
  --data /working/$INPUT \
  --pipeline.model.cull-scale-thresh 5.0 \
  --pipeline.model.cull-alpha-thresh 0.005 \
  --pipeline.model.densify-grad-thresh 0.0001 \
  nerfstudio-data \
  --downscale-factor $DOWNSCALE_FACTOR

  # # this should fix holes in the ground
  # --pipeline.model.cull-scale-thresh 5.0
  # --pipeline.model.cull-alpha-thresh 0.005
  # --pipeline.model.densify-grad-thresh 0.0001
