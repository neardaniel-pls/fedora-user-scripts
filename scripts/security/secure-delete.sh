#!/bin/bash
#
# secure-delete.sh - Secure file and directory deletion utility
#
# DESCRIPTION:
#   This script securely deletes files or directories by overwriting them with
#   random data before removal. It uses the 'shred' command to perform multiple
#   passes of overwriting, making data recovery significantly more difficult.
#   The script can handle both individual files and entire directory structures.
#
# USAGE:
#   ./secure-delete.sh <file|directory> [...]
#
# OPTIONS:
#   file|directory - One or more files or directories to securely delete
#
# EXAMPLES:
#   # Securely delete a single file
#   ./secure-delete.sh sensitive-document.txt
#
#   # Securely delete multiple files
#   ./secure-delete.sh file1.txt file2.txt file3.txt
#
#   # Securely delete a directory and all its contents
#   ./secure-delete.sh confidential-directory/
#
#   # Mix of files and directories
#   ./secure-delete.sh secret.txt private-data/ notes.doc
#
# DEPENDENCIES:
#   - shred: Core utility for secure file overwriting (typically from coreutils package)
#   - find: For locating files within directories (standard Unix utility)
#   - rm: Standard file removal utility (standard Unix utility)
#
# OPERATIONAL NOTES:
#   - The script performs 3 passes of overwriting followed by a final zero-fill
#   - Directory structures are processed recursively, shredding all contained files
#   - The script provides verbose output showing the progress of each operation
#   - Non-existent targets are skipped with a warning rather than causing script failure
#   - Exit codes: 0 for success, 1 for missing dependencies or invalid usage
#
# SECURITY CONSIDERATIONS:
#   - This method makes data recovery significantly more difficult but may not be
#     sufficient against sophisticated forensic techniques or specialized hardware
#   - For SSDs with wear-leveling, traditional shredding may be less effective
#   - The script does not overwrite free space or handle filesystem journaling artifacts
#   - Consider physical destruction of storage media for maximum security requirements

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

# ===== Dependency Check =====
# Verify that the required 'shred' command is available on the system
if ! command -v shred &> /dev/null; then
    error "The 'shred' command is not installed. Please install it to use this script."
    exit 1
fi

# ===== Usage Validation =====
# Ensure at least one target file or directory was provided
if [ $# -eq 0 ]; then
    error "Usage: secure-delete.sh <file|directory> [...]"
    exit 1
fi

# ===== Main Processing Loop =====
# Iterate through each target provided as a command-line argument
for target in "$@"; do
    # Check if the target exists (file, directory, or other)
    if [ ! -e "$target" ]; then
        warning "'$target' not found. Skipping."
        continue
    fi

    # Handle directory targets
    if [ -d "$target" ]; then
        info "Processing directory: $target"
        # Find all files in the directory and shred them recursively
        # shred options:
        #   -n 3: Perform 3 overwrite passes with random data
        #   -z:   Final pass with zeros to hide shredding
        #   -v:   Verbose output to show progress
        find "$target" -type f -exec shred -n 3 -z -v {} \;
        # Remove the now-empty directory structure
        rm -rf "$target"
        success "Directory '$target' securely deleted."
    # Handle regular file targets
    elif [ -f "$target" ]; then
        info "Processing file: $target"
        # Shred the file with the same security parameters
        shred -n 3 -z -v "$target"
        # Remove the shredded file
        rm "$target"
        success "File '$target' securely deleted."
    fi
done

# ===== Completion Message =====
success "Secure delete operation completed."