#!/usr/bin/env python3
import polars as pl
import sys
import argparse
from functools import reduce


def merge_tsv(files, output, join_type="full"):
    if not files:
        print("Error: No input files provided.")
        sys.exit(1)

    dfs = [pl.read_csv(f, separator="\t") for f in files]

    for i, df in enumerate(dfs):
        if "SampleID" not in df.columns:
            raise ValueError(f"'SampleID' column missing in file: {files[i]}")

    def safe_join(left, right):
        joined = left.join(right, on="SampleID", how=join_type)
        # Drop the 'SampleID_right' column if it exists after join
        if "SampleID_right" in joined.columns:
            joined = joined.drop("SampleID_right")
        return joined

    merged_df = reduce(safe_join, dfs)
    merged_df.write_csv(output, separator="\t")
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Merge TSV files on 'SampleID' using Polars")
    parser.add_argument("-i", "--input", nargs="+", required=True, help="List of input TSV files")
    parser.add_argument("-o", "--output", required=True, help="Output TSV file path")
    parser.add_argument("-j", "--join", choices=["inner", "full", "left", "right"], default="full",
                        help="Type of join (default: full)")
    args = parser.parse_args()

    merge_tsv(args.input, args.output, args.join)