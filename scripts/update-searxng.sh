#!/bin/bash
# Script to update the searxng instance

set -euo pipefail

# ===== Appearance (colors) =====
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; red="\033[31m"; reset="\033[0m"

echo -e "${bold}${blue}🚀 Updating searxng...${reset}"

# Navigate to the searxng directory
SEARXNG_DIR="$HOME/Documentos/searxng/searxng"

if [ ! -d "$SEARXNG_DIR" ]; then
  echo -e "${bold}${red}Error: Directory $SEARXNG_DIR not found.${reset}"
  exit 1
fi

cd "$SEARXNG_DIR" || exit 1

# Verify it's a git repository
if [ ! -d ".git" ]; then
  echo -e "${bold}${red}Error: Not a git repository.${reset}"
  exit 1
fi

# Verify remote origin
echo -e "${bold}Verifying repository...${reset}"
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ ! "$REMOTE_URL" =~ github\.com[:/]searxng/searxng ]]; then
  echo -e "${bold}${red}Error: Unexpected git remote origin: $REMOTE_URL${reset}"
  exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo -e "${bold}${red}Warning: You have uncommitted changes. Please commit or stash them first.${reset}"
  exit 1
fi

# Update the repository
echo -e "${bold}Checking for updates...${reset}"
if git pull origin main --ff-only 2>/dev/null || git pull origin master --ff-only 2>/dev/null; then
  if git diff --quiet HEAD@{1} HEAD 2>/dev/null; then
    echo -e "${bold}${green}✅ SearxNG is already up to date.${reset}"
  else
    echo -e "${bold}${green}✅ SearxNG updated successfully!${reset}"
  fi
else
  echo -e "${bold}${red}❌ Failed to update. Please check for conflicts or network issues.${reset}"
  exit 1
fi
