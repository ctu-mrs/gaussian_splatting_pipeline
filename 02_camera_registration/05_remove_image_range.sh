#!/bin/bash

# Check if the user provided the start and end range
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <start_id> <end_id>"
    echo "Example: $0 5031 5047"
    exit 1
fi

START_ID=$1
END_ID=$2

PROJECT=../00_data
INPUT_MODEL=workspace/sparse/0 
OUTPUT_MODEL=workspace/sparse/0
LIST_FILE=images_to_delete.txt

echo "Preparing to delete image range: $START_ID to $END_ID"

# 1. Generate a text file with one filename per line inside your data folder
seq -f "image_%04g.jpg" "$START_ID" "$END_ID" > "$PROJECT/$LIST_FILE"

# Ensure the output directory exists
mkdir -p "$PROJECT/$OUTPUT_MODEL"

# --- Docker Arguments ---
DOCKER_ARGS=(
    -it --rm
    --user "$(id -u):$(id -g)"
    -v "./$PROJECT:/working"
    -w /working
)

echo "Executing COLMAP image_deleter..."

# --- Execute ---
docker run "${DOCKER_ARGS[@]}" \
  klaxalk/colmap:latest \
  colmap image_deleter \
  --input_path "/working/$INPUT_MODEL" \
  --output_path "/working/$OUTPUT_MODEL" \
  --image_names "/working/$LIST_FILE"

echo "-"
echo "Done! The new, cleaned sparse model is saved in: $PROJECT/$OUTPUT_MODEL"
