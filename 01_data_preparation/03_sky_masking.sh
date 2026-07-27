#!/bin/sh
"exec" "`dirname $0`/python-env/bin/python3" "$0" "$@"

import os
import cv2
import numpy as np
import torch
import subprocess
import sys
from glob import glob
from PIL import Image

# Auto-install required ML libraries
try:
    from transformers import SegformerImageProcessor, SegformerForSemanticSegmentation
except ImportError:
    print("Required ML libraries not found. Installing...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "transformers", "torch", "torchvision", "Pillow"])
    from transformers import SegformerImageProcessor, SegformerForSemanticSegmentation

# ==========================================
# SETTINGS
# ==========================================
IMAGES_DIR = "../00_data/images"
MASKS_DIR = "../00_data/masks"
# ==========================================

os.makedirs(MASKS_DIR, exist_ok=True)

print("Loading SegFormer segmentation model (this may take a moment to download weights on first run)...")
processor = SegformerImageProcessor.from_pretrained("nvidia/segformer-b0-finetuned-ade-512-512")
model = SegformerForSemanticSegmentation.from_pretrained("nvidia/segformer-b0-finetuned-ade-512-512")

# Move to GPU if available for faster inference
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)

image_paths = sorted(glob(os.path.join(IMAGES_DIR, "*.jpg")))
print(f"Found {len(image_paths)} images. Generating masks...")

# In the ADE20k dataset ontology, the 'sky' class is always label index 2
SKY_LABEL_ID = 2

processed_count = 0

for img_path in image_paths:
    filename = os.path.basename(img_path)
    # Nerfstudio expects the mask to have the exact same filename. 
    # We save as PNG to prevent compression artifacts on the strict black/white borders.
    mask_filename = filename.replace('.jpg', '.png')
    mask_path = os.path.join(MASKS_DIR, mask_filename)

    # Skip if already generated
    if os.path.exists(mask_path):
        continue

    image = Image.open(img_path).convert("RGB")
    
    # Run the image through the segmentation network
    inputs = processor(images=image, return_tensors="pt").to(device)
    with torch.no_grad():
        outputs = model(**inputs)
        logits = outputs.logits 

    # The model outputs a smaller tensor. We must mathematically interpolate it back to the original image resolution.
    upsampled_logits = torch.nn.functional.interpolate(
        logits,
        size=image.size[::-1], 
        mode="bilinear",
        align_corners=False,
    )

    # Extract the highest probability class for each pixel
    predictions = upsampled_logits.argmax(dim=1).squeeze().cpu().numpy()

    # Create the binary mask: 
    # Valid geometry = 255 (White)
    # Ignored sky = 0 (Black)
    mask = np.ones_like(predictions, dtype=np.uint8) * 255
    mask[predictions == SKY_LABEL_ID] = 0

    cv2.imwrite(mask_path, mask)
    processed_count += 1
    
    print(f"[{processed_count}/{len(image_paths)}] Created mask for {filename}")

print("-" * 50)
print(f"Done! Successfully generated {processed_count} sky masks in {MASKS_DIR}")
