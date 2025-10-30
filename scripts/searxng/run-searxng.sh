#!/bin/bash
# Script to run the searxng web application

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

# ===== Configuration =====
SEARXNG_BASE="$HOME/Documentos/searxng"
SEARXNG_VENV="$SEARXNG_BASE/searxng-venv"
SEARXNG_APP="$SEARXNG_BASE/searxng"
WEBAPP_SCRIPT="$SEARXNG_APP/searx/webapp.py"
SEARXNG_PORT="${SEARXNG_PORT:-8888}"  # Default port, can be overridden

# ===== Appearance =====
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; red="\033[31m"; yellow="\033[33m"; reset="\033[0m"

echo -e "${bold}${blue}🚀 Starting SearxNG...${reset}"

# ===== Validation =====

# Check if base directory exists
if [ ! -d "$SEARXNG_BASE" ]; then
  echo -e "${bold}${red}Error: SearxNG directory not found: $SEARXNG_BASE${reset}"
  exit 1
fi

# Check if virtual environment exists
if [ ! -d "$SEARXNG_VENV" ]; then
  echo -e "${bold}${red}Error: Virtual environment not found: $SEARXNG_VENV${reset}"
  exit 1
fi

# Check if activation script exists
if [ ! -f "$SEARXNG_VENV/bin/activate" ]; then
  echo -e "${bold}${red}Error: Virtual environment activation script not found${reset}"
  exit 1
fi

# Check if webapp.py exists
if [ ! -f "$WEBAPP_SCRIPT" ]; then
  echo -e "${bold}${red}Error: webapp.py not found: $WEBAPP_SCRIPT${reset}"
  exit 1
fi

# Check if SearxNG is already running on the port
if command -v lsof &> /dev/null; then
  if lsof -Pi :$SEARXNG_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${bold}${yellow}⚠️  Warning: Port $SEARXNG_PORT is already in use.${reset}"
    echo -e "SearxNG may already be running. Use 'lsof -ti :$SEARXNG_PORT | xargs kill' to stop it."
    exit 1
  fi
elif command -v ss &> /dev/null; then
  if ss -ltn "sport = :$SEARXNG_PORT" | grep -q ":$SEARXNG_PORT"; then
    echo -e "${bold}${yellow}⚠️  Warning: Port $SEARXNG_PORT is already in use.${reset}"
    echo -e "SearxNG may already be running."
    exit 1
  fi
fi

# ===== Activation =====

echo -e "${bold}Activating virtual environment...${reset}"
# shellcheck disable=SC1091
source "$SEARXNG_VENV/bin/activate"

# Verify activation worked
if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo -e "${bold}${red}Error: Failed to activate virtual environment${reset}"
  exit 1
fi

echo -e "${bold}${green}✅ Virtual environment activated${reset}"

# ===== Cleanup handler =====
cleanup() {
  echo -e "\n${bold}${yellow}🛑 Shutting down SearxNG...${reset}"
  deactivate 2>/dev/null || true
  exit 0
}

trap cleanup SIGINT SIGTERM

# ===== Run SearxNG =====

echo -e "${bold}${green}✅ Starting SearxNG web application...${reset}"
echo -e "${bold}Access SearxNG at: http://localhost:$SEARXNG_PORT${reset}\n"

cd "$SEARXNG_APP" || exit 1
python3 searx/webapp.py

# Deactivate on normal exit
deactivate
