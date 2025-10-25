#!/bin/bash
#
# security-sweep.sh
#
# A comprehensive security sweep script for Fedora systems.
# This script performs the following checks:
# 1. System File Integrity Check (rpm -Va)
# 2. Rootkit Scan (chkrootkit)
# 3. Malware Scan (ClamAV)
# 4. Security Audit (Lynis)
# 5. Package & Dependency Verification (dnf check)
#

set -euo pipefail

# ===== Appearance (colors) =====
bold="\033[1m"; blue="\033[34m"; green="\033[32m"; yellow="\033[33m"; red="\033[31m"; reset="\033[0m"

# ===== Log file =====
LOG_FILE="/var/log/security-sweep-$(date +%Y%m%d-%H%M%S).log"

# ===== Status Variables =====
integrity_status="Not Run"
rootkit_status="Not Run"
malware_status="Not Run"
audit_status="Not Run"
package_status="Not Run"
exclude_home=0

# ===== Helper Functions =====
log_message() {
    # Logs to file without color codes
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${level}: ${message}" >> "$LOG_FILE"
}

info() {
    echo -e "${bold}${blue}ℹ️  $1${reset}"
    log_message "INFO" "$1"
}

success() {
    echo -e "${bold}${green}✅ $1${reset}"
    log_message "SUCCESS" "$1"
}

warning() {
    echo -e "${bold}${yellow}⚠️  $1${reset}"
    log_message "WARNING" "$1"
}

error() {
    echo -e "${bold}${red}❌ $1${reset}" >&2
    log_message "ERROR" "$1"
}

# ===== Scan Functions =====

check_dependencies() {
    info "Checking for required tools..."
    local missing_deps=0
    for cmd in rpm dnf chkrootkit clamscan lynis; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Dependency '$cmd' is not installed."
            missing_deps=1
        fi
    done

    if [ "$missing_deps" -eq 1 ]; then
        error "Please install the missing dependencies and try again."
        exit 1
    fi
    success "All dependencies are installed."
}

run_integrity_check() {
    info "Starting System File Integrity Check (rpm -Va)..."
    if output=$(sudo rpm -Va 2>&1); then
        if [ -z "$output" ]; then
            success "System file integrity check passed. No issues found."
            integrity_status="${green}Passed${reset}"
        else
            warning "System file integrity check completed with findings. See log for details."
            echo "$output"
            log_message "FINDINGS" "rpm -Va found issues:\n---\n$output\n---"
            integrity_status="${yellow}Findings${reset}"
        fi
    else
        error "System file integrity check failed to run."
        echo "$output"
        log_message "ERROR" "rpm -Va failed:\n---\n$output\n---"
        integrity_status="${red}Error${reset}"
    fi
    echo
}

run_rootkit_scan() {
    info "Starting Rootkit Scan (chkrootkit)..."
    if output=$(sudo chkrootkit 2>&1); then
        if echo "$output" | grep -q "INFECTED"; then
            warning "chkrootkit found potential issues. See log for details."
            rootkit_status="${yellow}Findings${reset}"
        else
            success "chkrootkit scan completed. No rootkits found."
            rootkit_status="${green}Passed${reset}"
        fi
        echo "$output"
        log_message "SCAN_OUTPUT" "chkrootkit output:\n---\n$output\n---"
    else
        error "chkrootkit failed to run."
        echo "$output"
        log_message "ERROR" "chkrootkit failed:\n---\n$output\n---"
        rootkit_status="${red}Error${reset}"
    fi
    echo
}

run_malware_scan() {
    info "Starting Malware Scan (ClamAV)..."
    info "Updating ClamAV virus definitions (freshclam)..."
    if sudo freshclam; then
        success "ClamAV definitions updated."
    else
        warning "Could not update ClamAV definitions. Scanning with existing database."
    fi

    info "Running ClamAV scan... (This may take a long time)"
    local clam_opts=(-r -i --exclude-dir="^/sys" --exclude-dir="^/proc" --exclude-dir="^/dev")
    if [ "$exclude_home" -eq 1 ]; then
        info "Excluding home directories from malware scan."
        clam_opts+=(--exclude-dir="^/home")
    fi

    if output=$(sudo clamscan "${clam_opts[@]}" / 2>&1); then
        if echo "$output" | grep -q "Infected files: 0"; then
            success "ClamAV scan completed. No malware found."
            malware_status="${green}Passed${reset}"
        else
            warning "ClamAV found potential malware. See log for details."
            malware_status="${yellow}Findings${reset}"
        fi
        echo "$output"
        log_message "SCAN_OUTPUT" "ClamAV output:\n---\n$output\n---"
    else
        error "ClamAV scan failed to run."
        echo "$output"
        log_message "ERROR" "ClamAV failed:\n---\n$output\n---"
        malware_status="${red}Error${reset}"
    fi
    echo
}

run_security_audit() {
    info "Starting Security Audit (Lynis)..."
    info "Note: The full Lynis report can be found in /var/log/lynis.log"
    if output=$(sudo lynis audit system --quiet 2>&1); then
        success "Lynis security audit completed."
        audit_status="${green}Completed${reset}"
        # Lynis provides a summary, which is good to have in our log.
        echo "$output"
        log_message "SCAN_OUTPUT" "Lynis output:\n---\n$output\n---"
    else
        error "Lynis security audit failed to run."
        echo "$output"
        log_message "ERROR" "Lynis failed:\n---\n$output\n---"
        audit_status="${red}Error${reset}"
    fi
    echo
}

run_package_check() {
    info "Starting Package & Dependency Verification..."
    local DNF
    if command -v dnf5 >/dev/null 2>&1; then
      DNF="dnf5"
    else
      DNF="dnf"
    fi
    info "Using ${DNF} for package check."

    # Temporarily disable exit on error to handle dnf's exit code 100
    set +e
    output=$(sudo "${DNF}" check 2>&1)
    exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
        success "Package dependency check passed. No issues found."
        package_status="${green}Passed${reset}"
    elif [ $exit_code -eq 100 ]; then
        warning "Package dependency check found issues. See log for details."
        echo "$output"
        log_message "FINDINGS" "DNF Check found issues:\n---\n$output\n---"
        package_status="${yellow}Findings${reset}"
    else
        error "Package dependency check failed to run (Exit code: $exit_code)."
        echo "$output"
        log_message "ERROR" "DNF Check failed:\n---\n$output\n---"
        package_status="${red}Error${reset}"
    fi
    echo
}


# ===== Main Function =====
usage() {
    echo "Usage: $0 [-i] [-r] [-m] [-a] [-p] [-e] [-h]"
    echo "  -i: Run Integrity check (rpm -Va)"
    echo "  -r: Run Rootkit scan (chkrootkit)"
    echo "  -m: Run Malware scan (ClamAV)"
    echo "  -a: Run Security Audit (Lynis)"
    echo "  -p: Run Package check (dnf check)"
    echo "  -e: Exclude home directories from scans (Privacy option)"
    echo "  -h: Display this help message"
    echo "If no options are specified, all scans will be performed."
    exit 1
}

cleanup() {
    error "Script interrupted. Cleaning up..."
    # Add any cleanup tasks here if needed in the future
    exit 1
}

rotate_logs() {
    # Keep the 7 most recent logs, excluding the current one
    ls -t /var/log/security-sweep-*.log | grep -v "$(basename "$LOG_FILE")" | tail -n +7 | xargs -r rm 2>/dev/null || true
}

main() {
    trap cleanup SIGINT SIGTERM

    local run_integrity=0 run_rootkit=0 run_malware=0 run_audit=0 run_package=0
    local all_scans=1

    while getopts "irmaphe" opt; do
        all_scans=0
        case "$opt" in
            i) run_integrity=1 ;;
            r) run_rootkit=1 ;;
            m) run_malware=1 ;;
            a) run_audit=1 ;;
            p) run_package=1 ;;
            e) exclude_home=1 ;;
            h) usage ;;
            *) usage ;;
        esac
    done

    if [ "$all_scans" -eq 1 ]; then
        run_integrity=1; run_rootkit=1; run_malware=1; run_audit=1; run_package=1
    fi

    clear
    echo -e "${bold}${blue}🚀 Starting Fedora Security Sweep...${reset}"

    # --- Log File Setup ---
    if [ ! -w "/var/log" ]; then
        error "Cannot write to /var/log. Please run with appropriate permissions."
        exit 1
    fi
    # Create and secure the log file
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    echo -e "Full log will be saved to: ${bold}${LOG_FILE}${reset}\n"
    rotate_logs


    echo -e "${bold}================== Initializing Scans ==================${reset}"
    check_dependencies
    echo -e "${bold}====================================================${reset}\n"

    [ "$run_integrity" -eq 1 ] && run_integrity_check
    [ "$run_rootkit" -eq 1 ] && run_rootkit_scan
    [ "$run_malware" -eq 1 ] && run_malware_scan
    [ "$run_audit" -eq 1 ] && run_security_audit
    [ "$run_package" -eq 1 ] && run_package_check

    print_summary
}

print_summary() {
    echo
    echo -e "${bold}==================== Scan Summary ====================${reset}"
    printf "%-35s: %s\n" "System File Integrity" "$integrity_status"
    printf "%-35s: %s\n" "Rootkit Scan (chkrootkit)" "$rootkit_status"
    printf "%-35s: %s\n" "Malware Scan (ClamAV)" "$malware_status"
    printf "%-35s: %s\n" "Security Audit (Lynis)" "$audit_status"
    printf "%-35s: %s\n" "Package & Dependency Verification" "$package_status"
    echo -e "${bold}====================================================${reset}"
    echo
    success "Security sweep completed!"
    info "Review the log file for detailed results: ${LOG_FILE}"
}

# ===== Script Execution =====
# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root. Please use sudo."
  exit 1
fi

main "$@"