#!/bin/bash

# Function to clean metadata and optimize PDF, PNG, and JPEG files
# Creates a copy with the suffix _cleaned_opt for each processed file

# Verificar dependências
for cmd in exiftool gs pngquant jpegoptim numfmt; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: Dependency '$cmd' is not installed." >&2
    exit 1
  fi
done

cleanmetadata() {
  if [ $# -eq 0 ]; then
    echo "Usage: cleanmetadata <file|directory> [...]"
    return 1
  fi

  for alvo in "$@"; do
    if [ -d "$alvo" ]; then
      echo "📂 Processing directory: $alvo"
      find "$alvo" -type f \( -iname '*.pdf' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -iname '*cleaned*' ! -iname '*cleaned_opt*' \
        | while IFS= read -r ficheiro; do
          cleanmetadata_file "$ficheiro"
        done
    elif [ -f "$alvo" ]; then
      case "$alvo" in
        *cleaned*|*cleaned_opt*)
          echo "⚠️ Ignoring already processed file: $alvo"
          ;;
        *)
          cleanmetadata_file "$alvo"
          ;;
      esac
    else
      echo "⚠️  Not found: $alvo"
    fi
  done

  echo "✅ Operation completed."
}

cleanmetadata_file() {
  local f="$1"
  local base="${f%.*}"
  local ext="${f##*.}"
  local tmp_cleaned="${base}_cleaned_${$}_${RANDOM}.${ext}"
  local tmp_optimized="${base}_opt_tmp_${$}_${RANDOM}.${ext}"
  local final="${base}_cleaned_opt.${ext}"

  echo "────────────────────────────────────────────"
  echo "📋 Processing: $f"
  
  # Show only essential metadata (not file system info)
  exiftool -G1 "$f" 2>/dev/null | grep -E "(Author|Title|Creator|Create Date|Modify Date|Subject|Keywords|Producer|Comment)" || echo "   (no significant metadata found)"

  echo "🧹 Cleaning all metadata..."
  exiftool -all= -P -o "$tmp_cleaned" "$f" 2>/dev/null || {
    echo "❌ Error: Failed to clean metadata. Aborting."
    return 1
  }

  if [ ! -f "$tmp_cleaned" ]; then
    echo "❌ Error: The cleaned file $tmp_cleaned was not created. Aborting."
    return 1
  fi

  local tamanho_limpo=$(stat -c%s "$tmp_cleaned")

  case "${ext,,}" in
    pdf)
      echo "📰 Optimizing PDF..."
      gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook \
         -dFastWebView=true -dAutoRotatePages=/None -dNOPAUSE -dQUIET -dBATCH \
         -sOutputFile="$tmp_optimized" "$tmp_cleaned" 2>/dev/null
      ;;
    png)
      echo "🌆 Optimizing PNG..."
      pngquant --quality=65-80 --speed 1 --output "$tmp_optimized" --force "$tmp_cleaned" 2>/dev/null
      ;;
    jpg|jpeg)
      echo "📸 Optimizing JPEG..."
      jpegoptim --max=80 --strip-all --stdout "$tmp_cleaned" > "$tmp_optimized" 2>/dev/null
      ;;
    *)
      echo "🔸 Format not supported for optimization: $f"
      mv "$tmp_cleaned" "$tmp_optimized"
      ;;
  esac

  local tamanho_opt=$(stat -c%s "$tmp_optimized" 2>/dev/null || echo 0)

  if [ "$tamanho_opt" -gt "$tamanho_limpo" ]; then
    echo "⚠️ Optimized file is larger than cleaned file, skipping optimization."
    mv "$tmp_cleaned" "$final"
    rm -f "$tmp_optimized"
  else
    mv "$tmp_optimized" "$final"
    rm -f "$tmp_cleaned"
  fi

  # Show only essential metadata (not file system info)
  echo "✓ Metadata removed:"
  exiftool -G1 "$final" 2>/dev/null | grep -E "(Author|Title|Creator|Create Date|Modify Date|Subject|Keywords|Producer|Comment)" || echo "   (clean)"

  local antes=$(stat -c%s "$f")
  local depois=$(stat -c%s "$final")
  local diff=$((depois - antes))
  local diff_abs=${diff#-}
  local sinal="+"
  [ $diff -lt 0 ] && sinal="-"

  local antes_h=$(numfmt --to=iec --suffix=B "$antes")
  local depois_h=$(numfmt --to=iec --suffix=B "$depois")

  printf "📊 Size: Before: %8s → After: %8s | Δ %s%6s\n" \
         "$antes_h" "$depois_h" "$sinal" "$diff_abs"
  echo "────────────────────────────────────────────"
}

# Call the main function with all arguments
cleanmetadata "$@"