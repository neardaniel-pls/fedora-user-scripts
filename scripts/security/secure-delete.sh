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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLI_ARG1="${1:-}"
source "${SCRIPT_DIR}/../lib/ui.sh"

if (( USE_ICONS && COLORS_ENABLED )); then
    readonly DELETE_ICON="🗑️"
else
    readonly DELETE_ICON=""
fi

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.3.4"
version_check "$SCRIPT_VERSION"

# ===== Dependency Check =====
# Verify that the required 'shred' command is available on the system
if ! command -v shred &> /dev/null; then
    error "The 'shred' command is not installed. Please install it to use this script."
    exit 1
fi

# ===== Usage Validation =====
# Ensure at least one target file or directory was provided
print_section_header "TARGET VALIDATION" "${FILE_ICON}"
print_operation_start "Validating command-line arguments"

if [ $# -eq 0 ]; then
    error "Usage: secure-delete.sh <file|directory> [...]"
    exit 1
fi

success "Found $# target(s) to process"
print_operation_end "Target validation completed"
print_separator

# ===== Main Processing Loop =====
# Iterate through each target provided as a command-line argument
print_section_header "SECURE DELETION PROCESS" "${DELETE_ICON}"
processed_count=0
skipped_count=0

for target in "$@"; do
    # Check if the target exists (file, directory, or other)
    if [ ! -e "$target" ]; then
        warning "'$target' not found. Skipping."
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # Handle directory targets
    if [ -d "$target" ]; then
        print_operation_start "Processing directory: $target"
        # Find all files in the directory and shred them recursively
        # shred options:
        #   -n 3: Perform 3 overwrite passes with random data
        #   -z:   Final pass with zeros to hide shredding
        #   -v:   Verbose output to show progress
        print_command_output
        shred_errors=0
        while IFS= read -r -d '' file; do
            if ! shred -n 3 -z -v "$file"; then
                error "Failed to shred: $file"
                shred_errors=$((shred_errors + 1))
            fi
        done < <(find "$target" -type f -print0)
        if [ "$shred_errors" -gt 0 ]; then
            error "$shred_errors file(s) could not be shredded. Aborting to prevent insecure deletion."
            exit 1
        fi
        rm -rf "$target"
        success "Directory '$target' securely deleted."
        processed_count=$((processed_count + 1))
    # Handle regular file targets
    elif [ -f "$target" ]; then
        print_operation_start "Processing file: $target"
        # Shred the file with the same security parameters
        print_command_output
        shred -n 3 -z -v "$target"
        # Remove the shredded file
        rm "$target"
        success "File '$target' securely deleted."
        processed_count=$((processed_count + 1))
    fi
done

print_operation_end "Secure deletion process completed"
print_separator

# ===== Completion Summary =====
print_header "DELETION SUMMARY"
echo -e "${BOLD}${GREEN}Processed: ${processed_count} target(s)${RESET}"
if [ "$skipped_count" -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}Skipped: ${skipped_count} target(s)${RESET}"
fi
print_separator
echo
success "Secure delete operation completed successfully!"