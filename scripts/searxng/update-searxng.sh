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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/ui.sh"

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

if [ ! -w ".git" ] || [ ! -w ".git/index" ] 2>/dev/null; then
    if [ -n "${SUDO_USER:-}" ]; then
        _repo_owner="$SUDO_USER"
    else
        _repo_owner="$(id -un)"
    fi
    _repo_group="$(id -gn "$_repo_owner")"
    _current_owner=$(stat -c '%U' .git 2>/dev/null || echo "unknown")
    if command -v sudo &>/dev/null; then
        info "Fixing repository ownership (currently owned by ${_current_owner})..."
        if sudo chown -R "$_repo_owner":"$_repo_group" .git; then
            sudo chown -R "$_repo_owner":"$_repo_group" . 2>/dev/null || true
            success "Repository ownership fixed"
        else
            error "Failed to fix ownership. Run manually:"
            echo "  sudo chown -R $_repo_owner:$_repo_group .git"
            exit 1
        fi
    else
        error "No write access to .git directory and sudo not available. Fix ownership:"
        echo "  sudo chown -R $_repo_owner:$_repo_group .git"
        exit 1
    fi
fi

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
# Stash uncommitted changes to allow a clean pull, then restore them after
STASHED=false
_stash_count_before=$(git stash list 2>/dev/null | wc -l)
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo "  Uncommitted changes detected — stashing before update..."
  git stash push -m "auto-stash by update-searxng.sh" 2>/dev/null || true
  _stash_count_after=$(git stash list 2>/dev/null | wc -l)
  if [ "$_stash_count_after" -gt "$_stash_count_before" ]; then
    STASHED=true
  fi
fi

# ===== Repository Update =====
# Pull the latest changes from the official repository
echo "  Checking for updates..."

PULL_SUCCESS=false
if git pull origin main --ff-only 2>&1; then
  PULL_SUCCESS=true
elif git pull origin master --ff-only 2>&1; then
  PULL_SUCCESS=true
fi

# Restore stashed changes if we stashed them
if [ "$STASHED" = true ]; then
  echo "  Restoring stashed changes..."
  if ! git stash pop 2>/dev/null; then
    PULL_SUCCESS=false
    warning "Could not restore stashed changes cleanly."
    warning "Resolve conflicts, then run 'git stash drop' to clean up."
  fi
fi

if [ "$PULL_SUCCESS" = true ]; then
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
