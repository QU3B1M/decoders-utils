#!/bin/bash

# DESCRIPTION:
#     This script manages integrations for the Wazuh engine:
#     
#     Setup (up action):
#     1. Adding the integration to the engine
#     2. Adding the integration policy
#     3. Setting up basic test configuration
#     
#     Cleanup (down action):
#     1. Removing test configuration
#     2. Removing integration policy
#     3. Removing integration from engine
#     
#     Reload (--reload flag):
#     1. Performs cleanup if integration exists
#     2. Performs setup

set -euo pipefail

NAMESPACE=wazuh

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
Usage: $0 <integration_name> [-n <namespace>] [-a <action>] [--reload] [--remove] [--generate-docs] [-h]

ARGUMENTS:
    integration_name        Name of the integration (required, positional)
                           Must contain only alphanumeric characters, hyphens, and underscores

OPTIONS:
    -n <namespace>          Name of the namespace (optional, default: $NAMESPACE)
                           Must contain only alphanumeric characters, hyphens, and underscores
    --reload                Reload integration (cleanup + setup) - overrides -a flag
    --remove                Remove the integration (cleanup)
    --generate-docs         Generate documentation for the integration
    -h                      Show this help message

EXAMPLES:
    $0 my-integration                       # Setup integration
    $0 my-integration -n custom-engine      # Setup with custom namespace
    $0 my-integration --reload              # Reload integration (down + up)

EOF
    exit 0
}

parse_args() {
    # Initialize variables
    INTEGRATION_NAME=""
    ACTION="up"
    RELOAD_FLAG=false
    
    # Check if any arguments were provided
    if [[ $# -eq 0 ]]; then
        log_error "No arguments provided"
        usage
    fi
    
    # First argument should be the integration name
    INTEGRATION_NAME="$1"
    shift
    
    # Validate integration name format
    if [[ ! "$INTEGRATION_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid integration name format. Use only alphanumeric characters, hyphens, and underscores."
        exit 1
    fi
    
    # Parse the remaining arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n)
                if [[ $# -lt 2 ]]; then
                    log_error "Option -n requires an argument"
                    usage
                fi
                NAMESPACE="$2"
                # Validate namespace format
                if [[ ! "$NAMESPACE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    log_error "Invalid namespace format. Use only alphanumeric characters, hyphens, and underscores."
                    exit 1
                fi
                shift 2
                ;;
            --reload)
                RELOAD_FLAG=true
                ACTION="reload"  # Override action
                shift
                ;;
            --remove)
                ACTION="down"
                shift
                ;;
            --generate-docs)
                ACTION="generate-docs"
                shift
                ;;
            -h)
                usage
                ;;
            --help)
                usage
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                log_error "Unexpected argument: $1"
                usage
                ;;
        esac
    done
    
    # Check if integration name is empty or just whitespace
    if [[ -z "${INTEGRATION_NAME// }" ]]; then
        log_error "Integration name cannot be empty or contain only whitespace"
        exit 1
    fi
    
    log_info "Using integration: $INTEGRATION_NAME"
    log_info "Using namespace: $NAMESPACE"
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
    log_info "Setting up integration '$INTEGRATION_NAME' on namespace '$NAMESPACE'..."
    
    # Check if integration already exists by trying to add it and checking the error
    log_info "Adding integration..."
    if ! engine-integration add -n "$NAMESPACE" "$INTEGRATION_NAME" 2>/dev/null; then
        # Check if it's because it already exists or because of another error
        if engine-integration add -n "$NAMESPACE" "$INTEGRATION_NAME" 2>&1 | grep -q "already exists\|duplicate"; then
            log_error "Integration '$INTEGRATION_NAME' already exists in namespace '$NAMESPACE'"
            log_info "Use --reload flag to reload the integration or --remove to remove it first"
            exit 1
        else
            log_error "Failed to add integration '$INTEGRATION_NAME'"
            log_info "Check if the integration exists in the ruleset/integrations directory"
            exit 1
        fi
    fi
    
    log_info "Adding policy..."
    if ! engine-policy asset-add -n "$NAMESPACE" "integration/${INTEGRATION_NAME}/0"; then
        log_error "Failed to add policy for integration '$INTEGRATION_NAME'"
        log_info "Rolling back integration..."
        engine-integration remove -n "$NAMESPACE" "integration/${INTEGRATION_NAME}/0" 2>/dev/null || true
        exit 1
    fi
    
    log_info "Adding test configuration..."
    if ! engine-test add -i "$INTEGRATION_NAME" -f single-line -c "file" -m "syslog" --log-file-path ""; then
        log_error "Failed to add test configuration for integration '$INTEGRATION_NAME'"
        log_info "Rolling back changes..."
        engine-policy asset-remove -n "$NAMESPACE" "integration/${INTEGRATION_NAME}/0" 2>/dev/null || true
        engine-integration remove -n "$NAMESPACE" "integration/${INTEGRATION_NAME}/0" 2>/dev/null || true
        exit 1
    fi
    
    log_success "Integration '$INTEGRATION_NAME' setup completed successfully!"
    log_info "Next steps:"
    log_info "  1. Configure your decoder in ruleset/decoders/${INTEGRATION_NAME}/"
    log_info "  2. Add test logs and expected outputs"
    log_info "  3. Run tests with: engine-test run -i ${INTEGRATION_NAME}"
}

action_cleanup() {
    log_info "Cleaning up integration '$INTEGRATION_NAME' from namespace '$NAMESPACE'..."
    
    log_info "Removing test configuration..."
    if ! engine-test delete "$INTEGRATION_NAME" 2>/dev/null; then
        log_error "Failed to remove test configuration for integration '$INTEGRATION_NAME'"
        log_info "Test configuration may not exist or was already removed"
    else
        log_info "Test configuration removed successfully"
    fi
    
    log_info "Removing policy..."
    if ! engine-policy asset-remove -n "$NAMESPACE" "integration/${INTEGRATION_NAME}/0" 2>/dev/null; then
        log_error "Failed to remove policy for integration '$INTEGRATION_NAME'"
        log_info "Policy may not exist or was already removed"
    else
        log_info "Policy removed successfully"
    fi
    
    log_info "Removing integration..."
    if ! engine-integration delete -n "$NAMESPACE" "${INTEGRATION_NAME}" 2>/dev/null; then
        log_error "Failed to remove integration '$INTEGRATION_NAME'"
        log_info "Integration may not exist or was already removed"
        return 1
    else
        log_info "Integration removed successfully"
    fi
    
    log_success "Integration '$INTEGRATION_NAME' cleanup completed successfully!"
    if [[ "$ACTION" != "reload" ]]; then
        log_info "Note: Decoder files in ruleset/decoders/${INTEGRATION_NAME}/ were not removed"
        log_info "Remove them manually if no longer needed"
    fi
}

action_reload() {
    log_info "Reloading integration '$INTEGRATION_NAME'..."
    
    # Always attempt cleanup first (it will gracefully handle non-existent integrations)
    log_info "Attempting cleanup of existing integration..."
    action_cleanup 2>/dev/null || log_info "No existing integration found or cleanup completed"
    
    log_info "Proceeding with setup..."
    
    # Now set up the integration
    action_up
    
    log_success "Integration '$INTEGRATION_NAME' reload completed successfully!"
}

action_generate_docs() {
    cd $INTEGRATION_NAME || {
        log_error "Integration directory '$INTEGRATION_NAME' does not exist"
        exit 1
    }
    log_info "Checking documentation.yml file..."
    if [[ ! -f documentation.yml ]]; then
        log_error "documentation.yml file not found in integration '$INTEGRATION_NAME'"
        exit 1
    fi
    if ! grep -q "title:" documentation.yml; then
        log_error "documentation.yml is missing the 'title' field"
        exit 1
    fi
    if ! grep -q "overview:" documentation.yml; then
        log_error "documentation.yml is missing the 'overview' field"
        exit 1
    fi
    if ! grep -q "compatibility:" documentation.yml; then
        log_error "documentation.yml is missing the 'compatibility' field"
        exit 1
    fi
    if ! grep -q "configuration:" documentation.yml; then
        log_error "documentation.yml is missing the 'configuration' field"
        exit 1
    fi
    if ! grep -q "event:" documentation.yml; then
        log_error "documentation.yml is missing the 'event' field"
        exit 1
    fi
    if ! grep -q "module:" documentation.yml; then
        log_error "documentation.yml is missing the 'module' field under 'event'"
        exit 1
    fi
    if ! grep -q "dataset:" documentation.yml; then
        log_error "documentation.yml is missing the 'dataset' field under 'event'"
        exit 1
    fi
    log_info "Generating documentation for integration '$INTEGRATION_NAME'..."
    engine-integration generate-doc || {
        log_error "Failed to generate documentation for integration '$INTEGRATION_NAME'"
        exit 1
    }
    cd ..
    log_success "Documentation generation completed successfully!"
}

parse_args "${@}"
navigate_to_repo_root

# Execute the requested action
case "$ACTION" in
    "up")
        action_up
        ;;
    "down")
        action_cleanup
        ;;
    "reload")
        action_reload
        ;;
    "generate-docs")
        action_generate_docs
        ;;
    *)
        log_error "Unknown action: $ACTION"
        usage
        ;;
esac
