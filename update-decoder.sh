
#!/bin/bash

# DESCRIPTION:
#     This script updates a Wazuh decoder.
#     Usage: update-decoder.sh <decoder_name> [-d <decoder_dir>] [-f <decoder_file>] [-h]

set -euo pipefail

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
    cat << EOF
Usage: $0 <decoder_name> [-d <decoder_dir>] [-f <decoder_file>] [-h]

ARGUMENTS:
    decoder_name         Name of the decoder (required, positional)
                        Must contain only alphanumeric characters, hyphens, and underscores

OPTIONS:
    -d <decoder_dir>     Directory of the decoder (optional, default: same as decoder name)
    -f <decoder_file>    File containing the decoder configuration (optional, default: decoder_name.yml)
    -h                   Show this help message

EXAMPLES:
    $0 my-decoder
    $0 my-decoder -d custom-dir
    $0 my-decoder -f custom-file.yml
EOF
    exit 0
}

parse_args() {
    DECODER_NAME=""
    DECODER_DIR=""
    DECODER_FILE=""

    if [[ $# -eq 0 ]]; then
        log_error "No arguments provided"
        usage
    fi

    DECODER_NAME="$1"
    shift

    # Validate decoder name format
    if [[ ! "$DECODER_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid decoder name format. Use only alphanumeric characters, hyphens, and underscores."
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -d requires an argument"
                    usage
                fi
                DECODER_DIR="$2"
                shift 2
                ;;
            -f)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -f requires an argument"
                    usage
                fi
                DECODER_FILE="$2"
                shift 2
                ;;
            -h)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Set defaults if not provided
    DECODER_DIR=${DECODER_DIR:-$DECODER_NAME}
    DECODER_FILE=${DECODER_FILE:-$DECODER_NAME.yml}

    log_info "Using decoder: $DECODER_NAME"
    log_info "Using decoder directory: $DECODER_DIR"
    log_info "Using decoder file: $DECODER_FILE"
}

navigate_to_repo_root() {
    repo_root_marker="intelligence-data"
    script_path=$(dirname "$(realpath "$0")")

    while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
        script_path=$(dirname "$script_path")
    done

    cd "$script_path/$repo_root_marker"

    RULESET_DIR=$(pwd)/ruleset

    # Load the decoders
    cd "$RULESET_DIR" || exit 1
}

action_update() {
    log_info "Updating decoder: $DECODER_NAME"
    if ! engine-catalog -n wazuh update decoder/$DECODER_NAME/0 < decoders/$DECODER_DIR/$DECODER_FILE; then
        log_error "Failed to update decoder"
        exit 1
    fi
    log_success "Decoder updated successfully"
}

parse_args "$@"
navigate_to_repo_root
action_update
