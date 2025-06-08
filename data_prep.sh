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
# For TARGET_DURATION, the default value is set to "3600", which represents a target total duration of 3600 
# seconds (or 1 hour) for each gender in the dataset. This means that, unless the variable is set elsewhere, 
# the script will aim to select audio samples totaling 1 hour for both male and female data. 
# If TARGET_DURATION is left empty, the script will use the entire dataset without limiting the duration.
#
# For DURATION_ORDER, the default is "random". This variable controls the method used to order or select audio 
# samples when assembling the dataset. The value can be "random" (select samples in a random order), 
# "min" (prioritize shorter samples first), or "max" (prioritize longer samples first). 
# This allows for flexible control over how the dataset is constructed, depending on the desired characteristics 
# for training or evaluation.
TARGET_DURATION=${TARGET_DURATION:-"3600"}  # 3600 means 1 hr each for both genders, If empty, full dataset will be used
DURATION_ORDER=${DURATION_ORDER:-"random"}  # Default ordering method, can be "random", "min", or "max"

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