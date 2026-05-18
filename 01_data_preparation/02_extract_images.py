#!/bin/sh
"exec" "`dirname $0`/python-env/bin/python3" "$0" "$@"

import os
import cv2

# ==========================================
# SETTINGS
# ==========================================
INPUT_FILE = "../00_data/video.mp4"
OUTPUT_DIR = "../00_data/images"
MAX_COUNT = 1000

# Match Threshold: What % of features MUST match to consider it the "same" scene?
MATCH_THRESHOLD = 0.30
# ==========================================

os.makedirs(OUTPUT_DIR, exist_ok=True)
cap = cv2.VideoCapture(INPUT_FILE)

if not cap.isOpened():
    print(f"Error: Could not open video {INPUT_FILE}")
    exit(1)

# Get the total number of frames in the video for our estimation math
total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

# 1. Initialize the Feature Detector
detector = cv2.ORB_create(nfeatures=1000) 
matcher = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)

# Read the baseline frame
ret, prev_frame = cap.read()
if not ret:
    print("Error: Could not read first frame.")
    exit(1)

# Detect features in the first frame
prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
prev_kp, prev_des = detector.detectAndCompute(prev_gray, None)

saved_count = 0
frame_id = 0

print(f"Processing video using Feature Matching ({total_frames} total frames)...")

while cap.isOpened() and saved_count < MAX_COUNT:
    ret, frame = cap.read()
    if not ret:
        break  # End of video
        
    frame_id += 1
    
    # Convert current frame to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    
    # Detect features in current frame
    kp, des = detector.detectAndCompute(gray, None)
    
    # If either frame has zero features detected, handle gracefully
    if des is None or prev_des is None:
        continue
        
    # Match descriptors between the reference frame and current frame
    matches = matcher.match(prev_des, des)
    
    # Calculate what percentage of original features survived/matched
    total_baseline_features = len(prev_kp)
    match_fraction = len(matches) / total_baseline_features
    
    # If feature similarity drops BELOW our threshold, significant motion happened
    if match_fraction < MATCH_THRESHOLD:
        saved_count += 1
        output_path = os.path.join(OUTPUT_DIR, f"image_{saved_count:03d}.jpg")
        cv2.imwrite(output_path, frame)
        
        # --- Uncapped Estimation Math ---
        video_progress_fraction = frame_id / total_frames
        
        if video_progress_fraction > 0:
            # Extrapolate completely without capping at MAX_COUNT
            estimated_total = int(saved_count / video_progress_fraction)
            estimate_string = str(estimated_total)
        else:
            estimate_string = "Calculating..."
            
        # Print out the stats clean and scannable
        print(f"Saved: {output_path} | Similarity: {match_fraction*100:.1f}%")
        print(f"      Progress: {video_progress_fraction*100:.1f}% | Uncapped Est. Total Images: {estimate_string}")
        print("-" * 50)
        
        # Reset the baseline to this frame so we track subsequent changes relative to it
        prev_kp, prev_des = kp, des
        

cap.release()
print(f"\nDone! Final yield: Extracted {saved_count} images.")
