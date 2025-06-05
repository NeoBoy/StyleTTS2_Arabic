#!/usr/bin/env python3
"""
hfData2WavFiles.py

This script downloads the specified dataset splits for the "NeoBoy/arabic-tts-wav-24k" Arabic
TTS dataset from Hugging Face, saving the audio files and associated metadata.
It uses a local cache directory for temporary files and writes the audio to the specified output folder.
The remaining metadata (excluding the audio array) is saved in a CSV file with an added "split" column.

Example usage:
    python hfData2WavFiles.py --dataset_name "NeoBoy/arabic-tts-wav-24k" --splits "train,test" \
      --cache_dir "cache" --output_dir "wav_data" --meta_csv "dataset_metadata.csv"
"""

import os
import argparse
import pandas as pd
import soundfile as sf
from datasets import load_dataset

def main():
    parser = argparse.ArgumentParser(
        description="Download dataset splits from Hugging Face and save audio files and metadata."
    )
    parser.add_argument(
        "--dataset_name", type=str, required=True,
        help="The dataset identifier on Hugging Face (e.g., 'NeoBoy/arabic-tts-wav-24k')."
    )
    parser.add_argument(
        "--splits", type=str, required=True,
        help="Comma-separated list of dataset splits to download (e.g., 'train,test')."
    )
    parser.add_argument(
        "--cache_dir", type=str, default="cache",
        help="Directory used to cache the dataset files (default: 'cache')."
    )
    parser.add_argument(
        "--output_dir", type=str, default="wav_data",
        help="Directory to save the audio files (default: 'wav_data')."
    )
    parser.add_argument(
        "--meta_csv", type=str, default="dataset_metadata.csv",
        help="Path to the CSV file to write the metadata (default: 'dataset_metadata.csv')."
    )
    args = parser.parse_args()

    dataset_name = args.dataset_name
    splits = [s.strip() for s in args.splits.split(",")]
    cache_dir = os.path.join(os.getcwd(), args.cache_dir)
    output_dir = os.path.join(os.getcwd(), args.output_dir)
    meta_csv = os.path.join(os.getcwd(), args.meta_csv)

    os.makedirs(cache_dir, exist_ok=True)
    os.makedirs(output_dir, exist_ok=True)

    print(f"Using cache directory: {cache_dir}")
    print(f"Output directory for audio files: {output_dir}")

    all_metadata = []

    for split in splits:
        print(f"\nProcessing split: {split}")
        try:
            dataset = load_dataset(dataset_name, split=split, cache_dir=cache_dir)
        except Exception as e:
            print(f"Error loading split '{split}': {e}")
            continue

        for idx, example in enumerate(dataset):
            audio_data = example.get("audio")
            if audio_data is None:
                print(f"Skipping example {idx} in split {split}: No audio data found.")
                continue

            if isinstance(audio_data, dict) and "array" in audio_data and "sampling_rate" in audio_data:
                filename = os.path.join(output_dir, f"{split}_audio_{idx:05d}.wav")
                try:
                    sf.write(filename, audio_data["array"], audio_data["sampling_rate"])
                    print(f"Saved audio file: {filename}")
                except Exception as e:
                    print(f"Error saving audio for example {idx} in split {split}: {e}")
                    continue

                # Copy metadata excluding the audio array and add additional fields.
                meta = {k: v for k, v in example.items() if k != "audio"}
                meta["file_path"] = filename
                meta["split"] = split
                all_metadata.append(meta)
            else:
                print(f"Skipping example {idx} in split {split}: Audio data not in expected format.")

    if all_metadata:
        df_meta = pd.DataFrame(all_metadata)
        df_meta.to_csv(meta_csv, index=False)
        print(f"\nMetadata for {len(all_metadata)} examples saved to: {meta_csv}")
    else:
        print("No metadata collected.")

if __name__ == "__main__":
    main()