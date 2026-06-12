# ui.sh — Shared UI library for fedora-user-scripts
#
# This file is sourced by all scripts. It provides:
#   - User config loading
#   - Color detection (NO_COLOR support)
#   - Icon configuration (USE_ICONS support)
#   - Color and icon definitions
#   - Output helper functions
#
# USAGE:
#   After "set -euo pipefail", source this file:
#     SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#     source "${SCRIPT_DIR}/../lib/ui.sh"

if [ -n "${SUDO_USER:-}" ]; then
    _USER_CONFIG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config/fedora-user-scripts/config.sh"
else
    _USER_CONFIG="${HOME}/.config/fedora-user-scripts/config.sh"
fi
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
