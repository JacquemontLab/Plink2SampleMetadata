#!/bin/bash


# Ensure Nextflow runs offline (no internet check)
export NXF_OFFLINE=false
export NXF_CONDA_CACHE=/home/jupyter/.conda_envs
mkdir -p $NXF_CONDA_CACHE

plink_prefix=/home/jupyter/plink/array_unduplicated
KING_REF_DIRECTORY=/home/jupyter/plink/Plink2SampleMetadata/resources/king_ref
genome_version=GRCh38

# --- Run Nextflow pipeline ---
nextflow run Plink2SampleMetadata/main.nf \
    --plink_file "$plink_prefix" \
    --king_ref "$KING_REF_DIRECTORY" \
    --genome_version "$genome_version" \
    -c Plink2SampleMetadata/setup/allofus/allofus.config \
    -with-report report.html \
    -resume 

