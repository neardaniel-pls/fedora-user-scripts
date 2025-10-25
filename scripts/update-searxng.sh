#!/bin/bash
# Script to update the searxng instance

set -euo pipefail

# ===== Appearance (colors) =====
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; reset="\033[0m"

echo -e "${bold}${blue}🚀 Updating searxng...${reset}"

# Navigate to the searxng directory
if [ -d "$HOME/Documentos/searxng/searxng" ]; then
  (
    cd "$HOME/Documentos/searxng/searxng" || exit
    echo -e "${bold}Checking for updates...${reset}"
    if git pull "https://github.com/searxng/searxng" | grep -q "Already up to date."; then
      echo -e "${bold}${green}✅ SearxNG is already up to date.${reset}"
    else
      echo -e "${bold}${green}✅ SearxNG updated successfully!${reset}"
    fi
  )
else
  echo "Error: Directory ~/Documentos/searxng/searxng not found."
  exit 1
fi