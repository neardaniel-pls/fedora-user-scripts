#!/bin/bash
#
# common.sh - Shared utility functions for user-scripts
#
# DESCRIPTION:
#   This library provides common utility functions used across multiple scripts
#   including dependency checking, argument parsing, temporary file handling,
#   and other frequently used operations. It promotes code reuse and
#   consistency across the entire user-scripts collection.
#
# USAGE:
#   Source this library at the beginning of your script:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#
# ENVIRONMENT VARIABLES:
#   SCRIPT_VERSION: Optional version string for version display
#

# --- Script Initialization ---
#
# init_script - Initialize common script environment
#
# DESCRIPTION:
#   Sets up common script environment including strict mode, error handling,
#   and cleanup traps. Should be called at the beginning of each script.
#
# PARAMETERS:
#   $1 - Optional script version (default: "unknown")
#
init_script() {
    local version="${1:-unknown}"
    
    # Exit immediately if a command exits with a non-zero status
    set -e
    # Treat unset variables as an error when substituting
    set -u
    # Pipes return the exit status of the last command to exit with a non-zero status
    set -o pipefail
    
    # Set IFS to prevent word splitting issues
    IFS=$'\n\t'
    
    # Get script information
    readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[1]}")"
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    
    # Set version if provided
    if [[ "$version" != "unknown" ]]; then
        readonly SCRIPT_VERSION="$version"
    fi
}

# --- Dependency Checking ---
#
# check_dependencies - Verify required commands are available
#
# DESCRIPTION:
#   Checks if all required commands are available on the system.
#   Provides clear error messages about missing dependencies.
#
# PARAMETERS:
#   $@ - List of required commands
#
# RETURNS:
#   0 - All dependencies found
#   1 - One or more dependencies missing
#
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

# --- Argument Parsing ---
#
# parse_common_args - Parse common command-line arguments
#
# DESCRIPTION:
#   Parses common arguments like --help, --version, and --verbose.
#   Sets global variables: VERBOSE_MODE, SHOW_HELP, SHOW_VERSION
#
# PARAMETERS:
#   $@ - All script arguments
#
parse_common_args() {
    VERBOSE_MODE=0
    SHOW_HELP=0
    SHOW_VERSION=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                SHOW_HELP=1
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=1
                shift
                ;;
            --version)
                SHOW_VERSION=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

# --- Temporary File Management ---
#
# create_temp_dir - Create secure temporary directory
#
# DESCRIPTION:
#   Creates a secure temporary directory with restricted permissions.
#   Automatically sets up cleanup trap to remove directory on exit.
#
# PARAMETERS:
#   $1 - Optional prefix for temp directory (default: "script")
#
# RETURNS:
#   Path to created temporary directory
#
create_temp_dir() {
    local prefix="${1:-script}"
    
    # Create temporary directory with restricted permissions
    TEMP_DIR=$(mktemp -d -t "${prefix}.XXXXXX") || {
        error "Failed to create temporary directory."
        exit 1
    }
    
    # Set secure permissions
    chmod 700 "$TEMP_DIR" || {
        error "Failed to set permissions on temporary directory."
        exit 1
    }
    
    # Set up cleanup trap
    trap 'rm -rf "$TEMP_DIR" 2>/dev/null || true' EXIT
    
    # Export for use in calling script
    export TEMP_DIR
    
    return 0
}

#
# create_temp_file - Create secure temporary file
#
# DESCRIPTION:
#   Creates a secure temporary file with restricted permissions.
#   Automatically sets up cleanup trap to remove file on exit.
#
# PARAMETERS:
#   $1 - Optional prefix for temp file (default: "script")
#   $2 - Optional suffix for temp file (default: "tmp")
#
# RETURNS:
#   Path to created temporary file
#
create_temp_file() {
    local prefix="${1:-script}"
    local suffix="${2:-tmp}"
    local temp_file
    
    # Create temporary file
    temp_file=$(mktemp -t "${prefix}.XXXXXX.${suffix}") || {
        error "Failed to create temporary file."
        exit 1
    }
    
    # Set secure permissions
    chmod 600 "$temp_file" || {
        error "Failed to set permissions on temporary file."
        exit 1
    }
    
    # Set up cleanup trap
    trap 'rm -f "$temp_file" 2>/dev/null || true' EXIT
    
    # Export for use in calling script
    export TEMP_FILE="$temp_file"
    
    return 0
}

# --- Error Handling ---
#
# die - Exit with error message
#
# DESCRIPTION:
#   Displays an error message and exits with status 1.
#   Provides a consistent way to handle fatal errors.
#
# PARAMETERS:
#   $1 - Error message to display
#
die() {
    error "$1"
    exit 1
}

#
# confirm_action - Get user confirmation for actions
#
# DESCRIPTION:
#   Prompts user for y/n confirmation with optional timeout.
#   Returns 0 for yes, 1 for no.
#
# PARAMETERS:
#   $1 - Prompt message
#   $2 - Optional timeout in seconds (default: 30)
#
# RETURNS:
#   0 - User confirmed (yes)
#   1 - User declined or timeout
#
confirm_action() {
    local prompt="$1"
    local timeout="${2:-30}"
    local response
    
    read -r -t "$timeout" -p "$prompt [y/N]: " response || return 1
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# --- Version Management ---
#
# show_version - Display script version information
#
# DESCRIPTION:
#   Displays standardized version information for scripts.
#   Uses SCRIPT_VERSION if set, otherwise shows "unknown".
#
show_version() {
    local version="${SCRIPT_VERSION:-unknown}"
    echo "$SCRIPT_NAME version $version"
}

# --- System Utilities ---
#
# require_root - Check if script is running as root
#
# DESCRIPTION:
#   Checks if the script is running with root privileges.
#   Exits with error if not running as root.
#
require_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root. Please use sudo."
        exit 1
    fi
}

#
# get_os_info - Detect operating system information
#
# DESCRIPTION:
#   Detects the operating system and version.
#   Sets global variables: OS_NAME, OS_VERSION
#
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        # Linux systems with /etc/os-release
        . /etc/os-release
        OS_NAME="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-unknown}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS systems
        OS_NAME="macos"
        OS_VERSION="$(sw_vers -productVersion)"
    elif [[ "$OSTYPE" == "msys"* ]]; then
        # Git Bash on Windows
        OS_NAME="windows"
        OS_VERSION="unknown"
    else
        # Fallback
        OS_NAME="${OSTYPE:-unknown}"
        OS_VERSION="unknown"
    fi
    
    readonly OS_NAME
    readonly OS_VERSION
}

# --- File Utilities ---
#
# validate_file - Validate file exists and is readable
#
# DESCRIPTION:
#   Checks if a file exists and is readable.
#   Provides consistent error messages.
#
# PARAMETERS:
#   $1 - File path to validate
#   $2 - Optional description (default: "file")
#
# RETURNS:
#   0 - File is valid
#   1 - File is invalid
#
validate_file() {
    local file_path="$1"
    local description="${2:-file}"
    
    if [[ ! -e "$file_path" ]]; then
        error "$description does not exist: $file_path"
        return 1
    fi
    
    if [[ ! -r "$file_path" ]]; then
        error "$description is not readable: $file_path"
        return 1
    fi
    
    return 0
}

#
# validate_dir - Validate directory exists and is accessible
#
# DESCRIPTION:
#   Checks if a directory exists and is accessible.
#   Provides consistent error messages.
#
# PARAMETERS:
#   $1 - Directory path to validate
#   $2 - Optional description (default: "directory")
#
# RETURNS:
#   0 - Directory is valid
#   1 - Directory is invalid
#
validate_dir() {
    local dir_path="$1"
    local description="${2:-directory}"
    
    if [[ ! -d "$dir_path" ]]; then
        error "$description does not exist: $dir_path"
        return 1
    fi
    
    if [[ ! -r "$dir_path" ]]; then
        error "$description is not accessible: $dir_path"
        return 1
    fi
    
    return 0
}