#!/bin/bash
#
# colors.sh - Standardized color and output formatting library
#
# DESCRIPTION:
#   This library provides consistent color definitions and output formatting
#   functions for all user-scripts. It automatically detects terminal capabilities
#   and provides appropriate formatting for interactive and non-interactive
#   environments.
#
# USAGE:
#   Source this library at the beginning of your script:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
#
#   Then use the provided functions:
#   info "Informational message"
#   success "Success message"
#   warning "Warning message"
#   error "Error message"
#
# ENVIRONMENT VARIABLES:
#   NO_COLOR: Set to any value to disable colors
#   USE_ICONS: Set to 0 to disable icons (default: 1)
#

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
    readonly RESET="\033[0m"
else
    # Set to empty strings when colors are disabled
    readonly BOLD=""
    readonly BLUE=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly RED=""
    readonly RESET=""
fi

# --- Icon Definitions ---
# Define icons only if icons are enabled AND colors are enabled
if (( USE_ICONS && COLORS_ENABLED )); then
    readonly INFO_ICON="ℹ️"
    readonly SUCCESS_ICON="✅"
    readonly WARNING_ICON="⚠️"
    readonly ERROR_ICON="❌"
else
    # Set to empty strings when icons or colors are disabled
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
fi

# --- Output Functions ---
#
# info - Display informational message
#
# DESCRIPTION:
#   Shows an informational message to user using blue color and info icon.
#
# PARAMETERS:
#   $1 - Message to display
#
info() {
    local message="$1"
    echo -e "${BOLD}${BLUE}${INFO_ICON}  ${message}${RESET}"
}

#
# success - Display success message
#
# DESCRIPTION:
#   Shows a success message to user using green color and checkmark icon.
#
# PARAMETERS:
#   $1 - Message to display
#
success() {
    local message="$1"
    echo -e "${BOLD}${GREEN}${SUCCESS_ICON} ${message}${RESET}"
}

#
# warning - Display warning message
#
# DESCRIPTION:
#   Shows a warning message to user using yellow color and warning icon.
#
# PARAMETERS:
#   $1 - Message to display
#
warning() {
    local message="$1"
    echo -e "${BOLD}${YELLOW}${WARNING_ICON} ${message}${RESET}"
}

#
# error - Display error message
#
# DESCRIPTION:
#   Shows an error message to user using red color and error icon.
#   Outputs to stderr for proper error handling.
#
# PARAMETERS:
#   $1 - Message to display
#
error() {
    local message="$1"
    echo -e "${BOLD}${RED}${ERROR_ICON} ${message}${RESET}" >&2
}

#
# print_header - Display a formatted header
#
# DESCRIPTION:
#   Shows a formatted header with the provided text, useful for section breaks.
#
# PARAMETERS:
#   $1 - Header text
#
print_header() {
    local text="$1"
    echo
    echo -e "${BOLD}${BLUE}================== ${text} ==================${RESET}"
}

#
# print_separator - Display a separator line
#
# DESCRIPTION:
#   Shows a separator line for visual separation of content.
#
print_separator() {
    echo -e "${BOLD}====================================================${RESET}"
}

#
# print_subheader - Display a formatted subheader
#
# DESCRIPTION:
#   Shows a formatted subheader with the provided text.
#
# PARAMETERS:
#   $1 - Subheader text
#
print_subheader() {
    local text="$1"
    echo -e "${BOLD}${text}${RESET}"
}