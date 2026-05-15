#!/bin/bash

PROJECT=../00_data
INPUT=nerfstudio_output
OUTPUT=splat_export

mkdir -p $PROJECT/$OUTPUT

docker run --gpus all -u $(id -u) \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -e HOME=/home/user \
  -v ./$PROJECT:/working \
  -v /home/$USER/.cache/:/home/user/.cache/ \
  -p 7007:7007 --rm -it --shm-size=7gb \
  ghcr.io/nerfstudio-project/nerfstudio:latest \
  ns-export gaussian-splat \
  --load-config /working/$INPUT/nerfstudio_input/splatfacto/config.yml \
  --output-dir /working/$OUTPUT
