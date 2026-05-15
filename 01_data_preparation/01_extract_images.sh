#!/bin/bash

# ==========================================
# SETTINGS - Change these values as needed
# ==========================================

DATA_FOLDER="../00_data"
INPUT_FILE="$DATA_FOLDER/video.mp4"
OUTPUT_PATTERN="$DATA_FOLDER/images/image_%03d.jpg"

mkdir -p $DATA_FOLDER

# Choose "rate" or "count"
# "rate"  = extract X frames per second
# "count" = extract X total frames spread across the video
MODE="count"

# The numeric value for the mode chosen above
VALUE="200"
# ==========================================

# 1. Validation
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file '$INPUT_FILE' not found."
    exit 1
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_PATTERN")"

# 2. Logic Selection
if [[ "$MODE" == "count" ]]; then
    # Calculate FPS based on duration to hit a specific total count
    echo "Calculating duration for fixed count..."
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

    # Calculate the rate (Frames / Duration)
    FPS_RATE=$(echo "scale=4; $VALUE / $DURATION" | bc)
    V_FRAMES="-vframes $VALUE"

    echo "Mode: Fixed Count ($VALUE images)"
    echo "Video Duration: $DURATION seconds"
    echo "Calculated Rate: $FPS_RATE fps"
else
    # Use the value directly as frames per second
    FPS_RATE="$VALUE"
    V_FRAMES=""
    echo "Mode: Fixed Rate ($FPS_RATE fps)"
fi

# 3. Execution
echo "Running FFmpeg..."
ffmpeg -i "$INPUT_FILE" -vf "fps=$FPS_RATE" $V_FRAMES "$OUTPUT_PATTERN" -y

# 4. Final Status
if [[ $? -eq 0 ]]; then
    echo "------------------------------------------------"
    echo "Success: Images extracted to $OUTPUT_PATTERN"
else
    echo "------------------------------------------------"
    echo "Error: Extraction failed. Check if 'bc' and 'ffprobe' are installed."
    exit 1
fi
