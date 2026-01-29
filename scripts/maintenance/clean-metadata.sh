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
#   Use --clean to only remove metadata without optimization, or
#   --optimize to only optimize without removing metadata.
#
# USAGE:
#   cleanmetadata [OPTIONS] <file|directory> [...]
#
# OPTIONS:
#   --help, -h        Display this help message and exit
#   --replace         Replace original files instead of creating copies (use with caution)
#   --verbose         Display metadata before cleaning for verification purposes
#   --clean           Only remove metadata without optimizing (default: both clean and optimize)
#   --optimize        Only optimize without removing metadata (default: both clean and optimize)
#
# EXAMPLES:
#   # Process a single file (clean and optimize)
#   cleanmetadata document.pdf
#
#   # Process an entire directory recursively
#   cleanmetadata ~/Documents/
#
#   # Only remove metadata without optimization
#   cleanmetadata --clean document.pdf
#
#   # Only optimize without removing metadata
#   cleanmetadata --optimize image.jpg
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
#   - Files with "cleaned", "cleaned_opt", or "optimized" in their names are automatically skipped
#   - Symbolic links are not processed for security reasons
#   - All temporary files are created in a secure temporary directory that is
#     automatically cleaned up on script exit
#   - The script validates output paths to prevent directory traversal attacks
#   - When optimization fails or results in larger files, the cleaned (non-optimized)
#     version is used instead
#   - Output suffixes: "_cleaned_opt" (default), "_cleaned" (--clean), "_optimized" (--optimize)
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
  local clean_only=0       # Flag: 1=only clean metadata, 0=optimize too
  local optimize_only=0    # Flag: 1=only optimize, 0=clean too
  local paths=()           # Array to store file/directory paths
  
  # Process command-line arguments using a while loop and case statement
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        cat << 'EOF'
Usage: cleanmetadata [OPTIONS] <file|directory> [...]

Remove metadata and optimize PDF, PNG, and JPEG files.

Options:
  --help, -h        Show this help message
  --replace         Replace original files instead of creating copies (use with caution)
  --verbose         Show metadata before cleaning
  --clean           Only remove metadata without optimization
  --optimize        Only optimize without removing metadata

Examples:
  cleanmetadata document.pdf
  cleanmetadata ~/Documents/
  cleanmetadata --clean document.pdf
  cleanmetadata --optimize image.jpg
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
      --clean)
        clean_only=1
        shift
        ;;
      --optimize)
        optimize_only=1
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

  # Validate that --clean and --optimize are not used together
  if [[ "$clean_only" == "1" && "$optimize_only" == "1" ]]; then
    error "Error: --clean and --optimize cannot be used together."
    error "Choose one or neither to perform both operations."
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
      done < <(find "$target" -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -iname '*cleaned*' ! -iname '*cleaned_opt*' ! -iname '*optimized*' -print0)
      
      print_operation_end "Found $file_count supported files"
      echo
      
      # Use process substitution to preserve parent scope for error_count
      # Find command with -print0 handles filenames with spaces/newlines safely
      # The regex pattern excludes already processed files to prevent duplication
      while IFS= read -r -d '' file; do
        if ! cleanmetadata_file "$file" "$replace_original" "$verbose" "$clean_only" "$optimize_only"; then
          error_count=$((error_count + 1))
          error "An error occurred while processing $file"
        fi
      done < <(find "$target" -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -iname '*cleaned*' ! -iname '*cleaned_opt*' ! -iname '*optimized*' -print0)
    elif [ -f "$target" ]; then
      # Check if file has already been processed by examining its name
      case "$target" in
        *cleaned*|*cleaned_opt*|*optimized*)
          warning "Ignoring already processed file: $target"
          ;;
        *)
          # Process the file and track any errors
          if ! cleanmetadata_file "$target" "$replace_original" "$verbose" "$clean_only" "$optimize_only"; then
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
# cleanmetadata_file - Processes a single file to remove metadata and/or optimize it
#
# DESCRIPTION:
#   Takes a single file, validates it, removes all metadata (unless --optimize),
#   applies format-specific optimization (unless --clean), and either creates
#   a new file or replaces the original. Implements multiple security checks to prevent
#   path traversal and ensure safe file handling.
#
# PARAMETERS:
#   $1 - File path to process
#   $2 - Replace flag (1=replace original, 0=create copy)
#   $3 - Verbose flag (1=show metadata, 0=quiet operation)
#   $4 - Clean only flag (1=only clean metadata, 0=optimize too)
#   $5 - Optimize only flag (1=only optimize, 0=clean too)
#
# RETURNS:
#   0 - Success (file processed successfully)
#   1 - Error (invalid file, processing failure, etc.)
#
cleanmetadata_file() {
  local f="$1"           # Input file path
  local resolved         # Canonical (absolute) path
  
  # Security: Symlink check
  if [ -L "$f" ]; then
      warning "Symbolic links are not supported: $f"
      return 1
  fi
  
  if [ ! -f "$f" ]; then
      warning "Not a regular file: $f"
      return 1
  fi
  
  # Security: Path traversal protection
  resolved=$(readlink -e "$f") || {
      error "Cannot resolve path: $f"
      return 1
  }
  f="$resolved"
  
  local replace_original="$2"
  local verbose="$3"
  local clean_only="$4"
  local optimize_only="$5"

  local basename_f
  basename_f=$(basename "$f")
  
  # Robust extension extraction
  local ext="${basename_f##*.}"
  local base="${basename_f%.*}"
  
  # Check if file had no extension
  if [[ "$basename_f" == "$base" ]]; then
       warning "File has no extension: $f"
       return 1
  fi
  
  case "${ext,,}" in
      pdf|png|jpg|jpeg) ;;
      *)
          warning "Unsupported file type: $f (extension: $ext)"
          return 1
          ;;
  esac

  # Sanitize filename for temp files
  local safe_base="${base//\//_}"
  safe_base="${safe_base//../_}"
  
  local tmp_cleaned="$TMP_DIR/${safe_base}_cleaned.tmp"
  local tmp_optimized="$TMP_DIR/${safe_base}_optimized.tmp"
  
  # Define final paths
  local final_dir
  final_dir=$(dirname "$f")
  # No need to readlink final_dir again as we derived it from resolved path $f
  
  local final_path
  if [[ "$replace_original" == "1" ]]; then
      final_path="$f"
  else
      # Determine output suffix based on mode
      local output_suffix
      if [[ "$clean_only" == "1" ]]; then
          output_suffix="cleaned"
      elif [[ "$optimize_only" == "1" ]]; then
          output_suffix="optimized"
      else
          output_suffix="cleaned_opt"
      fi
      final_path="$final_dir/${base}_${output_suffix}.${ext}"
  fi

  # Display status
  print_section_header "FILE PROCESSING" "${METADATA_ICON}"
  print_subheader "Processing: $f"

  if [[ "$verbose" == "1" ]]; then
    echo -e "${BOLD}${BLUE}Found metadata:${RESET}"
    exiftool -G1 "$f" 2>/dev/null | grep -E "(Author|Title|Creator|Create Date|Modify Date|Subject|Keywords|Producer|Comment)" || echo "   (no significant metadata found)"
    echo
  fi

  local source_to_move=""  # Will hold the final file to move

  # Step 1: Remove metadata (skip if --optimize)
  if [[ "$optimize_only" != "1" ]]; then
    print_operation_start "Removing all metadata"
    if ! exiftool -all= -P -o "$tmp_cleaned" "$f" >/dev/null 2>&1; then
      error "Failed to clean metadata."
      return 1
    fi
    print_operation_end "Metadata removal completed"

    if [ ! -s "$tmp_cleaned" ]; then
      error "Cleaned file is empty."
      return 1
    fi
  fi

  # Step 2: Optimize (skip if --clean)
  if [[ "$clean_only" != "1" ]]; then
    # Determine input file for optimization
    local optimize_input
    if [[ "$optimize_only" == "1" ]]; then
        optimize_input="$f"  # Use original file
        print_operation_start "Optimizing ${ext^^} file (without removing metadata)"
    else
        optimize_input="$tmp_cleaned"  # Use cleaned file
        print_operation_start "Optimizing ${ext^^} file"
    fi
    
    case "${ext,,}" in
      pdf)
        # Added -dSAFER for security
        if ! gs -sDEVICE="$GS_DEVICE" -dSAFER -dCompatibilityLevel=1.4 -dPDFSETTINGS="$PDF_SETTINGS" \
           -dFastWebView=true -dAutoRotatePages=/None -dNOPAUSE -dQUIET -dBATCH \
           -sOutputFile="$tmp_optimized" "$optimize_input" 2>/dev/null; then
           warning "PDF optimization failed."
           if [[ "$optimize_only" == "1" ]]; then
               cp "$optimize_input" "$tmp_optimized"
           else
               cp "$tmp_cleaned" "$tmp_optimized"
           fi
      elif ! gs -dNODISPLAY -dQUIET -dBATCH "$tmp_optimized" 2>/dev/null; then
            warning "Optimized PDF corrupted."
            if [[ "$optimize_only" == "1" ]]; then
                cp "$optimize_input" "$tmp_optimized"
            else
                cp "$tmp_cleaned" "$tmp_optimized"
            fi
      fi
      ;;
    png)
      if ! pngquant --quality="$PNG_QUALITY" --speed 1 --output "$tmp_optimized" --force "$optimize_input" 2>/dev/null; then
        warning "PNG optimization failed."
        if [[ "$optimize_only" == "1" ]]; then
            cp "$optimize_input" "$tmp_optimized"
        else
            cp "$tmp_cleaned" "$tmp_optimized"
        fi
      fi
      ;;
    jpg|jpeg)
      if ! jpegoptim --max="$JPEG_QUALITY" --strip-all --stdout "$optimize_input" > "$tmp_optimized" 2>/dev/null; then
        warning "JPEG optimization failed."
        if [[ "$optimize_only" == "1" ]]; then
            cp "$optimize_input" "$tmp_optimized"
        else
            cp "$tmp_cleaned" "$tmp_optimized"
        fi
      fi
      ;;
    esac
    print_operation_end "File optimization completed"

    if [ ! -s "$tmp_optimized" ]; then
        if [[ "$optimize_only" == "1" ]]; then
            cp "$optimize_input" "$tmp_optimized"
        else
            cp "$tmp_cleaned" "$tmp_optimized"
        fi
    fi

    # Compare sizes (only if we did optimization)
    if [[ "$optimize_only" == "1" ]]; then
        local size_orig
        size_orig=$(stat -c%s "$f")
        local size_opt
        size_opt=$(stat -c%s "$tmp_optimized")
        
        source_to_move="$tmp_optimized"
        if [ "$size_opt" -ge "$size_orig" ]; then
            source_to_move="$f"
        fi
    else
        local size_clean
        size_clean=$(stat -c%s "$tmp_cleaned")
        local size_opt
        size_opt=$(stat -c%s "$tmp_optimized")
        
        source_to_move="$tmp_optimized"
        if [ "$size_opt" -ge "$size_clean" ]; then
            source_to_move="$tmp_cleaned"
        fi
    fi
  else
    # --clean mode: use the cleaned file
    source_to_move="$tmp_cleaned"
  fi

  # Step 3: Finalize
  if [[ "$replace_original" == "1" ]]; then
    print_operation_start "Replacing original file"
    
    # Secure overwrite if shred is available
    if command -v shred &>/dev/null; then
        # Shred original before overwriting
        shred -u -n 1 "$f" 2>/dev/null || true
    fi
    
    # Move new file to original location
    if mv "$source_to_move" "$f"; then
        print_operation_end "Original file replaced"
    else
        error "Failed to replace original file!"
        return 1
    fi
  else
    print_operation_start "Creating cleaned file"
    # Ensure we don't overwrite an existing destination (unless it's the same file, logic handled above)
    if [[ -e "$final_path" ]]; then
       warning "File exists: $final_path. Skipping."
       return 1
    fi
    
    if mv "$source_to_move" "$final_path"; then
        print_operation_end "Cleaned file created"
    else
        error "Failed to create output file."
        return 1
    fi
  fi

  # Final Stats
  local size_orig
  size_orig=$(stat -c%s "$f")
  local size_final
  size_final=$(stat -c%s "$final_path")
  local diff=$((size_final - size_orig))
  local diff_abs=${diff#-}
  local sign="+"
  [ $diff -lt 0 ] && sign="-"

  local orig_h
  orig_h=$(numfmt --to=iec --suffix=B "$size_orig")
  local final_h
  final_h=$(numfmt --to=iec --suffix=B "$size_final")

  # Display operation mode in stats
  local mode_text=""
  if [[ "$clean_only" == "1" ]]; then
      mode_text=" (metadata cleaned only)"
  elif [[ "$optimize_only" == "1" ]]; then
      mode_text=" (optimized only)"
  fi

  printf "${BOLD}${GREEN}📊 Size: Before: %8s → After: %8s | Δ %s%s%s${RESET}\n" \
         "$orig_h" "$final_h" "$sign" "$(numfmt --to=iec --suffix=B $diff_abs)" "$mode_text"
  print_separator
}

# --- Script Entrypoint ---
# Call the main function with all script arguments passed to the script
# This allows the script to be used with command-line arguments directly
cleanmetadata "$@"