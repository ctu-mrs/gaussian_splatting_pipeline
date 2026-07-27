#!/bin/sh
"exec" "`dirname $0`/python-env/bin/python3" "$0" "$@"

import os
import cv2
import numpy as np
import re
import subprocess
import sys

# Auto-install piexif for EXIF metadata writing if missing
try:
    import piexif
except ImportError:
    print("piexif library not found. Installing into environment...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "piexif"])
    import piexif

# ==========================================
# SETTINGS
# ==========================================
INPUT_FILE = "../00_data/berlin_2_1.MP4"
INPUT_SRT = "../00_data/berlin_2_1.SRT"  # Path to DJI subtitle file
OUTPUT_DIR = "../00_data/images"
MAX_COUNT = 10000  

START_TIME_SEC = 0.0     # Time in seconds to start extracting from
START_IMAGE_ID = 3443       # The starting ID for the output filenames (e.g., image_0001.jpg)

# WINDOW THRESHOLDS (0.0 to 1.0)
# We collect frames while similarity is between these two numbers
MATCH_THRESHOLD_HIGH = 0.55
MATCH_THRESHOLD_LOW = 0.45
# ==========================================

os.makedirs(OUTPUT_DIR, exist_ok=True)

# ==========================================
# 1. PARSE THE DJI SRT FILE
# ==========================================
gps_data = {}
if os.path.exists(INPUT_SRT):
    print(f"Found DJI subtitle file: {INPUT_SRT}. Parsing GPS telemetry...")
    with open(INPUT_SRT, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split by double newline to get individual subtitle blocks
    blocks = content.strip().split('\n\n')
    for block in blocks:
        try:
            # 1. Find the Frame Count
            frame_m = re.search(r'FrameCnt:\s*(\d+)', block)
            if not frame_m:
                continue
            frame_idx = int(frame_m.group(1))
            
            # 2. Find Latitude and Longitude
            lat_m = re.search(r'\[latitude:\s*([-\d.]+)\]', block)
            lon_m = re.search(r'\[longitude:\s*([-\d.]+)\]', block)
            
            # 3. Find Altitude (No bracket requirement)
            abs_alt_m = re.search(r'abs_alt:\s*([-\d.]+)', block)
            rel_alt_m = re.search(r'rel_alt:\s*([-\d.]+)', block)
            
            if lat_m and lon_m:
                lat = float(lat_m.group(1))
                lon = float(lon_m.group(1))
                
                # Default to 0.0 if both altitude readings completely fail
                alt = 0.0
                if abs_alt_m:
                    alt = float(abs_alt_m.group(1))
                elif rel_alt_m:
                    alt = float(rel_alt_m.group(1))
                    
                gps_data[frame_idx] = (lat, lon, alt)
                
        except ValueError:
            continue
            
    print(f"Successfully loaded {len(gps_data)} GPS coordinates to map to frames.")
else:
    print(f"Warning: No SRT file found at {INPUT_SRT}. Images will lack EXIF data.")

# Helper to format GPS for EXIF specification
def create_gps_exif(lat, lng, alt):
    def to_deg(value, loc):
        loc_value = loc[0] if value < 0 else loc[1]
        abs_value = abs(value)
        deg = int(abs_value)
        t1 = (abs_value - deg) * 60
        min_val = int(t1)
        sec = (t1 - min_val) * 60
        return ((deg, 1), (min_val, 1), (int(sec * 100000), 100000)), loc_value

    lat_deg, lat_ref = to_deg(lat, ["S", "N"])
    lng_deg, lng_ref = to_deg(lng, ["W", "E"])
    
    exif_dict = {"GPS": {
        piexif.GPSIFD.GPSLatitudeRef: lat_ref,
        piexif.GPSIFD.GPSLatitude: lat_deg,
        piexif.GPSIFD.GPSLongitudeRef: lng_ref,
        piexif.GPSIFD.GPSLongitude: lng_deg,
        piexif.GPSIFD.GPSAltitudeRef: 0 if alt >= 0 else 1,
        piexif.GPSIFD.GPSAltitude: (int(abs(alt) * 1000), 1000)
    }}
    return piexif.dump(exif_dict)

# ==========================================
# 2. VIDEO PROCESSING ENGINE
# ==========================================
cap = cv2.VideoCapture(INPUT_FILE)
if not cap.isOpened():
    print(f"Error: Could not open video {INPUT_FILE}")
    exit(1)

if START_TIME_SEC > 0.0:
    cap.set(cv2.CAP_PROP_POS_MSEC, START_TIME_SEC * 1000.0)

total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
start_frame_id = int(cap.get(cv2.CAP_PROP_POS_FRAMES))

detector = cv2.ORB_create(nfeatures=1000) 
matcher = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)

def get_sharpness(gray_img):
    return cv2.Laplacian(gray_img, cv2.CV_64F).var()

ret, prev_frame = cap.read()
if not ret:
    print(f"Error: Could not read frame at {START_TIME_SEC}s.")
    exit(1)

prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
initial_sharpness = get_sharpness(prev_gray)
prev_kp, prev_des = detector.detectAndCompute(prev_gray, None)

images_saved_this_session = 0
current_image_id = START_IMAGE_ID - 1
frame_id = int(cap.get(cv2.CAP_PROP_POS_FRAMES))

frame_buffer = []

print(f"Processing video starting from {START_TIME_SEC}s (Frame {start_frame_id}/{total_frames})...")
print("-" * 50)

while cap.isOpened() and images_saved_this_session < MAX_COUNT:
    ret, frame = cap.read()
    
    if ret:
        frame_id += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        kp, des = detector.detectAndCompute(gray, None)
        if des is None or prev_des is None:
            continue
            
        matches = matcher.match(prev_des, des)
        match_fraction = len(matches) / len(prev_kp)
        sharpness_score = get_sharpness(gray)
    else:
        match_fraction = 0.0

    if MATCH_THRESHOLD_LOW <= match_fraction < MATCH_THRESHOLD_HIGH and ret:
        frame_buffer.append({
            "frame": frame.copy(),
            "frame_id": frame_id,  
            "kp": kp,
            "des": des,
            "similarity": match_fraction,
            "sharpness": sharpness_score
        })
        
    elif match_fraction < MATCH_THRESHOLD_LOW:
        if frame_buffer:
            best_candidate = max(frame_buffer, key=lambda x: x["sharpness"])
            
            images_saved_this_session += 1
            current_image_id += 1
            
            # Save as JPG to support EXIF metadata
            output_path = os.path.join(OUTPUT_DIR, f"image_{current_image_id:04d}.jpg")
            cv2.imwrite(output_path, best_candidate["frame"])
            
            # Inject GPS Data
            best_frame_id = best_candidate["frame_id"]
            if best_frame_id in gps_data:
                lat, lon, alt = gps_data[best_frame_id]
                exif_bytes = create_gps_exif(lat, lon, alt)
                piexif.insert(exif_bytes, output_path)
                gps_log = f"Lat {lat:.5f}, Lon {lon:.5f}, Alt {alt:.1f}m"
            else:
                gps_log = "No GPS found for frame."

            session_frames_processed = frame_id - start_frame_id
            session_progress_fraction = session_frames_processed / (total_frames - start_frame_id) if (total_frames - start_frame_id) > 0 else 1
            estimated_total = int(images_saved_this_session / session_progress_fraction) if session_progress_fraction > 0 else 0
                
            print(f"Saved: {output_path}")
            print(f"      Pool Match : Extracted peak sharp frame from {len(frame_buffer)} candidates.")
            print(f"      Telemetry  : {gps_log}")
            print(f"      Progress   : {session_progress_fraction*100:.1f}% | Est. Total: {estimated_total}")
            print("-" * 50)
            
            prev_kp, prev_des = best_candidate["kp"], best_candidate["des"]
            frame_buffer.clear()
            
        elif ret:
            # Emergency skip fallback
            images_saved_this_session += 1
            current_image_id += 1
            output_path = os.path.join(OUTPUT_DIR, f"image_{current_image_id:04d}.jpg")
            cv2.imwrite(output_path, frame)
            
            if frame_id in gps_data:
                lat, lon, alt = gps_data[frame_id]
                exif_bytes = create_gps_exif(lat, lon, alt)
                piexif.insert(exif_bytes, output_path)
                gps_log = f"Lat {lat:.5f}, Lon {lon:.5f}, Alt {alt:.1f}m"
            else:
                gps_log = "No GPS found for frame."
            
            print(f"Saved: {output_path}")
            print(f"      Reason     : Instant movement skip fallback (Bypassed window pool).")
            print(f"      Telemetry  : {gps_log}")
            print("-" * 50)
            
            prev_kp, prev_des = kp, des

    if not ret:
        break

cap.release()
print(f"\nDone! Successfully extracted {images_saved_this_session} georeferenced JPG images.")
