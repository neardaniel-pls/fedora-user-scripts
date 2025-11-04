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

# ===== Dependency Check =====
# Verify that the required 'shred' command is available on the system
if ! command -v shred &> /dev/null; then
    echo "Error: The 'shred' command is not installed. Please install it to use this script." >&2
    exit 1
fi

# ===== Usage Validation =====
# Ensure at least one target file or directory was provided
if [ $# -eq 0 ]; then
    echo "Usage: secure-delete.sh <file|directory> [...]"
    exit 1
fi

# ===== Main Processing Loop =====
# Iterate through each target provided as a command-line argument
for target in "$@"; do
    # Check if the target exists (file, directory, or other)
    if [ ! -e "$target" ]; then
        echo "Warning: '$target' not found. Skipping."
        continue
    fi

    # Handle directory targets
    if [ -d "$target" ]; then
        echo "Processing directory: $target"
        # Find all files in the directory and shred them recursively
        # shred options:
        #   -n 3: Perform 3 overwrite passes with random data
        #   -z:   Final pass with zeros to hide shredding
        #   -v:   Verbose output to show progress
        find "$target" -type f -exec shred -n 3 -z -v {} \;
        # Remove the now-empty directory structure
        rm -rf "$target"
        echo "Directory '$target' securely deleted."
    # Handle regular file targets
    elif [ -f "$target" ]; then
        echo "Processing file: $target"
        # Shred the file with the same security parameters
        shred -n 3 -z -v "$target"
        # Remove the shredded file
        rm "$target"
        echo "File '$target' securely deleted."
    fi
done

# ===== Completion Message =====
echo "Secure delete operation completed."