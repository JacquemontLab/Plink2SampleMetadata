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

# Return to repo root
cd "$(git rev-parse --show-toplevel)"