#!/bin/bash

PROJECT=../00_data
INPUT=nerfstudio_input
OUTPUT=nerfstudio_output

mkdir -p $PROJECT/$OUTPUT

docker run --gpus all -u $(id -u) \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -e HOME=/home/user \
  -v ./$PROJECT:/working \
  -v /home/$USER/.cache/:/home/user/.cache/ \
  -p 7007:7007 --rm -it --shm-size=7gb \
  ghcr.io/nerfstudio-project/nerfstudio:latest \
  ns-train splatfacto-big \
  --pipeline.model.use_scale_regularization=True \
  --pipeline.model.cull_alpha_thresh=0.1 \
  --data /working/$INPUT \
  --timestamp "" \
  --data /working/$INPUT \
  --output-dir /working/$OUTPUT

  # add these to start from a previous checkpoint
  # --load-dir /working/$OUTPUT/$INPUT/splatfacto/nerfstudio_models \
  # --load-config /working/$OUTPUT/$INPUT/splatfacto/config.yml
