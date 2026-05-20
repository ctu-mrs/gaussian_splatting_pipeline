#!/bin/bash

PROJECT=../00_data
INPUT=nerfstudio_input
OUTPUT=nerfstudio_output

DOWNSCALE_FACTOR=4 # {1, 2, 3, 4}, how much to downscale images, default is 4
MODEL_CMD=splatfacto
# MODEL_CMD=splatfacto-big > 12 GB VRAM

mkdir -p $PROJECT/$OUTPUT

# Run the docker container
docker run --gpus all -u $(id -u) \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -e HOME=/home/user \
  -v ./$PROJECT:/working \
  -v /home/$USER/.cache/:/home/user/.cache/ \
  -p 7007:7007 --rm -it --shm-size=7gb \
  klaxalk/nerfstudio:latest \
  ns-train $MODEL_CMD \
  --timestamp "" \
  --output-dir /working/$OUTPUT \
  --data /working/$INPUT \
  nerfstudio-data \
  --downscale-factor $DOWNSCALE_FACTOR
