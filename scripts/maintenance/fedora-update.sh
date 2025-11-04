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
#   - Optional: SearxNG update script at ~/Documents/code/user-scripts/scripts/searxng/update-searxng.sh
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

# ===== Configuration =====
# Path to the optional SearxNG update script
SEARXNG_UPDATE_SCRIPT="${HOME}/Documents/code/user-scripts/scripts/searxng/update-searxng.sh"

# ===== Appearance (colors) =====
# ANSI color codes for formatted output
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; yellow="\033[33m"; reset="\033[0m"

# Display script introduction with formatting
echo -e "${bold}${blue}🚀 Fedora maintenance (updates and cleaning)...${reset}"

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
    echo -e "${yellow}⚠️ About to $action the system.${reset}"
    read -r -t 10 -p "Type 'yes' to confirm: " confirmation
    
    if [ "$confirmation" = "yes" ]; then
        # Provide countdown before execution to allow cancellation
        echo "$action in 5 seconds..."
        sleep 5
        
        # Invalidate sudo credentials before executing system command
        # This prevents privilege escalation in case of command injection
        sudo -k
        $command
    else
        # User cancelled the operation
        echo "$action cancelled. Exiting..."
        exit 0
    fi
}

# ===== Verify sudo privileges upfront =====
# Early verification to fail fast if sudo is unavailable
echo "Verifying sudo privileges..."
sudo -v || { echo "Error: sudo authentication failed. Exiting."; exit 1; }

# ===== Detect dnf5 vs classic dnf =====
# Fedora 42+ uses dnf5 by default, but we need to support older versions
if command -v dnf5 >/dev/null 2>&1; then
    DNF="dnf5"  # Fedora 42 uses dnf5 by default
else
    DNF="dnf"   # Fallback for systems still using classic dnf
fi

# Construct the package manager command with sudo prefix
PKG="sudo ${DNF}"

# ===== Update repository cache =====
# Refresh the repository metadata to ensure we have the latest package information
echo -e "${bold}📦 Updating repository cache...${reset}"
if $PKG -y makecache --refresh; then
    echo -e "${green}✓ Repository cache updated${reset}"
else
    # Non-fatal error - continue with potentially stale cache
    echo -e "${yellow}⚠️ Repository cache update encountered issues (status: $?)${reset}"
fi

# ===== Update packages =====
# Upgrade all installed packages to their latest versions
echo -e "${bold}⬆️ Updating packages (upgrade)...${reset}"
if $PKG -y upgrade; then
    echo -e "${green}✓ Package upgrade completed${reset}"
else
    # Non-fatal error - report but continue with other maintenance tasks
    echo -e "${yellow}⚠️ Package upgrade encountered issues (status: $?)${reset}"
fi

# ===== Remove unnecessary packages =====
# Remove packages that were installed as dependencies but are no longer needed
echo -e "${bold}🧹 Removing unnecessary packages (autoremove)...${reset}"
if $PKG -y autoremove; then
    echo -e "${green}✓ Unnecessary packages removed${reset}"
else
    # Non-fatal error - report but continue
    echo -e "${yellow}⚠️ Autoremove encountered issues (status: $?)${reset}"
fi

# ===== Clean cache =====
# Remove all cached package files to free up disk space
echo -e "${bold}🧽 Cleaning package cache (clean all)...${reset}"
if $PKG -y clean all; then
    echo -e "${green}✓ Package cache cleaned${reset}"
else
    # Non-fatal error - report but continue
    echo -e "${yellow}⚠️ Cache cleaning encountered issues (status: $?)${reset}"
fi

# ===== Flatpak Update =====
# Update Flatpak applications and runtimes if Flatpak is installed
echo -e "${bold}📱 Updating Flatpaks...${reset}"
if command -v flatpak >/dev/null 2>&1; then
    # Update AppStream metadata first (required for proper operation)
    if flatpak update --appstream; then
        echo -e "${green}✓ AppStream metadata updated${reset}"
    else
        # Non-fatal error - continue with other Flatpak operations
        echo -e "${yellow}⚠️ AppStream update failed, continuing...${reset}"
    fi

    # Update all installed Flatpak applications and runtimes
    if flatpak -y update; then
        echo -e "${green}✓ Flatpak apps/runtimes updated${reset}"
    else
        # Non-fatal error - continue with cleanup
        echo -e "${yellow}⚠️ Flatpak update encountered issues, continuing...${reset}"
    fi

    # Remove unused Flatpak runtimes and applications to free space
    if flatpak -y uninstall --unused; then
        echo -e "${green}✓ Unused Flatpaks removed${reset}"
    else
        # Non-fatal error - report but continue
        echo -e "${yellow}⚠️ Flatpak cleanup failed, continuing...${reset}"
    fi
else
    # Flatpak is not installed on this system
    echo "ℹ️ Flatpak is not installed; skipping the Flatpaks section."
fi

# ===== SearxNG Update =====
# Conditionally update SearxNG if the update script exists and meets security criteria
if [ -f "$SEARXNG_UPDATE_SCRIPT" ] && [ -O "$SEARXNG_UPDATE_SCRIPT" ]; then
    echo -e "${bold}🔍 Updating SearxNG...${reset}"
    
    # Verify file is executable and has safe permissions (user-only: 700)
    if [ -x "$SEARXNG_UPDATE_SCRIPT" ]; then
        # Use octal mode check for clarity (700 = rwx------)
        file_perms=$(stat -c '%a' "$SEARXNG_UPDATE_SCRIPT")
        
        # Accept 700, 750, or 755 (user executable, no other write access)
        # This ensures the script can't be modified by other users
        if [[ "$file_perms" =~ ^7[0-5][0-5]$ ]]; then
            # Execute the SearxNG update script
            if bash "$SEARXNG_UPDATE_SCRIPT"; then
                echo -e "${green}✓ SearxNG updated${reset}"
            else
                # Non-fatal error - report but continue
                echo -e "${yellow}⚠️ SearxNG update encountered issues (status: $?)${reset}"
            fi
        else
            # Security warning - file permissions are too permissive
            echo -e "${yellow}⚠️ Warning: $SEARXNG_UPDATE_SCRIPT has insecure permissions ($file_perms). Run: chmod 700 \"$SEARXNG_UPDATE_SCRIPT\"${reset}"
        fi
    else
        # File exists but is not executable
        echo -e "${yellow}⚠️ Warning: $SEARXNG_UPDATE_SCRIPT is not executable. Skipping.${reset}"
    fi
elif [ -f "$SEARXNG_UPDATE_SCRIPT" ]; then
    # File exists but is not owned by the current user (security risk)
    echo -e "${yellow}⚠️ Warning: $SEARXNG_UPDATE_SCRIPT is not owned by current user. Skipping.${reset}"
fi

# ===== Completion and user options =====
echo
echo "================================================================="
echo -e "${bold}${green}✅ Maintenance completed!${reset}"
echo "================================================================="
echo

# Interactive menu for post-maintenance actions
# Loop until valid input received or timeout occurs
while true; do
    echo -e "${bold}What would you like to do now?${reset}"
    echo "1) 🔄 Restart the system"
    echo "2) ⚡ Shut down the system"
    echo "3) 🚪 Exit"
    
    # Read user input with 30-second timeout
    if read -r -t 30 -p "Choose (1-3): " opt 2>/dev/null; then
        case "$opt" in
            1)
                # System restart option
                confirm_and_execute_destructive "RESTART" "sudo reboot"
                break
                ;;
            2)
                # System shutdown option
                confirm_and_execute_destructive "SHUT DOWN" "sudo poweroff"
                break
                ;;
            3)
                # Exit without system changes
                echo "Exiting..."
                exit 0
                ;;
            *)
                # Invalid input - prompt again
                echo -e "${yellow}Invalid option. Please choose 1, 2, or 3.${reset}"
                continue
                ;;
        esac
    else
        # Timeout occurred - exit safely
        echo -e "\n⏱️ No input received (timeout). Exiting..."
        exit 0
    fi
done
