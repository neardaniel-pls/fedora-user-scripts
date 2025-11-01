#!/bin/bash

# Fedora maintenance: package updates (dnf/dnf5) and Flatpak,
# removal of unnecessary dependencies, and cache cleaning.
# Compatible with Fedora 42 (dnf5) and classic dnf (fallback).

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

# ===== Configuration =====
SEARXNG_UPDATE_SCRIPT="${HOME}/Documents/code/user-scripts/scripts/searxng/update-searxng.sh"

# ===== Appearance (colors) =====
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; yellow="\033[33m"; reset="\033[0m"

echo -e "${bold}${blue}🚀 Fedora maintenance (updates and cleaning)...${reset}"

# ===== Helper Functions =====
confirm_and_execute_destructive() {
    local action=$1
    local command=$2
    
    # Note: $command is intentionally unquoted for hardcoded internal use.
    # Only pass trusted, hardcoded commands (sudo reboot/poweroff).
    # For dynamic commands, refactor to use array-based argument passing.
    
    echo -e "${yellow}⚠️ About to $action the system.${reset}"
    read -r -t 10 -p "Type 'yes' to confirm: " confirmation
    if [ "$confirmation" = "yes" ]; then
        echo "$action in 5 seconds..."
        sleep 5
        sudo -k
        $command
    else
        echo "$action cancelled. Exiting..."
        exit 0
    fi
}

# ===== Verify sudo privileges upfront =====
echo "Verifying sudo privileges..."
sudo -v || { echo "Error: sudo authentication failed. Exiting."; exit 1; }

# ===== Detect dnf5 vs classic dnf =====
if command -v dnf5 >/dev/null 2>&1; then
    DNF="dnf5"  # Fedora 42 uses dnf5 by default
else
    DNF="dnf"   # Fallback for systems still using classic dnf
fi

PKG="sudo ${DNF}"

# ===== Update repository cache =====
echo -e "${bold}📦 Updating repository cache...${reset}"
if $PKG -y makecache --refresh; then
    echo -e "${green}✓ Repository cache updated${reset}"
else
    echo -e "${yellow}⚠️ Repository cache update encountered issues (status: $?)${reset}"
fi

# ===== Update packages =====
echo -e "${bold}⬆️ Updating packages (upgrade)...${reset}"
if $PKG -y upgrade; then
    echo -e "${green}✓ Package upgrade completed${reset}"
else
    echo -e "${yellow}⚠️ Package upgrade encountered issues (status: $?)${reset}"
fi

# ===== Remove unnecessary packages =====
echo -e "${bold}🧹 Removing unnecessary packages (autoremove)...${reset}"
if $PKG -y autoremove; then
    echo -e "${green}✓ Unnecessary packages removed${reset}"
else
    echo -e "${yellow}⚠️ Autoremove encountered issues (status: $?)${reset}"
fi

# ===== Clean cache =====
echo -e "${bold}🧽 Cleaning package cache (clean all)...${reset}"
if $PKG -y clean all; then
    echo -e "${green}✓ Package cache cleaned${reset}"
else
    echo -e "${yellow}⚠️ Cache cleaning encountered issues (status: $?)${reset}"
fi

# ===== Flatpak Update =====
echo -e "${bold}📱 Updating Flatpaks...${reset}"
if command -v flatpak >/dev/null 2>&1; then
    if flatpak update --appstream; then
        echo -e "${green}✓ AppStream metadata updated${reset}"
    else
        echo -e "${yellow}⚠️ AppStream update failed, continuing...${reset}"
    fi

    if flatpak -y update; then
        echo -e "${green}✓ Flatpak apps/runtimes updated${reset}"
    else
        echo -e "${yellow}⚠️ Flatpak update encountered issues, continuing...${reset}"
    fi

    if flatpak -y uninstall --unused; then
        echo -e "${green}✓ Unused Flatpaks removed${reset}"
    else
        echo -e "${yellow}⚠️ Flatpak cleanup failed, continuing...${reset}"
    fi
else
    echo "ℹ️ Flatpak is not installed; skipping the Flatpaks section."
fi

# ===== SearxNG Update =====
if [ -f "$SEARXNG_UPDATE_SCRIPT" ] && [ -O "$SEARXNG_UPDATE_SCRIPT" ]; then
    echo -e "${bold}🔍 Updating SearxNG...${reset}"
    
    # Verify file is executable and has safe permissions (user-only: 700)
    if [ -x "$SEARXNG_UPDATE_SCRIPT" ]; then
        # Use octal mode check for clarity (700 = rwx------)
        file_perms=$(stat -c '%a' "$SEARXNG_UPDATE_SCRIPT")
        
        # Accept 700, 750, or 755 (user executable, no other write access)
        if [[ "$file_perms" =~ ^7[0-5][0-5]$ ]]; then
            if bash "$SEARXNG_UPDATE_SCRIPT"; then
                echo -e "${green}✓ SearxNG updated${reset}"
            else
                echo -e "${yellow}⚠️ SearxNG update encountered issues (status: $?)${reset}"
            fi
        else
            echo -e "${yellow}⚠️ Warning: $SEARXNG_UPDATE_SCRIPT has insecure permissions ($file_perms). Run: chmod 700 \"$SEARXNG_UPDATE_SCRIPT\"${reset}"
        fi
    else
        echo -e "${yellow}⚠️ Warning: $SEARXNG_UPDATE_SCRIPT is not executable. Skipping.${reset}"
    fi
elif [ -f "$SEARXNG_UPDATE_SCRIPT" ]; then
    echo -e "${yellow}⚠️ Warning: $SEARXNG_UPDATE_SCRIPT is not owned by current user. Skipping.${reset}"
fi

# ===== Completion and user options =====
echo
echo "================================================================="
echo -e "${bold}${green}✅ Maintenance completed!${reset}"
echo "================================================================="
echo

# Loop until valid input received
while true; do
    echo -e "${bold}What would you like to do now?${reset}"
    echo "1) 🔄 Restart the system"
    echo "2) ⚡ Shut down the system"
    echo "3) 🚪 Exit"
    
    if read -r -t 30 -p "Choose (1-3): " opt 2>/dev/null; then
        case "$opt" in
            1)
                confirm_and_execute_destructive "RESTART" "sudo reboot"
                break
                ;;
            2)
                confirm_and_execute_destructive "SHUT DOWN" "sudo poweroff"
                break
                ;;
            3)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "${yellow}Invalid option. Please choose 1, 2, or 3.${reset}"
                continue
                ;;
        esac
    else
        # Timeout occurred
        echo -e "\n⏱️ No input received (timeout). Exiting..."
        exit 0
    fi
done
