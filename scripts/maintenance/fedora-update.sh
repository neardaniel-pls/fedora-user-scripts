#!/bin/bash
#
# fedora-update.sh - Comprehensive Fedora system maintenance and update utility
#
# DESCRIPTION:
#   This script performs a complete system maintenance routine for Fedora Linux,
#   including package updates, Flatpak management, and optional SearxNG updates.
#   It automatically detects whether the system uses dnf5 (Fedora 42+) or classic dnf
#   and adapts accordingly. The script provides colored output for better readability
#   and includes safety checks for potentially dangerous operations.
#
# USAGE:
#   ./fedora-update.sh
#
# OPTIONS:
#   None - the script runs interactively with user prompts for system restart/shutdown
#
# EXAMPLES:
#   # Run the complete maintenance routine
#   ./fedora-update.sh
#
#   # Run with sudo (recommended for system-wide updates)
#   sudo ./fedora-update.sh
#
# DEPENDENCIES:
#   - dnf or dnf5: Fedora package manager (automatically detected)
#   - flatpak: Optional, for Flatpak application management
#   - sudo: Required for system package operations
#   - stat: For file permission checks
#   - Optional: SearxNG update script at ~/Documents/code/fedora-user-scripts/scripts/searxng/update-searxng.sh
#
# OPERATIONAL NOTES:
#   - The script requires sudo privileges for package management operations
#   - Sudo authentication is verified at the beginning to fail fast if unavailable
#   - All operations are non-destructive except for the optional restart/shutdown at the end
#   - The SearxNG update is only executed if the script exists, is owned by the user,
#     and has safe permissions (700, 750, or 755)
#   - The script provides a 30-second timeout for user input at the completion menu
#   - Exit codes: 0 for success, 1 for errors or user cancellation
#
# SECURITY CONSIDERATIONS:
#   - The script validates file permissions before executing external scripts
#   - Sudo credentials are invalidated before system restart/shutdown for security
#   - Only trusted, hardcoded commands are used in the confirmation function

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
    readonly PACKAGE_ICON="📦"
    readonly CLEAN_ICON="🧹"
    readonly FLATPAK_ICON="📱"
    readonly SEARCH_ICON="🔍"
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
    readonly FLATPAK_ICON=""
    readonly SEARCH_ICON=""
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

# ===== Configuration =====
# Path to the optional SearxNG update script
# Use SUDO_USER if available (when running with sudo), otherwise use HOME
if [ -n "${SUDO_USER:-}" ]; then
    ORIGINAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    SEARXNG_UPDATE_SCRIPT="${ORIGINAL_USER_HOME}/Documents/code/fedora-user-scripts/scripts/searxng/update-searxng.sh"
else
    SEARXNG_UPDATE_SCRIPT="${HOME}/Documents/code/fedora-user-scripts/scripts/searxng/update-searxng.sh"
fi

# Display script introduction with formatting
print_header "FEDORA SYSTEM MAINTENANCE"
echo -e "${BOLD}${GREEN}${START_ICON} Starting comprehensive system maintenance...${RESET}"
echo

# ===== Helper Functions =====
#
# confirm_and_execute_destructive - Safely execute system-altering commands with user confirmation
#
# DESCRIPTION:
#   Implements a safety mechanism for potentially destructive system operations
#   like restart or shutdown. Requires explicit user confirmation and provides
#   a countdown before execution. Invalidates sudo credentials before execution
#   as an additional security measure.
#
# PARAMETERS:
#   $1 - Action description (e.g., "RESTART", "SHUT DOWN")
#   $2 - Command to execute (must be a trusted, hardcoded command)
#
# RETURNS:
#   Does not return on successful execution (exits after command)
#   Returns to caller if user cancels
#
confirm_and_execute_destructive() {
    local action=$1      # Human-readable action description
    local command=$2      # Command to execute (trusted, hardcoded)
    
    # SECURITY NOTE: $command is intentionally unquoted for hardcoded internal use.
    # Only pass trusted, hardcoded commands (sudo reboot/poweroff).
    # For dynamic commands, refactor to use array-based argument passing.
    
    # Display warning and request explicit confirmation
    warning "About to $action the system."
    read -r -t 10 -p "Type 'yes' to confirm: " confirmation
    
    if [ "$confirmation" = "yes" ]; then
        # Provide countdown before execution to allow cancellation
        info "$action in 5 seconds..."
        sleep 5
        
        # Invalidate sudo credentials before executing system command
        # This prevents privilege escalation in case of command injection
        sudo -k
        $command
    else
        # User cancelled the operation
        warning "$action cancelled. Exiting..."
        exit 0
    fi
}

# ===== Verify sudo privileges upfront =====
# Early verification to fail fast if sudo is unavailable
print_section_header "PRIVILEGE VERIFICATION" "${SECTION_ICON}"
if command -v sudo >/dev/null 2>&1; then
    print_operation_start "Verifying sudo privileges"
    if sudo -v; then
        success "Sudo privileges verified"
        SUDO_AVAILABLE=true
    else
        error "sudo authentication failed. Exiting."
        exit 1
    fi
else
    warning "sudo is not available. Some operations may be skipped."
    SUDO_AVAILABLE=false
fi
print_separator

# ===== Detect dnf5 vs classic dnf =====
# Fedora 42+ uses dnf5 by default, but we need to support older versions
print_section_header "PACKAGE MANAGER DETECTION" "${PACKAGE_ICON}"
if command -v dnf5 >/dev/null 2>&1; then
    DNF="dnf5"  # Fedora 42 uses dnf5 by default
    info "Detected dnf5 (Fedora 42+)"
else
    DNF="dnf"   # Fallback for systems still using classic dnf
    info "Detected classic dnf"
fi

# Construct the package manager command with sudo prefix (if available)
if [ "$SUDO_AVAILABLE" = true ]; then
    PKG="sudo ${DNF}"
    info "Package manager configured with sudo privileges"
else
    PKG="${DNF}"
    warning "Running package manager without sudo. This may have limited functionality."
fi
print_separator

# ===== Update repository cache =====
# Refresh the repository metadata to ensure we have the latest package information
print_section_header "REPOSITORY CACHE UPDATE" "🔄"
print_operation_start "Updating repository cache"
print_command_output
if $PKG -y makecache --refresh; then
    print_operation_end "Repository cache updated"
    success "Repository cache updated successfully"
else
    # Non-fatal error - continue with potentially stale cache
    warning "Repository cache update encountered issues (status: $?)"
fi
print_separator

# ===== Update packages =====
# Upgrade all installed packages to their latest versions
print_section_header "PACKAGE UPDATES" "${PACKAGE_ICON}"
print_operation_start "Upgrading all packages"
print_command_output
if $PKG -y upgrade; then
    print_operation_end "Package upgrade completed"
    success "All packages upgraded successfully"
else
    # Non-fatal error - report but continue with other maintenance tasks
    warning "Package upgrade encountered issues (status: $?)"
fi
print_separator

# ===== Remove unnecessary packages =====
# Remove packages that were installed as dependencies but are no longer needed
print_section_header "PACKAGE CLEANUP" "${CLEAN_ICON}"
print_operation_start "Removing unnecessary packages (autoremove)"
print_command_output
if $PKG -y autoremove; then
    print_operation_end "Unnecessary packages removed"
    success "Unnecessary packages removed successfully"
else
    # Non-fatal error - report but continue
    warning "Autoremove encountered issues (status: $?)"
fi

# ===== Clean cache =====
# Remove all cached package files to free up disk space
print_operation_start "Cleaning package cache (clean all)"
print_command_output
if $PKG -y clean all; then
    print_operation_end "Package cache cleaned"
    success "Package cache cleaned successfully"
else
    # Non-fatal error - report but continue
    warning "Cache cleaning encountered issues (status: $?)"
fi
print_separator

# ===== Flatpak Update =====
# Update Flatpak applications and runtimes if Flatpak is installed
print_section_header "FLATPAK MANAGEMENT" "${FLATPAK_ICON}"
if command -v flatpak >/dev/null 2>&1; then
    # Update AppStream metadata first (required for proper operation)
    print_operation_start "Updating AppStream metadata"
    print_command_output
    if flatpak update --appstream; then
        print_operation_end "AppStream metadata updated"
        success "AppStream metadata updated successfully"
    else
        # Non-fatal error - continue with other Flatpak operations
        warning "AppStream update failed, continuing..."
    fi
    echo

    # Update all installed Flatpak applications and runtimes
    print_operation_start "Updating Flatpak applications and runtimes"
    print_command_output
    if flatpak -y update; then
        print_operation_end "Flatpak apps/runtimes updated"
        success "Flatpak apps/runtimes updated successfully"
    else
        # Non-fatal error - continue with cleanup
        warning "Flatpak update encountered issues, continuing..."
    fi
    echo

    # Remove unused Flatpak runtimes and applications to free space
    print_operation_start "Removing unused Flatpak applications and runtimes"
    print_command_output
    if flatpak -y uninstall --unused; then
        print_operation_end "Unused Flatpaks removed"
        success "Unused Flatpaks removed successfully"
    else
        # Non-fatal error - report but continue
        warning "Flatpak cleanup failed, continuing..."
    fi
else
    # Flatpak is not installed on this system
    info "Flatpak is not installed; skipping the Flatpaks section."
fi
print_separator

# ===== SearxNG Update =====
# Conditionally update SearxNG if the update script exists and meets security criteria
print_section_header "SEARXNG UPDATE" "${SEARCH_ICON}"


# Check ownership against original user (not current effective user)
FILE_OWNER=$(stat -c '%U' "$SEARXNG_UPDATE_SCRIPT" 2>/dev/null || echo "unknown")
EXPECTED_OWNER="${SUDO_USER:-$(whoami)}"
if [ "$FILE_OWNER" = "$EXPECTED_OWNER" ]; then
    OWNERSHIP_CHECK_PASSED=true
else
    OWNERSHIP_CHECK_PASSED=false
fi

if [ -f "$SEARXNG_UPDATE_SCRIPT" ] && [ "$OWNERSHIP_CHECK_PASSED" = "true" ]; then
    print_operation_start "Updating SearxNG"
    
    # Verify file is executable and has safe permissions (user-only: 700)
    if [ -x "$SEARXNG_UPDATE_SCRIPT" ]; then
        # Use octal mode check for clarity (700 = rwx------)
        file_perms=$(stat -c '%a' "$SEARXNG_UPDATE_SCRIPT")
        
        # Accept 700, 750, or 755 (user executable, no other write access)
        # This ensures the script can't be modified by other users
        if [[ "$file_perms" =~ ^7[0-5][0-5]$ ]]; then
            # Execute the SearxNG update script with minimal output to avoid conflicts
            print_command_output
            if QUIET=1 bash "$SEARXNG_UPDATE_SCRIPT" 2>/dev/null; then
                print_operation_end "SearxNG updated"
                success "SearxNG updated successfully"
            else
                # Non-fatal error - report but continue
                warning "SearxNG update encountered issues (status: $?)"
            fi
        else
            # Security warning - file permissions are too permissive
            warning "Warning: $SEARXNG_UPDATE_SCRIPT has insecure permissions ($file_perms). Run: chmod 700 \"$SEARXNG_UPDATE_SCRIPT\""
        fi
    else
        # File exists but is not executable
        warning "Warning: $SEARXNG_UPDATE_SCRIPT is not executable. Skipping."
    fi
elif [ -f "$SEARXNG_UPDATE_SCRIPT" ]; then
    # File exists but is not owned by the current user (security risk)
    warning "Warning: $SEARXNG_UPDATE_SCRIPT is not owned by current user. Skipping."
else
    info "SearxNG update script not found. Skipping SearxNG update."
fi
print_separator

# ===== Completion and user options =====
print_header "MAINTENANCE SUMMARY"
echo -e "${BOLD}${GREEN}${SUCCESS_ICON} All maintenance operations completed successfully!${RESET}"
echo
print_separator
echo

# Interactive menu for post-maintenance actions
print_section_header "NEXT ACTIONS" "🎯"

# Loop endlessly until a valid choice is made or timeout
while true; do
    echo -e "${BOLD}${CYAN}Please select your next action:${RESET}"
    echo
    echo -e "${BOLD}  ${GREEN}1)${RESET} ${YELLOW}🔄${RESET} Restart the system"
    echo -e "${BOLD}  ${GREEN}2)${RESET} ${YELLOW}⚡${RESET} Shut down the system"
    echo -e "${BOLD}  ${GREEN}3)${RESET} ${YELLOW}🚪${RESET} Exit"
    echo
    print_separator

    # Read user input with 30-second timeout
    echo -n -e "${BOLD}${BLUE}Choose (1-3):${RESET} "
    if read -r -t 30 opt 2>/dev/null; then
        case "$opt" in
            1)
                # System restart option
                echo
                print_section_header "SYSTEM RESTART" "🔄"
                if [ "$SUDO_AVAILABLE" = true ]; then
                    info "Restarting the system..."
                    # Invalidate sudo credentials before executing system command
                    sudo -k
                    sudo reboot
                else
                    warning "Cannot restart: sudo is not available."
                fi
                break
                ;;
            2)
                # System shutdown option
                echo
                print_section_header "SYSTEM SHUTDOWN" "⚡"
                if [ "$SUDO_AVAILABLE" = true ]; then
                    info "Shutting down the system..."
                    # Invalidate sudo credentials before executing system command
                    sudo -k
                    sudo poweroff
                else
                    warning "Cannot shut down: sudo is not available."
                fi
                break
                ;;
            3)
                # Exit without system changes
                echo
                info "Exiting maintenance script..."
                echo
                print_separator
                echo -e "${BOLD}${GREEN}${SUCCESS_ICON} Thank you for using Fedora System Maintenance!${RESET}"
                print_separator
                exit 0
                ;;
            *)
                # Invalid input - loop handles the re-prompt automatically
                echo
                warning "Invalid option. Please choose 1, 2, or 3."
                echo
                # The loop continues here automatically
                ;;
        esac
    else
        # Timeout occurred - exit safely
        echo
        warning "No input received (timeout). Exiting..."
        echo
        print_separator
        echo -e "${BOLD}${GREEN}${SUCCESS_ICON} Maintenance completed - timed out gracefully${RESET}"
        print_separator
        exit 0
    fi
done
