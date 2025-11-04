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
#   - SearxNG installation: Expected at $HOME/Documents/code/searxng/searxng/
#
# OPERATIONAL NOTES:
#   - The script expects SearxNG to be installed in $HOME/Documents/code/searxng/searxng/
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

# ===== Appearance (colors) =====
# ANSI color codes for formatted output
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; red="\033[31m"; reset="\033[0m"

# Display script introduction with formatting
echo -e "${bold}${blue}🚀 Updating searxng...${reset}"

# ===== Configuration =====
# Path to the local SearxNG repository
SEARXNG_DIR="$HOME/Documents/code/searxng/searxng"

# ===== Directory Validation =====
# Verify the SearxNG directory exists
if [ ! -d "$SEARXNG_DIR" ]; then
  echo -e "${bold}${red}Error: Directory $SEARXNG_DIR not found.${reset}"
  echo "Please ensure SearxNG is installed in the expected location."
  exit 1
fi

# Change to the SearxNG directory (exit if this fails)
cd "$SEARXNG_DIR" || exit 1

# ===== Repository Validation =====
# Verify the directory is a git repository
if [ ! -d ".git" ]; then
  echo -e "${bold}${red}Error: Not a git repository.${reset}"
  echo "The specified directory is not a valid git repository."
  exit 1
fi

# Verify the remote origin matches the official SearxNG repository
echo -e "${bold}Verifying repository...${reset}"
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ ! "$REMOTE_URL" =~ github\.com[:/]searxng/searxng ]]; then
  echo -e "${bold}${red}Error: Unexpected git remote origin: $REMOTE_URL${reset}"
  echo "For security reasons, this script only works with the official SearxNG repository."
  exit 1
fi

# ===== Working Directory Validation =====
# Check for uncommitted changes that could be lost during update
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo -e "${bold}${red}Warning: You have uncommitted changes. Please commit or stash them first.${reset}"
  echo "Use 'git commit' to save changes or 'git stash' to temporarily save them."
  exit 1
fi

# ===== Repository Update =====
# Pull the latest changes from the official repository
echo -e "${bold}Checking for updates...${reset}"

# Try to update from main branch first, then fall back to master
# Use --ff-only to ensure only fast-forward updates are applied
if git pull origin main --ff-only 2>/dev/null || git pull origin master --ff-only 2>/dev/null; then
  # Check if any actual changes were downloaded
  if git diff --quiet HEAD@{1} HEAD 2>/dev/null; then
    echo -e "${bold}${green}✅ SearxNG is already up to date.${reset}"
  else
    echo -e "${bold}${green}✅ SearxNG updated successfully!${reset}"
  fi
else
  echo -e "${bold}${red}❌ Failed to update. Please check for conflicts or network issues.${reset}"
  echo "You may need to resolve conflicts or check your internet connection."
  exit 1
fi
