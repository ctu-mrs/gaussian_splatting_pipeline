#!/bin/sh
"exec" "`dirname $0`/python-env/bin/python3" "$0" "$@"

import json
import numpy as np
import open3d as o3d

def align_and_export_glb(input_mesh_path, output_glb_path, json_path):

    # 1. Load data from dataparser_transforms.json
    print(f"Loading transform and scale from: {json_path}")
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    transform_data = np.array(data["transform"])
    scale_factor = data["scale"]

    # 2. Create the Matrices
    transform_matrix = np.eye(4)
    transform_matrix[:3, :4] = transform_data

    # Apply scaling (including your custom 1000.0 multiplier)
    # We are multiplying by 1000 to not cause numerical problems later un Unreal Engine
    scale_matrix = np.eye(4)
    scale_matrix[0, 0] = scale_factor * 1000.0
    scale_matrix[1, 1] = scale_factor * 1000.0
    scale_matrix[2, 2] = scale_factor * 1000.0

    final_matrix = scale_matrix @ transform_matrix

    print(f"Reading mesh: {input_mesh_path}...")
    
    # 3. Load the input mesh using Open3D
    mesh = o3d.io.read_triangle_mesh(input_mesh_path)
    
    if not mesh.has_triangles():
        print("Error: Could not read triangles. Is the file path correct?")
        return

    print("Applying transform matrix...")
    # 4. Apply the mathematical transformation
    mesh.transform(final_matrix)

    print(f"Exporting transformed mesh as GLB to: {output_glb_path}")
    
    # 5. Save as GLB. Open3D automatically handles packing the colors/textures based on the extension!
    o3d.io.write_triangle_mesh(output_glb_path, mesh)
    
    print("Done! Your mesh is now a single, texture-packed .glb file.")

if __name__ == "__main__":

    # --- UPDATE THESE PATHS ---
    INPUT_FILE = "../00_data/workspace/dense/meshed-poisson.ply"
    
    # Notice the extension is now .glb
    OUTPUT_FILE = "../00_data/poisson-mesh-transformed.glb" 
    
    JSON_FILE = "../00_data/nerfstudio_output/nerfstudio_input/splatfacto/dataparser_transforms.json"
    
    align_and_export_glb(INPUT_FILE, OUTPUT_FILE, JSON_FILE)
