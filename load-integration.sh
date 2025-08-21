#!/bin/bash

# This script sets up a new integration for the Wazuh engine.

set -euo pipefail

ENGINE_NAME=wazuh

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
    echo "Usage: $0 -i <integration_name> -e <engine_name>"
    echo "       -i: Name of the integration"
    echo "       -e: Name of the engine (default: $ENGINE_NAME)"
    exit 1
}

parse_args() {
    # Check if any arguments were provided
    if [[ $# -eq 0 ]]; then
        log_error "No arguments provided"
        usage
        exit 1
    fi
    # Parse the arguments
    while getopts ":i:e:" opt; do
        case $opt in
            i) INTEGRATION_NAME="$OPTARG" ;;
            e) ENGINE_NAME="$OPTARG" ;;
            ?) 
                log_error "Unknown option: -$opt"
                usage
                exit 1
                ;;
        esac
    done
    # Integration name is required
    if [[ -z "$INTEGRATION_NAME" ]]; then
        log_error "Integration name is required"
        usage
        exit 1
    fi
}

navigate_to_repo_root() {
    repo_root_marker="intelligence-data"
    script_path=$(dirname "$(realpath "$0")")

    while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
        script_path=$(dirname "$script_path")
    done

    cd "$script_path/$repo_root_marker"

    RULESET_DIR=$(pwd)/ruleset

    # Load the integrations
    cd "$RULESET_DIR/integrations" || exit 1
}

action_up() {
    log_info "Setting up integration..."
    
    log_info "Adding integration..."
    engine-integration add -n "$ENGINE_NAME" "$INTEGRATION_NAME" || {
        log_error "Failed to add integration"
        exit 1
    }
    
    log_info "Adding policy..."
    engine-policy asset-add -n "$ENGINE_NAME" "integration/${INTEGRATION_NAME}/0" || {
        log_error "Failed to add policy"
        exit 1
    }
    
    log_info "Adding test..."
    engine-test add -i "$INTEGRATION_NAME" -f single-line -c "file" -m "syslog" --log-file-path "" || {
        log_error "Failed to add test"
        exit 1
    }
    
    log_success "Integration setup completed successfully"
}

parse_args "${@}"
navigate_to_repo_root
action_up
