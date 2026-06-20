#!/bin/bash
#
# run-searxng.sh - SearxNG privacy-respecting search engine launcher
#
# DESCRIPTION:
#   This script launches the SearxNG web application, a privacy-respecting search
#   engine that aggregates results from various search engines while protecting
#   user privacy. It handles virtual environment activation, port validation,
#   and graceful shutdown procedures. The script includes comprehensive error
#   checking and provides colored output for better user experience.
#
# USAGE:
#   ./run-searxng.sh [OPTIONS]
#
# OPTIONS:
#   -v, --verbose: Show all SearxNG output including non-critical warnings
#   -h, --help:    Display this help message
#   SEARXNG_PORT:  Optional environment variable to specify the port (default: 8888)
#                  Example: SEARXNG_PORT=8080 ./run-searxng.sh
#
# EXAMPLES:
#   # Run SearxNG on default port (8888) with filtered warnings
#   ./run-searxng.sh
#
#   # Run SearxNG with verbose output (show all warnings and errors)
#   ./run-searxng.sh --verbose
#
#   # Run SearxNG on custom port
#   SEARXNG_PORT=8080 ./run-searxng.sh
#
#   # Run SearxNG with verbose output on custom port
#   SEARXNG_PORT=8080 ./run-searxng.sh -v
#
#   # Stop any existing SearxNG instance and restart
#   lsof -ti :8888 | xargs kill -9 2>/dev/null || true
#   ./run-searxng.sh
#
# DEPENDENCIES:
#   - python3: Python interpreter for running the web application
#   - virtual environment: Pre-configured Python environment with SearxNG dependencies
#   - lsof or ss: For port conflict detection (standard Unix utilities)
#   - SearxNG installation: Expected at $HOME/Documents/code/searxng/ (or set SEARXNG_BASE)
#
# OPERATIONAL NOTES:
#   - The script expects SearxNG to be installed in $HOME/Documents/code/searxng/
#     Override with the SEARXNG_BASE environment variable if installed elsewhere
#   - A virtual environment named 'searxng-venv' should exist in the SearxNG base directory
#   - The default port is 8888 but can be overridden via the SEARXNG_PORT environment variable
#   - The script includes signal handlers for graceful shutdown (SIGINT, SIGTERM)
#   - Port conflicts are detected and reported before attempting to start the service
#   - Exit codes: 0 for success, 1 for configuration errors or port conflicts
#
# SECURITY CONSIDERATIONS:
#   - The script runs SearxNG within an isolated virtual environment
#   - Port conflicts are checked to prevent unexpected service binding
#   - The virtual environment is properly deactivated on exit to prevent contamination
#   - The script changes to the SearxNG application directory before execution

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLI_ARG1="${1:-}"
source "${SCRIPT_DIR}/../lib/ui.sh"

if (( USE_ICONS && COLORS_ENABLED )); then
    readonly SEARCH_ICON="🔍"
    readonly WEB_ICON="🌐"
else
    readonly SEARCH_ICON=""
    readonly WEB_ICON=""
fi

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.3.3"
version_check "$SCRIPT_VERSION"

# ===== Configuration =====
# Base directory for SearxNG installation
# Override with SEARXNG_BASE environment variable if installed elsewhere
SEARXNG_BASE="${SEARXNG_BASE:-$HOME/Documents/code/searxng}"
# Virtual environment directory for Python dependencies
SEARXNG_VENV="${SEARXNG_VENV:-$SEARXNG_BASE/searxng-venv}"
# SearxNG application directory
SEARXNG_APP="${SEARXNG_APP:-$SEARXNG_BASE/searxng}"
# Path to the main web application script
WEBAPP_SCRIPT="${WEBAPP_SCRIPT:-$SEARXNG_APP/searx/webapp.py}"
# Port for the web service (default: 8888, can be overridden via environment variable)
SEARXNG_PORT="${SEARXNG_PORT:-8888}"
# Show all SearxNG output including non-critical warnings (default: 0 to filter warnings)
VERBOSE_MODE=0

# ===== Argument Parsing =====
# Parse command-line arguments
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -v, --verbose  Show all SearxNG output including non-critical warnings
  -h, --help     Display this help message
  -V, --version  Display script version

ENVIRONMENT VARIABLES:
  SEARXNG_BASE   Base directory for SearxNG installation (default: $HOME/Documents/code/searxng)
  SEARXNG_VENV   Path to virtual environment (default: $SEARXNG_BASE/searxng-venv)
  SEARXNG_APP    Path to SearxNG app directory (default: $SEARXNG_BASE/searxng)
  SEARXNG_PORT   Port for the web service (default: 8888)
                 Example: SEARXNG_PORT=8080 $0

EXAMPLES:
  # Run SearxNG with filtered warnings (default)
  $0

  # Run SearxNG with verbose output
  $0 --verbose

  # Run SearxNG on custom port
  SEARXNG_PORT=8080 $0

  # Run SearxNG with verbose output on custom port
  SEARXNG_PORT=8080 $0 -v
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE_MODE=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        -V|--version)
            echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Display script introduction with formatting
print_header "SEARXNG LAUNCHER"
echo -e "${BOLD}${GREEN}${START_ICON} Starting privacy-respecting search engine...${RESET}"
echo

# ===== Environment Validation =====
# Verify all required directories and files exist before proceeding
print_section_header "ENVIRONMENT VALIDATION" "${SECTION_ICON}"
print_operation_start "Validating SearxNG installation"

# Check if base SearxNG directory exists
if [ ! -d "$SEARXNG_BASE" ]; then
  error "SearxNG directory not found: $SEARXNG_BASE"
  error "Please ensure SearxNG is installed in the expected location."
  exit 1
fi
success "Base directory found: $SEARXNG_BASE"

# Check if virtual environment directory exists
if [ ! -d "$SEARXNG_VENV" ]; then
  error "Virtual environment not found: $SEARXNG_VENV"
  error "Please create a virtual environment for SearxNG dependencies."
  exit 1
fi
success "Virtual environment found: $SEARXNG_VENV"

# Check if virtual environment activation script exists
if [ ! -f "$SEARXNG_VENV/bin/activate" ]; then
  error "Virtual environment activation script not found"
  error "The virtual environment appears to be corrupted or incomplete."
  exit 1
fi
success "Virtual environment activation script found"

# Check if the main web application script exists
if [ ! -f "$WEBAPP_SCRIPT" ]; then
  error "webapp.py not found: $WEBAPP_SCRIPT"
  error "Please ensure SearxNG is properly installed."
  exit 1
fi
success "Web application script found: $WEBAPP_SCRIPT"

print_operation_end "Environment validation completed"
print_separator

if [ ! -r "$SEARXNG_APP/searx/settings.yml" ]; then
    print_section_header "PERMISSION REPAIR" "${WARNING_ICON}"
    warning "settings.yml not readable — ownership drift detected"
    if ! fix_ownership "$SEARXNG_APP"; then
        exit 1
    fi
    success "Permissions fixed"
    print_separator
fi

# ===== Port Conflict Detection =====
# Check if the specified port is already in use to prevent conflicts
print_section_header "PORT VALIDATION" "${WEB_ICON}"
print_operation_start "Checking for port conflicts on $SEARXNG_PORT"

# Try using lsof first (more detailed information)
if command -v lsof &> /dev/null; then
  if lsof -Pi :"${SEARXNG_PORT}" -sTCP:LISTEN -t >/dev/null 2>&1; then
    error "Port $SEARXNG_PORT is already in use."
    info "SearxNG may already be running. Use 'lsof -ti :$SEARXNG_PORT | xargs kill' to stop it."
    exit 1
  fi
  success "Port $SEARXNG_PORT is available (checked with lsof)"
# Fallback to ss if lsof is not available
elif command -v ss &> /dev/null; then
  if ss -ltn "sport = :${SEARXNG_PORT}" | grep -q ":${SEARXNG_PORT}"; then
    error "Port $SEARXNG_PORT is already in use."
    info "SearxNG may already be running."
    exit 1
  fi
  success "Port $SEARXNG_PORT is available (checked with ss)"
else
  warning "Neither lsof nor ss is available for port checking"
  info "Proceeding without port validation"
fi

print_operation_end "Port validation completed"
print_separator

# ===== Virtual Environment Activation =====
# Activate the Python virtual environment to access SearxNG dependencies

print_section_header "VIRTUAL ENVIRONMENT" "${PACKAGE_ICON}"
print_operation_start "Activating Python virtual environment"
# Source the activation script (shellcheck disabled as this is a standard pattern)
# shellcheck disable=SC1091
source "$SEARXNG_VENV/bin/activate"

# Verify that the virtual environment was successfully activated
if [ -z "${VIRTUAL_ENV:-}" ]; then
  error "Failed to activate virtual environment"
  error "The virtual environment may be corrupted."
  exit 1
fi

print_operation_end "Virtual environment activated"
success "Python environment ready: $VIRTUAL_ENV"
print_separator

# ===== Cleanup Handler =====
# Define a function to handle graceful shutdown when signals are received
cleanup() {
  echo
  print_section_header "SHUTDOWN" "${WARNING_ICON}"
  info "Shutting down SearxNG gracefully..."
  # Deactivate the virtual environment (ignore errors if already deactivated)
  deactivate 2>/dev/null || true
  success "SearxNG stopped successfully"
  exit 0
}

# Register the cleanup function to handle SIGINT (Ctrl+C) and SIGTERM signals
trap cleanup SIGINT SIGTERM

# ===== Launch SearxNG Application =====
# Change to the application directory and start the web server
print_section_header "LAUNCHING SEARXNG" "${SEARCH_ICON}"
print_operation_start "Starting SearxNG web application"

# Change to the SearxNG application directory (exit if this fails)
cd "$SEARXNG_APP" || exit 1

print_operation_end "Application directory changed to: $SEARXNG_APP"
print_separator

# Display access information
echo -e "${BOLD}${GREEN}${WEB_ICON} Access SearxNG at: ${BOLD}${BLUE}http://localhost:$SEARXNG_PORT${RESET}"
echo -e "${BOLD}${CYAN}Press Ctrl+C to stop the server${RESET}"
echo

# Start the SearxNG web application
# This will run until interrupted or terminated
if (( VERBOSE_MODE )); then
  # Show all output including non-critical warnings
  python3 searx/webapp.py
else
  # Filter out non-critical warnings and errors (engine loading, bot detection)
  python3 searx/webapp.py 2>&1 | grep -vE 'searx\.engines.*loading engine.*failed|searx\.botdetection\.config.*missing config file|searx\.botdetection.*X-Forwarded-For nor X-Real-IP header is set'
fi

# Deactivate the virtual environment on normal exit
deactivate
