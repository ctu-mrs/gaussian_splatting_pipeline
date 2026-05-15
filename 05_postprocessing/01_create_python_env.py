#!/bin/bash

# Get the absolute path to the directory where this script is located
MY_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$MY_PATH"

# 1. Check if the environment directory already exists
if [ -d "python-env" ]; then
    echo "Python environment 'python-env' already exists. Skipping creation."
else
    echo "Creating new Python environment..."

    # Ensure python3-venv is installed
    sudo apt-get -y install python3-venv

    # Create the environment
    python3 -m venv python-env
    echo "Environment created successfully."
fi

# 2. Activate the environment
# Note: Activation only persists for the duration of this script's execution
source ./python-env/bin/activate

# 3. Install/Update requirements if the file exists
if [ -f "requirements.txt" ]; then
    echo "Installing requirements..."
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements.txt
else
    echo "Warning: requirements.txt not found. Skipping pip install."
fi

echo "Setup complete."
