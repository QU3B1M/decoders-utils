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

action_up() {
    log_info "Setting up integration..."
    
    cd "$INTEGRATIONS_DIR" || exit 1
    
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

repo_root_marker="intelligence-data"
script_path=$(dirname "$(realpath "$0")")

while [[ "$script_path" != "/" ]] && [[ ! -d "$script_path/$repo_root_marker" ]]; do
    script_path=$(dirname "$script_path")
done

cd "$script_path/$repo_root_marker"

RULESET_DIR=$(pwd)/ruleset

# Load the integrations
cd "$RULESET_DIR/integrations" || exit 1

# Parse the arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --integration-name)
            INTEGRATION_NAME="$2"
            shift 2
            ;;
        --engine-name)
            ENGINE_NAME="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done



action_up