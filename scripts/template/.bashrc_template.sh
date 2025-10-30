# ==============================================================================
#                            CUSTOM BASH CONFIGURATION
# ==============================================================================
#
# File: .bashrc
# Description: User-specific terminal configuration file.
# This script is executed every time a new interactive terminal is opened.
#
# ==============================================================================
# 1. GLOBAL DEFINITIONS
# ==============================================================================

# Source global definitions from the system, if they exist.
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# ==============================================================================
# 2. USER ENVIRONMENT
# ==============================================================================

# Add local directories to the PATH if they are not already present.
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the line below to disable automatic pagination in systemctl.
# export SYSTEMD_PAGER=

# ==============================================================================
# 3. ALIASES AND FUNCTIONS
# ==============================================================================

# Source additional configuration files from ~/.bashrc.d if the directory exists.
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# ------------------------------------------------------------------------------
# ALIASES FOR SYSTEM AND FILE MANAGEMENT
# ------------------------------------------------------------------------------

# System maintenance and script execution
alias update='bash "$HOME/user-scripts/scripts/maintenance/fedora-update.sh"'
alias cleanmeta='bash "$HOME/user-scripts/scripts/maintenance/clean-metadata.sh"'
alias run_searxng='bash "$HOME/user-scripts/scripts/searxng/run-searxng.sh"'
alias security_sweep='sudo bash "$HOME/user-scripts/scripts/security/security-sweep.sh"'
alias bleachbit_automation='sudo bash "$HOME/user-scripts/scripts/testing/bleachbit-automation.sh"'

# File and directory management
alias ll='ls -lah'          # List files in long format with human-readable sizes
alias ..='cd ..'            # Go up one directory
alias ...='cd ../..'        # Go up two directories

# System resource monitoring
alias diskspace='df -h'     # Show disk space usage in a human-readable format
alias meminfo='free -m -l -t' # Show memory usage in megabytes

# Security-focused aliases
alias rm='rm -i'            # Prompt for confirmation before deleting files
alias cp='cp -i'            # Prompt for confirmation before overwriting files
alias mv='mv -i'            # Prompt for confirmation before overwriting files

# ------------------------------------------------------------------------------
# CUSTOM FUNCTIONS
# ------------------------------------------------------------------------------

# Create a directory and navigate into it
# Usage: mkcd <directory_name>
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

# ==============================================================================
# 4. TERMINAL STARTUP EXECUTION
# ==============================================================================

# Display system information when the terminal opens.
if command -v fastfetch &> /dev/null; then
    fastfetch
fi

# ==============================================================================
#                                END OF FILE
# ==============================================================================
