#!/usr/bin/env bash

# ==============================================================================
# Script Name:    template.sh
# Author:         Your Name
# Version:        1.0.0
# License:        MIT License
# ==============================================================================
# Description:
#   This script serves as a comprehensive template for creating robust and
#   maintainable Bash scripts. It includes best practices for error handling,
#   argument parsing, modular design, and documentation.
#
# Inputs:
#   -f, --file <path>   : Specifies a required file path.
#   -v, --verbose       : Enables verbose output for debugging.
#   -h, --help          : Displays this help message.
#
# Outputs:
#   - stdout: Script's primary output, kept clean for piping.
#   - stderr: Logs, errors, and verbose messages.
# ==============================================================================

# Source shared colors library
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/colors.sh"

# --- Unofficial Bash Strict Mode ---
#
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command
#              to exit with a non-zero status, or zero if no command exited
#              with a non-zero status.
set -euo pipefail

# - IFS (Internal Field Separator)
#   Set the IFS to newline and tab. This prevents word splitting on spaces,
#   which is a common cause of bugs in shell scripts when dealing with filenames
#   that contain spaces.
IFS=$'\n\t'

# --- Global Variables and Constants ---
#
# Use 'readonly' for constants and uppercase naming convention.
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="1.0.0"

# Global variable for verbose mode. Must be global for cross-function access.
VERBOSE_MODE=0

# --- Function Definitions ---

#
# @description Prints a standard log message to stderr.
#
# @arg $1 string The log message.
#
function log() {
  local message="$1"
  echo "[$SCRIPT_NAME] $(date +'%Y-%m-%d %H:%M'): $message" >&2
}

#
# @description Prints a debug log message to stderr if verbose mode is enabled.
#
# @arg $1 string The debug message.
#
function debug_log() {
  # Accesses the global VERBOSE_MODE variable.
  if ((VERBOSE_MODE)); then
    log "DEBUG: $1"
  fi
}

#
# @description Prints the script's usage information and exits.
#
# @arg $1 integer The exit code to use (default: 0).
#
function usage() {
  local exit_code="${1:-0}"
  cat <<-EOF
Usage: $SCRIPT_NAME [-h] [-v] -f <file>

A template for robust Bash scripts.

Options:
  -f <file>   Path to a file (required).
  -v          Enable verbose mode.
  -h          Display this help message and exit.
EOF
  exit "$exit_code"
}

#
# @description Cleans up temporary files and resources.
# Registered with 'trap' to run on script exit.
#
function cleanup() {
  log "Performing cleanup tasks..."
  # Example of secure temp file handling:
  # TEMP_FILE=$(mktemp) || exit 1
  # trap "rm -f '$TEMP_FILE'" EXIT
}

# Register the cleanup function to be called on script exit, interrupt, or termination.
trap cleanup EXIT INT TERM

#
# @description The main function where the script's logic resides.
#
# @arg $@ string The original arguments passed to the script.
#
function main() {
  # --- Argument Parsing ---
  local file_path=""

  while getopts ":hvf:" opt; do
    case "$opt" in
      h)
        usage 0
        ;;
      v)
        VERBOSE_MODE=1  # Set the global variable for verbose mode.
        ;;
      f)
        file_path="$OPTARG"
        ;;
      \?)
        log "Error: Invalid option: -$OPTARG"
        usage 1
        ;;
      :)
        log "Error: Option -$OPTARG requires an argument."
        usage 1
        ;;
    esac
  done
  
  # Remove the options that have been processed by getopts.
  shift $((OPTIND - 1))

  # --- Argument Validation ---
  # Check for unexpected positional arguments.
  if [[ $# -gt 0 ]]; then
    log "Error: Unexpected arguments: $*"
    usage 1
  fi

  # Check for mandatory arguments.
  if [[ -z "$file_path" ]]; then
    log "Error: Missing required argument: -f <file>"
    usage 1
  fi

  # Validate file existence and readability.
  if [[ ! -e "$file_path" ]]; then
    log "Error: File does not exist: $file_path"
    exit 1
  fi

  if [[ ! -r "$file_path" ]]; then
    log "Error: File is not readable: $file_path"
    exit 1
  fi

  # --- Dependency Checks ---
  # Check for required command-line tools.
  local dependencies=("jq" "curl")
  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" > /dev/null; then
      log "Error: Required command '$cmd' is not installed."
      exit 1
    fi
  done
  
  debug_log "All dependencies verified."

  # --- Main Logic ---
  # Orchestrate calls to other functions from here.
  info "Script execution started."
  debug_log "Verbose mode is enabled."
  debug_log "File path provided: $file_path"

  # Safely get the current user name.
  local current_user="${LOGNAME:-${USER:-unknown}}"
  debug_log "Script is being run by user: $current_user"

  success "Script execution finished successfully."
}

# --- Script Entry Point ---
#
# Call the main function with all the script's arguments.
# This makes the script's execution flow explicit and allows functions to be
# defined anywhere in the file.
main "$@"
