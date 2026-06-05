#!/bin/bash
#
# lynis-harden.sh - Apply Lynis security hardening recommendations for Fedora systems
#
# DESCRIPTION:
#   Applies security hardening measures based on Lynis audit suggestions.
#   Offers an interactive menu to select which hardening steps to apply,
#   with full backup/undo support and dry-run mode.
#
# USAGE:
#   sudo ./lynis-harden.sh [OPTIONS]
#
# OPTIONS:
#   --dry-run:   Preview changes without applying them
#   --undo:      Revert last applied changes from backups
#   --all:       Apply all Tier 1 hardening (non-interactive)
#   -h:          Display this help message
#   -V:          Display script version
#
# EXAMPLES:
#   # Interactive mode - pick what to harden
#   sudo ./lynis-harden.sh
#
#   # Preview what would change
#   sudo ./lynis-harden.sh --dry-run
#
#   # Apply all Tier 1 defaults non-interactively
#   sudo ./lynis-harden.sh --all
#
#   # Undo last set of changes
#   sudo ./lynis-harden.sh --undo
#
# HARDENING ITEMS:
#   Tier 1 (safe, enabled by default):
#     [AUTH-9230]  Password hashing rounds
#     [AUTH-9286]  Password min/max age
#     [AUTH-9328]  Default umask 027
#     [KRNL-5820]  Disable core dumps
#     [NETW-3200]  Disable unused network protocols
#     [BANN-7126]  Login banner (/etc/issue)
#     [BANN-7130]  Network login banner (/etc/issue.net)
#     [KRNL-6000]  Sysctl hardening
#
#   Tier 2 (optional, disabled by default):
#     [USB-1000]   Disable USB storage
#     [STRG-1846]  Disable firewire storage
#     [HRDN-7222]  Restrict compilers to root
#     [FINT-4350]  Install AIDE file integrity
#
# DEPENDENCIES:
#   - Standard GNU coreutils (sed, grep, cp, etc.)
#
# OPERATIONAL NOTES:
#   - This script MUST be run with root privileges
#   - Backups are stored in /var/backups/lynis-harden/ with timestamps
#   - Logs are created in /var/log/ with timestamp and restricted permissions (600)
#   - The script automatically rotates logs, keeping only the 7 most recent
#   - Exit codes: 0 for success, 1 for errors or interruption
#
# SECURITY CONSIDERATIONS:
#   - All modified files are backed up before changes
#   - Use --undo to revert the last set of applied changes
#   - Use --dry-run to preview changes before applying
#

set -e
set -u
set -o pipefail

# --- User Configuration ---
if [ -n "${SUDO_USER:-}" ]; then
    _USER_CONFIG="$(getent passwd "$SUDO_USER" | cut -d: -f6)/.config/fedora-user-scripts/config.sh"
else
    _USER_CONFIG="${HOME}/.config/fedora-user-scripts/config.sh"
fi
if [ -f "$_USER_CONFIG" ]; then
    source "$_USER_CONFIG"
fi

# --- Color Detection ---
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLORS_ENABLED=1
else
    COLORS_ENABLED=0
fi

# --- Icon Configuration ---
USE_ICONS="${USE_ICONS:-1}"

# --- Color Definitions ---
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
if (( USE_ICONS && COLORS_ENABLED )); then
    readonly INFO_ICON="ℹ️"
    readonly SUCCESS_ICON="✅"
    readonly WARNING_ICON="⚠️"
    readonly ERROR_ICON="❌"
    readonly SECTION_ICON="🔧"
    readonly SECURITY_ICON="🔒"
    readonly DRYRUN_ICON="👁️"
else
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
    readonly SECTION_ICON=""
    readonly SECURITY_ICON=""
    readonly DRYRUN_ICON=""
fi

# --- Output Functions ---
print_header() {
    local text="$1"
    echo
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
    echo -e "${BOLD}${SECTION_ICON} ${text}${RESET}"
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

# --- Script Initialization ---
readonly SCRIPT_VERSION="1.0.0"
readonly BACKUP_DIR="/var/backups/lynis-harden"
readonly BACKUP_MANIFEST="${BACKUP_DIR}/manifest.txt"
readonly SYSCTL_CONF="/etc/sysctl.d/60-lynis-harden.conf"
readonly MODPROBE_CONF="/etc/modprobe.d/disable-protocols.conf"
readonly LOGIN_DEFS="/etc/login.defs"
readonly LIMITS_CONF="/etc/security/limits.conf"
readonly ISSUE_FILE="/etc/issue"
readonly ISSUE_NET="/etc/issue.net"

LOG_FILE="/var/log/lynis-harden-$(date +%Y%m%d-%H%M%S).log"
dry_run=0
undo_mode=0
all_mode=0

readonly BANNER_TEXT="Authorized use only. All activity is monitored and reported.
Unauthorized access is prohibited."

# ===== Hardening Item Definitions =====
# Each item: id|name|description|tier|default_enabled
HARDENING_ITEMS=(
    "AUTH-9230|Password Hashing Rounds|Increase SHA-512 hashing rounds in /etc/login.defs|1|1"
    "AUTH-9286|Password Min/Max Age|Set PASS_MIN_DAYS=1, PASS_MAX_DAYS=365 in /etc/login.defs|1|1"
    "AUTH-9328|Default Umask 027|Set UMASK 027 in /etc/login.defs for stricter file permissions|1|1"
    "KRNL-5820|Disable Core Dumps|Block core dump creation via limits.conf and sysctl|1|1"
    "NETW-3200|Disable Unused Protocols|Blacklist dccp, sctp, rds, tipc kernel modules|1|1"
    "BANN-7126|Login Banner (console)|Add legal warning banner to /etc/issue|1|1"
    "BANN-7130|Login Banner (network)|Add legal warning banner to /etc/issue.net|1|1"
    "KRNL-6000|Sysctl Hardening|Apply kernel network/security parameter tweaks|1|1"
    "USB-1000|Disable USB Storage|Prevent usb-storage kernel module from loading|2|0"
    "STRG-1846|Disable Firewire Storage|Prevent firewire storage modules from loading|2|0"
    "HRDN-7222|Restrict Compilers|Make gcc/g++/make executable by root only|2|0"
    "FINT-4350|Install AIDE|Install and initialize AIDE file integrity monitoring|2|0"
)

# Track user selections (indexed by position)
declare -a SELECTIONS=()

# ===== Logging =====
log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${level}: ${message}" >> "$LOG_FILE"
}

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

dryrun_info() {
    echo -e "${BOLD}${CYAN}${DRYRUN_ICON} [DRY-RUN] $1${RESET}"
    log_message "DRY-RUN" "$1"
}

# ===== Backup Functions =====
backup_file() {
    local filepath="$1"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name
    backup_name="$(basename "$filepath").${timestamp}"

    if (( dry_run )); then
        dryrun_info "Would back up ${filepath} to ${BACKUP_DIR}/${backup_name}"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"

    if grep -q "^${filepath}|" "$BACKUP_MANIFEST" 2>/dev/null; then
        log_message "BACKUP" "Skipping backup of ${filepath} — already in manifest"
        return 0
    fi

    if [ -f "$filepath" ]; then
        cp -a "$filepath" "${BACKUP_DIR}/${backup_name}"
        echo "${filepath}|${backup_name}" >> "$BACKUP_MANIFEST"
        log_message "BACKUP" "Backed up ${filepath} -> ${BACKUP_DIR}/${backup_name}"
    else
        log_message "BACKUP" "No existing file at ${filepath}, skipping backup"
        echo "${filepath}|NONE" >> "$BACKUP_MANIFEST"
    fi
}

# ===== Tier 1 Hardening Functions =====

harden_password_hashing() {
    print_section_header "AUTH-9230: Password Hashing Rounds" "${SECURITY_ICON}"

    if (( dry_run )); then
        dryrun_info "Would set SHA_CRYPT_MIN_ROUNDS 5000 in ${LOGIN_DEFS}"
        dryrun_info "Would set SHA_CRYPT_MAX_ROUNDS 10000 in ${LOGIN_DEFS}"
        return 0
    fi

    backup_file "$LOGIN_DEFS"

    if grep -q '^SHA_CRYPT_MIN_ROUNDS' "$LOGIN_DEFS" 2>/dev/null; then
        sed -i 's/^SHA_CRYPT_MIN_ROUNDS.*/SHA_CRYPT_MIN_ROUNDS 5000/' "$LOGIN_DEFS"
    else
        echo "SHA_CRYPT_MIN_ROUNDS 5000" >> "$LOGIN_DEFS"
    fi

    if grep -q '^SHA_CRYPT_MAX_ROUNDS' "$LOGIN_DEFS" 2>/dev/null; then
        sed -i 's/^SHA_CRYPT_MAX_ROUNDS.*/SHA_CRYPT_MAX_ROUNDS 10000/' "$LOGIN_DEFS"
    else
        echo "SHA_CRYPT_MAX_ROUNDS 10000" >> "$LOGIN_DEFS"
    fi

    success "Password hashing rounds configured (min 5000, max 10000)"
    info "Note: Only affects new/changed passwords"
}

harden_password_age() {
    print_section_header "AUTH-9286: Password Min/Max Age" "${SECURITY_ICON}"

    if (( dry_run )); then
        dryrun_info "Would set PASS_MIN_DAYS 1 in ${LOGIN_DEFS}"
        dryrun_info "Would set PASS_MAX_DAYS 365 in ${LOGIN_DEFS}"
        return 0
    fi

    backup_file "$LOGIN_DEFS"

    if grep -q '^PASS_MIN_DAYS' "$LOGIN_DEFS" 2>/dev/null; then
        sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 1/' "$LOGIN_DEFS"
    else
        echo "PASS_MIN_DAYS 1" >> "$LOGIN_DEFS"
    fi

    if grep -q '^PASS_MAX_DAYS' "$LOGIN_DEFS" 2>/dev/null; then
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 365/' "$LOGIN_DEFS"
    else
        echo "PASS_MAX_DAYS 365" >> "$LOGIN_DEFS"
    fi

    success "Password age configured (min 1 day, max 365 days)"
}

harden_umask() {
    print_section_header "AUTH-9328: Default Umask 027" "${SECURITY_ICON}"

    if (( dry_run )); then
        dryrun_info "Would set UMASK 027 in ${LOGIN_DEFS}"
        return 0
    fi

    backup_file "$LOGIN_DEFS"

    if grep -q '^UMASK' "$LOGIN_DEFS" 2>/dev/null; then
        sed -i 's/^UMASK.*/UMASK 027/' "$LOGIN_DEFS"
    else
        echo "UMASK 027" >> "$LOGIN_DEFS"
    fi

    success "Default umask set to 027 (new files: rw-r-----, dirs: rwxr-x---)"
}

harden_disable_core_dumps() {
    print_section_header "KRNL-5820: Disable Core Dumps" "${SECURITY_ICON}"

    if (( dry_run )); then
        dryrun_info "Would add '* hard core 0' to ${LIMITS_CONF}"
        dryrun_info "Would create sysctl config for kernel.core_pattern in ${SYSCTL_CONF}"
        return 0
    fi

    backup_file "$LIMITS_CONF"
    backup_file "$SYSCTL_CONF"

    if ! grep -q '^\*\s*hard\s*core\s*0' "$LIMITS_CONF" 2>/dev/null; then
        echo -e "\n# Disable core dumps (KRNL-5820)" >> "$LIMITS_CONF"
        echo "* hard core 0" >> "$LIMITS_CONF"
        success "Core dumps disabled in ${LIMITS_CONF}"
    else
        info "Core dumps already disabled in ${LIMITS_CONF}"
    fi

    local core_pattern_entry="kernel.core_pattern = |/bin/false"
    if [ -f "$SYSCTL_CONF" ]; then
        if ! grep -q '^kernel.core_pattern' "$SYSCTL_CONF" 2>/dev/null; then
            echo "$core_pattern_entry" >> "$SYSCTL_CONF"
            success "kernel.core_pattern set in ${SYSCTL_CONF}"
        else
            sed -i "s#^kernel.core_pattern.*#${core_pattern_entry}#" "$SYSCTL_CONF"
            info "Updated existing kernel.core_pattern in ${SYSCTL_CONF}"
        fi
    else
        echo "# Lynis hardening sysctl parameters (KRNL-6000, KRNL-5820)" > "$SYSCTL_CONF"
        echo "$core_pattern_entry" >> "$SYSCTL_CONF"
        success "Created ${SYSCTL_CONF} with kernel.core_pattern"
    fi

    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    info "Re-enable temporarily with: ulimit -c unlimited"
}

harden_disable_protocols() {
    print_section_header "NETW-3200: Disable Unused Network Protocols" "${SECURITY_ICON}"

    local protocols="dccp sctp rds tipc"

    if (( dry_run )); then
        dryrun_info "Would create ${MODPROBE_CONF} blacklisting: ${protocols}"
        return 0
    fi

    backup_file "$MODPROBE_CONF"

    {
        echo "# Disable unused network protocols (NETW-3200)"
        for proto in $protocols; do
            echo "install ${proto} /bin/false"
        done
    } > "$MODPROBE_CONF"

    for proto in $protocols; do
        modprobe -r "$proto" 2>/dev/null || true
    done

    success "Disabled unused protocols: ${protocols}"
    info "TCP/UDP are unaffected - normal networking continues to work"
}

harden_banner_issue() {
    print_section_header "BANN-7126: Login Banner (console)" "${SECURITY_ICON}"

    if (( dry_run )); then
        dryrun_info "Would write legal banner to ${ISSUE_FILE}"
        return 0
    fi

    backup_file "$ISSUE_FILE"
    echo "$BANNER_TEXT" > "$ISSUE_FILE"
    success "Console login banner set in ${ISSUE_FILE}"
}

harden_banner_issue_net() {
    print_section_header "BANN-7130: Login Banner (network)" "${SECURITY_ICON}"

    if (( dry_run )); then
        dryrun_info "Would write legal banner to ${ISSUE_NET}"
        return 0
    fi

    backup_file "$ISSUE_NET"
    echo "$BANNER_TEXT" > "$ISSUE_NET"
    success "Network login banner set in ${ISSUE_NET}"
}

harden_sysctl() {
    print_section_header "KRNL-6000: Sysctl Hardening" "${SECURITY_ICON}"

    declare -A sysctl_settings=(
        ["kernel.kptr_restrict"]="2"
        ["kernel.randomize_va_space"]="2"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv4.conf.all.accept_source_route"]="0"
        ["net.ipv4.conf.all.log_martians"]="1"
        ["net.ipv4.conf.all.send_redirects"]="0"
        ["net.ipv4.conf.default.accept_redirects"]="0"
        ["net.ipv4.conf.default.accept_source_route"]="0"
        ["net.ipv4.conf.default.log_martians"]="1"
        ["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
        ["net.ipv4.icmp_ignore_bogus_error_responses"]="1"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv6.conf.all.accept_redirects"]="0"
        ["net.ipv6.conf.default.accept_redirects"]="0"
    )

    if (( dry_run )); then
        dryrun_info "Would create/update ${SYSCTL_CONF} with the following:"
        for key in "${!sysctl_settings[@]}"; do
            dryrun_info "  ${key} = ${sysctl_settings[$key]}"
        done
        return 0
    fi

    backup_file "$SYSCTL_CONF"

    local header_written=0
    for key in $(echo "${!sysctl_settings[@]}" | tr ' ' '\n' | sort); do
        local value="${sysctl_settings[$key]}"
        local current_value
        current_value=$(sysctl -n "$key" 2>/dev/null || echo "NOT_SET")

        if [ "$current_value" = "$value" ]; then
            info "Already set: ${key} = ${value}"
            continue
        fi

        if [ "$header_written" -eq 0 ]; then
            if [ ! -f "$SYSCTL_CONF" ] || [ ! -s "$SYSCTL_CONF" ]; then
                echo "# Lynis hardening sysctl parameters (KRNL-6000, KRNL-5820)" > "$SYSCTL_CONF"
            fi
            header_written=1
        fi

        if [ -f "$SYSCTL_CONF" ] && grep -q "^${key}" "$SYSCTL_CONF" 2>/dev/null; then
            sed -i "s|^${key}.*|${key} = ${value}|" "$SYSCTL_CONF"
        else
            echo "${key} = ${value}" >> "$SYSCTL_CONF"
        fi

        info "Set: ${key} = ${value} (was: ${current_value})"
    done

    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    success "Sysctl hardening applied via ${SYSCTL_CONF}"
}

# ===== Tier 2 Hardening Functions =====

harden_disable_usb() {
    print_section_header "USB-1000: Disable USB Storage" "${SECURITY_ICON}"

    local usb_conf="/etc/modprobe.d/disable-usb-storage.conf"

    if (( dry_run )); then
        dryrun_info "Would create ${usb_conf} blacklisting usb-storage"
        dryrun_info "WARNING: This blocks USB thumb drives and external hard drives"
        return 0
    fi

    backup_file "$usb_conf"

    echo "# Disable USB storage (USB-1000)" > "$usb_conf"
    echo "install usb-storage /bin/false" >> "$usb_conf"

    modprobe -r usb_storage 2>/dev/null || true

    success "USB storage module disabled"
    warning "USB thumb drives and external hard drives will no longer work"
    info "To re-enable: rm ${usb_conf} && modprobe usb-storage"
}

harden_disable_firewire() {
    print_section_header "STRG-1846: Disable Firewire Storage" "${SECURITY_ICON}"

    local fw_conf="/etc/modprobe.d/disable-firewire.conf"

    if (( dry_run )); then
        dryrun_info "Would create ${fw_conf} blacklisting firewire storage modules"
        return 0
    fi

    backup_file "$fw_conf"

    {
        echo "# Disable firewire storage (STRG-1846)"
        echo "install ohci1394 /bin/false"
        echo "install sbp2 /bin/false"
        echo "install dv1394 /bin/false"
        echo "install raw1394 /bin/false"
        echo "install video1394 /bin/false"
        echo "install firewire-sbp2 /bin/false"
        echo "install firewire-ohci /bin/false"
    } > "$fw_conf"

    for mod in ohci1394 sbp2 dv1394 raw1394 video1394 firewire-sbp2 firewire-ohci; do
        modprobe -r "$mod" 2>/dev/null || true
    done

    success "Firewire storage modules disabled"
}

harden_restrict_compilers() {
    print_section_header "HRDN-7222: Restrict Compilers" "${SECURITY_ICON}"

    local compilers=()
    for cmd in gcc g++ cc c++ make; do
        local path
        path=$(command -v "$cmd" 2>/dev/null) && compilers+=("$path")
    done

    if [ ${#compilers[@]} -eq 0 ]; then
        warning "No compilers found on this system. Skipping."
        return 0
    fi

    if (( dry_run )); then
        dryrun_info "Would restrict permissions on:"
        for compiler in "${compilers[@]}"; do
            dryrun_info "  ${compiler} -> 0750 (root only)"
        done
        return 0
    fi

    for compiler in "${compilers[@]}"; do
        backup_file "$compiler"
        chmod 0750 "$compiler"
        info "Restricted: ${compiler}"
    done

    success "Compiler access restricted to root only"
    info "To restore: run 'lynis-harden.sh --undo' or chmod 0755 each compiler"
}

harden_install_aide() {
    print_section_header "FINT-4350: Install AIDE" "${SECURITY_ICON}"

    if (( dry_run )); then
        dryrun_info "Would install AIDE package"
        dryrun_info "Would initialize AIDE database"
        return 0
    fi

    local DNF
    if command -v dnf5 >/dev/null 2>&1; then
        DNF="dnf5"
    else
        DNF="dnf"
    fi

    if rpm -q aide >/dev/null 2>&1; then
        info "AIDE is already installed"
    else
        info "Installing AIDE..."
        "$DNF" install -y aide
        success "AIDE installed"
    fi

    if [ ! -f /var/lib/aide/aide.db.gz ]; then
        info "Initializing AIDE database (this may take a few minutes)..."
        aide --init
        if [ -f /var/lib/aide/aide.db.new.gz ]; then
            mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
            success "AIDE database initialized"
        fi
    else
        info "AIDE database already exists at /var/lib/aide/aide.db.gz"
    fi

    info "To check for changes: aide --check"
    info "To update database after legitimate changes: aide --update && mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz"
}

# ===== Dispatch Function =====
HARDEN_FUNCS=(
    "harden_password_hashing"
    "harden_password_age"
    "harden_umask"
    "harden_disable_core_dumps"
    "harden_disable_protocols"
    "harden_banner_issue"
    "harden_banner_issue_net"
    "harden_sysctl"
    "harden_disable_usb"
    "harden_disable_firewire"
    "harden_restrict_compilers"
    "harden_install_aide"
)

apply_item() {
    local index="$1"
    local func="${HARDEN_FUNCS[$index]}"
    $func
}

# ===== Interactive Menu =====
show_menu() {
    if [ -t 1 ]; then
        clear
    fi

    print_header "LYNIS HARDENING MENU"
    echo -e "Select hardening items to apply."
    echo -e "Tier 1 items are ${GREEN}safe for desktops${RESET}. Tier 2 items are ${YELLOW}optional${RESET}."
    echo -e "Press ${BOLD}[ENTER]${RESET} to confirm selections."
    echo

    local i=0
    for item in "${HARDENING_ITEMS[@]}"; do
        IFS='|' read -r id name desc tier default <<< "$item"

        local selected="${SELECTIONS[$i]}"
        local marker
        if [ "$selected" -eq 1 ]; then
            marker="${GREEN}[x]${RESET}"
        else
            marker="${RED}[ ]${RESET}"
        fi

        local tier_label
        if [ "$tier" = "1" ]; then
            tier_label="${GREEN}Tier 1${RESET}"
        else
            tier_label="${YELLOW}Tier 2${RESET}"
        fi

        echo -e "  ${marker} ${BOLD}$((i + 1)))${RESET} [${id}] ${BOLD}${name}${RESET}"
        echo -e "         ${tier_label} - ${desc}"
        echo

        i=$((i + 1))
    done

    echo -e "${BOLD}${CYAN}─────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}a)${RESET} Toggle all    ${BOLD}q)${RESET} Quit without changes    ${BOLD}ENTER)${RESET} Apply selected"
    echo -e "${BOLD}${CYAN}─────────────────────────────────────────────────────────${RESET}"
}

interactive_menu() {
    local i

    for i in "${!HARDENING_ITEMS[@]}"; do
        local item="${HARDENING_ITEMS[$i]}"
        IFS='|' read -r _ _ _ tier default <<< "$item"
        SELECTIONS[i]="$default"
    done

    while true; do
        show_menu

        read -rp "Choose items (1-12, 'a' for all, 'q' to quit): " choice

        case "$choice" in
            q|Q)
                info "No changes applied. Exiting."
                exit 0
                ;;
            a|A)
                for i in "${!SELECTIONS[@]}"; do
                    SELECTIONS[i]=$(( 1 - SELECTIONS[i] ))
                done
                ;;
            "")
                break
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#HARDENING_ITEMS[@]}" ]; then
                    local idx=$((choice - 1))
                    SELECTIONS[idx]=$(( 1 - SELECTIONS[idx] ))
                else
                    warning "Invalid choice: ${choice}"
                    sleep 1
                fi
                ;;
        esac
    done
}

# ===== Apply Selected Items =====
apply_selections() {
    print_header "APPLYING HARDENING"

    if (( dry_run )); then
        info "${DRYRUN_ICON} DRY-RUN MODE - no changes will be made"
        echo
    fi

    local applied=0
    local skipped=0
    local skipped_items=()
    local i=0

    for i in "${!SELECTIONS[@]}"; do
        if [ "${SELECTIONS[$i]}" -eq 1 ]; then
            apply_item "$i"
            applied=$((applied + 1))
        else
            local item="${HARDENING_ITEMS[$i]}"
            IFS='|' read -r id name _ _ _ <<< "$item"
            skipped_items+=("[${id}] ${name}")
            skipped=$((skipped + 1))
        fi
    done

    if [ "${#skipped_items[@]}" -gt 0 ]; then
        print_section_header "SKIPPED ITEMS" "${WARNING_ICON}"
        for skip in "${skipped_items[@]}"; do
            info "Skipping: ${skip}"
        done
        print_separator
    fi

    echo
    print_header "HARDENING SUMMARY"

    if (( dry_run )); then
        info "${DRYRUN_ICON} DRY-RUN: ${applied} items previewed, ${skipped} skipped"
        info "Run without --dry-run to apply changes"
    else
        success "${applied} hardening items applied, ${skipped} skipped"
    fi

    if [ -f "$BACKUP_MANIFEST" ] && (( ! dry_run )); then
        info "Backups stored in: ${BACKUP_DIR}"
        info "To undo: sudo $0 --undo"
    fi

    if [ -f "$SYSCTL_CONF" ] && (( ! dry_run )); then
        sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    fi

    if (( ! dry_run )) && command -v lynis >/dev/null 2>&1; then
        echo
        print_separator
        read -rp "Re-run Lynis audit to see updated score? [y/N]: " rerun
        if [[ "$rerun" =~ ^[Yy]$ ]]; then
            info "Running Lynis audit..."
            lynis audit system 2>&1 | tail -40
        fi
    fi
}

# ===== Undo Function =====
undo_changes() {
    print_header "UNDO: RESTORING BACKUPS"

    if [ ! -f "$BACKUP_MANIFEST" ]; then
        error "No backup manifest found at ${BACKUP_MANIFEST}"
        error "Nothing to undo."
        exit 1
    fi

    local count=0
    while IFS='|' read -r filepath backup_name; do
        if [ "$backup_name" = "NONE" ]; then
            if [ -f "$filepath" ]; then
                if (( dry_run )); then
                    dryrun_info "Would remove: ${filepath}"
                else
                    info "Removing file that was created by hardening: ${filepath}"
                    rm -f "$filepath"
                fi
                count=$((count + 1))
            else
                info "No action needed for ${filepath} (did not exist before)"
            fi
        else
            local backup_path="${BACKUP_DIR}/${backup_name}"
            if [ -f "$backup_path" ]; then
                if (( dry_run )); then
                    dryrun_info "Would restore: ${filepath} from ${backup_name}"
                else
                    cp -a "$backup_path" "$filepath"
                    success "Restored: ${filepath} from ${backup_name}"
                fi
                count=$((count + 1))
            else
                warning "Backup not found: ${backup_path}"
            fi
        fi
    done < "$BACKUP_MANIFEST"

    if (( ! dry_run )); then
        rm -f "$BACKUP_MANIFEST"
    fi

    echo
    if [ "$count" -gt 0 ]; then
        success "${count} files restored from backups"
    else
        warning "No files were restored"
    fi

    if [ -f "$SYSCTL_CONF" ]; then
        sysctl --system >/dev/null 2>&1 || true
    fi

    info "You may want to reboot or reload modules for full effect"
}

# ===== Log Setup =====
rotate_logs() {
    find /var/log -maxdepth 1 -name 'lynis-harden-*.log' -print0 2>/dev/null \
        | grep -zv "$(basename "$LOG_FILE")" \
        | xargs -0 ls -t 2>/dev/null \
        | tail -n +7 \
        | xargs -r rm 2>/dev/null || true
}

setup_log() {
    if [ ! -w "/var/log" ]; then
        error "Cannot write to /var/log. Please run with appropriate permissions."
        exit 1
    fi
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    rotate_logs
}

# ===== Usage =====
usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  (no options)  Interactive menu to select hardening items"
    echo "  --dry-run     Preview changes without applying them"
    echo "  --undo        Revert last set of changes from backups"
    echo "  --all         Apply all Tier 1 hardening (non-interactive)"
    echo "  -h, --help    Display this help message"
    echo "  -V, --version Display script version"
    echo
    echo "Hardening items:"
    echo "  Tier 1 (safe, enabled by default):"
    echo "    [AUTH-9230]  Password hashing rounds"
    echo "    [AUTH-9286]  Password min/max age"
    echo "    [AUTH-9328]  Default umask 027"
    echo "    [KRNL-5820]  Disable core dumps"
    echo "    [NETW-3200]  Disable unused network protocols"
    echo "    [BANN-7126]  Login banner (console)"
    echo "    [BANN-7130]  Login banner (network)"
    echo "    [KRNL-6000]  Sysctl hardening"
    echo "  Tier 2 (optional, disabled by default):"
    echo "    [USB-1000]   Disable USB storage"
    echo "    [STRG-1846]  Disable firewire storage"
    echo "    [HRDN-7222]  Restrict compilers to root"
    echo "    [FINT-4350]  Install AIDE file integrity"
    exit 0
}

# ===== Cleanup =====
cleanup() {
    error "Script interrupted. Cleaning up..."
    exit 1
}

# ===== Main =====
main() {
    trap cleanup SIGINT SIGTERM

    setup_log

    echo -e "${BOLD}${BLUE}${INFO_ICON} Starting Lynis Hardening Tool v${SCRIPT_VERSION}...${RESET}"
    info "Log file: ${LOG_FILE}"
    echo

    if (( undo_mode )); then
        undo_changes
        exit 0
    fi

    if (( all_mode )); then
        info "Non-interactive mode: applying all Tier 1 defaults"
        for i in "${!HARDENING_ITEMS[@]}"; do
            local item="${HARDENING_ITEMS[$i]}"
            IFS='|' read -r _ _ _ tier default <<< "$item"
            if [ "$tier" = "1" ]; then
                SELECTIONS[i]=1
            else
                SELECTIONS[i]=0
            fi
        done
    else
        interactive_menu
    fi

    apply_selections

    echo
    success "Lynis hardening tool completed!"
    info "Full log: ${LOG_FILE}"
}

# ===== Script Execution =====
case "${1:-}" in
    -h|--help) usage ;;
    -V|--version) echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"; exit 0 ;;
esac

if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root. Please use sudo."
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --undo) undo_mode=1 ;;
        --all) all_mode=1 ;;
        -h|--help) usage ;;
        -V|--version) echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"; exit 0 ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
    shift
done

main
