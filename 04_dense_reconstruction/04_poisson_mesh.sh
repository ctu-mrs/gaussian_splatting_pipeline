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
echo "Running COLMAP Poisson mesh creator"

## Note
## --PoissonMeshing.depth 11 makes it use coarser Octal Map, which results in coarses mesh.
## We want a coarses mesh for Unreal's collition checking.

docker run "${DOCKER_ARGS[@]}" "${COLMAP_IMAGE}" \
	colmap poisson_mesher \
    --input_path /working/workspace/dense/fused.ply \
    --output_path /working/workspace/dense/meshed-poisson.ply \
    --PoissonMeshing.depth 11
