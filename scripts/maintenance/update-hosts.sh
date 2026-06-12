#!/bin/bash
#
# update-hosts.sh - StevenBlack hosts repository update utility
#
# DESCRIPTION:
#   This script updates the StevenBlack hosts repository and generates a new hosts file
#   with specified extensions. It pulls the latest changes from the repository and then
#   runs the updateHostsFile.py script with the specified extensions.
#
# USAGE:
#   sudo ./update-hosts.sh [OPTIONS]
#
# OPTIONS:
#   --help          Show this help message and exit
#   --auto          Automatically flush DNS cache after updating hosts file
#
# EXAMPLES:
#   # Run the hosts update with default extensions (gambling, porn)
#   sudo ./update-hosts.sh
#
#   # Run with automatic DNS cache flush
#   sudo ./update-hosts.sh --auto
#
#   # Show help message
#   sudo ./update-hosts.sh --help
#
# DEPENDENCIES:
#   - git: For repository operations
#   - python3: For running the updateHostsFile.py script
#   - StevenBlack/hosts repository in ~/Documents/code/hosts
#
# OPERATIONAL NOTES:
#   - The script requires write access to the hosts repository directory
#   - The script answers prompts with a specific sequence: "yes" for replacing hosts file, "no" for DNS cache flush
#   - Use --auto flag to automatically flush the DNS cache for immediate effect
#   - Exit codes: 0 for success, 1 for errors
#

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CLI_ARG1="${1:-}"
source "${SCRIPT_DIR}/../lib/ui.sh"

if (( USE_ICONS && COLORS_ENABLED )); then
    readonly HOSTS_ICON="🌐"
    readonly UPDATE_ICON="🔄"
else
    readonly HOSTS_ICON=""
    readonly UPDATE_ICON=""
fi

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.3.2"
version_check "$SCRIPT_VERSION"

# --- Helper Functions ---
show_help() {
    cat << EOF
${BOLD}${GREEN}${START_ICON} StevenBlack Hosts Update Utility${RESET}

${BOLD}USAGE:${RESET}
    sudo ./update-hosts.sh [OPTIONS]

${BOLD}OPTIONS:${RESET}
    ${BOLD}--help, -h${RESET}       Show this help message and exit
    ${BOLD}--version, -V${RESET}    Display script version
    ${BOLD}--auto${RESET}           Automatically flush DNS cache after updating hosts file

${BOLD}DESCRIPTION:${RESET}
    This script updates the StevenBlack hosts repository and generates a new hosts file
    with specified extensions. It pulls the latest changes from the repository and then
    runs the updateHostsFile.py script with the specified extensions.

${BOLD}AVAILABLE EXTENSIONS:${RESET}
    1. fakenews    - Block fake news websites
    2. gambling    - Block gambling websites
    3. porn        - Block adult content websites
    4. social      - Block social media websites

${BOLD}EXAMPLES:${RESET}
    ${GREEN}#${RESET} Run with default extensions (gambling, porn)
    sudo ./update-hosts.sh

    ${GREEN}#${RESET} Run with automatic DNS cache flush
    sudo ./update-hosts.sh --auto

    ${GREEN}#${RESET} Use custom extensions via environment variable
    HOSTS_EXTENSIONS=fakenews,social sudo ./update-hosts.sh --auto

${BOLD}ENVIRONMENT VARIABLES:${RESET}
    ${BOLD}HOSTS_EXTENSIONS${RESET}    Comma-separated list of extensions to use
    ${BOLD}HOSTS_REPO_PATH${RESET}     Custom path to the hosts repository
    ${BOLD}NO_COLOR${RESET}            Disable colored output
    ${BOLD}USE_ICONS${RESET}           Disable icons (set to 0)

${BOLD}DEPENDENCIES:${RESET}
    - git: For repository operations
    - python3: For running the updateHostsFile.py script
    - StevenBlack/hosts repository in ~/Documents/code/hosts

${BOLD}DNS CACHE FLUSH:${RESET}
    When using the ${BOLD}--auto${RESET} flag, the script will automatically flush the
    DNS cache for immediate effect. Without this flag, you may need to manually
    flush the cache using one of these commands:

    ${GREEN}sudo systemctl restart systemd-resolved${RESET}
    ${GREEN}sudo systemctl restart nscd${RESET}
    ${GREEN}sudo systemctl restart dnsmasq${RESET}

${BOLD}EXIT CODES:${RESET}
    0    Success
    1    Error
EOF
}

flush_dns_cache() {
    print_section_header "DNS CACHE FLUSH" "${UPDATE_ICON}"
    print_operation_start "Flushing DNS cache for immediate effect"

    local flushed=0

    # Try systemd-resolved first (most common on Fedora)
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        if systemctl restart systemd-resolved 2>/dev/null; then
            success "systemd-resolved DNS cache flushed successfully"
            flushed=1
        else
            warning "Failed to flush systemd-resolved cache"
        fi
    # Try nscd
    elif systemctl is-active --quiet nscd 2>/dev/null; then
        if systemctl restart nscd 2>/dev/null; then
            success "nscd DNS cache flushed successfully"
            flushed=1
        else
            warning "Failed to flush nscd cache"
        fi
    # Try dnsmasq
    elif systemctl is-active --quiet dnsmasq 2>/dev/null; then
        if systemctl restart dnsmasq 2>/dev/null; then
            success "dnsmasq DNS cache flushed successfully"
            flushed=1
        else
            warning "Failed to flush dnsmasq cache"
        fi
    else
        info "No active DNS caching service detected"
    fi

    if [ "$flushed" -eq 1 ]; then
        print_operation_end "DNS cache flush completed"
        success "DNS cache flushed - hosts file changes are now in effect"
    else
        info "DNS cache was not flushed. Changes will take effect gradually."
        info "To manually flush the cache, run: sudo systemctl restart systemd-resolved"
    fi
    print_separator
}

# --- Argument Parsing ---
# Default values
AUTO_FLUSH_DNS=0

# Parse command-line arguments (before root check so --help works without sudo)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --auto)
            AUTO_FLUSH_DNS=1
            shift
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

# ===== Verify Root/Sudo =====
# The script modifies /etc/hosts, so root privileges are mandatory.
if [ "$EUID" -ne 0 ]; then
    error "This script must be run with sudo to update /etc/hosts."
    info "Please run: sudo ./update-hosts.sh"
    exit 1
fi

# Ensure SUDO_USER is set (in case someone ran it as actual root, not sudo)
if [ -z "${SUDO_USER:-}" ]; then
    warning "SUDO_USER not set. Assuming you are logged in as root."
    # If strictly root, we can't drop privileges effectively,
    # but the script will likely still work, just with root-owned git files.
    SUDO_USER="root"
fi

# ===== Configuration =====
# Path to the StevenBlack hosts repository
# Use SUDO_USER if available (when running with sudo), otherwise use HOME
# Allow customizing the repository path via environment variable
HOSTS_REPO="${HOSTS_REPO_PATH:-}"
if [ -z "$HOSTS_REPO" ]; then
    if [ -n "${SUDO_USER:-}" ]; then
        ORIGINAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        HOSTS_REPO="${ORIGINAL_USER_HOME}/Documents/code/hosts"
    else
        HOSTS_REPO="${HOME}/Documents/code/hosts"
    fi
fi

# Function to select extensions interactively
select_extensions() {
    # Create a simple numbered menu
    echo -e "${BOLD}${CYAN}Available extensions:${RESET}"
    echo "1. fakenews"
    echo "2. gambling"
    echo "3. porn"
    echo "4. social"
    
    echo -e "${BOLD}${CYAN}Enter the numbers of extensions you want to use (comma-separated, e.g., 1,2):${RESET}"
    echo -e "${YELLOW}Press Enter to use default extensions (gambling,porn) or input your selection:${RESET}"
    
    # Initialize EXTENSIONS with actual default value
    EXTENSIONS="gambling,porn"
    
    # Read with a timeout to handle Enter key press
    if read -t 30 -r user_selection; then
        # Check if user just pressed Enter without typing anything
        if [ -z "$user_selection" ]; then
            # Use default extensions
            echo -e "${YELLOW}No selection made. Using default extensions: $EXTENSIONS${RESET}"
        else
            # Parse user selection and build extensions string
            selected_extensions=()
            IFS=',' read -ra selections <<< "$user_selection"
            
            for num in "${selections[@]}"; do
                case "$num" in
                    1) selected_extensions+=("fakenews") ;;
                    2) selected_extensions+=("gambling") ;;
                    3) selected_extensions+=("porn") ;;
                    4) selected_extensions+=("social") ;;
                    *) echo -e "${RED}Invalid selection: $num${RESET}"; return 1 ;;
                esac
            done
            
            # Join selected extensions with comma
            EXTENSIONS=$(IFS=','; echo "${selected_extensions[*]}")
            echo -e "${GREEN}Selected extensions: $EXTENSIONS${RESET}"
        fi
    else
        echo -e "${RED}Timeout waiting for input. Using default extensions: $EXTENSIONS${RESET}"
    fi
    
    # Export EXTENSIONS for use in the main script
    export EXTENSIONS
}

# Default extensions to use
DEFAULT_EXTENSIONS="gambling,porn"
# Allow customizing extensions via environment variable
if [ -n "${HOSTS_EXTENSIONS:-}" ]; then
    EXTENSIONS="$HOSTS_EXTENSIONS"
    echo -e "${GREEN}Using extensions from environment variable: $EXTENSIONS${RESET}"
else
    # Interactive selection if not set via environment
    select_extensions
    
    # Make sure EXTENSIONS is set (it should be exported by the function)
    if [ -z "${EXTENSIONS:-}" ]; then
        EXTENSIONS="$DEFAULT_EXTENSIONS"
        echo -e "${YELLOW}Using default extensions: $EXTENSIONS${RESET}"
    fi
fi

# Display script introduction with formatting
print_header "STEVENBLACK HOSTS UPDATE"
echo -e "${BOLD}${GREEN}${START_ICON} Starting StevenBlack hosts repository update...${RESET}"
echo

# ===== Verify prerequisites =====
print_section_header "PREREQUISITE CHECK" "${SECTION_ICON}"

# Check if the hosts repository directory exists
if [ ! -d "$HOSTS_REPO" ]; then
    error "Hosts repository not found at: $HOSTS_REPO"
    error "Please clone the repository with: git clone https://github.com/StevenBlack/hosts.git ~/Documents/code/hosts"
    exit 1
fi
success "Hosts repository found at: $HOSTS_REPO"

# Check if git is available
if ! command -v git >/dev/null 2>&1; then
    error "git is not installed or not in PATH"
    exit 1
fi
success "git is available"

# Check if python3 is available
if ! command -v python3 >/dev/null 2>&1; then
    error "python3 is not installed or not in PATH"
    exit 1
fi
success "python3 is available"

# Check if updateHostsFile.py exists
if [ ! -f "$HOSTS_REPO/updateHostsFile.py" ]; then
    error "updateHostsFile.py not found in the hosts repository"
    exit 1
fi
success "updateHostsFile.py found in the hosts repository"
print_separator

# ===== Update repository =====
print_section_header "REPOSITORY UPDATE" "${UPDATE_ICON}"
print_operation_start "Updating StevenBlack hosts repository"
cd "$HOSTS_REPO" || { error "Failed to change to repository directory"; exit 1; }

# Fix permissions first if running as sudo
if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER":"$(id -gn "$SUDO_USER")" .
fi

if [ -n "${SUDO_USER:-}" ]; then
    git_cmd() { sudo -u "$SUDO_USER" git "$@"; }
else
    git_cmd() { git "$@"; }
fi

# Stash any local changes before pulling
if git_cmd status --porcelain | grep -q .; then
    info "Local changes detected, stashing them before update..."
    if git_cmd stash push -m "Auto-stash before update $(date)"; then
        success "Local changes stashed successfully"
    else
        warning "Failed to stash local changes, continuing anyway..."
    fi
else
    info "No local changes to stash"
fi

# Pull the latest changes from the repository
if git_cmd pull; then
    print_operation_end "Repository updated successfully"
    success "Repository updated with latest changes"

    if git_cmd stash list | grep -q "Auto-stash before update"; then
        info "Previously stashed changes found. You can restore them later with:"
        echo -e "${BOLD}${YELLOW}cd $HOSTS_REPO && git stash pop${RESET}"
    fi
else
    error "Failed to update the repository"
    exit 1
fi
print_separator

# ===== Update hosts file =====
print_section_header "HOSTS FILE GENERATION" "${HOSTS_ICON}"
print_operation_start "Generating hosts file with extensions: $EXTENSIONS"

# Change to the hosts repository directory if not already there
cd "$HOSTS_REPO" || { error "Failed to change to repository directory"; exit 1; }

# Fix the default extension logic
if [ -z "$EXTENSIONS" ]; then
    # Actually set the defaults you promised in the text
    EXTENSIONS="gambling,porn"
    echo -e "${YELLOW}No extensions specified. Using default extensions: $EXTENSIONS${RESET}"
fi

# Construct the command with proper flags
# StevenBlack script flags:
# --auto : skip prompts (equivalent to answering 'yes' to replace hosts file)
# --replace : replace /etc/hosts
# --extensions : specify extensions to use
CMD=(python3 updateHostsFile.py --auto --replace --extensions "$EXTENSIONS")

# Execute the command
if "${CMD[@]}"; then
    print_operation_end "Hosts file generated and installed successfully"
    success "System hosts file updated with extensions: $EXTENSIONS"
else
    error "Failed to generate the hosts file"
    exit 1
fi
print_separator

# ===== Flush DNS Cache (if --auto flag is set) =====
if [ "$AUTO_FLUSH_DNS" -eq 1 ]; then
    flush_dns_cache
fi

# ===== Completion =====
print_header "UPDATE SUMMARY"
echo -e "${BOLD}${GREEN}${SUCCESS_ICON} StevenBlack hosts update completed successfully!${RESET}"
echo
info "The hosts file has been updated with the following extensions: ${BOLD}${EXTENSIONS}${RESET}"
info "You can find the generated hosts file in: ${HOSTS_REPO}/hosts"
if [ "$AUTO_FLUSH_DNS" -eq 1 ]; then
    success "DNS cache was automatically flushed - changes are now in effect"
else
    info "DNS cache was not flushed. Changes will take effect gradually."
    info "To flush manually: sudo systemctl restart systemd-resolved"
    info "Or run with --auto flag next time for automatic flush"
fi
echo
print_separator

exit 0