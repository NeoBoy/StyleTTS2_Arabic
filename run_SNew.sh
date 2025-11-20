#!/bin/bash
# This script installs pyenv and poetry, then:
# - clones the repository
# - creates a pyenv-based Python for the project
# - installs dependencies with poetry
# - downloads both splits of the Arabic TTS dataset from Hugging Face
#   into /cache and saves audio files + metadata.

set -euo pipefail   # Exit on error, unset vars, or failed pipes

# ---------------------
# System Update & Package Installation
# ---------------------
echo "Updating system and installing required packages..."
sudo apt-get update
sudo apt-get install -y \
  vim less espeak-ng wget curl git build-essential \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
  libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
  libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# ---------------------
# Install pyenv (if not installed)
# ---------------------
if ! command -v pyenv >/dev/null 2>&1; then
  echo "Installing pyenv..."
  curl https://pyenv.run | bash

  # Add pyenv init to shell startup
  if ! grep -q 'pyenv init' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'EOF'

# pyenv initialization
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF
  fi

  # Initialize pyenv for current shell
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
else
  echo "pyenv already installed."
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

# ---------------------
# Install Poetry (if not installed)
# ---------------------
if ! command -v poetry >/dev/null 2>&1; then
  echo "Installing poetry..."
  curl -sSL https://install.python-poetry.org | python3 -
  # Add poetry to PATH
  if ! grep -q 'poetry/bin' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi
  export PATH="$HOME/.local/bin:$PATH"
else
  echo "poetry already installed."
  export PATH="$HOME/.local/bin:$PATH"
fi

# ---------------------
# Repository & Project Setup
# ---------------------
REPO_URL="https://github.com/MachineLearning-IIUI/StyleTTS2_Arabic.git"
REPO_DIR="StyleTTS2_Arabic"

# Parameters for the Python script (which is inside the repo)
DATASET_NAME="NeoBoy/arabic-tts-wav-24k"  # Dataset identifier on Hugging Face
SPLITS="train,test"                      # Comma-separated list of dataset splits
CACHE_DIR="cache"                        # Directory used for caching dataset files
OUTPUT_DIR="wav_data"                    # Directory where audio files will be saved
META_CSV="dataset_metadata.csv"          # CSV file to store metadata

# ---------------------
# Clone or Force Reset Repository
# ---------------------
if [ ! -d "$REPO_DIR" ]; then
  echo "Cloning repository from $REPO_URL..."
  git clone "$REPO_URL"
  cd "$REPO_DIR"
else
  echo "Repository folder exists. Discarding local changes before updating..."
  cd "$REPO_DIR"
  git reset --hard HEAD
  git fetch origin
  git reset --hard origin/main
fi

# ---------------------
# Python Version via pyenv
# ---------------------
# Choose a Python version that your project supports
PYTHON_VERSION="3.12.9"

if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  echo "Installing Python $PYTHON_VERSION via pyenv..."
  pyenv install "$PYTHON_VERSION"
fi

echo "Setting local Python version to $PYTHON_VERSION..."
pyenv local "$PYTHON_VERSION"

# Ensure the new Python is active in this shell
eval "$(pyenv init -)"

# ---------------------
# Poetry Environment & Dependencies
# ---------------------
# If you have a pyproject.toml in the repo, this will create/activate
# a virtualenv managed by Poetry and install dependencies.
echo "Installing dependencies with poetry..."
poetry env use "$PYTHON_VERSION"
poetry install --no-interaction --no-root

# ---------------------
# Execute the Python Script via Poetry
# ---------------------
echo "Executing hfData2WavFiles.py with the provided arguments via poetry..."
poetry run python hfData2WavFiles.py \
  --dataset_name "$DATASET_NAME" \
  --splits "$SPLITS" \
  --cache_dir "$CACHE_DIR" \
  --output_dir "$OUTPUT_DIR" \
  --meta_csv "$META_CSV"

echo "Processing complete."