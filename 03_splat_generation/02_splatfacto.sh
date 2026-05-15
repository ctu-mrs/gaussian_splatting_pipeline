#!/bin/bash

PROJECT=../00_data
INPUT=nerfstudio_input
OUTPUT=nerfstudio_output

# Separate the command argument from the folder name
MODEL_CMD=splatfacto-big
MODEL_DIR=splatfacto

mkdir -p $PROJECT/$OUTPUT

# We still check for the config to verify a run actually started previously
HOST_CONFIG_FILE="./$PROJECT/$OUTPUT/$INPUT/$MODEL_DIR/config.yml"

RESUME_ARGS=""

if [ -f "$HOST_CONFIG_FILE" ]; then
    echo "Found existing config file! Resuming training from checkpoint..."
    # For training, we ONLY pass the load-dir. Nerfstudio automatically finds the latest .ckpt file inside it.
    RESUME_ARGS="--load-dir /working/$OUTPUT/$INPUT/$MODEL_DIR/nerfstudio_models --pipeline.model.stop-split-at 4000"
else
    echo "No existing checkpoint found. Starting training from scratch..."
fi

# Run the docker container
docker run --gpus all -u $(id -u) \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -e HOME=/home/user \
  -v ./$PROJECT:/working \
  -v /home/$USER/.cache/:/home/user/.cache/ \
  -p 7007:7007 --rm -it --shm-size=7gb \
  ghcr.io/nerfstudio-project/nerfstudio:latest \
  ns-train $MODEL_CMD \
  --pipeline.model.use_scale_regularization=True \
  --pipeline.model.cull_alpha_thresh=0.1 \
  --timestamp "" \
  --output-dir /working/$OUTPUT \
  $RESUME_ARGS \
  --data /working/$INPUT
