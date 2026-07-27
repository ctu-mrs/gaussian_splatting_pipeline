#!/bin/bash
#
# UPDATED: SSH-friendly COLMAP Docker runner
# This version skips GUI checks when running command-line tasks over SSH.

set -e

# --- Cleanup Function ---
function cleanup {
    # Only attempt xhost cleanup if we are in a local GUI session
    if [ -n "$DISPLAY" ] && [ "$DISPLAY" != localhost* ]; then
        echo "Cleaning up X-server permissions..."
        xhost -local:root > /dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

HOST_DIR=../00_data
COLMAP_IMAGE="klaxalk/colmap:latest"

if [ ! -d "$HOST_DIR" ]; then
    echo "Error: Directory '$HOST_DIR' does not exist."
    exit 1
fi

# --- Docker Arguments ---
# We switch to --gpus all, which is the modern standard
DOCKER_ARGS=(
    -it --rm
    --gpus all
    --user $(id -u):$(id -g)
    -v "${HOST_DIR}:/working"
    -w /working
    -e NVIDIA_DRIVER_CAPABILITIES=all
)

# --- SSH / GUI Check ---
# If DISPLAY is missing (common in SSH), we skip GUI-specific flags
if [ -z "$DISPLAY" ]; then
    echo "Using SSH mode: Skipping X-server requirements."
else
    echo "Display detected ($DISPLAY). Enabling GUI support..."
    DOCKER_ARGS+=( -e DISPLAY=$DISPLAY --net=host )
    # Only run xhost if we aren't on a restricted remote shell
    xhost +local:root > /dev/null 2>&1 || echo "Warning: Could not set xhost permissions."
fi

# --- Execute ---
# We explicitly tell COLMAP to use the GPU for Sift Extraction
echo "Running COLMAP Sparse reconstruction"

mkdir -p $HOST_DIR/workspace/sparse

docker run "${DOCKER_ARGS[@]}" "${COLMAP_IMAGE}" \
	colmap hierarchical_mapper --help \
    --database_path /working/sparse.db \
    --image_path /working/images \
    --output_path /working/workspace/sparse \
    --Mapper.ba_use_gpu 1 \
    --Mapper.min_model_size 50 \
    --Mapper.max_model_overlap 30

  # # Arguments for the hierarchical_mapper
  # # Defaults for reference
  # --Mapper.max_num_models arg (=50)
  # --Mapper.max_model_overlap arg (=20)
  # --Mapper.min_model_size arg (=10)
