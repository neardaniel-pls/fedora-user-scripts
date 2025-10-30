#!/bin/bash

# Securely delete files or directories by overwriting them with random data before deletion.

# Check for dependencies
if ! command -v shred &> /dev/null; then
    echo "Error: The 'shred' command is not installed. Please install it to use this script." >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: secure-delete.sh <file|directory> [...]"
    exit 1
fi

for target in "$@"; do
    if [ ! -e "$target" ]; then
        echo "Warning: '$target' not found. Skipping."
        continue
    fi

    if [ -d "$target" ]; then
        echo "Processing directory: $target"
        # Find all files in the directory and shred them
        find "$target" -type f -exec shred -n 3 -z -v {} \;
        # Remove the now-empty directory structure
        rm -rf "$target"
        echo "Directory '$target' securely deleted."
    elif [ -f "$target" ]; then
        echo "Processing file: $target"
        shred -n 3 -z -v "$target"
        rm "$target"
        echo "File '$target' securely deleted."
    fi
done

echo "Secure delete operation completed."