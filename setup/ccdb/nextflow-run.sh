#!/bin/bash
#SBATCH --job-name=Plink2SampleMetadata          # Job name
#SBATCH --mail-type=END,FAIL              # Notifications: job ends or fails
#SBATCH --ntasks=1                        # Single task
#SBATCH --cpus-per-task=64                # Number of CPU cores per task
#SBATCH --mem-per-cpu=3500MB              # Memory per CPU
#SBATCH --time=00:20:00                   # Time limit (hh:mm:ss)
#SBATCH --output=Plink2SampleMetadata_%j.log     # Standard output and error log
#SBATCH --account=rrg-jacquese            # Account name


################################################################################
# Script: nextflow-run.sh
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
#   sbatch nextflow-run.sh <plink_file_prefix>
#
# Example:
#   sbatch nextflow-run.sh \
#          /lustre09/project/6008022/flben/Ancestry_SPARK/iWGS1.1/merged_plink/sample_data
################################################################################

KING_REF_DIRECTORY=/lustre09/project/6008022/LAB_WORKSPACE/RAW_DATA/Genetic/Reference_Data/king_ref

# Ensure Nextflow runs offline (no internet check)
export NXF_OFFLINE=true

module load apptainer
module load nextflow

# Run Nextflow pipeline
nextflow run main.nf \
    --plink_file $1 \
    --king_ref $KING_REF_DIRECTORY \
    --genome_version GRCh38 \
    -c setup/ccdb/ccdb.config \
    -with-report report.html \
    -resume
