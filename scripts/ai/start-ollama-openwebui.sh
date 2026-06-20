#!/bin/bash
#
# start-ollama-openwebui.sh - Start Ollama and Open Web UI services
#
# DESCRIPTION:
#   This script starts Ollama and Open Web UI services.
#   It provides colored output for better user experience and includes
#   status checking for both services.
#
# USAGE:
#   ./start-ollama-openwebui.sh
#
# OPTIONS:
#   None - the script starts both services
#
# EXAMPLES:
#   # Start both services
#   ./start-ollama-openwebui.sh
#
# DEPENDENCIES:
#   - podman: Container engine for Open Web UI
#   - systemctl: Manage Ollama service
#   - sudo: Required for systemctl operations
#
# OPERATIONAL NOTES:
#   - The script expects Open Web UI container named 'open-webui'
#   - The script expects Ollama service managed by systemd
#   - Exit codes: 0 for success, 1 for errors
#
# SECURITY CONSIDERATIONS:
#   - The script requires sudo privileges for systemctl operations

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLI_ARG1="${1:-}"
source "${SCRIPT_DIR}/../lib/ui.sh"

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.3.3"
version_check "$SCRIPT_VERSION"

# ===== Configuration =====
# Container and service names
OPENWEBUI_CONTAINER="open-webui"
OLLAMA_SERVICE="ollama"

# Flag to prevent cleanup from running multiple times
CLEANUP_RAN=false

# ===== Helper Functions =====
show_help() {
    cat << EOF
Usage: $0

Start Ollama and Open Web UI services.

OPTIONS:
    --help        Display this help message
    --version, -V Display script version

EXAMPLES:
    # Start both services
    $0

ACCESS POINTS:
    Open Web UI:  http://localhost:8080
    Ollama API:    http://127.0.0.1:11434

For more information, see the documentation at:
    docs/guides/start-ollama-openwebui-guide.md
EOF
}

# ===== Start Functions =====
start_ollama() {
    print_operation_start "Starting Ollama service"

    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^${OLLAMA_SERVICE}.service"; then
        error "Ollama service not found. Please install Ollama first."
        return 1
    fi

    # Check if already running
    if systemctl is-active --quiet "${OLLAMA_SERVICE}" 2>/dev/null; then
        info "Ollama is already running"
        return 0
    fi

    # Start service
    print_command_output
    sudo systemctl start ollama || {
        error "Failed to start Ollama service"
        return 1
    }

    # Verify it's running
    if systemctl is-active --quiet "${OLLAMA_SERVICE}" 2>/dev/null; then
        success "Ollama started successfully"
        print_operation_end "Ollama service"
        return 0
    else
        error "Ollama service failed to start"
        return 1
    fi
}

start_openwebui() {
    print_operation_start "Starting Open Web UI container"

    # Check if container exists
    if ! podman ps -a -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        error "Open Web UI container not found. Please run setup script first."
        return 1
    fi

    # Check if already running
    if podman ps -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        info "Open Web UI is already running"
        return 0
    fi

    # Start container
    print_command_output
    podman start "${OPENWEBUI_CONTAINER}" || {
        error "Failed to start Open Web UI container"
        return 1
    }

    # Verify it's running
    if podman ps | grep -q "${OPENWEBUI_CONTAINER}"; then
        success "Open Web UI started successfully"
        print_operation_end "Open Web UI container"
        return 0
    else
        error "Open Web UI container failed to start"
        return 1
    fi
}

# ===== Stop Functions =====
stop_ollama() {
    print_operation_start "Stopping Ollama service"

    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^${OLLAMA_SERVICE}.service"; then
        warning "Ollama service not found"
        return 0
    fi

    # Check if already stopped
    if ! systemctl is-active --quiet "${OLLAMA_SERVICE}" 2>/dev/null; then
        info "Ollama is already stopped"
        return 0
    fi

    # Stop service
    print_command_output
    sudo systemctl stop ollama || {
        error "Failed to stop ollama service"
        return 1
    }

    success "Ollama stopped successfully"
    print_operation_end "Ollama service"

    return 0
}

stop_openwebui() {
    print_operation_start "Stopping Open Web UI container"

    # Check if container exists
    if ! podman ps -a -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        warning "Open Web UI container not found"
        return 0
    fi

    # Check if already stopped
    if ! podman ps -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        info "Open Web UI is already stopped"
        return 0
    fi

    # Stop container
    print_command_output
    podman stop "${OPENWEBUI_CONTAINER}" || {
        error "Failed to stop Open Web UI container"
        return 1
    }

    success "Open Web UI stopped successfully"
    print_operation_end "Open Web UI container"

    return 0
}

# ===== Cleanup Function =====
cleanup() {
    # Prevent cleanup from running multiple times
    if [ "$CLEANUP_RAN" = true ]; then
        return 0
    fi

    CLEANUP_RAN=true

    echo
    print_section_header "CLEANUP" "🧹"

    stop_ollama
    stop_openwebui

    print_separator

    # Exit script after cleanup
    exit 0
}

# ===== Main Script =====
# Set trap to cleanup on Ctrl+C (not on normal exit)
trap cleanup INT TERM

# Parse command line arguments (script takes no positional arguments;
# each flag exits, so a flat case replaces the unreachable loop/shift).
case "${1:-}" in
    --help)
        show_help
        exit 0
        ;;
    --version|-V)
        echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
        exit 0
        ;;
    "")
        ;;  # No arguments — proceed to start services
    *)
        error "Unknown option: $1"
        echo
        show_help
        exit 1
        ;;
esac

# Display header
print_header "OLLAMA AND OPEN WEB UI START"

# Start services
print_section_header "STARTING SERVICES" "${START_ICON}"
start_ollama || exit 1
start_openwebui || exit 1

# Display completion
print_header "START SUMMARY"
success "Ollama and Open Web UI started successfully!"
echo
echo -e "${BOLD}${INFO_ICON}  Access points:${RESET}"
echo -e "  Open Web UI:  ${BOLD}http://localhost:8080${RESET}"
echo -e "  Ollama API:    ${BOLD}http://127.0.0.1:11434${RESET}"
echo
echo -e "${BOLD}${INFO_ICON}  Press Ctrl+C to stop both services${RESET}"
print_separator

# Keep script running
while true; do
    sleep 86400 || true
done
