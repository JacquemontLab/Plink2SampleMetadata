#!/bin/bash
#----------------------------------------------------------
# Script: plink_sexe_callrate.sh
# Description: Run PLINK QC (missingness + sex check) and
#              output a single TSV file
# Usage: ./plink_sexe_callrate.sh <plink_prefix> <output_file>
#----------------------------------------------------------

set -e  # Exit on any error

#--- Logging function ---
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

#--- Check arguments ---
if [[ $# -ne 2 ]]; then
    log_step "ERROR: Wrong number of arguments"
    echo "Usage: $0 <plink_prefix> <output_file>"
    exit 1
fi

plink_path_prefix="$1"
output_file="$2"

#--- Check PLINK availability ---
if ! command -v plink &>/dev/null; then
    log_step "ERROR: PLINK is not installed or not in PATH."
    exit 1
fi
log_step "STEP: PLINK detected"


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




#--- Run PLINK missingness and sex check ---
log_step "STEP: Running PLINK missingness and sex check"
plink --bfile "$plink_path_prefix" \
        --missing \
        --check-sex \
        --threads "$cpus" \
        --memory "$mem_MB" \
        --out tmp_plink_outputs
log_step "DONE: PLINK run completed"

#--- Verify files ---
if [[ ! -s tmp_plink_outputs.imiss ]] || [[ ! -s tmp_plink_outputs.sexcheck ]]; then
    log_step "ERROR: PLINK output files missing"
    exit 1
fi


#--- Build merged TSV ---
log_step "STEP: Creating merged output TSV"
(
    echo -e "SampleID\tCall_Rate\tSexe"
    join -1 1 -2 1 \
        <(awk 'NR>1 {print $2, (1-$6)}' tmp_plink_outputs.imiss | sort -k1,1) \
        <(awk 'NR>1 {sex=($4==1?"male":($4==2?"female":"unknown")); print $2, sex}' tmp_plink_outputs.sexcheck | sort -k1,1) \
        | tr ' ' '\t'
) > "$output_file"

log_step "DONE: Final TSV created → $output_file"

#--- Clean up ---
rm -f tmp_plink_outputs.*

