#!/bin/bash

# This script updates a Wazuh decoder.

set -euo pipefail
RULESET_DIR=0

# Logging functions
log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*" >&2
}

usage() {
    echo "Usage: $0 -n <decoder_name> [-d <decoder_dir>]"
    echo "       -n: Name of the decoder"
    echo "       -d: Directory of the decoder (default: same as decoder name)"
    exit 1
}

navigate_to_ruleset_root() {
    # If RULESET_DIR directly navigate to it
    if [[ -d "$RULESET_DIR" ]]; then
        cd $RULESET_DIR
        return
    fi
    repo_root_marker="intelligence-data"
    script_path=$(dirname "$(realpath "$0")")

    while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
        script_path=$(dirname "$script_path")
    done

    cd "$script_path/$repo_root_marker"

    RULESET_DIR=$(pwd)/ruleset

    # Load the integrations
    cd "$RULESET_DIR" || exit 1
}

parse_args() {
    # Check if any arguments were provided
    if [[ $# -eq 0 ]]; then
        log_error "No arguments provided"
        usage
        exit 1
    fi
    # Parse the arguments
    while getopts ":n:d:" opt; do
        case $opt in
            n) DECODER_NAME="$OPTARG" ;;
            d) DECODER_DIR="$OPTARG" ;;
            ?) 
                log_error "Unknown option: -$opt"
                usage
                exit 1
                ;;
        esac
    done

    # Decoder name is required
    if [[ -z "$DECODER_NAME" ]]; then
        log_error "Decoder name is required"
        usage
        exit 1
    fi

    # If not decoder directory defined asume it repeates the decoder name
    DECODER_DIR=${DECODER_DIR:-$DECODER_NAME}
}

action_update() {
    log_info "Updating decoder: $DECODER_NAME"
    engine-catalog -n wazuh update decoder/$DECODER_NAME/0 < decoders/$DECODER_DIR/$DECODER_NAME.yml || {
        log_error "Failed to update decoder"
        exit 1
    }
    log_success "Decoder updated successfully"
}

parse_args "${@}"
navigate_to_ruleset_root
action_update
