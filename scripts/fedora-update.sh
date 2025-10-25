#!/bin/bash
# Weekly Fedora maintenance: package updates (dnf/dnf5) and Flatpak,
# removal of unnecessary dependencies, and cache cleaning.
# Compatible with Fedora 42 (dnf5) and classic dnf (fallback).

set -euo pipefail

# ===== Appearance (colors) =====
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; yellow="\033[33m"; reset="\033[0m"

echo -e "${bold}${blue}🚀 Weekly Fedora maintenance (updates and cleaning)...${reset}"

# ===== Detect dnf5 vs classic dnf =====
if command -v dnf5 >/dev/null 2>&1; then
  DNF="dnf5"     # Fedora 42 uses dnf5 by default
else
  DNF="dnf"      # Fallback for systems still using classic dnf
fi

# Prefix with sudo (it is recommended to run the script in a shell with sudo configured)
PKG="sudo ${DNF}"

# ===== Update repository cache =====
# makecache --refresh forces the update of the local index/metadata [DNF/DNF5].
echo -e "${bold}📦 Updating repository cache...${reset}"
$PKG -y makecache --refresh

# ===== Update packages =====
# upgrade applies all available updates safely [DNF/DNF5].
echo -e "${bold}⬆️  Updating packages (upgrade)...${reset}"
$PKG -y upgrade

# ===== Remove unnecessary packages =====
# autoremove removes "leaf packages" that are no longer needed; installonly kernels are not removed [DNF5].
echo -e "${bold}🧹 Removing unnecessary packages (autoremove)...${reset}"
$PKG -y autoremove

# ===== Clean cache =====
# clean all removes temporary data and package/metadata cache to free up space [DNF5].
echo -e "${bold}🧽 Cleaning package cache (clean all)...${reset}"
$PKG -y clean all

# ===== Flatpak Update =====
# The recommended order is: 1) update AppStream metadata, 2) update apps/runtimes, 3) remove unused runtimes.
echo -e "${bold}📱 Updating Flatpaks...${reset}"
if command -v flatpak >/dev/null 2>&1; then
  # Update AppStream metadata (silently to reduce noise)
  flatpak update --appstream >/dev/null 2>&1 || true

  # Update installed apps and runtimes
  flatpak -y update || true

  # Remove unused runtimes/SDKs from installed apps
  flatpak -y uninstall --unused || true
else
  echo "ℹ️ Flatpak is not installed; skipping the Flatpaks section."
fi

# ===== SearxNG Update =====
if [ -f "$HOME/user-scripts/scripts/update-searxng.sh" ]; then
  echo -e "${bold}🔍 Updating SearxNG...${reset}"
  bash "$HOME/user-scripts/scripts/update-searxng.sh"
fi

# ===== Completion and convenience options =====
echo
echo "================================================================="
echo -e "${bold}${green}✅ Weekly maintenance completed!${reset}"
echo "================================================================="
echo
echo -e "${bold}What would you like to do now?${reset}"
echo "1) 🔄 Restart the system"
echo "2) ⚡ Shut down the system"
echo "3) 🚪 Exit"
read -r -t 30 -p "Choose (1-3): " opt || opt=3
case "$opt" in
  1) echo "Restarting...";   sudo reboot   ;;
  2) echo "Shutting down...";    sudo poweroff ;;
  3) echo "Exiting..."; exit 0 ;;
  *) echo "Invalid option. Exiting..."; exit 1 ;;
esac

