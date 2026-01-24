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
    readonly HOSTS_ICON="🌐"
    readonly UPDATE_ICON="🔄"
else
    # Set to empty strings when icons or colors are disabled
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
    readonly SECTION_ICON=""
    readonly START_ICON=""
    readonly HOSTS_ICON=""
    readonly UPDATE_ICON=""
fi

# --- Helper Functions ---
show_help() {
    # Use printf to properly handle escape codes
    printf '%b' "${BOLD}${GREEN}${START_ICON} StevenBlack Hosts Update Utility${RESET}\n"
    printf '\n'
    printf '%b' "${BOLD}USAGE:${RESET}\n"
    printf '    sudo ./update-hosts.sh [OPTIONS]\n'
    printf '\n'
    printf '%b' "${BOLD}OPTIONS:${RESET}\n"
    printf '    %b--help, -h%b       Show this help message and exit\n' "${BOLD}" "${RESET}"
    printf '    %b--auto%b           Automatically flush DNS cache after updating hosts file\n' "${BOLD}" "${RESET}"
    printf '\n'
    printf '%b' "${BOLD}DESCRIPTION:${RESET}\n"
    printf '    This script updates the StevenBlack hosts repository and generates a new hosts file\n'
    printf '    with specified extensions. It pulls the latest changes from the repository and then\n'
    printf '    runs the updateHostsFile.py script with the specified extensions.\n'
    printf '\n'
    printf '%b' "${BOLD}AVAILABLE EXTENSIONS:${RESET}\n"
    printf '    1. fakenews    - Block fake news websites\n'
    printf '    2. gambling    - Block gambling websites\n'
    printf '    3. porn        - Block adult content websites\n'
    printf '    4. social      - Block social media websites\n'
    printf '\n'
    printf '%b' "${BOLD}EXAMPLES:${RESET}\n"
    printf '    %b#%b Run with default extensions (gambling, porn)\n' "${GREEN}" "${RESET}"
    printf '    sudo ./update-hosts.sh\n'
    printf '\n'
    printf '    %b#%b Run with automatic DNS cache flush\n' "${GREEN}" "${RESET}"
    printf '    sudo ./update-hosts.sh --auto\n'
    printf '\n'
    printf '    %b#%b Use custom extensions via environment variable\n' "${GREEN}" "${RESET}"
    printf '    HOSTS_EXTENSIONS=fakenews,social sudo ./update-hosts.sh --auto\n'
    printf '\n'
    printf '%b' "${BOLD}ENVIRONMENT VARIABLES:${RESET}\n"
    printf '    %bHOSTS_EXTENSIONS%b    Comma-separated list of extensions to use\n' "${BOLD}" "${RESET}"
    printf '    %bHOSTS_REPO_PATH%b     Custom path to the hosts repository\n' "${BOLD}" "${RESET}"
    printf '    %bNO_COLOR%b            Disable colored output\n' "${BOLD}" "${RESET}"
    printf '    %bUSE_ICONS%b           Disable icons (set to 0)\n' "${BOLD}" "${RESET}"
    printf '\n'
    printf '%b' "${BOLD}DEPENDENCIES:${RESET}\n"
    printf '    - git: For repository operations\n'
    printf '    - python3: For running the updateHostsFile.py script\n'
    printf '    - StevenBlack/hosts repository in ~/Documents/code/hosts\n'
    printf '\n'
    printf '%b' "${BOLD}DNS CACHE FLUSH:${RESET}\n"
    printf '    When using the %b--auto%b flag, the script will automatically flush the\n' "${BOLD}" "${RESET}"
    printf '    DNS cache for immediate effect. Without this flag, you may need to manually\n'
    printf '    flush the cache using one of these commands:\n'
    printf '\n'
    printf '    %bsudo systemctl restart systemd-resolved%b\n' "${GREEN}" "${RESET}"
    printf '    %bsudo systemctl restart nscd%b\n' "${GREEN}" "${RESET}"
    printf '    %bsudo systemctl restart dnsmasq%b\n' "${GREEN}" "${RESET}"
    printf '\n'
    printf '%b' "${BOLD}EXIT CODES:${RESET}\n"
    printf '    0    Success\n'
    printf '    1    Error\n'
    printf '\n'
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
cd "$HOSTS_REPO"

# Fix permissions first if running as sudo
if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER":"$(id -gn "$SUDO_USER")" .
fi

# Stash any local changes before pulling
if [ -n "${SUDO_USER:-}" ]; then
    # Run git as the original user, not root
    if sudo -u "$SUDO_USER" git status --porcelain | grep -q .; then
        info "Local changes detected, stashing them before update..."
        if sudo -u "$SUDO_USER" git stash push -m "Auto-stash before update $(date)"; then
            success "Local changes stashed successfully"
        else
            warning "Failed to stash local changes, continuing anyway..."
        fi
    else
        info "No local changes to stash"
    fi
    
    # Pull the latest changes from the repository
    if sudo -u "$SUDO_USER" git pull; then
        print_operation_end "Repository updated successfully"
        success "Repository updated with latest changes"
        
        # Check if we stashed changes and offer to restore them
        if sudo -u "$SUDO_USER" git stash list | grep -q "Auto-stash before update"; then
            info "Previously stashed changes found. You can restore them later with:"
            echo -e "${BOLD}${YELLOW}cd $HOSTS_REPO && git stash pop${RESET}"
        fi
    else
        error "Failed to update the repository"
        exit 1
    fi
else
    # Run as current user
    if git status --porcelain | grep -q .; then
        info "Local changes detected, stashing them before update..."
        if git stash push -m "Auto-stash before update $(date)"; then
            success "Local changes stashed successfully"
        else
            warning "Failed to stash local changes, continuing anyway..."
        fi
    else
        info "No local changes to stash"
    fi
    
    # Pull the latest changes from the repository
    if git pull; then
        print_operation_end "Repository updated successfully"
        success "Repository updated with latest changes"
        
        # Check if we stashed changes and offer to restore them
        if git stash list | grep -q "Auto-stash before update"; then
            info "Previously stashed changes found. You can restore them later with:"
            echo -e "${BOLD}${YELLOW}cd $HOSTS_REPO && git stash pop${RESET}"
        fi
    else
        error "Failed to update the repository"
        exit 1
    fi
fi
print_separator

# ===== Update hosts file =====
print_section_header "HOSTS FILE GENERATION" "${HOSTS_ICON}"
print_operation_start "Generating hosts file with extensions: $EXTENSIONS"

# Change to the hosts repository directory if not already there
cd "$HOSTS_REPO"

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
CMD="python3 updateHostsFile.py --auto --replace --extensions $EXTENSIONS"

# Execute the command
if $CMD; then
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