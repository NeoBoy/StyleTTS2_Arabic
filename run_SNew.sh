#!/bin/bash

set -euo pipefail

echo "Updating system and installing required packages..."
sudo apt-get update
sudo apt-get install -y \
  vim less espeak-ng wget curl git build-essential \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
  libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
  libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# ---------------------
# Ensure pyenv is available (but do NOT reinstall if /root/.pyenv exists)
# ---------------------
if [ ! -d "$HOME/.pyenv" ] && ! command -v pyenv >/dev/null 2>&1; then
  echo "Installing pyenv..."
  curl https://pyenv.run | bash
else
  echo "pyenv already present at $HOME/.pyenv or on PATH."
fi

# Initialize pyenv for this script
export PATH="$HOME/.pyenv/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
else
  echo "ERROR: pyenv not found on PATH even after install. Aborting."
  exit 1
fi

# ---------------------
# Install Poetry (if not installed)
# ---------------------
if ! command -v poetry >/dev/null 2>&1; then
  echo "Installing poetry..."
  curl -sSL https://install.python-poetry.org | python3 -
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

DATASET_NAME="NeoBoy/arabic-tts-wav-24k"
SPLITS="train,test"
CACHE_DIR="cache"
OUTPUT_DIR="wav_data"
META_CSV="dataset_metadata.csv"

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
PYTHON_VERSION="3.12.9"

if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  echo "Installing Python $PYTHON_VERSION via pyenv..."
  pyenv install "$PYTHON_VERSION"
fi

echo "Setting local Python version to $PYTHON_VERSION..."
pyenv local "$PYTHON_VERSION"
eval "$(pyenv init -)"

# ---------------------
# Remove existing pyproject.toml and Poetry env to start fresh
# ---------------------
echo "Cleaning up any existing Poetry configuration..."
rm -f pyproject.toml poetry.lock
poetry env remove --all 2>/dev/null || true

# ---------------------
# Create pyproject.toml with correct Python constraint
# ---------------------
echo "Creating pyproject.toml with Python constraint >=3.12,<3.15..."
cat > pyproject.toml <<EOF
[tool.poetry]
name = "styletts2-arabic"
version = "0.1.0"
description = "Arabic TTS using StyleTTS2"
authors = ["Your Name <you@example.com>"]

[tool.poetry.dependencies]
python = ">=3.12,<3.15"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
EOF

# Use the pyenv Python in Poetry
poetry env use "$PYTHON_VERSION"

# ---------------------
# Import dependencies from requirements.txt (excluding 'typing' and PyTorch libs)
# ---------------------
if [ -f requirements.txt ]; then
  echo "Importing requirements.txt into Poetry (skipping 'typing' and PyTorch libs)..."
  # Skip typing, torch, torchaudio, torchvision - we'll add them separately with specific versions
  DEPS=$(grep -v '^\s*#' requirements.txt | \
         grep -vi '^typing' | \
         grep -vi '^torch' | \
         grep -vi '^torchaudio' | \
         grep -vi '^torchvision' | \
         tr '\n' ' ')
  if [ -n "$DEPS" ]; then
    echo "Adding non-PyTorch dependencies to Poetry..."
    poetry add $DEPS
  fi
fi

# ---------------------
# Add PyTorch libraries with specific version 2.7.0 + torchcodec
# ---------------------
echo "Adding PyTorch libraries with version 2.7.0 and torchcodec..."
poetry add torch==2.7.0 torchaudio==2.7.0 torchcodec

echo "Installing dependencies with poetry..."
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