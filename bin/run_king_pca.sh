#!/bin/bash


# ======================================================
# KING PCA Pipeline
# Author: Florian Bénitière
# Date: 2025-07-28
#
# Description:
#   This script performs ancestry projection PCA using KING 
#   by merging a target PLINK dataset with the 1000 Genomes
#   reference panel (GRCh37 or optionally lifted to GRCh38).
#   It ensures unique SNP IDs, harmonizes genome versions,
#   and produces PCA plots and output files for ancestry 
#   inference.
#
# Usage:
#   ./run_king_pca.sh <plink_prefix> <king_ref_directory> <output_file> [genome_version]
#
# Arguments:
#   <plink_prefix>     Prefix of the input PLINK dataset (.bed/.bim/.fam)
#   <king_ref_directory> Path to the KING reference panel directory 
#                        (will be downloaded if not present)
#   <output_file>      Prefix for PCA output
#   [genome_version]   Genome build of the dataset, GRCh37 or GRCh38 
#                      (default: GRCh38)
#
# Example:
#   ./run_king_pca.sh my_dataset /path/to/king_ref my_pca GRCh38
#
# Requirements:
#   - PLINK v1.9+
#   - KING v2.3+
#   - R 3.6.0
#   - wget, awk, coreutils
#   - liftOver (if converting from GRCh37 to GRCh38)
#   - SLURM environment (optional, for automatic resource detection)
#
# Notes:
#   - The script automatically downloads the 1000 Genomes reference 
#     (GRCh37) from the KING website.
#   - If GRCh38 is requested, it performs liftOver conversion using
#     UCSC chain files.
#   - Intermediate files are handled in a temporary directory and
#     cleaned up at the end.
#   - The pipeline auto-detects CPU cores and available memory, and
#     adjusts PLINK resource usage accordingly.
#
# Output:
#   - KING PCA projection files (prefix: king_prefix)
#   - PCA plots (in .rplot and PDF formats if supported)
#
# ======================================================

set -e  # Exit on any error

log_step() {
    # Choose a symbol depending on the message
    case "$1" in
        STEP*) icon="🔹" ;;   # blue diamond for pipeline steps
        ERROR*) icon="❌" ;;  # red cross for errors
        WARN*) icon="⚠️ " ;;  # warning sign
        DONE*) icon="✅" ;;   # check mark for done
        *) icon="ℹ️ " ;;      # info icon
    esac
    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] $icon $1"
}

# --------------------- Argument Parsing ---------------------
if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <plink_prefix> <king_ref_directory> <output_file> [genome_version]"
  exit 1
fi

# ---------------------------
# Parse arguments
# ---------------------------
plink_prefix=${1:? "Error: You must provide the PLINK dataset prefix"}
king_ref_directory=${2:? "Error: You must provide the output file prefix"}
output_file=${3:? "Error: You must provide the output file prefix"}
genome_version=${4:-"GRCh38"}

log_step "STEP Starting pipeline with input: ${plink_prefix}, genome version: ${genome_version}, king_ref_directory: ${king_ref_directory}"

#--- Check PLINK availability ---
if ! command -v plink &>/dev/null; then
    log_step "ERROR: PLINK is not installed or not in PATH."
    exit 1
fi
log_step "STEP: PLINK detected"


#--- Check KING availability ---
if ! command -v king &>/dev/null; then
    log_step "ERROR: KING is not installed or not in PATH."
    exit 1
fi
log_step "STEP: KING detected"


# ---------------------------
# Resource detection
# ---------------------------
# Get number of CPUs
cpus="${SLURM_CPUS_ON_NODE:-$(nproc)}"
echo "💻 Running with $cpus cores"


# Detect memory
if [[ -n "$SLURM_MEM_PER_CPU" ]]; then
  # Memory per CPU × number of CPUs, with 90% safety margin
  mem_MB=$(( SLURM_MEM_PER_CPU * cpus * 90 / 100 ))
elif [[ -n "$SLURM_MEM_PER_NODE" ]]; then
  # Fallback if MEM_PER_CPU is not set
  mem_MB=$(( SLURM_MEM_PER_NODE * 90 / 100 ))
else
  # Fallback to checking system memory
  read total_mem used_mem free_mem shared_mem buff_cache available_mem <<< $(free -m | awk '/Mem:/ {print $2, $3, $4, $5, $6, $7}')
  echo "Available memory (MB): $available_mem"

  # Use 90% of available memory
  mem_MB=$(( available_mem * 90 / 100 ))
fi

echo "Setting PLINK memory to: $mem_MB MB"
echo "Setting PLINK threads to: $cpus"


log_step "STEP Setting memory to: $mem_MB MB and threads to: $cpus"


# --------------------------------------
# Prepare working directory
# --------------------------------------
tmpdir="./king_pca/"
mkdir -p "$tmpdir"
log_step "STEP Using temporary directory: $tmpdir"

# ---------------------------
# Update SNP names for input dataset
# ---------------------------

log_step "STEP: Starting SNP name update..."

awk -v OFS='\t' '{
    chr = $1
    sub(/^chr/, "", chr)        # Remove leading "chr" if present
    chr = "chr"chr            # Add "chr" prefix explicitly
    new_id = chr"_"$4"_"$5"_"$6
    if (!seen[new_id]++) print $2, new_id
    }' "${plink_prefix}.bim" > "${tmpdir}update_SNPname.tsv"

log_step "DONE: SNP names updated in ${tmpdir}update_SNPname.tsv"

plink --bfile "${plink_prefix}" \
        --update-name "${tmpdir}update_SNPname.tsv" \
        --make-bed \
        --out "${tmpdir}plink_updated_name" --memory ${mem_MB} --threads ${cpus}

log_step "DONE: Plink updated with new SNP names, output: ${tmpdir}plink_updated_name"

# ---------------------------
# Prepare files for KING PCA
# ---------------------------


log_step "STEP: Preparing files for KING PCA..."

awk -v OFS='\t' '{print $2}' ${king_ref_directory}/KGref_${genome_version}_final.bim > ${tmpdir}KGref_${genome_version}_SNP_selection.txt
plink --bfile "${tmpdir}plink_updated_name" --extract ${tmpdir}KGref_${genome_version}_SNP_selection.txt --make-bed --out ${tmpdir}plink_for_pcancestry --memory ${mem_MB} --threads ${cpus}

awk -v OFS='\t' '{print $2}' ${tmpdir}plink_for_pcancestry.bim > ${tmpdir}snp_to_select.txt
plink --bfile "${king_ref_directory}/KGref_${genome_version}_final" --extract ${tmpdir}snp_to_select.txt --make-bed --out ${tmpdir}kingref_for_pcancestry --memory ${mem_MB} --threads ${cpus}

log_step "DONE: KING PCA preparation done."

# ---------------------------
# Check R availability (must be 3.6.x)
# ---------------------------
log_step "STEP: Checking R 3.6.x availability..."

if ! command -v R &> /dev/null; then
    log_step "ERROR: R not found — loading R 3.6.0 module..."
    module load nixpkgs/16.09 gcc/7.3.0
    module load openmpi/3.1.2
    module load r/3.6.0
    log_step "DONE: R 3.6.0 loaded."
else
    R_VERSION=$(R --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+')
    if [[ "$R_VERSION" == "3.6" ]]; then
        log_step "DONE: R $R_VERSION detected."
    else
        log_step "WARN: R version $R_VERSION detected — loading R 3.6.0 module..."
        module load nixpkgs/16.09 gcc/7.3.0
        module load openmpi/3.1.2
        module load r/3.6.0
        log_step "DONE: R 3.6.0 loaded."
    fi
fi

log_step "STEP: Running KING PCA..."

king -b ${tmpdir}kingref_for_pcancestry.bed,${tmpdir}plink_for_pcancestry.bed --pca --projection --rplot --prefix ${tmpdir}king_output --cpus ${cpus}

log_step "DONE: KING PCA run completed."

awk -v OFS='\t' 'NR==FNR {
        if (FNR==1) {next}              # skip ancestry header
        a[$2]=$9                        # store ancestry column by IID
        next
     }
     FNR==1 {
        # Print header: change IID → SampleID, add Ancestry
        $2="SampleID"
        print $2, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16 , "Ancestry"
        next
     }
     ($2 in a) {
        $2=$2                           # just to ensure SampleID prints correctly
        print $2, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16 , a[$2]
     }' OFS='\t' ${tmpdir}king_output_InferredAncestry.txt ${tmpdir}king_outputpc.txt > ${output_file}


rm -rf "$tmpdir"

log_step "DONE: KING PCA analysis completed successfully."
