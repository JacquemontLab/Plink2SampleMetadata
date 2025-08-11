#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

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


# --- Default Parameters ---
RESOURCE_DIR="$(git rev-parse --show-toplevel)/resources"

# Check if king is available
log_step "STEP: Checking if king is available..."
if command -v king &> /dev/null; then
    log_step "DONE: king is available: $(command -v king)"
else
    log_step "ERROR: king is not available"
fi

# Check if plink is available
log_step "STEP: Checking if plink is available..."
if command -v plink &> /dev/null; then
    log_step "DONE: plink is available: $(command -v plink)"
else
    log_step "ERROR: plink is not available"
fi

# Check if python is available
log_step "STEP: Checking if python is available..."
if command -v python &> /dev/null; then
    log_step "DONE: python is available: $(command -v python)"
elif command -v python3 &> /dev/null; then
    log_step "DONE: python3 is available: $(command -v python3)"
else
    log_step "ERROR: python is not available"
fi

log_step "STEP: Checking if nextflow is available..."
if command -v nextflow &> /dev/null; then
    log_step "DONE: nextflow is available: $(command -v nextflow)"
else
    log_step "ERROR: nextflow is not available"
fi


log_step "STEP: Checking if liftOver is available..."
if command -v liftOver &> /dev/null; then
    log_step "DONE: liftOver is available: $(command -v liftOver)"
else
    log_step "ERROR: liftOver is not available"
fi



# Pull or build container image
SIF_NAME="$RESOURCE_DIR/r3.6_with_king_plink_free.sif"

log_step "STEP: Attempting to pull Docker image flobenhsj/r3.6_with_king_plink_free:latest..."

if command -v docker &> /dev/null; then
    if docker pull flobenhsj/r3.6_with_king_plink_free:latest; then
        log_step "DONE: Docker image pulled successfully."
    else
        log_step "ERROR: Failed to pull Docker image with Docker."
        if command -v apptainer &> /dev/null; then
            log_step "STEP: Trying to build Apptainer image from Docker image..."
            SIF_NAME="$RESOURCE_DIR/r3.6_with_king_plink_free.sif"
            if apptainer build "$SIF_NAME" docker://flobenhsj/r3.6_with_king_plink_free:latest; then
                log_step "DONE: Apptainer image $SIF_NAME built successfully."
            else
                log_step "ERROR: Failed to build Apptainer image."
            fi
        else
            log_step "ERROR: Apptainer not found, cannot build container image."
        fi
    fi
elif command -v apptainer &> /dev/null; then
    log_step "STEP: Docker not found. Building Apptainer image from Docker image..."
    SIF_NAME="$RESOURCE_DIR/r3.6_with_king_plink_free.sif"
    if apptainer build "$SIF_NAME" docker://flobenhsj/r3.6_with_king_plink_free:latest; then
        log_step "DONE: Apptainer image $SIF_NAME built successfully."
    else
        log_step "ERROR: Failed to build Apptainer image."
    fi
else
    log_step "ERROR: Neither Docker nor Apptainer found, cannot pull or build image."
fi

# Update config file with new SIF path
CONFIG_FILE="$(git rev-parse --show-toplevel)/setup/new_cluster/cluster.config"

log_step "STEP: Updating SIF path in $CONFIG_FILE..."
if [[ -f "$CONFIG_FILE" ]]; then
    sed -i "s|path_to/r3.6_with_king_plink_free.sif|$SIF_NAME|g" "$CONFIG_FILE"
    log_step "DONE: SIF path replaced with $SIF_NAME in $CONFIG_FILE."
else
    log_step "ERROR: Config file $CONFIG_FILE not found."
fi


# Run KING reference extraction
KING_DIR="$RESOURCE_DIR/king_ref/"

cd "$KING_DIR"

# Make sure the script is executable
chmod +x extraction_king_ref.sh

# Check if the script exists before running
if [[ -f extraction_king_ref.sh ]]; then
    log_step "STEP: Launching extraction_king_ref.sh script..."
    ./extraction_king_ref.sh
    log_step "DONE: extraction_king_ref.sh finished."
else
    log_step "ERROR: extraction_king_ref.sh not found!"
fi

# Update nextflow-run.sh with KING directory path
NEXTFLOW_MAIN="$(git rev-parse --show-toplevel)/setup/new_cluster/nextflow-run.sh"

log_step "STEP: Updating KING_REF path in $NEXTFLOW_MAIN..."
if [[ -f "$NEXTFLOW_MAIN" ]]; then
    sed -i "s|PATH_TO_directory/king_ref|$KING_DIR|g" "$NEXTFLOW_MAIN"
    log_step "DONE: KING_REF path replaced with $KING_DIR in $NEXTFLOW_MAIN."
else
    log_step "ERROR: Config file $NEXTFLOW_MAIN not found."
fi

# Return to repo root
cd "$(git rev-parse --show-toplevel)"