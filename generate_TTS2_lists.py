#!/usr/bin/env python3
"""
generate_TTS2_lists.py

This script reads a metadata CSV file (produced by hfData2WavFiles.py) and generates two list files for StyleTTS2:
  - A training list file (e.g., Data/train_list.txt)
  - A validation list file (e.g., Data/val_list.txt)

Each output file contains one line per sample in the format:
    file_name|phonetic_text|speakerID

For the training set only, if a target duration (in seconds) is specified, the script selects audio
until it reaches that duration **for each gender separately**.
Sorting is determined by --duration_order:
    - "random" (default) shuffles the files,
    - "min" sorts in ascending order (shorter files first),
    - "max" sorts in descending order (longer files first).

If the available data is less than `target_duration`, it selects **all files for that gender**.

The validation (test) set remains unchanged.

Usage:
    python generate_TTS2_lists.py --metadata_csv dataset_metadata.csv \
        --train_split train --val_split test \
        --train_list Data/train_list.txt --val_list Data/val_list.txt \
        --text_field phonetic_text --target_duration 3600 --duration_order random
"""

import os
import argparse
import pandas as pd

def write_list_file(data: pd.DataFrame, output_file: str, text_field: str):
    """Write list file in format: file_name|phonetic_text|speakerID."""
    out_dir = os.path.dirname(output_file)
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    with open(output_file, "w", encoding="utf-8") as f:
        for _, row in data.iterrows():
            file_name = row.get("file_name", "").strip()
            phonetic_text = str(row.get(text_field, "")).strip()
            gender = row.get("gender", "").strip().lower()

            # Assign speakerID based on gender (0 for female, 1 for male)
            speaker_id = "0" if gender == "female" else "1"

            f.write(f"{file_name}|{phonetic_text}|{speaker_id}\n")
    
    print(f"Wrote {len(data)} entries to {output_file}.")

def select_per_gender(df: pd.DataFrame, target_duration: float, order: str) -> pd.DataFrame:
    """
    Select rows **per gender** given a target cumulative duration.
    - Each gender ('male' and 'female') gets at least `target_duration` seconds.
    - If the total available duration for a gender is **less than `target_duration`**, all files are selected.
    - Sorting behavior: 'random', 'min' (ascending), or 'max' (descending).
    """
    selected_rows = []

    for gender in ['male', 'female']:
        df_gender = df[df['gender'].str.lower() == gender].copy()
        if df_gender.empty:
            print(f"Warning: No data found for gender '{gender}'.")
            continue

        total_duration = df_gender["duration"].sum()
        if total_duration < target_duration:
            print(f"Total available duration for {gender} ({total_duration:.2f} sec) is less than {target_duration:.2f} sec. Selecting full data.")
            selected_rows.append(df_gender)
            continue

        # Apply sorting behavior
        if order == 'random':
            df_gender = df_gender.sample(frac=1, random_state=42)
        elif order == 'min':
            df_gender = df_gender.sort_values(by='duration', ascending=True)
        elif order == 'max':
            df_gender = df_gender.sort_values(by='duration', ascending=False)
        else:
            df_gender = df_gender.sample(frac=1, random_state=42)

        cum_duration = 0.0
        selected_indices = []
        for idx, row in df_gender.iterrows():
            try:
                dur = float(row.get("duration", 0.0))
            except Exception:
                dur = 0.0
            selected_indices.append(idx)
            cum_duration += dur
            if cum_duration >= target_duration:
                break
        print(f"Selected {len(selected_indices)} entries for gender '{gender}' with cumulative duration {cum_duration:.2f} sec.")
        selected_rows.append(df_gender.loc[selected_indices])

    return pd.concat(selected_rows, ignore_index=True) if selected_rows else df

def main():
    parser = argparse.ArgumentParser(description="Generate list files for StyleTTS2 from a metadata CSV file.")
    parser.add_argument("--metadata_csv", type=str, required=True, help="Path to metadata CSV file.")
    parser.add_argument("--train_split", type=str, default="train", help="Metadata 'split' value for training.")
    parser.add_argument("--val_split", type=str, default="test", help="Metadata 'split' value for validation.")
    parser.add_argument("--train_list", type=str, default="Data/train_list.txt", help="Output file for train list.")
    parser.add_argument("--val_list", type=str, default="Data/val_list.txt", help="Output file for validation list.")
    parser.add_argument("--text_field", type=str, default="phonetic_text", help="Column in metadata containing phonetic text.")
    parser.add_argument("--target_duration", type=float, default=None, help="Target duration **per gender** in seconds.")
    parser.add_argument("--duration_order", type=str, default="random", choices=["random", "min", "max"], help="Ordering method: 'random' (default), 'min' (ascending), 'max' (descending).")
    args = parser.parse_args()

    if not os.path.exists(args.metadata_csv):
        print(f"Error: Metadata CSV file '{args.metadata_csv}' not found.")
        exit(1)

    df = pd.read_csv(args.metadata_csv)

    # Validate required columns exist
    for col in ["file_name", "split", args.text_field, "gender"]:
        if col not in df.columns:
            print(f"Error: Required column '{col}' not found in metadata.")
            exit(1)

    df_train = df[df["split"] == args.train_split]
    df_val = df[df["split"] == args.val_split]

    print(f"Total training entries: {len(df_train)}")
    print(f"Total validation entries: {len(df_val)}")

    # Apply gender-balanced selection **only for training set**, if requested
    if args.target_duration is not None:
        if "duration" in df_train.columns:
            print(f"Applying gender-balanced selection for training set: {args.target_duration} sec per gender, sorted by '{args.duration_order}'.")
            df_train = select_per_gender(df_train, args.target_duration, args.duration_order)
            print(f"After filtering, training entries: {len(df_train)}")
        else:
            print("Skipping duration filtering for training set (missing 'duration' column).")

    # Write the training and validation list files
    write_list_file(df_train, args.train_list, args.text_field)
    write_list_file(df_val, args.val_list, args.text_field)

if __name__ == "__main__":
    main()