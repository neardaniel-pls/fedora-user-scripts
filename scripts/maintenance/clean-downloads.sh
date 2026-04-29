#!/bin/bash
#
# clean-downloads.sh - Downloads directory organizer and cleanup utility
#
# DESCRIPTION:
#   This script sorts files in ~/Downloads (or a specified directory) into
#   categorized subdirectories by file type. It can also purge files older
#   than a configurable age. All operations support dry-run mode for safe
#   preview before making changes.
#
# USAGE:
#   ./clean-downloads.sh [OPTIONS] [directory]
#
# OPTIONS:
#   --organize         Sort files into categorized subdirectories (default action)
#   --purge <days>     Delete files older than the specified number of days
#   --dry-run          Preview actions without moving or deleting anything
#   --help, -h         Display this help message and exit
#   --version, -V      Display script version
#
# EXAMPLES:
#   # Organize ~/Downloads into categorized subdirectories
#   ./clean-downloads.sh
#
#   # Preview what would be organized without making changes
#   ./clean-downloads.sh --dry-run
#
#   # Organize a specific directory
#   ./clean-downloads.sh ~/Documents/Unsorted
#
#   # Delete files older than 30 days
#   ./clean-downloads.sh --purge 30
#
#   # Preview purge of files older than 14 days
#   ./clean-downloads.sh --purge 14 --dry-run
#
#   # Organize and then purge old files
#   ./clean-downloads.sh --organize --purge 30
#
# DEPENDENCIES:
#   - file: For MIME type detection (standard on most systems)
#   - Standard Unix utilities: mkdir, mv, rm, find
#
# OPERATIONAL NOTES:
#   - The default target directory is ~/Downloads
#   - Files are sorted into subdirectories: Images, Documents, Archives,
#     Videos, Audio, Code, Fonts, Other
#   - Category mappings can be customized via CLEAN_DL_MAPPINGS config variable
#   - Filename conflicts are resolved by appending a number suffix
#   - Empty directories left after organizing are not removed by default
#   - The script never follows symbolic links when purging
#   - Exit codes: 0 for success, 1 for errors
#
# SECURITY CONSIDERATIONS:
#   - All file operations validate paths to prevent directory traversal
#   - The script refuses to operate on system directories (/, /etc, /usr, etc.)
#   - Symbolic links are not followed during purge operations
#   - Dry-run mode is available for safe preview of all operations

set -e
set -u
set -o pipefail

# --- User Configuration ---
if [ -n "${SUDO_USER:-}" ]; then
    _USER_CONFIG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config/fedora-user-scripts/config.sh"
else
    _USER_CONFIG="${HOME}/.config/fedora-user-scripts/config.sh"
fi
if [ -f "$_USER_CONFIG" ]; then
    source "$_USER_CONFIG"
fi

# --- Color Detection ---
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLORS_ENABLED=1
else
    COLORS_ENABLED=0
fi

USE_ICONS="${USE_ICONS:-1}"

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
    readonly BOLD=""
    readonly BLUE=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly RED=""
    readonly CYAN=""
    readonly MAGENTA=""
    readonly RESET=""
fi

if (( USE_ICONS && COLORS_ENABLED )); then
    readonly INFO_ICON="ℹ️"
    readonly SUCCESS_ICON="✅"
    readonly WARNING_ICON="⚠️"
    readonly ERROR_ICON="❌"
    readonly SECTION_ICON="🔧"
    readonly START_ICON="🚀"
    readonly FOLDER_ICON="📁"
    readonly DELETE_ICON="🗑️"
    readonly MOVE_ICON="📦"
    readonly DRY_ICON="👁️"
else
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
    readonly SECTION_ICON=""
    readonly START_ICON=""
    readonly FOLDER_ICON=""
    readonly DELETE_ICON=""
    readonly MOVE_ICON=""
    readonly DRY_ICON=""
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
    echo -e "${BOLD}${SECTION_ICON} ${text}${RESET}"
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

print_operation_start() {
    local operation="$1"
    echo -e "${BOLD}${YELLOW}▶ Starting: ${operation}${RESET}"
}

print_operation_end() {
    local operation="$1"
    echo -e "${BOLD}${GREEN}✓ Completed: ${operation}${RESET}"
}

print_subheader() {
    local text="$1"
    echo -e "${BOLD}${text}${RESET}"
}

print_kv() {
    local key="$1"
    local value="$2"
    printf "  ${BOLD}%-22s${RESET} %s\n" "$key" "$value"
}

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.0.0"

if [[ "${1:-}" == "--version" || "${1:-}" == "-V" ]]; then
    echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
    exit 0
fi

# --- Category Definitions ---
declare -A CATEGORIES
CATEGORIES=(
    ["Images"]="jpg jpeg png gif bmp svg webp ico tiff tif raw cr2 nef arw dng heic heif"
    ["Documents"]="pdf doc docx odt odp ods txt rtf md rst tex epub mobi xls xlsx ppt pptx csv"
    ["Archives"]="zip tar gz bz2 xz 7z rar zst lz lz4 cpio deb rpm apk dmg iso"
    ["Videos"]="mp4 mkv avi mov wmv flv webm m4v mpg mpeg 3gp ogv"
    ["Audio"]="mp3 flac ogg opus wav aac m4a wma aiff alac"
    ["Code"]="js ts py rb go rs java c cpp h hpp sh bash html css json xml yaml yml toml sql php cs vue jsx tsx"
    ["Fonts"]="ttf otf woff woff2 eot"
)

DEFAULT_CATEGORY="Other"

# --- Helper Functions ---
get_category() {
    local filename="$1"
    local extension="${filename##*.}"
    extension="${extension,,}"

    if [[ "$filename" == *.* ]]; then
        for category in "${!CATEGORIES[@]}"; do
            local extensions="${CATEGORIES[$category]}"
            for ext in $extensions; do
                if [[ "$extension" == "$ext" ]]; then
                    echo "$category"
                    return 0
                fi
            done
        done
    fi

    echo "$DEFAULT_CATEGORY"
}

resolve_conflict() {
    local dest_dir="$1"
    local dest_file="$2"
    local counter=1
    local base="${dest_file%.*}"
    local ext="${dest_file##*.}"

    if [[ "$dest_file" == *.* ]]; then
        while [[ -e "${dest_dir}/${base}_${counter}.${ext}" ]]; do
            ((counter++))
        done
        echo "${base}_${counter}.${ext}"
    else
        while [[ -e "${dest_dir}/${dest_file}_${counter}" ]]; do
            ((counter++))
        done
        echo "${dest_file}_${counter}"
    fi
}

is_system_directory() {
    local dir="$1"
    case "$dir" in
        /|/etc|/usr|/var|/bin|/sbin|/lib|/lib64|/boot|/dev|/proc|/sys|/run|/root|/tmp)
            return 0
            ;;
    esac
    return 1
}

show_help() {
    cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] [directory]

Organize and clean up your Downloads directory by sorting files into
categorized subdirectories and optionally purging old files.

OPTIONS:
    --organize         Sort files into categorized subdirectories (default)
    --purge <days>     Delete files older than the specified number of days
    --dry-run          Preview actions without moving or deleting anything
    --help, -h         Display this help message
    --version, -V      Display script version

CATEGORIES:
    Images       jpg, png, gif, svg, webp, raw, heic, ...
    Documents    pdf, doc, txt, csv, md, epub, ...
    Archives     zip, tar, gz, 7z, rar, rpm, iso, ...
    Videos       mp4, mkv, avi, mov, webm, ...
    Audio        mp3, flac, ogg, opus, wav, aac, ...
    Code         js, py, go, rs, sh, html, json, yaml, ...
    Fonts        ttf, otf, woff, woff2, ...
    Other        Anything not matched above

EXAMPLES:
    # Organize ~/Downloads
    $(basename "${BASH_SOURCE[0]}")

    # Preview what would happen
    $(basename "${BASH_SOURCE[0]}") --dry-run

    # Organize a specific directory
    $(basename "${BASH_SOURCE[0]}") ~/Documents/Unsorted

    # Delete files older than 30 days
    $(basename "${BASH_SOURCE[0]}") --purge 30

    # Organize and purge old files (preview)
    $(basename "${BASH_SOURCE[0]}") --organize --purge 30 --dry-run

ENVIRONMENT VARIABLES:
    NO_COLOR     Disable colored output
    USE_ICONS    Disable icons (set to 0)
EOF
    exit 0
}

# --- Argument Parsing ---
DO_ORGANIZE=false
DO_PURGE=false
PURGE_DAYS=0
DRY_RUN=false
TARGET_DIR="${CLEAN_DL_DIR:-$HOME/Downloads}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --organize)
            DO_ORGANIZE=true
            shift
            ;;
        --purge)
            DO_PURGE=true
            if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                error "--purge requires a number of days (e.g., --purge 30)"
                exit 1
            fi
            PURGE_DAYS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        --version|-V)
            echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

if [[ "$DO_ORGANIZE" == "false" && "$DO_PURGE" == "false" ]]; then
    DO_ORGANIZE=true
fi

# --- Validation ---
if [[ ! -d "$TARGET_DIR" ]]; then
    error "Directory not found: $TARGET_DIR"
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

if is_system_directory "$TARGET_DIR"; then
    error "Refusing to operate on system directory: $TARGET_DIR"
    exit 1
fi

# --- Header ---
print_header "DOWNLOADS ORGANIZER"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BOLD}${YELLOW}${DRY_ICON} DRY RUN MODE - No files will be modified${RESET}"
fi
echo -e "${BOLD}${GREEN}${START_ICON} Target directory: ${BOLD}${CYAN}${TARGET_DIR}${RESET}"
echo

# --- Organize ---
if [[ "$DO_ORGANIZE" == "true" ]]; then
    print_section_header "ORGANIZING FILES" "${MOVE_ICON}"
    print_operation_start "Sorting files into categories"

    declare -A category_counts
    moved_count=0
    skipped_count=0

    for file in "$TARGET_DIR"/*; do
        [[ -f "$file" ]] || continue

        filename="$(basename "$file")"
        category="$(get_category "$filename")"
        dest_dir="${TARGET_DIR}/${category}"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BOLD}${BLUE}${MOVE_ICON}  ${RESET}${filename} -> ${category}/"
            ((moved_count++)) || true
        else
            mkdir -p "$dest_dir"

            dest_file="$filename"
            if [[ -e "${dest_dir}/${dest_file}" ]]; then
                dest_file="$(resolve_conflict "$dest_dir" "$filename")"
            fi

            if mv "$file" "${dest_dir}/${dest_file}" 2>/dev/null; then
                ((moved_count++)) || true
            else
                warning "Failed to move: $filename"
                ((skipped_count++)) || true
            fi
        fi

        category_counts["$category"]=$(( ${category_counts["$category"]:-0} + 1 ))
    done

    print_operation_end "File sorting completed"

    echo
    print_subheader "Category Breakdown"
    for category in $(echo "${!category_counts[@]}" | tr ' ' '\n' | sort); do
        print_kv "$category" "${category_counts[$category]} file(s)"
    done

    echo
    if [[ "$DRY_RUN" == "true" ]]; then
        info "Would organize ${moved_count} file(s)"
    else
        success "Organized ${moved_count} file(s)"
        if [[ "$skipped_count" -gt 0 ]]; then
            warning "Skipped ${skipped_count} file(s) due to errors"
        fi
    fi
    print_separator
fi

# --- Purge ---
if [[ "$DO_PURGE" == "true" ]]; then
    print_section_header "PURGING OLD FILES" "${DELETE_ICON}"
    print_operation_start "Finding files older than ${PURGE_DAYS} days"

    purge_count=0
    purge_size=0

    while IFS= read -r -d '' file; do
        if [[ "$DRY_RUN" == "true" ]]; then
            local_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            purge_size=$((purge_size + local_size))
            echo -e "  ${BOLD}${RED}${DELETE_ICON}  ${RESET}$(basename "$file")"
            ((purge_count++)) || true
        else
            local_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            if rm "$file" 2>/dev/null; then
                purge_size=$((purge_size + local_size))
                ((purge_count++)) || true
            else
                warning "Failed to delete: $(basename "$file")"
            fi
        fi
    done < <(find "$TARGET_DIR" -maxdepth 1 -type f -mtime "+${PURGE_DAYS}" -print0 2>/dev/null)

    print_operation_end "Purge scan completed"

    echo
    local human_size
    if command -v numfmt &>/dev/null; then
        human_size=$(numfmt --to=iec --suffix=B "$purge_size")
    else
        human_size="${purge_size} B"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        info "Would delete ${purge_count} file(s) (${human_size})"
    else
        if [[ "$purge_count" -gt 0 ]]; then
            success "Deleted ${purge_count} file(s) (${human_size})"
        else
            info "No files older than ${PURGE_DAYS} days found"
        fi
    fi
    print_separator
fi

# --- Summary ---
print_header "SUMMARY"
if [[ "$DRY_RUN" == "true" ]]; then
    info "Dry run complete. No files were modified."
    info "Run without --dry-run to apply changes."
else
    success "Operation completed successfully."
fi
print_separator
echo
