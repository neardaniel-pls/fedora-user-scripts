#!/bin/bash
#
# Cleans metadata and optimizes PDF, PNG, and JPEG files.
# Creates a copy with the suffix _cleaned_opt for each processed file.

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

# --- Configuration ---
readonly PNG_QUALITY="${PNG_QUALITY:-65-80}"
readonly JPEG_QUALITY="${JPEG_QUALITY:-80}"
readonly PDF_SETTINGS="${PDF_SETTINGS:-/ebook}"
readonly GS_DEVICE="${GS_DEVICE:-pdfwrite}"

# --- Dependency Check ---
for cmd in exiftool gs pngquant jpegoptim numfmt; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: Dependency '$cmd' is not installed." >&2
    exit 1
  fi
done

# --- Temporary Directory ---
# Create a secure temporary directory and ensure it's cleaned up on exit.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# --- Main Function ---
cleanmetadata() {
  # --- Option Parsing ---
  local replace_original=0
  local verbose=0
  local paths=()
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
        paths+=("$1")
        shift
        ;;
    esac
  done

  # Restore positional parameters
  set -- "${paths[@]}"

  if [ $# -eq 0 ]; then
    echo "Usage: cleanmetadata <file|directory> [...]" >&2
    echo "Try 'cleanmetadata --help' for more information." >&2
    return 1
  fi

  local error_count=0
  for target in "$@"; do
    # Skip if target is not a regular file or directory, or is a symlink
    if [ ! -f "$target" ] && [ ! -d "$target" ] || [ -L "$target" ]; then
        echo "⚠️  Skipping invalid or non-regular file/directory: $target" >&2
        continue
    fi

    if [ -d "$target" ]; then
      echo "📂 Processing directory: $target"
      # Use process substitution to preserve parent scope for error_count
      while IFS= read -r -d '' file; do
        if ! cleanmetadata_file "$file" "$replace_original" "$verbose"; then
          error_count=$((error_count + 1))
          echo "❌ An error occurred while processing $file" >&2
        fi
      done < <(find "$target" -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -iname '*cleaned*' ! -iname '*cleaned_opt*' -print0)
    elif [ -f "$target" ]; then
      case "$target" in
        *cleaned*|*cleaned_opt*)
          echo "⚠️ Ignoring already processed file: $target" >&2
          ;;
        *)
          if ! cleanmetadata_file "$target" "$replace_original" "$verbose"; then
            error_count=$((error_count + 1))
            echo "❌ An error occurred while processing $target" >&2
          fi
          ;;
      esac
    fi
  done

  if [ "$error_count" -gt 0 ]; then
      echo "❌ Operation completed with $error_count errors." >&2
      return 1
  else
      echo "✅ Operation completed successfully."
  fi
}

# --- File Processing Function ---
cleanmetadata_file() {
  local f="$1"
  local resolved
  
  # Explicitly check for symlink FIRST to avoid TOCTOU race condition
  if [ -L "$f" ]; then
      echo "⚠️  Symbolic links are not supported: $f" >&2
      return 1
  fi
  
  # Check if it's a regular file
  if [ ! -f "$f" ]; then
      echo "⚠️  Not a regular file: $f" >&2
      return 1
  fi
  
  # Get canonical path (resolves .., ., etc.) to prevent path traversal
  resolved=$(readlink -e "$f") || {
      echo "❌ Error: Cannot resolve path: $f" >&2
      return 1
  }
  
  # Use the resolved, absolute path from here on
  f="$resolved"
  local replace_original="$2"
  local verbose="$3"

  # Extract filename and extension safely using parameter expansion
  local basename_f
  basename_f=$(basename "$f")
  
  local base ext
  if [[ "$basename_f" == *.* ]]; then
      # Has extension: split on last dot
      ext="${basename_f##*.}"
      base="${basename_f%.*}"
  else
      # No extension
      echo "⚠️  File has no extension: $f" >&2
      return 1
  fi
  
  # Validate extension is supported
  case "${ext,,}" in
      pdf|png|jpg|jpeg)
          # Valid, continue
          ;;
      *)
          echo "⚠️  Unsupported file type: $f (extension: $ext)" >&2
          return 1
          ;;
  esac

  # Sanitize base name (remove dangerous characters)
  base="${base//\//_}"  # Replace / with _
  base="${base//../_}"   # Replace .. with _
  
  local tmp_cleaned="$TMP_DIR/${base}_cleaned.tmp"
  local tmp_optimized="$TMP_DIR/${base}_optimized.tmp"
  
  # Get directory and ensure it's canonical
  local final_dir
  final_dir=$(dirname "$f")
  final_dir=$(readlink -f "$final_dir")
  
  local final="$final_dir/${base}_cleaned_opt.${ext}"
  
  # Verify final path is within the expected directory
  local final_canonical
  final_canonical=$(dirname "$final")
  final_canonical=$(readlink -f "$final_canonical")
  
  if [[ "$final_canonical" != "$final_dir" ]]; then
      echo "❌ Error: Refusing to write outside source directory." >&2
      echo "    Expected: $final_dir" >&2
      echo "    Got: $final_canonical" >&2
      return 1
  fi


  echo "────────────────────────────────────────────"
  echo "📋 Processing: $f"

  # Show essential metadata if verbose
  if [[ "$verbose" == "1" ]]; then
    echo "Found metadata:"
    exiftool -G1 "$f" 2>/dev/null | grep -E "(Author|Title|Creator|Create Date|Modify Date|Subject|Keywords|Producer|Comment)" || echo "   (no significant metadata found)"
  fi

  echo "🧹 Cleaning all metadata..."
  if ! exiftool -all= -P -o "$tmp_cleaned" "$f"; then
    echo "❌ Error: Failed to clean metadata. Aborting." >&2
    return 1
  fi

  if [ ! -s "$tmp_cleaned" ]; then
    echo "❌ Error: The cleaned file is empty or was not created. Aborting." >&2
    return 1
  fi

  local tamanho_limpo
  tamanho_limpo=$(stat -c%s "$tmp_cleaned")

  # Optimization logic
  case "${ext,,}" in
    pdf)
      echo "📰 Optimizing PDF..."
      # Redirect stderr to /dev/null to suppress all non-error Ghostscript logs
      if ! gs -sDEVICE="$GS_DEVICE" -dCompatibilityLevel=1.4 -dPDFSETTINGS="$PDF_SETTINGS" \
         -dFastWebView=true -dAutoRotatePages=/None -dNOPAUSE -dQUIET -dBATCH \
         -sOutputFile="$tmp_optimized" "$tmp_cleaned" 2>/dev/null; then
         echo "⚠️ PDF optimization failed. Using cleaned file instead." >&2
         cp "$tmp_cleaned" "$tmp_optimized"
      else
        # Validate the optimized PDF is readable
        if ! gs -dNODISPLAY -dQUIET -dBATCH "$tmp_optimized" 2>/dev/null; then
            echo "⚠️ Optimized PDF appears corrupted. Using cleaned file instead." >&2
            cp "$tmp_cleaned" "$tmp_optimized"
        fi
      fi
      ;;
    png)
      echo "🌆 Optimizing PNG..."
      if ! pngquant --quality="$PNG_QUALITY" --speed 1 --output "$tmp_optimized" --force "$tmp_cleaned"; then
        echo "⚠️ PNG optimization failed. Using cleaned file instead." >&2
        cp "$tmp_cleaned" "$tmp_optimized"
      fi
      ;;
    jpg|jpeg)
      echo "📸 Optimizing JPEG..."
      if ! jpegoptim --max="$JPEG_QUALITY" --strip-all --stdout "$tmp_cleaned" > "$tmp_optimized"; then
        echo "⚠️ JPEG optimization failed. Using cleaned file instead." >&2
        cp "$tmp_cleaned" "$tmp_optimized"
      fi
      ;;
    *)
      echo "🔸 Format not supported for optimization: $f"
      cp "$tmp_cleaned" "$tmp_optimized"
      ;;
  esac

  if [ ! -s "$tmp_optimized" ]; then
      echo "❌ Error: Optimized file is empty. Using cleaned file instead." >&2
      cp "$tmp_cleaned" "$tmp_optimized"
  fi

  local tamanho_opt
  tamanho_opt=$(stat -c%s "$tmp_optimized")

  local source_file_for_final
  if [ "$tamanho_opt" -ge "$tamanho_limpo" ]; then
    echo "⚠️ Optimized file is not smaller, using cleaned file."
    source_file_for_final="$tmp_cleaned"
  else
    source_file_for_final="$tmp_optimized"
  fi

  if [[ "$replace_original" == "1" ]]; then
    echo "🔄 Replacing original file..."
    # Use -n to avoid overwriting other files if the original name is reused
    if ! mv -n "$source_file_for_final" "$f"; then
        echo "❌ Error replacing original file. A file with the original name may already exist." >&2
        return 1
    fi
    # Securely delete the original file if shred is available
    if command -v shred &>/dev/null; then
        shred -ufz -n 1 "$f" 2>/dev/null || true # ignore shred errors
    fi
    mv "$f" "$final" # Rename to final name
  else
    if ! mv -n "$source_file_for_final" "$final"; then
        echo "⚠️  Output file already exists or could not be moved: $final" >&2
        return 1
    fi
  fi

  echo "✓ Metadata removed:"
  exiftool -G1 "$final" 2>/dev/null | grep -E "(Author|Title|Creator|Create Date|Modify Date|Subject|Keywords|Producer|Comment)" || echo "   (clean)"

  local antes
  antes=$(stat -c%s "$f")
  local depois
  depois=$(stat -c%s "$final")
  local diff=$((depois - antes))
  local diff_abs=${diff#-}
  local sinal="+"
  [ $diff -lt 0 ] && sinal="-"

  local antes_h
  antes_h=$(numfmt --to=iec --suffix=B "$antes")
  local depois_h
  depois_h=$(numfmt --to=iec --suffix=B "$depois")

  printf "📊 Size: Before: %8s → After: %8s | Δ %s%s\n" \
         "$antes_h" "$depois_h" "$sinal" "$(numfmt --to=iec --suffix=B $diff_abs)"
  echo "────────────────────────────────────────────"
}

# --- Script Entrypoint ---
# Call the main function with all script arguments
cleanmetadata "$@"