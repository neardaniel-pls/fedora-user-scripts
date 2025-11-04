#!/bin/bash
#
# bleachbit-automation.sh
#
# Automates system cleaning using the BleachBit command-line interface.
# This script provides a structured and safe way to run BleachBit with a predefined set of cleaners.
#

# Source shared colors library
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/colors.sh"

set -euo pipefail

# ===== Core Functions =====

check_dependencies() {
    info "Checking for required tools..."
    if ! command -v bleachbit &> /dev/null; then
        error "Dependency 'bleachbit' is not installed."
        error "Please install BleachBit and try again."
        exit 1
    fi
    success "All dependencies are installed."
}

run_bleachbit_clean() {
    info "Starting BleachBit cleaning process..."
    
    # Define the list of cleaners to use.
    # ⚠️  WARNING: Carefully review before enabling any cleaner.
    # Password cleaners are ENABLED by default - they PERMANENTLY delete saved credentials!
    # Always export/backup passwords before enabling these cleaners.
    
    local cleaners=(
      # ========================================
      # SYSTEM CLEANERS (generally safe)
      # ========================================
      system.cache                  # Clear system cache
      system.clipboard              # Clear clipboard content
      system.memory                 # Clear system memory and swap
      system.recent_documents       # Clear recently used document list
      system.rotated_logs           # Delete rotated system logs
      system.tmp                    # Delete temporary files
      system.trash                  # Empty the trash can
      system.localizations          # Delete unused language packs (frees 200-500 MB)
      thumbnails.cache              # Clear thumbnail cache


      # ========================================
      # FEDORA PACKAGE MANAGER CLEANERS
      # ========================================
      # ℹ️  Use yum.clean_all instead of dnf.* cleaners (more reliable on Fedora)
      dnf.clean_all                 # Clean YUM/DNF package cache (works on Fedora)


      # ========================================
      # SHELL CLEANERS
      # ========================================
      # bash.history                # ⚠️  DESTRUCTIVE: Clears your command history permanently


      # ========================================
      # DEEP SCAN CLEANERS (use with caution)
      # ========================================
      # deep_scan.backup            # ⚠️  May delete important backup files
      # deep_scan.ds_store          # ℹ️  Remove macOS .DS_Store files
      # deep_scan.thumbs_db         # ℹ️  Remove Windows Thumbs.db files
      # deep_scan.tmp               # ⚠️  Deep scan for scattered temporary files


      # ========================================
      # FIREFOX CLEANERS (mostly safe for privacy)
      # ========================================
      firefox.cache                 # Clear Firefox cache
      firefox.cookies               # Delete Firefox cookies
      firefox.crash_reports         # Delete Firefox crash reports
      firefox.dom_storage           # Clear Firefox DOM storage
      firefox.download_history      # Clear Firefox download history
      firefox.forms                 # Clear saved form history in Firefox
      firefox.session_restore       # Clear Firefox session restore data
      firefox.site_preferences      # Delete Firefox site-specific preferences
      firefox.url_history           # Clear Firefox browsing history
      # firefox.passwords           # 🚨 DANGER: Permanently deletes ALL saved passwords!
      # firefox.vacuum              # ℹ️  Vacuum Firefox databases for performance (optional)
      # firefox.backup              # ℹ️  Delete Firefox backup files (optional)


      # ========================================
      # GOOGLE CHROME CLEANERS
      # ========================================
      google_chrome.cache           # Clear Google Chrome cache
      google_chrome.cookies         # Delete Google Chrome cookies
      google_chrome.form_history    # Clear saved form history
      google_chrome.history         # Clear Google Chrome browsing history
      google_chrome.search_engines  # Clear custom search engines
      google_chrome.session         # Clear Google Chrome session data
      # google_chrome.passwords     # 🚨 DANGER: Permanently deletes ALL saved passwords!
      # google_chrome.vacuum        # ℹ️  Vacuum Chrome databases for performance (optional)


      # ========================================
      # THUNDERBIRD CLEANERS
      # ========================================
      thunderbird.cache             # Clear Thunderbird cache
      thunderbird.cookies           # Delete Thunderbird cookies
      thunderbird.url_history       # Clear Thunderbird URL history
      # thunderbird.passwords       # 🚨 DANGER: Permanently deletes email account passwords!
      # thunderbird.vacuum          # ℹ️  Vacuum Thunderbird databases for performance (optional)


      # ========================================
      # VLC MEDIA PLAYER CLEANER
      # ========================================
      vlc.mru                       # Clear VLC's most recently used files list


      # ========================================
      # X11 DISPLAY SERVER
      # ========================================
      x11.debug_logs                # Delete X11 debug logs


      # ========================================
      # OPTIONAL DESKTOP ENVIRONMENT CLEANERS
      # ========================================
      # Uncomment if using GNOME Desktop:
      # gnome.search_history        # Clear GNOME search history
      # gnome.run_history           # Clear GNOME run dialog history

      # Uncomment if using KDE Plasma:
      # kde.cache                   # Clear KDE cache
      # kde.recent_documents        # Clear KDE recent documents
      # kde.tmp                     # Clear KDE temporary files


      # ========================================
      # CUSTOM CLEANERS (requires configuration)
      # ========================================
      # system.custom               # ⚠️  Delete custom files - MUST CONFIGURE FIRST
      # system.free_disk_space      # ⚠️  SLOW: Overwrites free space (anti-forensics - very slow!)
    )


    # Validation: Warn if dangerous cleaners are enabled
    local dangerous_cleaners=("firefox.passwords" "google_chrome.passwords" "thunderbird.passwords" "bash.history")
    for dangerous in "${dangerous_cleaners[@]}"; do
        for cleaner in "${cleaners[@]}"; do
            if [[ "$cleaner" == "$dangerous" ]]; then
                warning "DANGEROUS CLEANER ENABLED: $cleaner - This will permanently delete data!"
                read -p "Are you sure you want to proceed? (yes/no): " -r confirm
                if [[ ! "$confirm" =~ ^[Yy][Ee][Ss]$ ]]; then
                    error "Aborted by user due to dangerous cleaner: $cleaner"
                    exit 1
                fi
            fi
        done
    done
    
    # Validate cleaner names (defense-in-depth)
    local name_regex='^[a-z0-9_]+\.[a-z0-9_]+$'
    for cleaner in "${cleaners[@]}"; do
        if [[ ! "$cleaner" =~ $name_regex ]]; then
            error "Invalid cleaner name detected: $cleaner"
            exit 1
        fi
    done

    info "Executing BleachBit with ${#cleaners[@]} cleaners..."
    
    # Execute with detailed error handling
    local output
    local exit_code
    
    set +e
    output=$(sudo bleachbit --clean "${cleaners[@]}" 2>&1)
    exit_code=$?
    set -e
    
    case $exit_code in
        0)
            success "BleachBit cleaning completed successfully."
            echo -e "BleachBit output:\n---\n$output\n---"
            ;;
        1)
            warning "BleachBit completed with warnings."
            echo -e "BleachBit output:\n---\n$output\n---"
            ;;
        126)
            error "Permission denied executing BleachBit."
            exit 1
            ;;
        127)
            error "BleachBit command not found."
            exit 1
            ;;
        *)
            error "BleachBit failed with exit code: $exit_code"
            echo -e "BleachBit output:\n---\n$output\n---" >&2
            exit 1
            ;;
    esac
    echo
}

# ===== Main Function =====
cleanup() {
    error "Script interrupted. No cleanup needed."
    exit 1
}

main() {
    trap cleanup SIGINT SIGTERM

    clear
    echo -e "${BOLD}${BLUE}${INFO_ICON} Starting BleachBit Automation...${RESET}"

    print_header "Initializing Cleaner"
    check_dependencies
    print_separator
    echo

    run_bleachbit_clean

    success "BleachBit automation finished!"
    info "Review the output above for detailed results."
}

# ===== Script Execution =====
# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root. Please use sudo."
  exit 1
fi

main "$@"