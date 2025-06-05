#!/usr/bin/env python3
"""
generate_TTS2_lists.py

This script reads a metadata CSV file (produced by hfData2WavFiles.py) and generates two list files for StyleTTS2:
  - A training list file (e.g., Data/train_list.txt)
  - A validation list file (e.g., Data/val_list.txt)

Each output file contains one line per sample in the format:
    <relative_audio_filename>|<transcript>

For the training set only, if a target duration (in seconds) is specified, the script will attempt
to select files in a gender-balanced way. For example, if target_duration is 3600 (1 hour), then it will select
files so that the male files sum up to at least 1800 seconds and the female files likewise.
The selection order is determined by --duration_order:
    - "random" (default) shuffles the files,
    - "min" sorts in ascending order (shorter files first),
    - "max" sorts in descending order (longer files first).

If the total available duration for a gender is less than the required half of the target duration,
the script selects all files available for that gender.

The complete validation (test) set is written to the validation list without duration filtering.

Usage example:
    python generate_TTS2_lists.py --metadata_csv dataset_metadata.csv --root_path wav_data \
        --train_split train --val_split test \
        --train_list Data/train_list.txt --val_list Data/val_list.txt \
        --text_field text --target_duration 3600 --duration_order random
"""

import os
import argparse
import pandas as pd

def write_list_file(data: pd.DataFrame, root_path: str, output_file: str, text_field: str):
    """Write the list file where each line is: relative_audio_filename|transcript."""
    out_dir = os.path.dirname(output_file)
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    with open(output_file, "w", encoding="utf-8") as f:
        for _, row in data.iterrows():
            file_path = row.get("file_path", "")
            if not file_path:
                continue

            try:
                root_abs = os.path.abspath(root_path)
                file_abs = os.path.abspath(file_path)
                rel_path = os.path.relpath(file_abs, start=root_abs)
            except Exception:
                rel_path = os.path.basename(file_path)

            transcript = str(row.get(text_field, "")).strip()
            f.write(f"{rel_path}|{transcript}\n")
    print(f"Wrote {len(data)} entries to {output_file}.")

def select_balanced_by_gender(df: pd.DataFrame, target_duration: float, order: str) -> pd.DataFrame:
    """
    For the training set, select rows in a gender-balanced way given a target cumulative duration (in seconds).
    For each gender ('male' and 'female'), aim to accumulate files until the sum of durations is >= target_duration/2.
    If the total available duration for a gender is less than required, select all available files for that gender.
    
    The 'order' parameter determines the order in which files are considered:
      - "random": shuffle the rows before accumulating.
      - "min": sort ascending by duration.
      - "max": sort descending by duration.
    """
    required_per_gender = target_duration / 2.0
    selected_rows = []

    for gender in ['male', 'female']:
        df_gender = df[df['gender'].str.lower() == gender].copy()
        if df_gender.empty:
            print(f"Warning: No data found for gender '{gender}'.")
            continue

        total_duration = df_gender["duration"].sum()
        if total_duration < required_per_gender:
            print(f"Total available duration for {gender} ({total_duration:.2f} sec) is less than the required {required_per_gender:.2f} sec. Selecting full data for this gender.")
            selected_rows.append(df_gender)
            continue

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
            if cum_duration >= required_per_gender:
                break
        print(f"Selected {len(selected_indices)} entries for gender '{gender}' with cumulative duration {cum_duration:.2f} sec.")
        selected_rows.append(df_gender.loc[selected_indices])
    
    if selected_rows:
        return pd.concat(selected_rows, ignore_index=True)
    else:
        return df

def main():
    parser = argparse.ArgumentParser(
        description="Generate list files for StyleTTS2 from a metadata CSV file."
    )
    parser.add_argument("--metadata_csv", type=str, required=True,
                        help="Path to the metadata CSV file produced by hfData2WavFiles.py.")
    parser.add_argument("--root_path", type=str, default="wav_data",
                        help="Root directory where audio files are stored (default: 'wav_data').")
    parser.add_argument("--train_split", type=str, default="train",
                        help="Value in the metadata 'split' column to treat as training data (default: 'train').")
    parser.add_argument("--val_split", type=str, default="test",
                        help="Value in the metadata 'split' column to treat as validation data (default: 'test').")
    parser.add_argument("--train_list", type=str, default="Data/train_list.txt",
                        help="Output file for the training list (default: 'Data/train_list.txt').")
    parser.add_argument("--val_list", type=str, default="Data/val_list.txt",
                        help="Output file for the validation list (default: 'Data/val_list.txt').")
    parser.add_argument("--text_field", type=str, default="text",
                        help="Name of the field in metadata containing the transcript text (default: 'text').")
    parser.add_argument("--target_duration", type=float, default=None,
                        help="(Training set only) If specified (in seconds), select files such that for each gender the cumulative duration is at least half of this value. "
                             "If the available duration for a gender is less than required, all files are selected. "
                             "If not provided, use the full training set.")
    parser.add_argument("--duration_order", type=str, default="random", choices=["random", "min", "max"],
                        help="Determines the order for duration-based selection on the training set: 'random' (default), 'min' (ascending) or 'max' (descending).")
    args = parser.parse_args()

    if not os.path.exists(args.metadata_csv):
        print(f"Error: Metadata CSV file '{args.metadata_csv}' not found.")
        exit(1)

    df = pd.read_csv(args.metadata_csv)

    # Check that required columns exist.
    for col in ["file_path", "split", args.text_field]:
        if col not in df.columns:
            print(f"Error: Required column '{col}' not found in metadata.")
            exit(1)

    # Construct training and validation subsets.
    df_train = df[df["split"] == args.train_split]
    df_val = df[df["split"] == args.val_split]

    print(f"Total training entries: {len(df_train)}")
    print(f"Total validation entries: {len(df_val)}")

    # Apply duration-based selection to the training set if target_duration is specified and required columns exist.
    if args.target_duration is not None:
        if all(col in df_train.columns for col in ["gender", "duration"]):
            print(f"Applying gender-balanced selection on training set with target duration {args.target_duration} sec and order '{args.duration_order}'.")
            df_train = select_balanced_by_gender(df_train, args.target_duration, args.duration_order)
            print(f"After filtering, training entries: {len(df_train)}")
        else:
            print("Skipping duration filtering on training set because 'gender' or 'duration' columns are missing.")

    # Write the training list file.
    write_list_file(df_train, args.root_path, args.train_list, args.text_field)
    # Write the validation list file (using the complete validation set).
    write_list_file(df_val, args.root_path, args.val_list, args.text_field)

if __name__ == "__main__":
    main()