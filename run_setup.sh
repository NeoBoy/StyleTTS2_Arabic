#!/bin/bash
# This script installs Anaconda distribution and speech related tools then clones the repository, 
# creates a conda environment using arabicTTS.yml,
# downloads both splits of the Arabic TTS dataset from Hugging Face using the /cache directory
# for dataset files, then saves the audio files in the wav_data/ folder and meta data in a CSV file.

set -euo pipefail   # Exit on error, unset vars, or failed pipes

# ---------------------
# Fetch the Latest Anaconda Installer
# ---------------------
echo "Fetching the latest Anaconda installer from https://repo.anaconda.com/archive/ ..."
ANACONDA_VER=$(curl -s https://repo.anaconda.com/archive/ | grep -Eo 'Anaconda3-[0-9]{4}\.[0-9]{2}-1-Linux-x86_64.sh' | sort -V | tail -n 1)
if [ -z "$ANACONDA_VER" ]; then
    echo "Error: Could not determine the latest Anaconda installer version."
    exit 1
fi
echo "Latest Anaconda installer: ${ANACONDA_VER}"

# ---------------------
# System Update & Package Installation
# ---------------------
echo "Updating system and installing required packages..."
apt-get update
apt-get install -y vim less espeak-ng wget curl git

# ---------------------
# Download and Install Latest Anaconda
# ---------------------
# ...existing code...

if [ -d "$HOME/anaconda3" ]; then
    echo "Anaconda is already installed at $HOME/anaconda3. Skipping installation..."
else
    echo "Downloading Anaconda installer: ${ANACONDA_VER}"
    if [ -f "${ANACONDA_VER}" ]; then
        echo "Installer ${ANACONDA_VER} already exists. Skipping download."
    else
        wget https://repo.anaconda.com/archive/${ANACONDA_VER}
    fi
    chmod +x "${ANACONDA_VER}"

    echo "Installing Anaconda to $HOME/anaconda3..."
    bash "${ANACONDA_VER}" -b -p "$HOME/anaconda3"
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
    echo "source \$HOME/anaconda3/etc/profile.d/conda.sh" >> ~/.bashrc

    echo "Updating conda to the latest version..."
    conda update -n base -c defaults conda -y
fi



# ---------------------
# Repository & Environment Setup
# ---------------------
REPO_URL="https://github.com/MachineLearning-IIUI/StyleTTS2_Arabic.git"
REPO_DIR="StyleTTS2_Arabic"
ENV_YML="arabicTTS.yml"

# Parameters for the Python script (which is inside the repo)
DATASET_NAME="NeoBoy/arabic-tts-wav-24k"  # Dataset identifier on Hugging Face
SPLITS="train,test"                      # Comma-separated list of dataset splits
CACHE_DIR="cache"                        # Directory used for caching dataset files (should be in .gitignore)
OUTPUT_DIR="wav_data"                    # Directory where audio files will be saved (should be in .gitignore)
META_CSV="dataset_metadata.csv"          # CSV file to store metadata

# ---------------------
# Clone or Force Reset Repository
# ---------------------
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning repository from $REPO_URL..."
    git clone "$REPO_URL"
else
    echo "Repository folder exists. Discarding local changes before updating..."
    cd "$REPO_DIR"

    # Reset all local changes
    git reset --hard HEAD

    # Pull latest updates forcefully, overwriting local changes
    git pull --force origin main
fi

cd "$REPO_DIR"


# ---------------------
# Conda Environment Setup
# ---------------------
echo "Creating the conda environment using $ENV_YML..."
conda env create -f "$ENV_YML" || echo "Conda environment may already exist."
ENV_NAME=$(grep "^name:" "$ENV_YML" | awk '{print $2}')
if [ -z "$ENV_NAME" ]; then
    echo "Error: Unable to determine environment name from $ENV_YML"
    exit 1
fi
echo "Environment created: $ENV_NAME"

echo "Activating conda environment: $ENV_NAME"
conda activate "$ENV_NAME"

# ---------------------
# Upgrade Pip & Reinstall Dependencies
# ---------------------
echo "Upgrading pip and reinstalling all dependencies..."
pip install --upgrade pip
pip install --upgrade --force-reinstall -r requirements.txt


# ---------------------
# Execute the Python Script
# ---------------------
echo "Executing hfData2WavFiles.py with the provided arguments..."
python hfData2WavFiles.py \
  --dataset_name "$DATASET_NAME" \
  --splits "$SPLITS" \
  --cache_dir "$CACHE_DIR" \
  --output_dir "$OUTPUT_DIR" \
  --meta_csv "$META_CSV"

echo "Processing complete."