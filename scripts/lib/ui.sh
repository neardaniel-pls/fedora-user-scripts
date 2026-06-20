# ui.sh — Shared UI library for fedora-user-scripts
#
# This file is sourced by all scripts. It provides:
#   - User config loading
#   - Color detection (NO_COLOR support)
#   - Icon configuration (USE_ICONS support)
#   - Color and icon definitions
#   - Output helper functions
#   - Shared utility functions
#
# USAGE:
#   After "set -euo pipefail", source this file:
#     SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#     source "${SCRIPT_DIR}/../lib/ui.sh"

_get_user_home() {
    if [ -n "${SUDO_USER:-}" ]; then
        getent passwd "$SUDO_USER" | cut -d: -f6
    else
        echo "$HOME"
    fi
}

_USER_CONFIG="$(_get_user_home)/.config/fedora-user-scripts/config.sh"
if [ -f "$_USER_CONFIG" ]; then
    _config_mode=$(stat -c '%a' "$_USER_CONFIG" 2>/dev/null || echo "000")
    case "$_config_mode" in
        ???w?*|???w) ;;
        *)
            _config_owner=$(stat -c '%u' "$_USER_CONFIG" 2>/dev/null || echo "0")
            if [ -n "${SUDO_USER:-}" ]; then
                _expected_uid=$(id -u "$SUDO_USER" 2>/dev/null || echo "0")
            else
                _expected_uid=$(id -u)
            fi
            if [ "$_config_owner" = "$_expected_uid" ] || [ "$_config_owner" = "0" ]; then
                source "$_USER_CONFIG"
            fi
            ;;
    esac
fi

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
    readonly PACKAGE_ICON="📦"
    readonly CLEAN_ICON="🧹"
    readonly FILE_ICON="📄"
    readonly METADATA_ICON="🏷️"
else
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

_LOG_FILE=""

enable_logging() {
    _LOG_FILE="$1"
    touch "$_LOG_FILE"
    chmod 600 "$_LOG_FILE"
}

_log() {
    [ -n "$_LOG_FILE" ] || return 0
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1: $2" >> "$_LOG_FILE"
}

info() {
    local message="$1"
    echo -e "${BOLD}${BLUE}${INFO_ICON}  ${message}${RESET}"
    _log "INFO" "$message"
}

success() {
    local message="$1"
    echo -e "${BOLD}${GREEN}${SUCCESS_ICON} ${message}${RESET}"
    _log "SUCCESS" "$message"
}

warning() {
    local message="$1"
    echo -e "${BOLD}${YELLOW}${WARNING_ICON} ${message}${RESET}"
    _log "WARNING" "$message"
}

error() {
    local message="$1"
    echo -e "${BOLD}${RED}${ERROR_ICON} ${message}${RESET}" >&2
    _log "ERROR" "$message"
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

check_dependencies() {
    local missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Dependency '$cmd' is not installed."
            missing=1
        fi
    done
    if (( missing )); then
        error "Install missing dependencies and try again."
        exit 1
    fi
}

human_size() {
    local bytes="$1"
    if command -v numfmt &>/dev/null; then
        numfmt --to=iec --suffix=B "$bytes"
    else
        echo "${bytes} B"
    fi
}

_parse_size_to_bytes() {
    local input="${1//[[:space:]]/}"
    local num="${input%%[!0-9.]*}"
    local unit="${input##*[0-9.]}"
    local int="${num%%.*}"
    local -i mul=1
    case "${unit:-B}" in
        K) mul=1024 ;;
        M) mul=1048576 ;;
        G) mul=1073741824 ;;
        T) mul=1099511627776 ;;
    esac
    echo $(( ${int:-0} * mul ))
}

print_kv() {
    local key="$1"
    local value="$2"
    printf "  ${BOLD}%-22s${RESET} %s\n" "$key" "$value"
}

version_check() {
    local version="$1"
    if [[ "${_CLI_ARG1:-}" == "--version" || "${_CLI_ARG1:-}" == "-V" ]]; then
        echo "$(basename "${BASH_SOURCE[1]}") ${version}"
        exit 0
    fi
}

fix_ownership() {
    local target_dir="$1"
    local expected_owner expected_group

    if [ -n "${SUDO_USER:-}" ]; then
        expected_owner="$SUDO_USER"
    else
        expected_owner="$(id -un)"
    fi
    expected_group="$(id -gn "$expected_owner")"

    local wrong_owner
    wrong_owner=$(find "$target_dir" -not -type l -not -user "$expected_owner" -print -quit 2>/dev/null)

    if [ -z "$wrong_owner" ]; then
        return 0
    fi

    if ! command -v sudo &>/dev/null; then
        error "Wrong ownership in $target_dir. Fix manually:"
        echo "  sudo chown -R $expected_owner:$expected_group $target_dir"
        return 1
    fi

    info "Fixing ownership..."
    sudo find "$target_dir" -not -type l -execdir chown "$expected_owner":"$expected_group" {} +
    sudo find "$target_dir" -not -type l -type d -exec chmod 755 {} +
    sudo find "$target_dir" -not -type l -type f -exec chmod 644 {} +
    sudo find "$target_dir" -not -type l -type f -name "*.sh" -exec chmod 755 {} +
    success "Ownership and permissions fixed"
}
