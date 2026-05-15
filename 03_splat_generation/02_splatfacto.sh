#!/bin/bash

PROJECT=../00_data
INPUT=nerfstudio_input
OUTPUT=nerfstudio_output
DOWNSCALE_FACTOR=2 # {1, 2, 3, 4}, how much to downscale images

# Separate the command argument from the folder name
MODEL_CMD=splatfacto-big

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

  # $RESUME_ARGS \
  # --pipeline.model.use_scale_regularization=True \
  # --pipeline.model.cull_alpha_thresh=0.1 \
