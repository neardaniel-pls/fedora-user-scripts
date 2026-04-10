#!/bin/bash
#
# update-searxng.sh - SearxNG repository update utility
#
# DESCRIPTION:
#   This script updates a local SearxNG installation by pulling the latest
#   changes from the official GitHub repository. It performs comprehensive
#   validation to ensure the repository is legitimate, checks for uncommitted
#   changes, and safely updates the codebase using fast-forward merges only.
#   The script provides colored output for better user experience and includes
#   multiple safety checks to prevent accidental data loss.
#
# USAGE:
#   ./update-searxng.sh
#
# OPTIONS:
#   None - the script runs non-interactively with automatic validation
#
# EXAMPLES:
#   # Update SearxNG to the latest version
#   ./update-searxng.sh
#
#   # Check for updates without applying them (manual git commands)
#   cd ~/Documents/code/searxng/searxng && git fetch && git log HEAD..origin/main
#
# DEPENDENCIES:
#   - git: Version control system for repository operations
#   - Standard Unix utilities: cd, echo, test
#   - SearxNG installation: Expected at $HOME/Documents/code/searxng/searxng/ (or set SEARXNG_DIR)
#
# OPERATIONAL NOTES:
#   - The script expects SearxNG to be installed in $HOME/Documents/code/searxng/searxng/
#     Override with the SEARXNG_DIR environment variable if installed elsewhere
#   - Only fast-forward updates are allowed to prevent history divergence
#   - The script supports both 'main' and 'master' as the default branch
#   - Uncommitted changes will prevent the update from proceeding
#   - The repository is verified to be the official SearxNG repository
#   - Exit codes: 0 for success (including no updates needed), 1 for errors
#
# SECURITY CONSIDERATIONS:
#   - The script validates the git remote URL to ensure it matches the official repository
#   - Fast-forward only updates prevent unexpected history changes
#   - Uncommitted changes are detected and reported to prevent data loss
#   - The script refuses to run on non-git repositories or unexpected remotes

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

# --- User Configuration ---
# Load user config if available (sets env vars that override defaults)
if [ -n "${SUDO_USER:-}" ]; then
    _USER_CONFIG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config/fedora-user-scripts/config.sh"
else
    _USER_CONFIG="${HOME}/.config/fedora-user-scripts/config.sh"
fi
if [ -f "$_USER_CONFIG" ]; then
    source "$_USER_CONFIG"
fi

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
    readonly RESET="\033[0m"
else
    # Set to empty strings when colors are disabled
    readonly BOLD=""
    readonly BLUE=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly RED=""
    readonly RESET=""
fi

# --- Icon Definitions ---
# Define icons only if icons are enabled AND colors are enabled
if (( USE_ICONS && COLORS_ENABLED )); then
    readonly INFO_ICON="ℹ️"
    readonly SUCCESS_ICON="✅"
    readonly WARNING_ICON="⚠️"
    readonly ERROR_ICON="❌"
else
    # Set to empty strings when icons or colors are disabled
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
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
    echo -e "${BOLD}🔍 ${text}${RESET}"
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
}

print_separator() {
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
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

# --- Script Initialization ---
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"

# Quick version check before any heavy initialization
if [[ "${1:-}" == "--version" || "${1:-}" == "-V" ]]; then
    echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
    exit 0
fi

# --- Dependency Checking ---
check_dependencies() {
    local missing_deps=0
    local cmd
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Dependency '$cmd' is not installed."
            missing_deps=1
        fi
    done
    
    if [ "$missing_deps" -eq 1 ]; then
        error "Please install missing dependencies and try again."
        exit 1
    fi
    
    return 0
}

# Display script introduction with formatting (skip if being called from another script)
if [[ "${QUIET:-}" != "1" ]]; then
    print_header "SEARXNG UPDATE"
fi

# ===== Configuration =====
# Path to the local SearxNG repository
# Use SUDO_USER if available (when running with sudo), otherwise use HOME
if [ -n "${SUDO_USER:-}" ]; then
    ORIGINAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    _DEFAULT_SEARXNG_DIR="${ORIGINAL_USER_HOME}/Documents/code/searxng/searxng"
else
    _DEFAULT_SEARXNG_DIR="$HOME/Documents/code/searxng/searxng"
fi
SEARXNG_DIR="${SEARXNG_DIR:-$_DEFAULT_SEARXNG_DIR}"

# ===== Dependency Check =====
# Verify required tools are available
check_dependencies git

# ===== Directory Validation =====
# Verify the SearxNG directory exists
if [ ! -d "$SEARXNG_DIR" ]; then
  error "Directory $SEARXNG_DIR not found."
  echo "Please ensure SearxNG is installed in the expected location."
  exit 1
fi

# Change to the SearxNG directory (exit if this fails)
cd "$SEARXNG_DIR" || exit 1

# ===== Repository Validation =====
# Verify the directory is a git repository
if [ ! -d ".git" ]; then
  error "Not a git repository."
  echo "The specified directory is not a valid git repository."
  exit 1
fi

# Verify the remote origin matches the official SearxNG repository
if [[ "${QUIET:-}" != "1" ]]; then
    print_operation_start "Updating SearxNG"
    print_command_output
fi
echo "  Verifying repository..."
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ ! "$REMOTE_URL" =~ ^https?://github\.com[:/]searxng/searxng(\.git)?$ ]]; then
  error "Unexpected git remote origin: $REMOTE_URL"
  echo "For security reasons, this script only works with the official SearxNG repository."
  exit 1
fi

# ===== Working Directory Validation =====
# Check for uncommitted changes that could be lost during update
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  error "You have uncommitted changes. Please commit or stash them first."
  echo "Use 'git commit' to save changes or 'git stash' to temporarily save them."
  exit 1
fi

# ===== Repository Update =====
# Pull the latest changes from the official repository
echo "  Checking for updates..."

# Try to update from main branch first, then fall back to master
# Use --ff-only to ensure only fast-forward updates are applied
if git pull origin main --ff-only 2>/dev/null || git pull origin master --ff-only 2>/dev/null; then
  # Check if any actual changes were downloaded
  if git diff --quiet HEAD@{1} HEAD 2>/dev/null; then
    echo "Already up to date."
    if [[ "${QUIET:-}" != "1" ]]; then
        print_operation_end "SearxNG updated"
        success "SearxNG updated successfully"
    fi
  else
    echo " SearxNG updated successfully!"
    if [[ "${QUIET:-}" != "1" ]]; then
        print_operation_end "SearxNG updated"
        success "SearxNG updated successfully"
    fi
  fi
else
  error "Failed to update. Please check for conflicts or network issues."
  echo "You may need to resolve conflicts or check your internet connection."
  exit 1
fi

# Only print separator if not being called quietly
if [[ "${QUIET:-}" != "1" ]]; then
    print_separator
fi
