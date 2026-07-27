#!/bin/sh
"exec" "`dirname $0`/python-env/bin/python3" "$0" "$@"

import os
import cv2
import numpy as np

# ==========================================
# SETTINGS
# ==========================================
INPUT_FILE = "../00_data/berlin_1_1.MP4"
OUTPUT_DIR = "../00_data/images"
MAX_COUNT = 6000  

START_TIME_SEC = 0     # Time in seconds to start extracting from
START_IMAGE_ID = 6450       # The starting ID for the output filenames (e.g., image_0001.png)

# WINDOW THRESHOLDS (0.0 to 1.0)
# We collect frames while similarity is between these two numbers
MATCH_THRESHOLD_HIGH = 0.45
MATCH_THRESHOLD_LOW = 0.35
# ==========================================

os.makedirs(OUTPUT_DIR, exist_ok=True)
cap = cv2.VideoCapture(INPUT_FILE)

if not cap.isOpened():
    print(f"Error: Could not open video {INPUT_FILE}")
    exit(1)

# Jump to the specified start time
if START_TIME_SEC > 0.0:
    cap.set(cv2.CAP_PROP_POS_MSEC, START_TIME_SEC * 1000.0)

total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
start_frame_id = int(cap.get(cv2.CAP_PROP_POS_FRAMES))

detector = cv2.ORB_create(nfeatures=1000) 
matcher = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)

def get_sharpness(gray_img):
    return cv2.Laplacian(gray_img, cv2.CV_64F).var()

# Read the first frame at the start time to seed the tracking
ret, prev_frame = cap.read()
if not ret:
    print(f"Error: Could not read frame at {START_TIME_SEC}s. Is the time beyond the video length?")
    exit(1)

prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
initial_sharpness = get_sharpness(prev_gray)

prev_kp, prev_des = detector.detectAndCompute(prev_gray, None)

images_saved_this_session = 0
current_image_id = START_IMAGE_ID - 1
frame_id = int(cap.get(cv2.CAP_PROP_POS_FRAMES))

# Buffer to store candidate frames within the threshold window
# Stores dicts: {"frame": mat, "kp": kp, "des": des, "similarity": float, "sharpness": float}
frame_buffer = []

print(f"Processing video starting from {START_TIME_SEC}s (Frame {start_frame_id}/{total_frames})...")
print(f"Output filenames will start at image_{START_IMAGE_ID:04d}.png")
print(f"Initial anchor sharpness: {initial_sharpness:.1f}")
print("-" * 50)

while cap.isOpened() and images_saved_this_session < MAX_COUNT:
    ret, frame = cap.read()
    
    # Handle normal frames or the end-of-video flush
    if ret:
        frame_id += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Calculate matching metrics
        kp, des = detector.detectAndCompute(gray, None)
        if des is None or prev_des is None:
            continue
            
        matches = matcher.match(prev_des, des)
        total_baseline_features = len(prev_kp)
        match_fraction = len(matches) / total_baseline_features
        sharpness_score = get_sharpness(gray)
    else:
        # End of video reached. Force match_fraction to 0 to flush any leftover buffer
        match_fraction = 0.0

    # --- WINDOW EVALUATION ENGINE ---
    
    # Case 1: Camera is inside the movement window
    if MATCH_THRESHOLD_LOW <= match_fraction < MATCH_THRESHOLD_HIGH and ret:
        # Add this frame to our candidate pool
        frame_buffer.append({
            "frame": frame.copy(),
            "kp": kp,
            "des": des,
            "similarity": match_fraction,
            "sharpness": sharpness_score
        })
        
    # Case 2: Camera has moved PAST the window (Similarity dropped below LOW threshold) OR video ended
    elif match_fraction < MATCH_THRESHOLD_LOW:
        
        if frame_buffer:
            # OPTIMIZATION: Extract the frame that achieved maximum sharpness in the pool
            best_candidate = max(frame_buffer, key=lambda x: x["sharpness"])
            
            images_saved_this_session += 1
            current_image_id += 1
            output_path = os.path.join(OUTPUT_DIR, f"image_{current_image_id:04d}.png")
            cv2.imwrite(output_path, best_candidate["frame"])
            
            # Calculate progress based on the session's starting frame
            session_frames_processed = frame_id - start_frame_id
            session_progress_fraction = session_frames_processed / (total_frames - start_frame_id) if (total_frames - start_frame_id) > 0 else 1
            estimated_total = int(images_saved_this_session / session_progress_fraction) if session_progress_fraction > 0 else 0
                
            print(f"Saved: {output_path}")
            print(f"      Reason: Extracted peak sharp frame from a pool of {len(frame_buffer)} window candidates.")
            print(f"      Selected Similarity: {best_candidate['similarity']*100:.1f}% | Sharpness: {best_candidate['sharpness']:.1f}")
            print(f"      Pool Range: Min Similarity {frame_buffer[-1]['similarity']*100:.1f}% -> Max {frame_buffer[0]['similarity']*100:.1f}%")
            print(f"      Session Progress: {session_progress_fraction*100:.1f}% | Est. Total Images This Run: {estimated_total}")
            print("-" * 50)
            
            # Update baseline anchoring using our best saved frame
            prev_kp, prev_des = best_candidate["kp"], best_candidate["des"]
            
            # Clear the buffer pool for the next physical camera movement step
            frame_buffer.clear()
            
        elif ret:
            # Emergency fallback: If the camera moved so fast in a single frame update that 
            # it instantly skipped past our high window directly below 0.30, save this frame raw.
            images_saved_this_session += 1
            current_image_id += 1
            output_path = os.path.join(OUTPUT_DIR, f"image_{current_image_id:04d}.png")
            cv2.imwrite(output_path, frame)
            
            print(f"Saved: {output_path}")
            print(f"      Reason: Instant movement skip fallback (Bypassed window pool).")
            print(f"      Similarity: {match_fraction*100:.1f}% | Sharpness: {sharpness_score:.1f}")
            print("-" * 50)
            
            prev_kp, prev_des = kp, des

    # Stop looping if video ended
    if not ret:
        break

cap.release()
print(f"\nDone! Successfully extracted {images_saved_this_session} peak-sharpness PNG images in this session.")
