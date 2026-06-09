#!/bin/bash
#
# clean-system.sh - System-wide cache, temp, and junk file cleanup utility
#
# DESCRIPTION:
#   Cleans disposable files across the system: user cache, thumbnails, trash,
#   temp files, DNF package cache, systemd journal logs, and Docker data.
#   Supports selective targets via flags and dry-run mode for safe preview.
#   User-space targets run without sudo; system-level targets require root.
#
# USAGE:
#   ./clean-system.sh [OPTIONS]
#
# OPTIONS:
#   --all              Run all cleanup targets (default)
#   --cache            Clean user cache (~/.cache/)
#   --thumbnails       Clean thumbnail cache
#   --trash            Empty trash
#   --temp             Clean temp files
#   --dnf              Clean DNF package cache (needs sudo)
#   --journal          Vacuum systemd journal (needs sudo)
#   --docker           Prune unused Docker data (needs sudo)
#   --dry-run          Preview what would be deleted without deleting
#   --help, -h         Display this help message and exit
#   --version, -V      Display script version
#
# EXAMPLES:
#   # Run all cleanup targets
#   sudo ./clean-system.sh
#
#   # Preview all cleanup actions
#   ./clean-system.sh --dry-run
#
#   # Only clean user cache and thumbnails
#   ./clean-system.sh --cache --thumbnails
#
#   # Only clean DNF cache and journal (needs sudo)
#   sudo ./clean-system.sh --dnf --journal
#
#   # Only prune Docker
#   sudo ./clean-system.sh --docker
#
# DEPENDENCIES:
#   - find, rm, du: Standard Unix utilities
#   - numfmt: For human-readable sizes (part of coreutils)
#   - dnf or dnf5: Optional, for --dnf target
#   - journalctl: Optional, for --journal target
#   - podman or docker: Optional, for --containers target
#
# OPERATIONAL NOTES:
#   - User-space targets (cache, thumbnails, trash, temp) run without sudo
#   - System-level targets (dnf, journal, containers) require root privileges
#   - If system-level targets are selected without sudo, a warning is printed
#     and those targets are skipped
#   - Cache files older than CLEAN_CACHE_DAYS (default: 30) are removed
#   - Temp files older than CLEAN_TEMP_DAYS (default: 7) are removed
#   - Journal logs older than CLEAN_JOURNAL_DAYS (default: 7) are kept
#   - All operations support --dry-run for safe preview
#   - Exit codes: 0 for success, 1 for errors
#
# SECURITY CONSIDERATIONS:
#   - The script only removes files in known safe locations
#   - User cache cleanup respects age thresholds to avoid removing active data
#   - Temp file cleanup only targets files owned by the current user
#   - Container pruning only removes dangling/unused resources

set -e
set -u
set -o pipefail

# --- User Configuration ---
if [ -n "${SUDO_USER:-}" ]; then
    _ACTUAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    _USER_CONFIG="${_ACTUAL_HOME}/.config/fedora-user-scripts/config.sh"
else
    _ACTUAL_HOME="${HOME}"
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
    readonly CLEAN_ICON="🧹"
    readonly DELETE_ICON="🗑️"
    readonly FOLDER_ICON="📁"
    readonly PACKAGE_ICON="📦"
    readonly DRY_ICON="👁️"
else
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
    readonly SECTION_ICON=""
    readonly START_ICON=""
    readonly CLEAN_ICON=""
    readonly DELETE_ICON=""
    readonly FOLDER_ICON=""
    readonly PACKAGE_ICON=""
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

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.0.0"

if [[ "${1:-}" == "--version" || "${1:-}" == "-V" ]]; then
    echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
    exit 0
fi

# --- Configuration ---
readonly CACHE_DIR="${_ACTUAL_HOME}/.cache"
readonly THUMBNAIL_DIR="${_ACTUAL_HOME}/.cache/thumbnails"
readonly TRASH_DIR="${_ACTUAL_HOME}/.local/share/Trash"
readonly CACHE_DAYS="${CLEAN_CACHE_DAYS:-30}"
readonly TEMP_DAYS="${CLEAN_TEMP_DAYS:-7}"
readonly JOURNAL_DAYS="${CLEAN_JOURNAL_DAYS:-7}"

# --- State ---
TOTAL_FREED=0

human_size() {
    local bytes="$1"
    if command -v numfmt &>/dev/null; then
        numfmt --to=iec --suffix=B "$bytes"
    else
        echo "${bytes} B"
    fi
}

add_freed() {
    local bytes="$1"
    TOTAL_FREED=$((TOTAL_FREED + bytes))
}

has_root() {
    [[ $EUID -eq 0 ]]
}

# --- Cleanup Targets ---

clean_cache() {
    print_section_header "USER CACHE" "${FOLDER_ICON}"
    print_operation_start "Scanning ${CACHE_DIR} (files older than ${CACHE_DAYS} days)"

    if [[ ! -d "$CACHE_DIR" ]]; then
        warning "Cache directory not found: ${CACHE_DIR}"
        print_separator
        return
    fi

    local freed=0
    local count=0
    local find_excludes=()
    if [[ "$DO_THUMBNAILS" == "true" && -d "$THUMBNAIL_DIR" ]]; then
        find_excludes=(-not -path "${THUMBNAIL_DIR}/*")
    fi

    while IFS= read -r -d '' file; do
        local size
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BOLD}${YELLOW}${DELETE_ICON}  ${RESET}${file#"${_ACTUAL_HOME}"/}"
            freed=$((freed + size))
            count=$((count + 1))
        else
            if rm -f "$file" 2>/dev/null; then
                freed=$((freed + size))
                count=$((count + 1))
            fi
        fi
    done < <(find "$CACHE_DIR" -type f -mtime "+${CACHE_DAYS}" "${find_excludes[@]}" -print0 2>/dev/null)

    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$count" -gt 0 ]]; then
            info "Would remove ${count} cache file(s), freeing $(human_size "$freed")"
        else
            info "No cache files older than ${CACHE_DAYS} days found"
        fi
    else
        add_freed "$freed"
        if [[ "$count" -gt 0 ]]; then
            success "Removed ${count} cache file(s), freed $(human_size "$freed")"
        else
            info "No cache files older than ${CACHE_DAYS} days found"
        fi
    fi

    print_operation_end "User cache cleanup"
    print_separator
}

clean_thumbnails() {
    print_section_header "THUMBNAIL CACHE" "${FOLDER_ICON}"
    print_operation_start "Scanning ${THUMBNAIL_DIR}"

    if [[ ! -d "$THUMBNAIL_DIR" ]]; then
        info "Thumbnail directory not found (nothing to clean)"
        print_separator
        return
    fi

    local freed=0
    local count=0

    while IFS= read -r -d '' file; do
        local size
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BOLD}${YELLOW}${DELETE_ICON}  ${RESET}${file#"${_ACTUAL_HOME}"/}"
            count=$((count + 1))
            freed=$((freed + size))
        else
            if rm -f "$file" 2>/dev/null; then
                freed=$((freed + size))
                count=$((count + 1))
            fi
        fi
    done < <(find "$THUMBNAIL_DIR" -type f -print0 2>/dev/null)

    if [[ "$DRY_RUN" == "true" ]]; then
        info "Would remove ${count} thumbnail(s), freeing $(human_size "$freed")"
    else
        add_freed "$freed"
        if [[ "$count" -gt 0 ]]; then
            success "Removed ${count} thumbnail(s), freed $(human_size "$freed")"
        else
            info "No thumbnails found"
        fi
    fi

    print_operation_end "Thumbnail cache cleanup"
    print_separator
}

clean_trash() {
    print_section_header "TRASH" "${DELETE_ICON}"
    print_operation_start "Scanning ${TRASH_DIR}"

    if [[ ! -d "$TRASH_DIR" ]]; then
        info "Trash directory not found (nothing to clean)"
        print_separator
        return
    fi

    local freed=0
    local count=0

    while IFS= read -r -d '' file; do
        local size
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BOLD}${YELLOW}${DELETE_ICON}  ${RESET}${file#"${_ACTUAL_HOME}"/}"
            count=$((count + 1))
            freed=$((freed + size))
        else
            if rm -rf "$file" 2>/dev/null; then
                freed=$((freed + size))
                count=$((count + 1))
            fi
        fi
    done < <(find "$TRASH_DIR" -type f -print0 2>/dev/null)

    if [[ "$DRY_RUN" == "true" ]]; then
        info "Would remove ${count} trash item(s), freeing $(human_size "$freed")"
    else
        add_freed "$freed"
        if [[ "$count" -gt 0 ]]; then
            success "Removed ${count} trash item(s), freed $(human_size "$freed")"
        else
            info "Trash is already empty"
        fi
    fi

    print_operation_end "Trash cleanup"
    print_separator
}

clean_temp() {
    print_section_header "TEMP FILES" "${CLEAN_ICON}"
    print_operation_start "Scanning temp files (older than ${TEMP_DAYS} days)"

    local freed=0
    local count=0
    local user_id
    user_id=$(id -u)

    while IFS= read -r -d '' file; do
        local size
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${BOLD}${YELLOW}${DELETE_ICON}  ${RESET}${file}"
            freed=$((freed + size))
            count=$((count + 1))
        else
            if rm -f "$file" 2>/dev/null; then
                freed=$((freed + size))
                count=$((count + 1))
            fi
        fi
    done < <(find /tmp -maxdepth 1 -type f -mtime "+${TEMP_DAYS}" -user "$user_id" -print0 2>/dev/null)

    local state_tmp="${_ACTUAL_HOME}/.local/state"
    if [[ -d "$state_tmp" ]]; then
        while IFS= read -r -d '' file; do
            local size
            size=$(stat -c%s "$file" 2>/dev/null || echo 0)

            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "  ${BOLD}${YELLOW}${DELETE_ICON}  ${RESET}${file#"${_ACTUAL_HOME}"/}"
                freed=$((freed + size))
                count=$((count + 1))
            else
                if rm -f "$file" 2>/dev/null; then
                    freed=$((freed + size))
                    count=$((count + 1))
                fi
            fi
        done < <(find "$state_tmp" -maxdepth 1 -type f -mtime "+${TEMP_DAYS}" -print0 2>/dev/null)
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$count" -gt 0 ]]; then
            info "Would remove ${count} temp file(s), freeing $(human_size "$freed")"
        else
            info "No temp files older than ${TEMP_DAYS} days found"
        fi
    else
        add_freed "$freed"
        if [[ "$count" -gt 0 ]]; then
            success "Removed ${count} temp file(s), freed $(human_size "$freed")"
        else
            info "No temp files older than ${TEMP_DAYS} days found"
        fi
    fi

    print_operation_end "Temp file cleanup"
    print_separator
}

clean_dnf() {
    print_section_header "DNF PACKAGE CACHE" "${PACKAGE_ICON}"
    print_operation_start "Cleaning DNF cache"

    if ! has_root; then
        warning "Skipping DNF cache cleanup (requires sudo)"
        print_separator
        return
    fi

    if ! command -v dnf5 &>/dev/null && ! command -v dnf &>/dev/null; then
        warning "DNF not found, skipping"
        print_separator
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        local cache_size=0
        if command -v dnf5 &>/dev/null; then
            cache_size=$(du -sb /var/cache/dnf/ 2>/dev/null | tail -1 | cut -f1 || echo 0)
        else
            cache_size=$(du -sb /var/cache/dnf/ 2>/dev/null | tail -1 | cut -f1 || echo 0)
        fi
        info "Would clean DNF package cache: approximately $(human_size "${cache_size}")"
    else
        local before=0
        before=$(du -sb /var/cache/dnf/ 2>/dev/null | tail -1 | cut -f1 || echo 0)

        if command -v dnf5 &>/dev/null; then
            dnf5 clean packages 2>/dev/null || true
        else
            dnf clean packages 2>/dev/null || true
        fi

        local after=0
        after=$(du -sb /var/cache/dnf/ 2>/dev/null | tail -1 | cut -f1 || echo 0)
        local freed=$((before - after))
        add_freed "$freed"
        success "DNF package cache cleaned, freed $(human_size "$freed")"
    fi

    print_operation_end "DNF cache cleanup"
    print_separator
}

clean_journal() {
    print_section_header "SYSTEMD JOURNAL" "${CLEAN_ICON}"
    print_operation_start "Vacuuming journal logs (keeping last ${JOURNAL_DAYS} days)"

    if ! has_root; then
        warning "Skipping journal vacuum (requires sudo)"
        print_separator
        return
    fi

    if ! command -v journalctl &>/dev/null; then
        warning "journalctl not found, skipping"
        print_separator
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        local journal_size
        journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[KMGT]' | head -1 || echo "unknown")
        info "Would vacuum journal to ${JOURNAL_DAYS} days (current usage: ${journal_size})"
    else
        local before=0
        before=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+' | head -1 || echo 0)

        journalctl --vacuum-time="${JOURNAL_DAYS}d" --no-pager 2>/dev/null || true

        local after=0
        after=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+' | head -1 || echo 0)
        local freed=$((before - after))
        if [[ "$freed" -lt 0 ]]; then freed=0; fi
        add_freed "$freed"
        success "Journal vacuumed to ${JOURNAL_DAYS} days, freed $(human_size "$freed")"
    fi

    print_operation_end "Journal vacuum"
    print_separator
}

clean_containers() {
    local runtime=""
    if command -v podman &>/dev/null; then
        runtime="podman"
    elif command -v docker &>/dev/null; then
        runtime="docker"
    else
        info "No container runtime (podman/docker) found, skipping"
        print_separator
        return
    fi

    print_section_header "CONTAINERS (${runtime^^})" "${PACKAGE_ICON}"
    print_operation_start "Pruning unused ${runtime} data"

    if ! has_root; then
        warning "Skipping ${runtime} prune (requires sudo)"
        print_separator
        return
    fi

    if [[ "$runtime" == "docker" ]] && ! docker info &>/dev/null; then
        warning "Docker daemon not running, skipping"
        print_separator
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        local reclaimable
        reclaimable=$(${runtime} system df 2>/dev/null | tail -1 | awk '{print $4, $5}' || echo "unknown")
        info "Would reclaim approximately: ${reclaimable}"
    else
        local before=0
        before=$(${runtime} system df --format '{{.Size}}' 2>/dev/null | head -1 | grep -oP '\d+' | head -1 || echo 0)

        local output
        output=$(${runtime} system prune -f 2>/dev/null || true)

        local after=0
        after=$(${runtime} system df --format '{{.Size}}' 2>/dev/null | head -1 | grep -oP '\d+' | head -1 || echo 0)
        local freed=$((before - after))
        if [[ "$freed" -lt 0 ]]; then freed=0; fi
        add_freed "$freed"

        local reclaimed
        reclaimed=$(echo "$output" | grep -oP 'Total reclaimed space:\s+\K.*' || echo "unknown")
        success "${runtime} pruned, reclaimed: ${reclaimed}"
    fi

    print_operation_end "${runtime} prune"
    print_separator
}

# --- Help ---
show_help() {
    cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

Clean disposable files across the system: cache, temp files, package manager
cache, journal logs, and container data (podman/docker).

OPTIONS:
    --all              Run all cleanup targets (default)
    --cache            Clean user cache (~/.cache/)
    --thumbnails       Clean thumbnail cache
    --trash            Empty trash
    --temp             Clean temp files
    --dnf              Clean DNF package cache (needs sudo)
    --journal          Vacuum systemd journal (needs sudo)
    --containers       Prune unused podman/docker data (needs sudo)
    --dry-run          Preview actions without deleting anything
    --help, -h         Display this help message
    --version, -V      Display script version

TARGETS:
    User-space (no sudo required):
        --cache          Files in ~/.cache/ older than ${CACHE_DAYS} days
        --thumbnails     All thumbnail cache (auto-regenerated)
        --trash          Empty ~/.local/share/Trash/
        --temp           Temp files older than ${TEMP_DAYS} days

    System-level (requires sudo):
        --dnf            DNF package manager cache
        --journal        Systemd journal logs (keeps ${JOURNAL_DAYS} days)
        --containers     Unused podman/docker images, containers, build cache

EXAMPLES:
    # Run all targets (use sudo for system-level targets)
    sudo $(basename "${BASH_SOURCE[0]}")

    # Preview everything without making changes
    $(basename "${BASH_SOURCE[0]}") --dry-run

    # Only user-space cleanup
    $(basename "${BASH_SOURCE[0]}") --cache --thumbnails --trash --temp

    # Only system-level cleanup
    sudo $(basename "${BASH_SOURCE[0]}") --dnf --journal --containers

CONFIGURATION:
    Set in ~/.config/fedora-user-scripts/config.sh:
        CLEAN_CACHE_DAYS=30    Cache file age threshold (default: 30)
        CLEAN_TEMP_DAYS=7      Temp file age threshold (default: 7)
        CLEAN_JOURNAL_DAYS=7   Journal retention days (default: 7)

ENVIRONMENT VARIABLES:
    NO_COLOR     Disable colored output
    USE_ICONS    Disable icons (set to 0)
EOF
    exit 0
}

# --- Argument Parsing ---
DO_ALL=false
DO_CACHE=false
DO_THUMBNAILS=false
DO_TRASH=false
DO_TEMP=false
DO_DNF=false
DO_JOURNAL=false
DO_CONTAINERS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            DO_ALL=true
            shift
            ;;
        --cache)
            DO_CACHE=true
            shift
            ;;
        --thumbnails)
            DO_THUMBNAILS=true
            shift
            ;;
        --trash)
            DO_TRASH=true
            shift
            ;;
        --temp)
            DO_TEMP=true
            shift
            ;;
        --dnf)
            DO_DNF=true
            shift
            ;;
        --journal)
            DO_JOURNAL=true
            shift
            ;;
        --containers)
            DO_CONTAINERS=true
            shift
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
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

if [[ "$DO_ALL" == "false" && "$DO_CACHE" == "false" && "$DO_THUMBNAILS" == "false" && \
      "$DO_TRASH" == "false" && "$DO_TEMP" == "false" && "$DO_DNF" == "false" && \
      "$DO_JOURNAL" == "false" && "$DO_CONTAINERS" == "false" ]]; then
    DO_ALL=true
fi

if [[ "$DO_ALL" == "true" ]]; then
    DO_CACHE=true
    DO_THUMBNAILS=true
    DO_TRASH=true
    DO_TEMP=true
    DO_DNF=true
    DO_JOURNAL=true
    DO_CONTAINERS=true
fi

# --- Log Setup ---
LOG_FILE="/var/log/clean-system-$(date +%Y%m%d-%H%M%S).log"

cleanup() {
    if [[ -f "$LOG_FILE" ]] && has_root; then
        chmod 600 "$LOG_FILE" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if has_root; then
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

# --- Header ---
print_header "SYSTEM CLEANUP"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BOLD}${YELLOW}${DRY_ICON} DRY RUN MODE - No files will be deleted${RESET}"
fi

local_user="${SUDO_USER:-$(whoami)}"
echo -e "${BOLD}${GREEN}${START_ICON} Running as: ${local_user}${RESET}"
echo -e "${BOLD}${GREEN}${START_ICON} Cache threshold: ${CACHE_DAYS} days | Temp threshold: ${TEMP_DAYS} days | Journal retention: ${JOURNAL_DAYS} days${RESET}"
echo

# --- Execute Targets ---
if [[ "$DO_CACHE" == "true" ]]; then
    clean_cache
fi

if [[ "$DO_THUMBNAILS" == "true" ]]; then
    clean_thumbnails
fi

if [[ "$DO_TRASH" == "true" ]]; then
    clean_trash
fi

if [[ "$DO_TEMP" == "true" ]]; then
    clean_temp
fi

if [[ "$DO_DNF" == "true" ]]; then
    clean_dnf
fi

if [[ "$DO_JOURNAL" == "true" ]]; then
    clean_journal
fi

if [[ "$DO_CONTAINERS" == "true" ]]; then
    clean_containers
fi

# --- Summary ---
print_header "SUMMARY"
if [[ "$DRY_RUN" == "true" ]]; then
    info "Dry run complete. No files were deleted."
    info "Run without --dry-run to apply changes."
else
    success "Cleanup completed."
    if [[ "$TOTAL_FREED" -gt 0 ]]; then
        success "Total space freed: $(human_size "$TOTAL_FREED")"
    fi
fi

if [[ "$DO_DNF" == "true" || "$DO_JOURNAL" == "true" || "$DO_CONTAINERS" == "true" ]]; then
    if ! has_root; then
        echo
        warning "System-level targets (dnf, journal, containers) were skipped."
        info "Re-run with sudo to include them:"
        info "  sudo $(basename "${BASH_SOURCE[0]}") --dnf --journal --containers"
    fi
fi

print_separator
echo
