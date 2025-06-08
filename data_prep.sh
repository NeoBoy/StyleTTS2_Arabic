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
TARGET_DURATION=${TARGET_DURATION:-""}  # If empty, full dataset will be used
DURATION_ORDER=${DURATION_ORDER:-"random"}  # Default ordering method

# Prepare arguments for generate_TTS2_lists.py
args=( --metadata_csv "$META_CSV"
       --train_split "$TRAIN_SPLIT"
       --val_split "$VAL_SPLIT"
       --train_list "$TRAIN_LIST"
       --val_list "$VAL_LIST"
       --text_field "$TEXT_FIELD" )

# Add duration filtering **ONLY** if TARGET_DURATION is set
if [ -n "$TARGET_DURATION" ]; then
    echo "Using target duration: $TARGET_DURATION sec per gender with sorting order: $DURATION_ORDER."
    args+=( --target_duration "$TARGET_DURATION" --duration_order "$DURATION_ORDER" )
else
    echo "No target duration provided—using the full dataset. Default sorting order: $DURATION_ORDER."
fi

echo "Generating list files for StyleTTS2..."
python generate_TTS2_lists.py "${args[@]}"

echo "List files generated:"
echo "  Train list: $TRAIN_LIST"
echo "  Validation list: $VAL_LIST"