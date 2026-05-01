#!/bin/bash
#
# security-sweep.sh - Comprehensive security scanning and auditing utility for Fedora systems
#
# DESCRIPTION:
#   This script performs a thorough security assessment of Fedora Linux systems
#   using multiple specialized tools. It conducts file integrity checks, rootkit
#   detection, malware scanning, security auditing, and package verification.
#   The script generates detailed logs and provides a color-coded summary of results.
#   It's designed to be run regularly as part of a security maintenance routine.
#
# USAGE:
#   sudo ./security-sweep.sh [OPTIONS]
#
# OPTIONS:
#   -i: Run Integrity check (rpm -Va) only
#   -r: Run Rootkit scan (chkrootkit) only
#   -m: Run Malware scan (ClamAV) only
#   -a: Run Security Audit (Lynis) only
#   -p: Run Package check (dnf check) only
#   -e: Exclude home directories from scans (Privacy option)
#   -h: Display this help message
#
# EXAMPLES:
#   # Run all security scans (default behavior)
#   sudo ./security-sweep.sh
#
#   # Run only malware and rootkit scans
#   sudo ./security-sweep.sh -m -r
#
#   # Run all scans but exclude home directories for privacy
#   sudo ./security-sweep.sh -e
#
#   # Run only the integrity check
#   sudo ./security-sweep.sh -i
#
# DEPENDENCIES:
#   - rpm: For package integrity verification
#   - dnf or dnf5: For package management and dependency checking
#   - chkrootkit: For rootkit detection
#   - clamscan: For malware scanning
#   - freshclam: For updating ClamAV virus definitions
#   - lynis: For comprehensive security auditing
#
# OPERATIONAL NOTES:
#   - This script MUST be run with root privileges for comprehensive scanning
#   - Logs are created in /var/log/ with timestamp and restricted permissions (600)
#   - The script automatically rotates logs, keeping only the 7 most recent
#   - Scans may take considerable time, especially the malware scan
#   - The script handles tool failures gracefully and continues with other scans
#   - Exit codes: 0 for success, 1 for errors or interruption
#
# SECURITY CONSIDERATIONS:
#   - The script requires root access to scan system files and processes
#   - Log files are created with 600 permissions for security
#   - The -e option allows excluding home directories for privacy compliance
#   - All scan outputs are logged for forensic analysis
#

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u
# Pipes return the exit status of the last command to exit with a non-zero status.
set -o pipefail

# --- User Configuration ---
# Load user config if available (sets env vars that override defaults)
if [ -n "${SUDO_USER:-}" ]; then
    _USER_CONFIG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config/fedora-user-scripts/config.sh"
else
    _USER_CONFIG="${HOME}/.config/fedora-user-scripts/config.sh"
fi
if [ -f "$_USER_CONFIG" ]; then
    source "$_USER_CONFIG"
fi

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
    readonly SECURITY_ICON="🔒"
    readonly SCAN_ICON="🔍"
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
    readonly SECURITY_ICON=""
    readonly SCAN_ICON=""
fi

# --- Output Functions ---
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

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.0.0"

# Quick version check before any heavy initialization
if [[ "${1:-}" == "--version" || "${1:-}" == "-V" ]]; then
    echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
    exit 0
fi

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
#
# log_message - Write timestamped messages to log file without color codes
#
# DESCRIPTION:
#   Centralized logging function that writes messages with timestamps to log file.
#   Strips color codes to ensure clean log files suitable for forensic analysis.
#
# PARAMETERS:
#   $1 - Log level (INFO, SUCCESS, WARNING, ERROR, FINDINGS, SCAN_OUTPUT)
#   $2 - Message to log
#
log_message() {
    local level="$1"    # Log level for categorization
    local message="$2"   # Message content
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${level}: ${message}" >> "$LOG_FILE"
}

# Override the colors library functions to add logging
info() {
    echo -e "${BOLD}${BLUE}${INFO_ICON}  $1${RESET}"
    log_message "INFO" "$1"
}

success() {
    echo -e "${BOLD}${GREEN}${SUCCESS_ICON} $1${RESET}"
    log_message "SUCCESS" "$1"
}

warning() {
    echo -e "${BOLD}${YELLOW}${WARNING_ICON} $1${RESET}"
    log_message "WARNING" "$1"
}

error() {
    echo -e "${BOLD}${RED}${ERROR_ICON} $1${RESET}" >&2
    log_message "ERROR" "$1"
}

# ===== Scan Functions =====
#
# check_dependencies - Verify required security tools are installed for selected scans
#
# DESCRIPTION:
#   Checks for the presence of security tools needed for the selected scans.
#   Only validates dependencies for scans that will actually run.
#
# PARAMETERS:
#   $1 - run_integrity (1/0)
#   $2 - run_rootkit (1/0)
#   $3 - run_malware (1/0)
#   $4 - run_audit (1/0)
#   $5 - run_package (1/0)
#
# RETURNS:
#   Exits with status 1 if any dependencies are missing
#
check_dependencies() {
    local run_integrity="$1"
    local run_rootkit="$2"
    local run_malware="$3"
    local run_audit="$4"
    local run_package="$5"

    info "Checking for required tools..."
    local missing_deps=0
    local required_cmds=()

    # rpm is needed by both integrity and package checks
    if [ "$run_integrity" -eq 1 ] || [ "$run_package" -eq 1 ]; then
        required_cmds+=(rpm)
    fi

    # dnf is needed by package check
    if [ "$run_package" -eq 1 ]; then
        required_cmds+=(dnf)
    fi

    # chkrootkit is needed by rootkit scan
    if [ "$run_rootkit" -eq 1 ]; then
        required_cmds+=(chkrootkit)
    fi

    # ClamAV is needed by malware scan
    if [ "$run_malware" -eq 1 ]; then
        required_cmds+=(clamscan freshclam)
    fi

    # Lynis is needed by security audit
    if [ "$run_audit" -eq 1 ]; then
        required_cmds+=(lynis)
    fi

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Dependency '$cmd' is not installed."
            missing_deps=1
        fi
    done

    if [ "$missing_deps" -eq 1 ]; then
        error "Please install the missing dependencies and try again."
        exit 1
    fi
    success "All required dependencies are installed."
}

#
# run_integrity_check - Verify system file integrity using RPM
#
# DESCRIPTION:
#   Runs 'rpm -Va' to verify all installed packages against their original
#   checksums. This detects unauthorized modifications to system files.
#   The output is analyzed to determine if any issues were found.
#
# RETURNS:
#   Sets integrity_status variable based on scan results
#
run_integrity_check() {
    print_section_header "SYSTEM FILE INTEGRITY CHECK" "${SECURITY_ICON}"
    print_operation_start "Verifying package integrity (rpm -Va)"
    
    local tmp_output
    tmp_output=$(mktemp)
    set +e
    rpm -Va 2>&1 | tee "$tmp_output"
    local pipe_exit=${PIPESTATUS[0]}
    set -e
    output=$(<"$tmp_output")
    rm -f "$tmp_output"

    if [ $pipe_exit -eq 0 ]; then
        if [ -z "$output" ]; then
            success "System file integrity check passed. No issues found."
            integrity_status="${GREEN}Passed${RESET}"
        else
            warning "System file integrity check completed with findings. See log for details."
            log_message "FINDINGS" "rpm -Va found issues:\n---\n$output\n---"
            integrity_status="${YELLOW}Findings${RESET}"
        fi
    else
        error "System file integrity check failed to run."
        log_message "ERROR" "rpm -Va failed:\n---\n$output\n---"
        integrity_status="${RED}Error${RESET}"
    fi
    print_operation_end "System file integrity check completed"
    print_separator
}

#
# run_rootkit_scan - Scan for rootkits using chkrootkit
#
# DESCRIPTION:
#   Runs chkrootkit to detect known rootkits and signs of system compromise.
#   The output is analyzed for the "INFECTED" keyword to determine if any
#   potential threats were found.
#
# RETURNS:
#   Sets rootkit_status variable based on scan results
#
run_rootkit_scan() {
    print_section_header "ROOTKIT DETECTION" "${SCAN_ICON}"
    print_operation_start "Scanning for rootkits (chkrootkit)"
    
    local tmp_output
    tmp_output=$(mktemp)
    set +e
    chkrootkit 2>&1 | tee "$tmp_output"
    local pipe_exit=${PIPESTATUS[0]}
    set -e
    output=$(<"$tmp_output")
    rm -f "$tmp_output"

    if [ $pipe_exit -eq 0 ]; then
        if echo "$output" | grep -q "INFECTED"; then
            warning "chkrootkit found potential issues. See log for details."
            rootkit_status="${YELLOW}Findings${RESET}"
        else
            success "chkrootkit scan completed. No rootkits found."
            rootkit_status="${GREEN}Passed${RESET}"
        fi
        log_message "SCAN_OUTPUT" "chkrootkit output:\n---\n$output\n---"
    else
        error "chkrootkit failed to run."
        log_message "ERROR" "chkrootkit failed:\n---\n$output\n---"
        rootkit_status="${RED}Error${RESET}"
    fi
    print_operation_end "Rootkit scan completed"
    print_separator
}

#
# run_malware_scan - Scan for malware using ClamAV
#
# DESCRIPTION:
#   Updates ClamAV virus definitions and performs a comprehensive system scan.
#   Excludes system directories that would generate false positives or cause issues.
#   Optionally excludes home directories based on the exclude_home flag.
#
# RETURNS:
#   Sets malware_status variable based on scan results
#
run_malware_scan() {
    print_section_header "MALWARE DETECTION" "${CLEAN_ICON}"
    print_operation_start "Updating virus definitions (freshclam)"
    
    freshclam || warning "Could not update ClamAV definitions. Scanning with existing database."
    success "ClamAV definitions updated."

    print_operation_start "Scanning for malware (clamscan)"
    info "This may take a long time depending on system size..."
    
    local clam_opts=(-r --exclude-dir="^/sys" --exclude-dir="^/proc" --exclude-dir="^/dev")
    
    if [ "$exclude_home" -eq 1 ]; then
        info "Excluding home directories from malware scan for privacy."
        clam_opts+=(--exclude-dir="^/home")
    fi

    local tmp_output
    tmp_output=$(mktemp)
    set +e
    clamscan "${clam_opts[@]}" / 2>&1 | grep -v "^Scanning " | tee "$tmp_output"
    local pipe_exit=${PIPESTATUS[0]}
    set -e
    output=$(<"$tmp_output")
    rm -f "$tmp_output"

    if [ $pipe_exit -eq 0 ]; then
        if echo "$output" | grep -q "Infected files: 0"; then
            success "ClamAV scan completed. No malware found."
            malware_status="${GREEN}Passed${RESET}"
        else
            warning "ClamAV found potential malware. See log for details."
            malware_status="${YELLOW}Findings${RESET}"
        fi
        log_message "SCAN_OUTPUT" "ClamAV output:\n---\n$output\n---"
    else
        error "ClamAV scan failed to run."
        log_message "ERROR" "ClamAV failed:\n---\n$output\n---"
        malware_status="${RED}Error${RESET}"
    fi
    print_operation_end "Malware scan completed"
    print_separator
}

#
# run_security_audit - Perform comprehensive security audit using Lynis
#
# DESCRIPTION:
#   Runs Lynis to perform a comprehensive security audit of the system.
#   Lynis checks hundreds of security settings and provides recommendations.
#   The full report is saved to /var/log/lynis.log for detailed analysis.
#
# RETURNS:
#   Sets audit_status variable based on scan results
#
run_security_audit() {
    print_section_header "SECURITY AUDIT" "${SECURITY_ICON}"
    print_operation_start "Performing comprehensive security audit (Lynis)"
    info "The full Lynis report can be found in /var/log/lynis.log"
    
    local tmp_output
    tmp_output=$(mktemp)
    set +e
    lynis audit system 2>&1 | tee "$tmp_output"
    local pipe_exit=${PIPESTATUS[0]}
    set -e
    output=$(<"$tmp_output")
    rm -f "$tmp_output"

    if [ $pipe_exit -eq 0 ]; then
        success "Lynis security audit completed."
        audit_status="${GREEN}Completed${RESET}"
        log_message "SCAN_OUTPUT" "Lynis output:\n---\n$output\n---"
    else
        error "Lynis security audit failed to run."
        log_message "ERROR" "Lynis failed:\n---\n$output\n---"
        audit_status="${RED}Error${RESET}"
    fi
    print_operation_end "Security audit completed"
    print_separator
}

#
# run_package_check - Verify package dependencies and consistency
#
# DESCRIPTION:
#   Uses dnf/dnf5 to check for package dependency issues and inconsistencies.
#   Automatically detects whether the system uses dnf5 or classic dnf.
#   Handles dnf's special exit code 100 which indicates issues found (not an error).
#
# RETURNS:
#   Sets package_status variable based on check results
#
run_package_check() {
    print_section_header "PACKAGE VERIFICATION" "${PACKAGE_ICON}"
    print_operation_start "Verifying package dependencies and consistency"
    
    local DNF
    if command -v dnf5 >/dev/null 2>&1; then
      DNF="dnf5"
    else
      DNF="dnf"
    fi
    success "Using ${DNF} for package check."

    local tmp_output
    tmp_output=$(mktemp)
    set +e
    "${DNF}" check 2>&1 | tee "$tmp_output"
    exit_code=${PIPESTATUS[0]}
    set -e
    output=$(<"$tmp_output")
    rm -f "$tmp_output"

    if [ $exit_code -eq 0 ]; then
        success "Package dependency check passed. No issues found."
        package_status="${GREEN}Passed${RESET}"
    elif [ $exit_code -eq 100 ]; then
        warning "Package dependency check found issues. See log for details."
        log_message "FINDINGS" "DNF Check found issues:\n---\n$output\n---"
        package_status="${YELLOW}Findings${RESET}"
    else
        error "Package dependency check failed to run (Exit code: $exit_code)."
        log_message "ERROR" "DNF Check failed:\n---\n$output\n---"
        package_status="${RED}Error${RESET}"
    fi
    print_operation_end "Package verification completed"
    print_separator
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
    echo "  -V: Display script version"
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
    find /var/log -maxdepth 1 -name 'security-sweep-*.log' -print0 2>/dev/null \
        | grep -zv "$(basename "$LOG_FILE")" \
        | xargs -0 ls -t 2>/dev/null \
        | tail -n +7 \
        | xargs -r rm 2>/dev/null || true
}

main() {
    trap cleanup SIGINT SIGTERM

    local run_integrity=0 run_rootkit=0 run_malware=0 run_audit=0 run_package=0
    local all_scans=1

    while getopts "irmapheV" opt; do
        all_scans=0
        case "$opt" in
            i) run_integrity=1 ;;
            r) run_rootkit=1 ;;
            m) run_malware=1 ;;
            a) run_audit=1 ;;
            p) run_package=1 ;;
            e) exclude_home=1 ;;
            h) usage ;;
            V) echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"; exit 0 ;;
            *) usage ;;
        esac
    done

    if [ "$all_scans" -eq 1 ]; then
        run_integrity=1; run_rootkit=1; run_malware=1; run_audit=1; run_package=1
    fi

    if [ -t 1 ]; then
        clear
    fi
    echo -e "${BOLD}${BLUE}${INFO_ICON} Starting Fedora Security Sweep...${RESET}"

    # --- Log File Setup ---
    if [ ! -w "/var/log" ]; then
        error "Cannot write to /var/log. Please run with appropriate permissions."
        exit 1
    fi
    # Create and secure the log file
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    echo -e "Full log will be saved to: ${BOLD}${LOG_FILE}${RESET}\n"
    rotate_logs


    print_header "Initializing Scans"
    check_dependencies "$run_integrity" "$run_rootkit" "$run_malware" "$run_audit" "$run_package"
    print_separator
    echo

    [ "$run_integrity" -eq 1 ] && run_integrity_check
    [ "$run_rootkit" -eq 1 ] && run_rootkit_scan
    [ "$run_malware" -eq 1 ] && run_malware_scan
    [ "$run_audit" -eq 1 ] && run_security_audit
    [ "$run_package" -eq 1 ] && run_package_check

    print_summary
}

print_summary() {
    echo
    print_header "SECURITY SWEEP SUMMARY"
    echo -e "$(printf "%-35s" "System File Integrity"): $integrity_status"
    echo -e "$(printf "%-35s" "Rootkit Scan (chkrootkit)"): $rootkit_status"
    echo -e "$(printf "%-35s" "Malware Scan (ClamAV)"): $malware_status"
    echo -e "$(printf "%-35s" "Security Audit (Lynis)"): $audit_status"
    echo -e "$(printf "%-35s" "Package & Dependency Verification"): $package_status"
    print_separator
    echo
    success "Security sweep completed successfully!"
    info "Review the log file for detailed results: ${LOG_FILE}"
}

# ===== Script Execution =====
# Allow --help and --version without root
case "${1:-}" in
    -h|--help) usage ;;
    -V|--version) echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"; exit 0 ;;
esac

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root. Please use sudo."
  exit 1
fi

main "$@"