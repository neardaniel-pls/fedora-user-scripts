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
#   ./run-searxng.sh
#
# OPTIONS:
#   SEARXNG_PORT - Optional environment variable to specify the port (default: 8888)
#                 Example: SEARXNG_PORT=8080 ./run-searxng.sh
#
# EXAMPLES:
#   # Run SearxNG on default port (8888)
#   ./run-searxng.sh
#
#   # Run SearxNG on custom port
#   SEARXNG_PORT=8080 ./run-searxng.sh
#
#   # Stop any existing SearxNG instance and restart
#   lsof -ti :8888 | xargs kill -9 2>/dev/null || true
#   ./run-searxng.sh
#
# DEPENDENCIES:
#   - python3: Python interpreter for running the web application
#   - virtual environment: Pre-configured Python environment with SearxNG dependencies
#   - lsof or ss: For port conflict detection (standard Unix utilities)
#   - SearxNG installation: Expected at $HOME/Documents/code/searxng/
#
# OPERATIONAL NOTES:
#   - The script expects SearxNG to be installed in $HOME/Documents/code/searxng/
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

# --- Color Detection ---
# Detect if colors should be enabled
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    # Output is to a terminal and NO_COLOR is not set
    COLORS_ENABLED=1
else
    # Output is redirected or NO_COLOR is set
    COLORS_ENABLED=0
fi

# --- Icon Configuration ---
# Allow disabling icons for environments that don't support Unicode
USE_ICONS="${USE_ICONS:-1}"

# --- Color Definitions ---
# Define colors only if colors are enabled
if (( COLORS_ENABLED )); then
    readonly BOLD="\033[1m"
    readonly BLUE="\033[34m"
    readonly GREEN="\033[32m"
    readonly YELLOW="\033[33m"
    readonly RED="\033[31m"
    readonly CYAN="\033[36m"
    readonly MAGENTA="\033[35m"
    readonly RESET="\033[0m"
else
    # Set to empty strings when colors are disabled
    readonly BOLD=""
    readonly BLUE=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly RED=""
    readonly CYAN=""
    readonly MAGENTA=""
    readonly RESET=""
fi

# --- Icon Definitions ---
# Define icons only if icons are enabled AND colors are enabled
if (( USE_ICONS && COLORS_ENABLED )); then
    readonly INFO_ICON="ℹ️"
    readonly SUCCESS_ICON="✅"
    readonly WARNING_ICON="⚠️"
    readonly ERROR_ICON="❌"
    readonly SECTION_ICON="🔧"
    readonly START_ICON="🚀"
    readonly PACKAGE_ICON="📦"
    readonly CLEAN_ICON="🧹"
    readonly SEARCH_ICON="🔍"
    readonly WEB_ICON="🌐"
else
    # Set to empty strings when icons or colors are disabled
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
    readonly SECTION_ICON=""
    readonly START_ICON=""
    readonly PACKAGE_ICON=""
    readonly CLEAN_ICON=""
    readonly SEARCH_ICON=""
    readonly WEB_ICON=""
fi

# --- Output Functions ---
info() {
    local message="$1"
    echo -e "${BOLD}${BLUE}${INFO_ICON}  ${message}${RESET}"
}

success() {
    local message="$1"
    echo -e "${BOLD}${GREEN}${SUCCESS_ICON} ${message}${RESET}"
}

warning() {
    local message="$1"
    echo -e "${BOLD}${YELLOW}${WARNING_ICON} ${message}${RESET}"
}

error() {
    local message="$1"
    echo -e "${BOLD}${RED}${ERROR_ICON} ${message}${RESET}" >&2
}

print_header() {
    local text="$1"
    echo
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}🔧 ${text}${RESET}"
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
}

print_section_header() {
    local text="$1"
    local icon="$2"
    echo
    echo -e "${BOLD}${MAGENTA}─────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}${MAGENTA}${icon} ${text}${RESET}"
    echo -e "${BOLD}${MAGENTA}─────────────────────────────────────────────────────────${RESET}"
    echo
}

print_separator() {
    echo -e "${BOLD}${CYAN}─────────────────────────────────────────────────────────${RESET}"
}

print_subheader() {
    local text="$1"
    echo -e "${BOLD}${text}${RESET}"
}

print_command_output() {
    echo -e "${BOLD}${BLUE}↳ Command output:${RESET}"
}

print_operation_start() {
    local operation="$1"
    echo -e "${BOLD}${YELLOW}▶ Starting: ${operation}${RESET}"
}

print_operation_end() {
    local operation="$1"
    echo -e "${BOLD}${GREEN}✓ Completed: ${operation}${RESET}"
}

# ===== Configuration =====
# Base directory for SearxNG installation
SEARXNG_BASE="$HOME/Documents/code/searxng"
# Virtual environment directory for Python dependencies
SEARXNG_VENV="$SEARXNG_BASE/searxng-venv"
# SearxNG application directory
SEARXNG_APP="$SEARXNG_BASE/searxng"
# Path to the main web application script
WEBAPP_SCRIPT="$SEARXNG_APP/searx/webapp.py"
# Port for the web service (default: 8888, can be overridden via environment variable)
SEARXNG_PORT="${SEARXNG_PORT:-8888}"

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

# ===== Port Conflict Detection =====
# Check if the specified port is already in use to prevent conflicts
print_section_header "PORT VALIDATION" "${WEB_ICON}"
print_operation_start "Checking for port conflicts on $SEARXNG_PORT"

# Try using lsof first (more detailed information)
if command -v lsof &> /dev/null; then
  if lsof -Pi :$SEARXNG_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    error "Port $SEARXNG_PORT is already in use."
    info "SearxNG may already be running. Use 'lsof -ti :$SEARXNG_PORT | xargs kill' to stop it."
    exit 1
  fi
  success "Port $SEARXNG_PORT is available (checked with lsof)"
# Fallback to ss if lsof is not available
elif command -v ss &> /dev/null; then
  if ss -ltn "sport = :$SEARXNG_PORT" | grep -q ":$SEARXNG_PORT"; then
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
python3 searx/webapp.py

# Deactivate the virtual environment on normal exit
deactivate
