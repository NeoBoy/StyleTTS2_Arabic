#!/bin/bash
set -euo pipefail

# Ensure conda is initialized in this shell (in case you're running data_prep.sh separately)
if [ -z "${CONDA_PREFIX:-}" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
fi

# Customize these values as needed.
META_CSV="dataset_metadata.csv"
OUTPUT_DIR="wav_data"

# Values corresponding to the "split" column in the metadata.
TRAIN_SPLIT="train"
VAL_SPLIT="test"

# Output file paths for StyleTTS2 list files.
TRAIN_LIST="Data/train_list.txt"
VAL_LIST="Data/val_list.txt"

# The field in the metadata CSV containing the transcript text.
TEXT_FIELD="phonetic_text"

# OPTIONAL: Uncomment the following lines if you want to enable duration-based selection for the training set.
# TARGET_DURATION=3600    # Duration in seconds (e.g., 3600 sec = 1 hour total for training set)
# DURATION_ORDER="random" # Options: random, min (ascending by duration) or max (descending by duration)

# Prepare the arguments array to pass to generate_TTS2_lists.py
args=( --metadata_csv "$META_CSV" \
       --root_path "$OUTPUT_DIR" \
       --train_split "$TRAIN_SPLIT" \
       --val_split "$VAL_SPLIT" \
       --train_list "$TRAIN_LIST" \
       --val_list "$VAL_LIST" \
       --text_field "$TEXT_FIELD" )

# Add duration parameters only if TARGET_DURATION is set (non-empty)
if [ -n "${TARGET_DURATION:-}" ]; then
  args+=( --target_duration "$TARGET_DURATION" --duration_order "${DURATION_ORDER:-random}" )
fi

echo "Generating list files for StyleTTS2 using generate_TTS2_lists.py..."
python generate_TTS2_lists.py "${args[@]}"

echo "List files generated:"
echo "  Train list: $TRAIN_LIST"
echo "  Validation list: $VAL_LIST"