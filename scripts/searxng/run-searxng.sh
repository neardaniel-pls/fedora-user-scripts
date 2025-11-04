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

# Source shared colors library
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/colors.sh"

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

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
echo -e "${BOLD}${BLUE}${INFO_ICON} Starting SearxNG...${RESET}"

# ===== Environment Validation =====
# Verify all required directories and files exist before proceeding

# Check if base SearxNG directory exists
if [ ! -d "$SEARXNG_BASE" ]; then
  error "SearxNG directory not found: $SEARXNG_BASE"
  echo "Please ensure SearxNG is installed in the expected location."
  exit 1
fi

# Check if virtual environment directory exists
if [ ! -d "$SEARXNG_VENV" ]; then
  error "Virtual environment not found: $SEARXNG_VENV"
  echo "Please create a virtual environment for SearxNG dependencies."
  exit 1
fi

# Check if virtual environment activation script exists
if [ ! -f "$SEARXNG_VENV/bin/activate" ]; then
  error "Virtual environment activation script not found"
  echo "The virtual environment appears to be corrupted or incomplete."
  exit 1
fi

# Check if the main web application script exists
if [ ! -f "$WEBAPP_SCRIPT" ]; then
  error "webapp.py not found: $WEBAPP_SCRIPT"
  echo "Please ensure SearxNG is properly installed."
  exit 1
fi

# ===== Port Conflict Detection =====
# Check if the specified port is already in use to prevent conflicts

# Try using lsof first (more detailed information)
if command -v lsof &> /dev/null; then
  if lsof -Pi :$SEARXNG_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    warning "Port $SEARXNG_PORT is already in use."
    echo "SearxNG may already be running. Use 'lsof -ti :$SEARXNG_PORT | xargs kill' to stop it."
    exit 1
  fi
# Fallback to ss if lsof is not available
elif command -v ss &> /dev/null; then
  if ss -ltn "sport = :$SEARXNG_PORT" | grep -q ":$SEARXNG_PORT"; then
    warning "Port $SEARXNG_PORT is already in use."
    echo "SearxNG may already be running."
    exit 1
  fi
fi

# ===== Virtual Environment Activation =====
# Activate the Python virtual environment to access SearxNG dependencies

info "Activating virtual environment..."
# Source the activation script (shellcheck disabled as this is a standard pattern)
# shellcheck disable=SC1091
source "$SEARXNG_VENV/bin/activate"

# Verify that the virtual environment was successfully activated
if [ -z "${VIRTUAL_ENV:-}" ]; then
  error "Failed to activate virtual environment"
  echo "The virtual environment may be corrupted."
  exit 1
fi

success "Virtual environment activated"

# ===== Cleanup Handler =====
# Define a function to handle graceful shutdown when signals are received
cleanup() {
  echo -e "\n${BOLD}${YELLOW}${WARNING_ICON} Shutting down SearxNG...${RESET}"
  # Deactivate the virtual environment (ignore errors if already deactivated)
  deactivate 2>/dev/null || true
  exit 0
}

# Register the cleanup function to handle SIGINT (Ctrl+C) and SIGTERM signals
trap cleanup SIGINT SIGTERM

# ===== Launch SearxNG Application =====
# Change to the application directory and start the web server

success "Starting SearxNG web application..."
echo -e "${BOLD}Access SearxNG at: http://localhost:$SEARXNG_PORT${RESET}\n"

# Change to the SearxNG application directory (exit if this fails)
cd "$SEARXNG_APP" || exit 1

# Start the SearxNG web application
# This will run until interrupted or terminated
python3 searx/webapp.py

# Deactivate the virtual environment on normal exit
deactivate
