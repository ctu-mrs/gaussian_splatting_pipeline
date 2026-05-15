PROJECT=../00_data
COLMAP_WORKSPACE=workspace
OUTPUT_DIR=nerfstudio_input

echo PROJECT: $PROJECT

mkdir -p $PROJECT/$OUTPUT_DIR

docker run --gpus all -u $(id -u) -e HOME=/home/user -v ./$PROJECT:/working -v /home/$USER/.cache/:/home/user/.cache/ -p 7007:7007 --rm -it --shm-size=12gb \
            ghcr.io/nerfstudio-project/nerfstudio:latest \
            ns-process-data images --data /working/images --output-dir /working/$OUTPUT_DIR --skip-colmap --colmap-model-path /working/$COLMAP_WORKSPACE/sparse/0   # Smaple command of nerfstudio.
