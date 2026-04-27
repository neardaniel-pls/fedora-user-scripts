#!/bin/bash
#
# update-ollama-openwebui.sh - Ollama and Open Web UI update utility
#
# DESCRIPTION:
#   This script updates Ollama and Open Web UI installations with automatic
#   backup functionality. It handles container updates for Open Web UI and
#   binary updates for Ollama, preserving all data and configurations.
#   The script provides colored output for better user experience and includes
#   comprehensive safety checks to prevent data loss.
#
# USAGE:
#   ./update-ollama-openwebui.sh [OPTIONS]
#
# OPTIONS:
#   --backup-only    - Only create backups without updating
#   --restore        - Restore from latest backup (requires --restore-date)
#   --restore-date   - Specify backup date (YYYYMMDD-HHMMSS) for restore
#   --no-backup      - Skip backup before update (not recommended)
#   --help           - Display this help message
#
# EXAMPLES:
#   # Update both Ollama and Open Web UI with backup
#   ./update-ollama-openwebui.sh
#
#   # Only create backups
#   ./update-ollama-openwebui.sh --backup-only
#
#   # Restore from specific backup
#   ./update-ollama-openwebui.sh --restore --restore-date 20260314-143000
#
# DEPENDENCIES:
#   - podman: Container engine for Open Web UI
#   - curl: Download Ollama installer
#   - systemctl: Manage Ollama service
#   - tar: Create/extract backups
#   - Standard Unix utilities: mkdir, cp, mv, rm
#
# OPERATIONAL NOTES:
#   - The script expects Open Web UI container named 'open-webui'
#   - The script expects Ollama service managed by systemd
#   - Backups are stored in ~/backups/open-webui/ and ~/backups/ollama/
#   - Models are preserved during Ollama updates
#   - Exit codes: 0 for success, 1 for errors
#
# SECURITY CONSIDERATIONS:
#   - Backups are created before any destructive operations
#   - Service status is verified before updates
#   - Container and volume integrity is checked
#   - The script requires sudo privileges for systemd operations

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

# --- User Configuration ---
# Load user config if available (sets env vars that override defaults)
if [ -n "${SUDO_USER:-}" ]; then
    _USER_CONFIG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config/fedora-user-scripts/config.sh"
else
    _USER_CONFIG="${HOME}/.config/fedora-user-scripts/config.sh"
fi
if [ -f "$_USER_CONFIG" ]; then
    source "$_USER_CONFIG"
fi

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
    readonly BACKUP_ICON="💾"
    readonly RESTORE_ICON="🔄"
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
    readonly BACKUP_ICON=""
    readonly RESTORE_ICON=""
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
    echo -e "${BOLD}🤖 ${text}${RESET}"
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

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.0.0"

# Quick version check before any heavy initialization
if [[ "${1:-}" == "--version" || "${1:-}" == "-V" ]]; then
    echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
    exit 0
fi

# ===== Configuration =====
# Override with BACKUP_BASE_DIR and OLLAMA_DATA_DIR environment variables if needed
# Use SUDO_USER if available (when running with sudo), otherwise use HOME
if [ -n "${SUDO_USER:-}" ]; then
    ORIGINAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    _DEFAULT_BACKUP_BASE="${ORIGINAL_USER_HOME}/backups"
    _DEFAULT_OLLAMA_DATA="${ORIGINAL_USER_HOME}/.ollama"
else
    _DEFAULT_BACKUP_BASE="${HOME}/backups"
    _DEFAULT_OLLAMA_DATA="${HOME}/.ollama"
fi
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-$_DEFAULT_BACKUP_BASE}"
OLLAMA_DATA_DIR="${OLLAMA_DATA_DIR:-$_DEFAULT_OLLAMA_DATA}"

readonly MAX_BACKUPS="${MAX_BACKUPS:-5}"

# Backup directories
OPENWEBUI_BACKUP_DIR="${BACKUP_BASE_DIR}/open-webui"
OLLAMA_BACKUP_DIR="${BACKUP_BASE_DIR}/ollama"

# Container and service names
OPENWEBUI_CONTAINER="open-webui"
OPENWEBUI_IMAGE="ghcr.io/open-webui/open-webui:main"
OPENWEBUI_VOLUME="open-webui"
OLLAMA_SERVICE="ollama"

# ===== Helper Functions =====
show_help() {
    # Calculate backup locations based on whether running with sudo
    local backup_base_dir
    if [ -n "${SUDO_USER:-}" ]; then
        backup_base_dir=$(getent passwd "$SUDO_USER" | cut -d: -f6)/backups
    else
        backup_base_dir="${HOME}/backups"
    fi

    cat << EOF
Usage: $0 [OPTIONS]

Update Ollama and Open Web UI installations with automatic backup.

OPTIONS:
    --backup-only        Only create backups without updating
    --restore            Restore from backup (requires --restore-date)
    --restore-date DATE  Specify backup date (YYYYMMDD-HHMMSS) for restore
    --no-backup          Skip backup before update (not recommended)
    --help               Display this help message
    --version, -V        Display script version

EXAMPLES:
    # Update both Ollama and Open Web UI with backup
    $0

    # Only create backups
    $0 --backup-only

    # Restore from specific backup
    $0 --restore --restore-date 20260314-143000

ENVIRONMENT VARIABLES:
    BACKUP_BASE_DIR  Base directory for backups (default: ~/backups)
    OLLAMA_DATA_DIR  Ollama data directory (default: ~/.ollama)

BACKUP LOCATIONS:
    Open Web UI: ${backup_base_dir}/open-webui
    Ollama:      ${backup_base_dir}/ollama

For more information, see the documentation at:
    docs/guides/ollama-openwebui-guide.md
EOF
}

check_dependencies() {
    local missing_deps=0
    local cmd

    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Dependency '$cmd' is not installed."
            missing_deps=1
        fi
    done

    if [ "$missing_deps" -eq 1 ]; then
        error "Please install missing dependencies and try again."
        exit 1
    fi

    return 0
}

# ===== Backup Functions =====
backup_openwebui() {
    local timestamp="$1"
    local backup_file="${OPENWEBUI_BACKUP_DIR}/open-webui-backup-${timestamp}.tar.gz"

    print_operation_start "Creating Open Web UI backup"

    # Check if volume exists (this is what we're backing up)
    if ! podman volume ls -q | grep -q "^${OPENWEBUI_VOLUME}$"; then
        warning "Open Web UI volume '${OPENWEBUI_VOLUME}' not found."
        warning "Skipping backup. Data may be lost if update fails!"
        return 0
    fi

    # Stop container if running
    if podman ps -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        print_command_output
        podman stop "${OPENWEBUI_CONTAINER}" || {
            error "Failed to stop Open Web UI container"
            return 1
        }
    fi

    # Create backup directory
    mkdir -p "${OPENWEBUI_BACKUP_DIR}"

    # Create backup using alpine container
    print_command_output
    podman run --rm \
        -v "${OPENWEBUI_VOLUME}:/data:ro" \
        -v "${OPENWEBUI_BACKUP_DIR}:/backup:z" \
        alpine tar czf "/backup/open-webui-backup-${timestamp}.tar.gz" -C /data . || {
        error "Failed to create Open Web UI backup"
        return 1
    }

    success "Open Web UI backed up to: ${backup_file}"
    print_operation_end "Open Web UI backup"
    rotate_backups "${OPENWEBUI_BACKUP_DIR}" "open-webui-backup"

    return 0
}

backup_ollama() {
    local timestamp="$1"
    local backup_file="${OLLAMA_BACKUP_DIR}/ollama-backup-${timestamp}.tar.gz"

    print_operation_start "Creating Ollama backup"

    # Check if Ollama data directory exists (this is what we're backing up)
    if [ ! -d "${OLLAMA_DATA_DIR}" ]; then
        warning "Ollama data directory '${OLLAMA_DATA_DIR}' not found. Skipping backup."
        return 0
    fi

    # Check if Ollama is installed
    if ! command -v ollama &> /dev/null; then
        warning "Ollama binary not found. Skipping backup."
        return 0
    fi

    # Stop service if running (service might not exist, so don't fail if it doesn't)
    if systemctl list-unit-files | grep -q "^${OLLAMA_SERVICE}.service"; then
        if systemctl is-active --quiet "${OLLAMA_SERVICE}" 2>/dev/null; then
            print_command_output
            sudo systemctl stop ollama || {
                error "Failed to stop Ollama service"
                return 1
            }
        fi
    fi

    # Create backup directory
    mkdir -p "${OLLAMA_BACKUP_DIR}"

    # Create backup
    print_command_output
    tar czf "${backup_file}" "${OLLAMA_DATA_DIR}" || {
        error "Failed to create Ollama backup"
        return 1
    }

    # Restart service if it exists
    if systemctl list-unit-files | grep -q "^${OLLAMA_SERVICE}.service"; then
        print_command_output
        sudo systemctl start ollama || {
            warning "Failed to restart Ollama service"
        }
    fi

    success "Ollama backed up to: ${backup_file}"
    print_operation_end "Ollama backup"
    rotate_backups "${OLLAMA_BACKUP_DIR}" "ollama-backup"

    return 0
}

# ===== Backup Rotation =====
rotate_backups() {
    local backup_dir="$1"
    local prefix="$2"

    if [ ! -d "$backup_dir" ]; then
        return 0
    fi

    local count
    count=$(find "$backup_dir" -maxdepth 1 -name "${prefix}-*.tar.gz" 2>/dev/null | wc -l)

    if [ "$count" -le "$MAX_BACKUPS" ]; then
        return 0
    fi

    local to_remove
    to_remove=$((count - MAX_BACKUPS))
    info "Rotating backups: keeping ${MAX_BACKUPS} most recent in ${backup_dir}"

    find "$backup_dir" -maxdepth 1 -name "${prefix}-*.tar.gz" 2>/dev/null \
        | sort \
        | head -n "$to_remove" \
        | xargs -r rm -f 2>/dev/null || true
}

# ===== Update Functions =====
update_openwebui() {
    print_operation_start "Updating Open Web UI"

    # Pull latest image
    print_command_output
    podman pull "${OPENWEBUI_IMAGE}" || {
        error "Failed to pull Open Web UI image"
        return 1
    }

    # Check if volume exists before proceeding
    if ! podman volume ls -q | grep -q "^${OPENWEBUI_VOLUME}$"; then
        warning "Open Web UI volume '${OPENWEBUI_VOLUME}' not found."
        warning "A new volume will be created. Existing data may be lost!"
    fi

    # Stop and remove existing container
    if podman ps -a -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        print_command_output
        podman stop "${OPENWEBUI_CONTAINER}" || {
            error "Failed to stop Open Web UI container"
            return 1
        }
        podman rm "${OPENWEBUI_CONTAINER}" || {
            error "Failed to remove Open Web UI container"
            return 1
        }
    fi

    # Create new container
    print_command_output
    podman run -d \
        --network=host \
        -v "${OPENWEBUI_VOLUME}:/app/backend/data" \
        -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
        --name "${OPENWEBUI_CONTAINER}" \
        --restart always \
        "${OPENWEBUI_IMAGE}" || {
        error "Failed to create Open Web UI container"
        return 1
    }

    # Verify container is running
    if podman ps | grep -q "${OPENWEBUI_CONTAINER}"; then
        success "Open Web UI updated successfully"
        print_operation_end "Open Web UI update"
        return 0
    else
        error "Open Web UI container is not running"
        return 1
    fi
}

update_ollama() {
    print_operation_start "Updating Ollama"

    # Check if Ollama is installed
    if ! command -v ollama &> /dev/null; then
        warning "Ollama not found. Skipping update."
        return 0
    fi

    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^${OLLAMA_SERVICE}.service"; then
        warning "Ollama service not found. Skipping update."
        return 0
    fi

    # Stop service
    print_command_output
    sudo systemctl stop ollama || {
        error "Failed to stop Ollama service"
        return 1
    }

    # Run installer
    # Download to temp file first to avoid piping unverified content to sh.
    # Perform basic sanity check before execution.
    local ollama_installer
    ollama_installer=$(mktemp /tmp/ollama-install.XXXXXX.sh)
    print_command_output
    if ! curl -fsSL https://ollama.com/install.sh -o "$ollama_installer"; then
        error "Failed to download Ollama installer"
        rm -f "$ollama_installer"
        return 1
    fi

    if ! head -1 "$ollama_installer" 2>/dev/null | grep -qE '^#!'; then
        error "Downloaded installer does not appear to be a valid shell script"
        rm -f "$ollama_installer"
        return 1
    fi

    sh "$ollama_installer" || {
        error "Failed to update Ollama"
        rm -f "$ollama_installer"
        return 1
    }
    rm -f "$ollama_installer"

    # Start service
    print_command_output
    sudo systemctl start ollama || {
        error "Failed to start Ollama service"
        return 1
    }

    # Verify installation
    print_command_output
    ollama --version || {
        error "Failed to verify Ollama installation"
        return 1
    }

    # List models
    print_command_output
    ollama list || {
        warning "Failed to list Ollama models"
    }

    success "Ollama updated successfully"
    print_operation_end "Ollama update"

    return 0
}

# ===== Restore Functions =====
restore_openwebui() {
    local backup_date="$1"

    # Validate backup_date format (YYYYMMDD-HHMMSS) to prevent command injection
    if [[ ! "$backup_date" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
        error "Invalid restore date format: '$backup_date'. Expected YYYYMMDD-HHMMSS"
        return 1
    fi

    local backup_file="${OPENWEBUI_BACKUP_DIR}/open-webui-backup-${backup_date}.tar.gz"

    print_operation_start "Restoring Open Web UI from backup"

    # Verify backup exists
    if [ ! -f "${backup_file}" ]; then
        error "Backup file not found: ${backup_file}"
        return 1
    fi

    # Stop container if running
    if podman ps -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        print_command_output
        podman stop "${OPENWEBUI_CONTAINER}" || {
            error "Failed to stop Open Web UI container"
            return 1
        }
    fi

    # Remove container if exists
    if podman ps -a -q --filter "name=${OPENWEBUI_CONTAINER}" | grep -q .; then
        print_command_output
        podman rm "${OPENWEBUI_CONTAINER}" || {
            error "Failed to remove Open Web UI container"
            return 1
        }
    fi

    # Remove volume if exists
    if podman volume ls -q | grep -q "^${OPENWEBUI_VOLUME}$"; then
        print_command_output
        podman volume rm "${OPENWEBUI_VOLUME}" || {
            error "Failed to remove Open Web UI volume"
            return 1
        }
    fi

    # Create new volume
    print_command_output
    podman volume create "${OPENWEBUI_VOLUME}" || {
        error "Failed to create Open Web UI volume"
        return 1
    }

    # Restore backup
    print_command_output
    podman run --rm \
        -v "${OPENWEBUI_VOLUME}:/data" \
        -v "${OPENWEBUI_BACKUP_DIR}:/backup:ro" \
        alpine sh -c "cd /data && tar xzf /backup/open-webui-backup-${backup_date}.tar.gz" || {
        error "Failed to restore Open Web UI backup"
        return 1
    }

    # Start container
    print_command_output
    podman run -d \
        --network=host \
        -v "${OPENWEBUI_VOLUME}:/app/backend/data" \
        -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
        --name "${OPENWEBUI_CONTAINER}" \
        --restart always \
        "${OPENWEBUI_IMAGE}" || {
        error "Failed to start Open Web UI container"
        return 1
    }

    success "Open Web UI restored from backup"
    print_operation_end "Open Web UI restore"

    return 0
}

restore_ollama() {
    local backup_date="$1"

    # Validate backup_date format (YYYYMMDD-HHMMSS) to prevent command injection
    if [[ ! "$backup_date" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
        error "Invalid restore date format: '$backup_date'. Expected YYYYMMDD-HHMMSS"
        return 1
    fi

    local backup_file="${OLLAMA_BACKUP_DIR}/ollama-backup-${backup_date}.tar.gz"

    print_operation_start "Restoring Ollama from backup"

    # Verify backup exists
    if [ ! -f "${backup_file}" ]; then
        error "Backup file not found: ${backup_file}"
        return 1
    fi

    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^${OLLAMA_SERVICE}.service"; then
        error "Ollama service not found. Cannot restore."
        return 1
    fi

    # Stop service if running
    if systemctl is-active --quiet "${OLLAMA_SERVICE}"; then
        print_command_output
        sudo systemctl stop ollama || {
            error "Failed to stop Ollama service"
            return 1
        }
    fi

    # Backup current data if exists
    if [ -d "${OLLAMA_DATA_DIR}" ]; then
        print_command_output
        mv "${OLLAMA_DATA_DIR}" "${OLLAMA_DATA_DIR}.old" || {
            error "Failed to backup current Ollama data"
            return 1
        }
    fi

    # Restore backup - extract to parent directory (tar stores full path)
    print_command_output
    local ollama_parent
    ollama_parent=$(dirname "${OLLAMA_DATA_DIR}")
    mkdir -p "$ollama_parent"
    if ! tar xzf "${backup_file}" -C "$ollama_parent"; then
        error "Failed to restore Ollama backup"
        return 1
    fi

    if [ ! -d "${OLLAMA_DATA_DIR}" ]; then
        error "Restored data not found at expected path: ${OLLAMA_DATA_DIR}"
        return 1
    fi

    # Start service
    print_command_output
    sudo systemctl start ollama || {
        error "Failed to start Ollama service"
        return 1
    }

    # Verify installation
    print_command_output
    ollama list || {
        warning "Failed to list Ollama models"
    }

    # Remove old data if exists
    if [ -d "${OLLAMA_DATA_DIR}.old" ]; then
        print_command_output
        rm -rf "${OLLAMA_DATA_DIR}.old" || {
            warning "Failed to remove old Ollama data"
        }
    fi

    success "Ollama restored from backup"
    print_operation_end "Ollama restore"

    return 0
}

# ===== Main Script =====
# Parse command line arguments
BACKUP_ONLY=false
RESTORE=false
RESTORE_DATE=""
NO_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-only)
            BACKUP_ONLY=true
            shift
            ;;
        --restore)
            RESTORE=true
            shift
            ;;
        --restore-date)
            RESTORE_DATE="$2"
            shift 2
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --version|-V)
            echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo
            show_help
            exit 1
            ;;
    esac
done

# Display header
if [[ "${QUIET:-}" != "1" ]]; then
    print_header "OLLAMA AND OPEN WEB UI UPDATE"
fi

# Check dependencies
check_dependencies podman curl systemctl tar

# Handle restore mode
if [ "$RESTORE" = true ]; then
    if [ -z "${RESTORE_DATE:-}" ]; then
        error "Restore date required. Use --restore-date YYYYMMDD-HHMMSS"
        exit 1
    fi

    print_section_header "RESTORE MODE" "${RESTORE_ICON}"
    restore_openwebui "$RESTORE_DATE" || exit 1
    restore_ollama "$RESTORE_DATE" || exit 1

    print_header "RESTORE SUMMARY"
    success "Restore completed successfully"
    print_separator
    exit 0
fi

# Handle backup-only mode
if [ "$BACKUP_ONLY" = true ]; then
    print_section_header "BACKUP MODE" "${BACKUP_ICON}"
    BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    backup_openwebui "$BACKUP_TIMESTAMP" || exit 1
    backup_ollama "$BACKUP_TIMESTAMP" || exit 1

    print_header "BACKUP SUMMARY"
    success "Backup completed successfully"
    print_separator
    exit 0
fi

# Normal update mode
print_section_header "UPDATE MODE" "${START_ICON}"

# Create backups unless --no-backup is specified
if [ "$NO_BACKUP" != true ]; then
    print_section_header "BACKUP" "${BACKUP_ICON}"
    BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    backup_openwebui "$BACKUP_TIMESTAMP" || exit 1
    backup_ollama "$BACKUP_TIMESTAMP" || exit 1
fi

# Perform updates
print_section_header "UPDATE" "${PACKAGE_ICON}"
update_openwebui || exit 1
update_ollama || exit 1

# Display completion
print_header "UPDATE SUMMARY"
success "Ollama and Open Web UI updated successfully!"
print_separator

exit 0
