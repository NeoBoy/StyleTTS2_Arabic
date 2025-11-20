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
  # Ensure Poetry is on PATH for this script
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
# Python Version via pyenv (use 3.10 for dependency compatibility)
# ---------------------
PYTHON_VERSION="3.10.14"

if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  echo "Installing Python $PYTHON_VERSION via pyenv..."
  pyenv install "$PYTHON_VERSION"
fi

echo "Setting local Python version to $PYTHON_VERSION..."
pyenv local "$PYTHON_VERSION"
eval "$(pyenv init -)"

# ---------------------
# Ensure pyproject.toml exists, then import requirements.txt into Poetry
# ---------------------
if [ ! -f pyproject.toml ]; then
  echo "No pyproject.toml found. Initializing a minimal Poetry project..."
  poetry init -n --name "styletss2-arabic"
  # Optionally constrain Python version in pyproject later by hand:
  #   python = "3.10.*"
fi

# Use the pyenv Python in Poetry
poetry env use "$PYTHON_VERSION"

# If requirements.txt exists, import it into Poetry (excluding 'typing' backport)
if [ -f requirements.txt ]; then
  echo "Importing requirements.txt into Poetry (skipping 'typing')..."
  DEPS=$(grep -v '^\s*#' requirements.txt | grep -vi '^typing' | tr '\n' ' ')
  if [ -n "$DEPS" ]; then
    poetry add $DEPS
  fi
fi

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