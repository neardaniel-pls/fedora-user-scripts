#!/bin/bash
#
# clean-metadata.sh - Privacy-focused metadata removal and file optimization utility
#
# DESCRIPTION:
#   This script removes all metadata from PDF, PNG, and JPEG files and applies
#   optimization to reduce file size while maintaining acceptable quality.
#   It creates processed copies with the suffix "_cleaned_opt" by default,
#   preserving the original files. The script is designed with security in mind,
#   implementing proper path validation, temporary file handling, and error
#   checking to prevent data loss or security issues.
#
# USAGE:
#   cleanmetadata [OPTIONS] <file|directory> [...]
#
# OPTIONS:
#   --help, -h     Display this help message and exit
#   --replace      Replace original files instead of creating copies (use with caution)
#   --verbose      Display metadata before cleaning for verification purposes
#
# EXAMPLES:
#   # Process a single file
#   cleanmetadata document.pdf
#
#   # Process an entire directory recursively
#   cleanmetadata ~/Documents/
#
#   # Replace original files (destructive operation)
#   cleanmetadata --replace sensitive.pdf
#
#   # Show metadata before cleaning
#   cleanmetadata --verbose image.jpg
#
#   # Process multiple files and directories
#   cleanmetadata file1.pdf directory/ file2.jpg
#
# DEPENDENCIES:
#   - exiftool: For reading and removing metadata from files
#   - gs (Ghostscript): For PDF optimization and validation
#   - pngquant: For PNG compression and optimization
#   - jpegoptim: For JPEG compression and optimization
#   - numfmt: For human-readable number formatting
#   - shred: Optional, for secure file deletion when using --replace
#
# OPERATIONAL NOTES:
#   - Files with "cleaned" or "cleaned_opt" in their names are automatically skipped
#   - Symbolic links are not processed for security reasons
#   - All temporary files are created in a secure temporary directory that is
#     automatically cleaned up on script exit
#   - The script validates output paths to prevent directory traversal attacks
#   - When optimization fails or results in larger files, the cleaned (non-optimized)
#     version is used instead
#   - Exit codes: 0 for success, 1 for errors
#
# For more detailed information, see clean-metadata-guide.md

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
    readonly CYAN="\033[36m"
    readonly MAGENTA="\033[35m"
    readonly RESET="\033[0m"
else
    # Set to empty strings when colors are disabled
    readonly BOLD=""
    readonly BLUE=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly RED=""
    readonly CYAN=""
    readonly MAGENTA=""
    readonly RESET=""
fi

# --- Icon Definitions ---
# Define icons only if icons are enabled AND colors are enabled
if (( USE_ICONS && COLORS_ENABLED )); then
    readonly INFO_ICON="ℹ️"
    readonly SUCCESS_ICON="✅"
    readonly WARNING_ICON="⚠️"
    readonly ERROR_ICON="❌"
    readonly SECTION_ICON="🔧"
    readonly START_ICON="🚀"
    readonly PACKAGE_ICON="📦"
    readonly CLEAN_ICON="🧹"
    readonly FILE_ICON="📄"
    readonly METADATA_ICON="🏷️"
else
    # Set to empty strings when icons or colors are disabled
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
    readonly SECTION_ICON=""
    readonly START_ICON=""
    readonly PACKAGE_ICON=""
    readonly CLEAN_ICON=""
    readonly FILE_ICON=""
    readonly METADATA_ICON=""
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
    echo -e "${BOLD}🔧 ${text}${RESET}"
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
}

print_section_header() {
    local text="$1"
    local icon="$2"
    echo
    echo -e "${BOLD}${MAGENTA}─────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}${MAGENTA}${icon} ${text}${RESET}"
    echo -e "${BOLD}${MAGENTA}─────────────────────────────────────────────────────────${RESET}"
    echo
}

print_separator() {
    echo -e "${BOLD}${CYAN}─────────────────────────────────────────────────────────${RESET}"
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

# --- Configuration ---
# Set quality and optimization parameters with environment variable overrides
# These values balance file size reduction with acceptable quality for most use cases
readonly PNG_QUALITY="${PNG_QUALITY:-65-80}"    # PNG quality range (min-max)
readonly JPEG_QUALITY="${JPEG_QUALITY:-80}"     # JPEG quality percentage
readonly PDF_SETTINGS="${PDF_SETTINGS:-/ebook}" # Ghostscript PDF preset for size optimization
readonly GS_DEVICE="${GS_DEVICE:-pdfwrite}"     # Ghostscript device for PDF output

# ===== Dependency Check =====
# Verify all required tools are available before proceeding
print_section_header "DEPENDENCY VERIFICATION" "${PACKAGE_ICON}"
print_operation_start "Checking required dependencies"
for cmd in exiftool gs pngquant jpegoptim numfmt; do
  if ! command -v "$cmd" &> /dev/null; then
    error "Dependency '$cmd' is not installed."
    exit 1
  fi
done
print_operation_end "Dependency verification completed"
success "All required dependencies are available"
print_separator

# --- Temporary Directory ---
# Create a secure temporary directory and ensure it's cleaned up on exit
# Using mktemp -d creates a directory with restricted permissions (700)
TMP_DIR=$(mktemp -d)
# Set up cleanup trap to remove temporary directory on script exit (normal or error)
trap 'rm -rf "$TMP_DIR"' EXIT

# Display script introduction with formatting
print_header "METADATA CLEANING AND OPTIMIZATION"
echo -e "${BOLD}${GREEN}${START_ICON} Starting privacy-focused metadata removal...${RESET}"
echo

# --- Main Function ---
#
# cleanmetadata - Main entry point for the metadata cleaning and optimization utility
#
# DESCRIPTION:
#   Parses command-line options, validates inputs, and orchestrates the processing
#   of files and directories. Handles error tracking and reporting for batch operations.
#
# PARAMETERS:
#   $@ - All command-line arguments (options and file/directory paths)
#
# RETURNS:
#   0 - Success (all files processed without errors)
#   1 - Error (invalid arguments, missing dependencies, or processing failures)
#
cleanmetadata() {
  # --- Option Parsing ---
  local replace_original=0  # Flag: 1=replace original, 0=create copy
  local verbose=0          # Flag: 1=show metadata, 0=quiet operation
  local paths=()           # Array to store file/directory paths
  
  # Process command-line arguments using a while loop and case statement
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        cat << 'EOF'
Usage: cleanmetadata [OPTIONS] <file|directory> [...]

Remove metadata and optimize PDF, PNG, and JPEG files.

Options:
  --help, -h     Show this help message
  --replace      Replace original files instead of creating copies (use with caution)
  --verbose      Show metadata before cleaning

Examples:
  cleanmetadata document.pdf
  cleanmetadata ~/Documents/
  cleanmetadata --replace sensitive.pdf

For more information, see clean-metadata-guide.md
EOF
        return 0
        ;;
      --replace)
        replace_original=1
        shift
        ;;
      --verbose)
        verbose=1
        shift
        ;;
      *)
        # Collect all non-option arguments as file/directory paths
        paths+=("$1")
        shift
        ;;
    esac
  done

  # Restore positional parameters with just the file/directory paths
  set -- "${paths[@]}"

  # Validate that at least one file or directory was provided
  if [ $# -eq 0 ]; then
    error "Usage: cleanmetadata <file|directory> [...]"
    error "Try 'cleanmetadata --help' for more information."
    return 1
  fi

  # Initialize error counter for batch operations
  local error_count=0
  
  # Process each target (file or directory) provided
  for target in "$@"; do
    # Skip if target is not a regular file or directory, or is a symlink
    # This prevents processing of special files and potential security issues
    if [ ! -f "$target" ] && [ ! -d "$target" ] || [ -L "$target" ]; then
        warning "Skipping invalid or non-regular file/directory: $target"
        continue
    fi

    if [ -d "$target" ]; then
      print_section_header "PROCESSING DIRECTORY" "${FILE_ICON}"
      info "Scanning directory: $target"
      print_operation_start "Finding supported files"
      
      # Count files for progress reporting
      local file_count=0
      while IFS= read -r -d '' file; do
        ((file_count++))
      done < <(find "$target" -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -iname '*cleaned*' ! -iname '*cleaned_opt*' -print0)
      
      print_operation_end "Found $file_count supported files"
      echo
      
      # Use process substitution to preserve parent scope for error_count
      # Find command with -print0 handles filenames with spaces/newlines safely
      # The regex pattern excludes already processed files to prevent duplication
      while IFS= read -r -d '' file; do
        if ! cleanmetadata_file "$file" "$replace_original" "$verbose"; then
          error_count=$((error_count + 1))
          error "An error occurred while processing $file"
        fi
      done < <(find "$target" -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -iname '*cleaned*' ! -iname '*cleaned_opt*' -print0)
    elif [ -f "$target" ]; then
      # Check if file has already been processed by examining its name
      case "$target" in
        *cleaned*|*cleaned_opt*)
          warning "Ignoring already processed file: $target"
          ;;
        *)
          # Process the file and track any errors
          if ! cleanmetadata_file "$target" "$replace_original" "$verbose"; then
            error_count=$((error_count + 1))
            error "An error occurred while processing $target"
          fi
          ;;
      esac
    fi
  done

  # Report final status based on error count
  print_header "PROCESSING SUMMARY"
  if [ "$error_count" -gt 0 ]; then
      error "Operation completed with $error_count errors."
      print_separator
      return 1
  else
      success "All files processed successfully!"
      print_separator
  fi
}

# --- File Processing Function ---
#
# cleanmetadata_file - Processes a single file to remove metadata and optimize it
#
# DESCRIPTION:
#   Takes a single file, validates it, removes all metadata, applies format-specific
#   optimization, and either creates a new file or replaces the original. Implements
#   multiple security checks to prevent path traversal and ensure safe file handling.
#
# PARAMETERS:
#   $1 - File path to process
#   $2 - Replace flag (1=replace original, 0=create copy)
#   $3 - Verbose flag (1=show metadata, 0=quiet operation)
#
# RETURNS:
#   0 - Success (file processed successfully)
#   1 - Error (invalid file, processing failure, etc.)
#
cleanmetadata_file() {
  local f="$1"           # Input file path
  local resolved         # Canonical (absolute) path to the file
  
  # Explicitly check for symlink FIRST to avoid TOCTOU (Time-of-Check-Time-of-Use) race condition
  # This prevents following symlinks which could lead to processing unintended files
  if [ -L "$f" ]; then
      warning "Symbolic links are not supported: $f"
      return 1
  fi
  
  # Verify the target is a regular file (not a directory, device file, etc.)
  if [ ! -f "$f" ]; then
      warning "Not a regular file: $f"
      return 1
  fi
  
  # Get canonical path (resolves .., ., symbolic links, etc.) to prevent path traversal attacks
  # This ensures we're working with the actual file location, not a relative path
  resolved=$(readlink -e "$f") || {
      error "Cannot resolve path: $f"
      return 1
  }
  
  # Use the resolved, absolute path from here on to prevent path manipulation
  f="$resolved"
  local replace_original="$2"  # Replace flag from main function
  local verbose="$3"           # Verbose flag from main function

  # Extract filename and extension safely using parameter expansion
  # This approach avoids issues with spaces and special characters in filenames
  local basename_f
  basename_f=$(basename "$f")
  
  local base ext  # Base name without extension, and file extension
  if [[ "$basename_f" == *.* ]]; then
      # Has extension: split on last dot using parameter expansion
      ext="${basename_f##*.}"  # Everything after the last dot
      base="${basename_f%.*}"   # Everything before the last dot
  else
      # No extension found - cannot determine file type
      warning "File has no extension: $f"
      return 1
  fi
  
  # Validate extension is supported by our processing tools
  # Using case-insensitive comparison with ${ext,,}
  case "${ext,,}" in
      pdf|png|jpg|jpeg)
          # Valid extension, continue processing
          ;;
      *)
          warning "Unsupported file type: $f (extension: $ext)"
          return 1
          ;;
  esac

  # Sanitize base name to prevent directory traversal in output filename
  # This removes potentially dangerous characters that could affect path handling
  base="${base//\//_}"  # Replace forward slashes with underscores
  base="${base//../_}"   # Replace relative path components with underscores
  
  # Define temporary file paths in our secure temporary directory
  local tmp_cleaned="$TMP_DIR/${base}_cleaned.tmp"      # After metadata removal
  local tmp_optimized="$TMP_DIR/${base}_optimized.tmp"   # After optimization
  
  # Get the directory of the input file and ensure it's canonical
  # This prevents issues with relative paths in directory references
  local final_dir
  final_dir=$(dirname "$f")
  final_dir=$(readlink -f "$final_dir")  # Resolve to absolute path
  
  # Define the final output path with the _cleaned_opt suffix
  local final="$final_dir/${base}_cleaned_opt.${ext}"
  
  # Security check: Verify final path is within the expected directory
  # This prevents directory traversal attacks through manipulated filenames
  local final_canonical
  final_canonical=$(dirname "$final")
  final_canonical=$(readlink -f "$final_canonical")
  
  if [[ "$final_canonical" != "$final_dir" ]]; then
      error "Refusing to write outside source directory."
      error "    Expected: $final_dir"
      error "    Got: $final_canonical"
      return 1
  fi

  # Display processing header for user feedback
  print_section_header "FILE PROCESSING" "${METADATA_ICON}"
  print_subheader "Processing: $f"

  # Show essential metadata if verbose mode is enabled
  if [[ "$verbose" == "1" ]]; then
    echo -e "${BOLD}${BLUE}Found metadata:${RESET}"
    # Filter for common metadata fields to avoid overwhelming output
    exiftool -G1 "$f" 2>/dev/null | grep -E "(Author|Title|Creator|Create Date|Modify Date|Subject|Keywords|Producer|Comment)" || echo "   (no significant metadata found)"
    echo
  fi

  # Step 1: Remove all metadata using exiftool
  print_operation_start "Removing all metadata"
  print_command_output
  if ! exiftool -all= -P -o "$tmp_cleaned" "$f"; then
    error "Failed to clean metadata. Aborting."
    return 1
  fi
  print_operation_end "Metadata removal completed"

  # Verify the cleaned file was created and is not empty
  if [ ! -s "$tmp_cleaned" ]; then
    error "The cleaned file is empty or was not created. Aborting."
    return 1
  fi

  # Get the size of the cleaned file for later comparison
  local tamanho_limpo
  tamanho_limpo=$(stat -c%s "$tmp_cleaned")

  # Step 2: Apply format-specific optimization
  print_operation_start "Optimizing ${ext^^} file"
  print_command_output
  
  case "${ext,,}" in
    pdf)
      if ! gs -sDEVICE="$GS_DEVICE" -dCompatibilityLevel=1.4 -dPDFSETTINGS="$PDF_SETTINGS" \
         -dFastWebView=true -dAutoRotatePages=/None -dNOPAUSE -dQUIET -dBATCH \
         -sOutputFile="$tmp_optimized" "$tmp_cleaned" 2>/dev/null; then
         warning "PDF optimization failed. Using cleaned file instead."
          cp "$tmp_cleaned" "$tmp_optimized"
      else
        # Validate the optimized PDF is readable by attempting to parse it
        if ! gs -dNODISPLAY -dQUIET -dBATCH "$tmp_optimized" 2>/dev/null; then
            warning "Optimized PDF appears corrupted. Using cleaned file instead."
            cp "$tmp_cleaned" "$tmp_optimized"
        fi
      fi
      ;;
    png)
      if ! pngquant --quality="$PNG_QUALITY" --speed 1 --output "$tmp_optimized" --force "$tmp_cleaned"; then
        warning "PNG optimization failed. Using cleaned file instead."
        cp "$tmp_cleaned" "$tmp_optimized"
      fi
      ;;
    jpg|jpeg)
      if ! jpegoptim --max="$JPEG_QUALITY" --strip-all --stdout "$tmp_cleaned" > "$tmp_optimized"; then
        warning "JPEG optimization failed. Using cleaned file instead."
        cp "$tmp_cleaned" "$tmp_optimized"
      fi
      ;;
    *)
      # This should never be reached due to earlier validation, but included for safety
      warning "Format not supported for optimization: $f"
      cp "$tmp_cleaned" "$tmp_optimized"
      ;;
  esac
  print_operation_end "File optimization completed"

  # Verify the optimized file was created and is not empty
  if [ ! -s "$tmp_optimized" ]; then
      error "Optimized file is empty. Using cleaned file instead."
      cp "$tmp_cleaned" "$tmp_optimized"
  fi

  # Get the size of the optimized file for comparison
  local tamanho_opt
  tamanho_opt=$(stat -c%s "$tmp_optimized")

  # Determine which file to use as the final output
  # Use the optimized version only if it's smaller than the cleaned version
  local source_file_for_final
  if [ "$tamanho_opt" -ge "$tamanho_limpo" ]; then
    warning "Optimized file is not smaller, using cleaned file."
    source_file_for_final="$tmp_cleaned"
  else
    source_file_for_final="$tmp_optimized"
  fi

  # Step 3: Handle file output based on replace flag
  if [[ "$replace_original" == "1" ]]; then
    print_operation_start "Replacing original file"
    # Use -n to avoid overwriting other files if the original name is reused
    if ! mv -n "$source_file_for_final" "$f"; then
        error "Error replacing original file. A file with the original name may already exist."
        return 1
    fi
    # Securely delete the original file if shred is available
    # This helps ensure data privacy when replacing files
    if command -v shred &>/dev/null; then
        shred -ufz -n 1 "$f" 2>/dev/null || true # ignore shred errors
    fi
    mv "$f" "$final" # Rename to final name with _cleaned_opt suffix
    print_operation_end "Original file replaced"
  else
    print_operation_start "Creating cleaned file"
    # Create a new file with the _cleaned_opt suffix
    if ! mv -n "$source_file_for_final" "$final"; then
        warning "Output file already exists or could not be moved: $final"
        return 1
    fi
    print_operation_end "Cleaned file created"
  fi

  # Verify metadata was successfully removed
  echo -e "${BOLD}${BLUE}Metadata verification:${RESET}"
  exiftool -G1 "$final" 2>/dev/null | grep -E "(Author|Title|Creator|Create Date|Modify Date|Subject|Keywords|Producer|Comment)" || echo "   (clean)"
  echo

  # Calculate and display file size change
  local antes
  antes=$(stat -c%s "$f")           # Original file size
  local depois
  depois=$(stat -c%s "$final")      # Final file size
  local diff=$((depois - antes))     # Size difference
  local diff_abs=${diff#-}           # Absolute value of difference
  local sinal="+"
  [ $diff -lt 0 ] && sinal="-"       # Use minus sign for size reduction

  # Format sizes in human-readable format (KB, MB, etc.)
  local antes_h
  antes_h=$(numfmt --to=iec --suffix=B "$antes")
  local depois_h
  depois_h=$(numfmt --to=iec --suffix=B "$depois")

  # Display size comparison
  printf "${BOLD}${GREEN}📊 Size: Before: %8s → After: %8s | Δ %s%s${RESET}\n" \
         "$antes_h" "$depois_h" "$sinal" "$(numfmt --to=iec --suffix=B $diff_abs)"
  print_separator
}

# --- Script Entrypoint ---
# Call the main function with all script arguments passed to the script
# This allows the script to be used with command-line arguments directly
cleanmetadata "$@"