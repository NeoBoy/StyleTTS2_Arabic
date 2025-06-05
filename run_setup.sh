#!/bin/bash
# This script installs Anaconda distribution and speech related tools then clones the repository, 
# creates a conda environment using arabicTTS.yml,
# downloads both splits of the Arabic TTS dataset from Hugging Face using the /cache directory
# for dataset files, then saves the audio files in the wav_data/ folder and meta data in a CSV file.

set -euo pipefail   # exit on error, unset vars, or failed pipes

# Fetch the latest Anaconda installer name from the archive
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
apt-get install -y vim less espeak-ng wget

# ---------------------
# Download and Install Latest Anaconda
# ---------------------
echo "Downloading Anaconda installer: ${ANACONDA_VER}"
wget https://repo.anaconda.com/archive/${ANACONDA_VER}

chmod +x ${ANACONDA_VER}

echo "Installing Anaconda to \$HOME/anaconda3..."
bash "${ANACONDA_VER}" -b -p "$HOME/anaconda3"

source "$HOME/anaconda3/etc/profile.d/conda.sh"
echo "source \$HOME/anaconda3/etc/profile.d/conda.sh" >> ~/.bashrc

# Optionally update conda in the base environment to latest version
echo "Updating conda to the latest version..."
conda update -n base -c defaults conda -y

# ---------------------
# Repository & Environment Setup
# ---------------------
REPO_URL="https://github.com/MachineLearning-IIUI/StyleTTS2_Arabic.git"
REPO_DIR="StyleTTS2_Arabic"
ENV_YML="arabicTTS.yml"

# Parameters for the Python script.
DATASET_NAME="NeoBoy/arabic-tts-wav-24k"  # Dataset identifier on Hugging Face
SPLITS="train,test"                      # Comma-separated list of dataset splits
CACHE_DIR="cache"                        # Directory used for caching dataset files (in .gitignore)
OUTPUT_DIR="wav_data"                    # Directory where audio files will be saved (in .gitignore)
META_CSV="dataset_metadata.csv"          # CSV file to store metadata

echo "Cloning repository from $REPO_URL..."
if [ ! -d "$REPO_DIR" ]; then
  git clone "$REPO_URL"
fi
cd "$REPO_DIR"

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
