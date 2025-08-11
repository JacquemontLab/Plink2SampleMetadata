#!/bin/bash
#SBATCH --job-name=Plink2SampleMetadata          # Job name
#SBATCH --ntasks=1                        # Single task
#SBATCH --cpus-per-task=64                # Number of CPU cores per task
#SBATCH --mem-per-cpu=3500MB              # Memory per CPU
#SBATCH --time=00:20:00                   # Time limit (hh:mm:ss)
#SBATCH --output=Plink2SampleMetadata_%j.log     # Standard output and error log
#SBATCH --account=rrg-jacquese            # Account name


################################################################################
# Script: run_plink_metadata.sh
#
# Description:
#   SLURM submission script to run a Nextflow workflow that infers
#   per-sample metadata from a PLINK dataset. The workflow:
#     - Calculates sex call rates with PLINK
#     - Infers family trios using KING
#     - Performs PCA using a KING reference panel
#     - Merges the results into a consolidated TSV metadata file
#
# Requirements:
#   - SLURM workload manager
#   - Nextflow installed and configured
#   - KING reference data directory available
#
# Usage:
#   sbatch run_plink_metadata.sh <plink_file_prefix> <genome_version>
#
# Example:
#   sbatch run_plink_metadata.sh \
#          /lustre09/project/6008022/flben/Ancestry_SPARK/iWGS1.1/merged_plink/sample_data \
#          GRCh38
################################################################################

# --- Parse arguments ---
plink_prefix=$1
genome_version=$2

KING_REF_DIRECTORY=PATH_TO_directory/king_ref

# Ensure Nextflow runs offline (no internet check)
export NXF_OFFLINE=true

# --- Run Nextflow pipeline ---
nextflow run main.nf \
    --plink_file "$plink_prefix" \
    --king_ref "$KING_REF_DIRECTORY" \
    --genome_version "$genome_version" \
    -c setup/ccdb/ccdb.config \
    -with-report report.html \
    -resume
