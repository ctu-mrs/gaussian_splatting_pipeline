#!/bin/bash

./01_data_preparation/01_extract_images.sh

./02_camera_registration/01_extract_features.sh
./02_camera_registration/02_feature_matching.sh
./02_camera_registration/03_sparse_reconstruction.sh
./02_camera_registration/04_gui_visual_check.sh

./03_dense_reconstruction/01_undistort_images.sh
./03_dense_reconstruction/02_stereo_reconstruction.sh
./03_dense_reconstruction/03_stereo_fusion.sh
./03_dense_reconstruction/04_poisson_mesh.sh

./04_splat_generation/01_convert_to_nerfstudio.sh
./04_splat_generation/02_splatfacto.sh
./04_splat_generation/03_export_splat.sh

./05_postprocessing/01_create_python_env.py
./05_postprocessing/02_transform_mesh.sh
