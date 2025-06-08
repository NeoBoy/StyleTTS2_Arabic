#!/usr/bin/env python3
"""
hfData2WavFiles.py

This script downloads an Arabic TTS dataset from Hugging Face, saves audio files using their original filenames,
and writes the metadata to a CSV file.

The audio files will be stored in 'wav_data' using the filename from the 'file' column (appending '.wav').
Metadata will be saved, excluding the 'file_path' column (since the filenames remain unchanged).

Example usage:
    python hfData2WavFiles.py --dataset_name "NeoBoy/arabic-tts-wav-24k" \
      --splits "train,test" --cache_dir "cache" --output_dir "wav_data" --meta_csv "dataset_metadata.csv"
"""

import os
import argparse
import pandas as pd
import soundfile as sf
from datasets import load_dataset

def main():
    parser = argparse.ArgumentParser(description="Download Hugging Face dataset, save audio with original filenames, and store metadata.")
    parser.add_argument("--dataset_name", type=str, required=True,
                        help="Dataset identifier on Hugging Face (e.g., 'NeoBoy/arabic-tts-wav-24k').")
    parser.add_argument("--splits", type=str, required=True,
                        help="Comma-separated list of dataset splits to process (e.g., 'train,test').")
    parser.add_argument("--cache_dir", type=str, default="cache",
                        help="Directory used for dataset caching (default: 'cache').")
    parser.add_argument("--output_dir", type=str, default="wav_data",
                        help="Directory to save the audio files (default: 'wav_data').")
    parser.add_argument("--meta_csv", type=str, default="dataset_metadata.csv",
                        help="Path to the CSV file for storing metadata (default: 'dataset_metadata.csv').")
    args = parser.parse_args()

    # Ensure directories exist
    os.makedirs(args.cache_dir, exist_ok=True)
    os.makedirs(args.output_dir, exist_ok=True)

    print(f"Using cache directory: {args.cache_dir}")
    print(f"Saving audio files in: {args.output_dir}")

    all_metadata = []

    for split in args.splits.split(","):
        print(f"\nProcessing split: {split}")
        try:
            dataset = load_dataset(args.dataset_name, split=split, cache_dir=args.cache_dir)
        except Exception as e:
            print(f"Error loading split '{split}': {e}")
            continue

        for idx, example in enumerate(dataset):
            audio_data = example.get("audio")
            file_name = example.get("file")  # Get the original filename

            if audio_data is None or file_name is None:
                print(f"Skipping example {idx} in split {split}: Missing audio or filename.")
                continue

            # Ensure filename has .wav extension
            file_path = os.path.join(args.output_dir, f"{file_name}.wav")

            try:
                sf.write(file_path, audio_data["array"], audio_data["sampling_rate"])
                print(f"Saved audio file: {file_path}")
            except Exception as e:
                print(f"Error saving audio for example {idx} in split {split}: {e}")
                continue

            # Store metadata (excluding file_path, using original file column)
            meta = {k: v for k, v in example.items() if k not in ["audio"]}
            meta["file_name"] = f"{file_name}.wav"  # Store only filename (not full path)
            meta["split"] = split
            all_metadata.append(meta)

    # Save metadata to CSV (excluding file_path column)
    if all_metadata:
        df_meta = pd.DataFrame(all_metadata)
        df_meta.to_csv(args.meta_csv, index=False)
        print(f"\nMetadata saved to: {args.meta_csv}")
    else:
        print("No metadata collected.")

if __name__ == "__main__":
    main()