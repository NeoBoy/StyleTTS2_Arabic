#!/bin/bash
set -euo pipefail   # Exit on error, unset vars, or failed pipes

# Ensure conda is initialized in this shell (in case running data_prep.sh separately)
if [ -z "${CONDA_PREFIX:-}" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
fi

# Define key variables
META_CSV="dataset_metadata.csv"

# Metadata split values
TRAIN_SPLIT="train"
VAL_SPLIT="test"

# Output file paths for StyleTTS2 list files
TRAIN_LIST="Data/train_list.txt"
VAL_LIST="Data/val_list.txt"

# The field in the metadata CSV containing the phonetic transcript text
TEXT_FIELD="phonetic_text"

# OPTIONAL: Duration-based filtering for the training set
TARGET_DURATION=3600  # Per gender (e.g., 3600 sec = 1 hour per male, 1 hour per female)
DURATION_ORDER="random" # Options: random, min (ascending by duration), max (descending by duration)

# Validate metadata existence
if [ ! -f "$META_CSV" ]; then
    echo "Error: Metadata file '$META_CSV' not found! Ensure that dataset processing is complete."
    exit 1
fi

# Prepare the arguments array for generate_TTS2_lists.py
args=( --metadata_csv "$META_CSV"
       --train_split "$TRAIN_SPLIT"
       --val_split "$VAL_SPLIT"
       --train_list "$TRAIN_LIST"
       --val_list "$VAL_LIST"
       --text_field "$TEXT_FIELD" )

# Add duration filtering only if TARGET_DURATION is set
if [ -n "$TARGET_DURATION" ]; then
    args+=( --target_duration "$TARGET_DURATION" --duration_order "$DURATION_ORDER" )
else
    echo "Using the full training dataset (no duration filtering)."
fi

echo "Generating list files for StyleTTS2..."
python generate_TTS2_lists.py "${args[@]}"

echo "List files generated:"
echo "  Train list: $TRAIN_LIST"
echo "  Validation list: $VAL_LIST"