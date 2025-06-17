#!/bin/bash

# Set your Hugging Face repo and token
REPO_ID="NeoBoy/style_tts2_finetune_audiobook"
LOCAL_FOLDER="style_tts2/Models/FineTune.AudioBook"
HF_TOKEN="${HUGGINGFACE_TOKEN:?Please set HUGGINGFACE_TOKEN environment variable}"

# Find the most recent .pth file
LATEST_PTH=$(ls -t "$LOCAL_FOLDER"/*.pth 2>/dev/null | head -n 1)

if [ -z "$LATEST_PTH" ]; then
    echo "No .pth files found in $LOCAL_FOLDER"
    exit 1
fi

echo "Latest .pth file: $LATEST_PTH"

# Install huggingface_hub CLI if not present
if ! command -v huggingface-cli &> /dev/null; then
    pip install huggingface_hub
fi

# Create the repo if it doesn't exist
huggingface-cli repo create "$REPO_ID" --type=model --token "$HF_TOKEN" --yes

# Upload the file using the CLI
huggingface-cli upload "$REPO_ID" "$LATEST_PTH" --token "$HF_TOKEN" --repo-type model

echo "Upload complete."