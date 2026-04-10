#!/bin/bash
#
# drive-check.sh - Read-only drive information inspector for Fedora systems
#
# DESCRIPTION:
#   This script inspects storage drives and displays comprehensive information
#   including device identification, USB version/speed verification, capacity
#   validation, partition layout, SMART health data, and mount points.
#   The script is read-only and does not modify the drive in any way.
#
# USAGE:
#   sudo ./drive-check.sh [OPTIONS] <device>
#
# OPTIONS:
#   --health    Show extended SMART health attributes (wear leveling, realloc sectors, etc.)
#   --help, -h  Display this help message and exit
#
# EXAMPLES:
#   # Show all info about a drive
#   sudo ./drive-check.sh /dev/sdb
#
#   # Show info including detailed SMART health
#   sudo ./drive-check.sh --health /dev/sdb
#
# DEPENDENCIES:
#   - lsblk, fdisk, blockdev (util-linux)
#   - lsusb (usbutils): For USB device info
#   - smartctl (smartmontools): For SMART health data (optional, gracefully handled)
#
# OPERATIONAL NOTES:
#   - This script MUST be run with root privileges for full device access
#   - The script is read-only; it will not modify any drive contents
#   - System drives (identified by mounted root filesystem) are rejected
#   - Exit codes: 0 for success, 1 for errors
#
# SECURITY CONSIDERATIONS:
#   - Device path is validated to be a block device before any operations
#   - System drives are detected and rejected to prevent accidental inspection
#   - Only read-only commands are used; no write operations are performed

set -e
set -u
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

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLORS_ENABLED=1
else
    COLORS_ENABLED=0
fi

USE_ICONS="${USE_ICONS:-1}"

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

if (( USE_ICONS && COLORS_ENABLED )); then
    readonly INFO_ICON="ℹ️"
    readonly SUCCESS_ICON="✅"
    readonly WARNING_ICON="⚠️"
    readonly ERROR_ICON="❌"
    readonly SECTION_ICON="🔧"
    readonly START_ICON="🚀"
    readonly PACKAGE_ICON="📦"
    readonly DRIVE_ICON="💾"
    readonly HEALTH_ICON="🏥"
    readonly USB_ICON="🔌"
    readonly PARTITION_ICON="🗺️"
    readonly MOUNT_ICON="📍"
else
    readonly INFO_ICON=""
    readonly SUCCESS_ICON=""
    readonly WARNING_ICON=""
    readonly ERROR_ICON=""
    readonly SECTION_ICON=""
    readonly START_ICON=""
    readonly PACKAGE_ICON=""
    readonly DRIVE_ICON=""
    readonly HEALTH_ICON=""
    readonly USB_ICON=""
    readonly PARTITION_ICON=""
    readonly MOUNT_ICON=""
fi

info() {
    echo -e "${BOLD}${BLUE}${INFO_ICON}  $1${RESET}"
}

success() {
    echo -e "${BOLD}${GREEN}${SUCCESS_ICON} $1${RESET}"
}

warning() {
    echo -e "${BOLD}${YELLOW}${WARNING_ICON} $1${RESET}"
}

error() {
    echo -e "${BOLD}${RED}${ERROR_ICON} $1${RESET}" >&2
}

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

print_kv() {
    local key="$1"
    local value="$2"
    printf "  ${BOLD}%-22s${RESET} %s\n" "$key" "$value"
}

usage() {
    cat << 'EOF'
Usage: sudo drive-check.sh [OPTIONS] <device>

Inspect drive information (read-only, no modifications).

Arguments:
  device                  Block device path (e.g., /dev/sdb)

Options:
  --health                Show extended SMART health attributes
  --help, -h              Show this help message
  --version, -V           Display script version

Examples:
  sudo drive-check.sh /dev/sdb
  sudo drive-check.sh --health /dev/sdb
EOF
    exit 0
}

format_bytes_human() {
    local bytes="$1"
    if command -v numfmt &>/dev/null; then
        numfmt --to=iec --suffix=B "$bytes"
    else
        echo "${bytes} B"
    fi
}

validate_device() {
    local dev="$1"

    if [[ ! -b "$dev" ]]; then
        error "'$dev' is not a block device."
        exit 1
    fi

    if ! lsblk -dn -o NAME "$dev" &>/dev/null; then
        error "Cannot access device '$dev'."
        exit 1
    fi

    local dev_basename
    dev_basename=$(basename "$dev")

    if [[ "$dev_basename" =~ ^sd[a-z]+[0-9] ]] || \
       [[ "$dev_basename" =~ ^nvme[0-9]+n[0-9]+p[0-9]+ ]] || \
       [[ "$dev_basename" =~ ^vd[a-z]+[0-9] ]] || \
       [[ "$dev_basename" =~ ^mmcblk[0-9]+p[0-9]+ ]]; then
        local parent
        parent=$(lsblk -dn -o PKNAME "$dev" 2>/dev/null | xargs)
        if [[ -n "$parent" ]]; then
            warning "'$dev' is a partition, not a whole disk."
            info "Auto-resolving to parent disk /dev/${parent}"
            DEVICE="/dev/${parent}"
        fi
        return
    fi

    if lsblk -dn -o MOUNTPOINT "$dev" | grep -q '/$'; then
        error "'$dev' appears to be the system root drive. Refusing to operate on it."
        exit 1
    fi
    if lsblk -dn -o MOUNTPOINT "${dev}1" 2>/dev/null | grep -q '/boot' || \
       lsblk -dn -o MOUNTPOINT "${dev}1" 2>/dev/null | grep -q '/efi'; then
        error "'$dev' appears to contain the boot partition. Refusing to operate on it."
        exit 1
    fi
}

check_dependencies() {
    local missing=()
    for cmd in lsblk fdisk blockdev lsusb; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        error "Missing required dependencies: ${missing[*]}"
        exit 1
    fi
    success "Core dependencies available"
}

show_device_info() {
    local dev="$1"
    print_section_header "DEVICE IDENTIFICATION" "${DRIVE_ICON}"

    local model serial vendor size tran hotplug rota
    model=$(lsblk -dn -o MODEL "$dev" | xargs)
    serial=$(lsblk -dn -o SERIAL "$dev" | xargs)
    vendor=$(lsblk -dn -o VENDOR "$dev" | xargs)
    size=$(lsblk -dn -o SIZE "$dev" | xargs)
    tran=$(lsblk -dn -o TRAN "$dev" | xargs)
    hotplug=$(lsblk -dn -o HOTPLUG "$dev" | xargs)
    rota=$(lsblk -dn -o ROTA "$dev" | xargs)

    print_kv "Device" "$dev"
    print_kv "Model" "${model:-(unknown)}"
    print_kv "Serial" "${serial:-(not available)}"
    print_kv "Vendor" "${vendor:-(unknown)}"
    print_kv "Size" "$size"
    print_kv "Transport" "${tran:-(unknown)}"
    print_kv "Hotpluggable" "${hotplug:-(unknown)}"

    local devtype_label=""
    if [[ "$rota" == "1" ]]; then
        if [[ "$tran" == "usb" ]]; then
            devtype_label="USB Flash Drive (or HDD)"
        else
            devtype_label="HDD (rotational)"
        fi
    elif [[ "$rota" == "0" ]]; then
        devtype_label="SSD (non-rotational)"
    else
        devtype_label="${rota}"
    fi
    print_kv "Drive Type" "$devtype_label"

    local devname
    devname=$(basename "$dev")
    local phys_path="/sys/block/${devname}/device"
    if [[ -d "$phys_path" ]]; then
        local wwid
        wwid=$(cat "${phys_path}/wwid" 2>/dev/null || echo "")
        if [[ -n "$wwid" ]]; then
            print_kv "WWID" "$wwid"
        fi
    fi
}

show_capacity_verification() {
    local dev="$1"
    print_section_header "CAPACITY VERIFICATION" "${DRIVE_ICON}"

    local size_bytes size_human
    size_bytes=$(blockdev --getsize64 "$dev")
    size_human=$(format_bytes_human "$size_bytes")

    print_kv "Reported Size" "$size_human ($size_bytes bytes)"

    local devname
    devname=$(basename "$dev")
    if [[ -f "/sys/block/${devname}/size" ]]; then
        local sys_size
        sys_size=$(cat "/sys/block/${devname}/size")
        local sys_bytes=$((sys_size * 512))
        local sys_human
        sys_human=$(format_bytes_human "$sys_bytes")
        print_kv "Sysfs Size" "$sys_human ($sys_bytes bytes)"
    fi

    if command -v smartctl &>/dev/null; then
        local smart_size
        smart_size=$(smartctl -i "$dev" 2>/dev/null | grep -i "User Capacity" | sed 's/.*: *//' | xargs || echo "")
        if [[ -n "$smart_size" ]]; then
            print_kv "SMART Capacity" "$smart_size"
        fi
    fi

    local size_gb
    size_gb=$((size_bytes / 1000000000))
    local size_mb
    size_mb=$((size_bytes / 1000000))

    if (( size_gb == 0 )); then
        print_kv "Marketing Label" "Likely marketed as ${size_mb}MB"
    else
        local rounded_gb=$(( (size_gb + 1) / 1 ))
        print_kv "Marketing Label" "Likely marketed as ${rounded_gb}GB"
    fi

    echo
    info "Tip: Compare the reported size against the drive's advertised capacity."
    info "A small difference (< 1%) is normal due to GiB vs GB binary/decimal conversion."
}

show_usb_info() {
    local dev="$1"
    local tran
    tran=$(lsblk -dn -o TRAN "$dev" | xargs)

    if [[ "$tran" != "usb" ]]; then
        return
    fi

    print_section_header "USB DETAILS" "${USB_ICON}"

    local devname
    devname=$(basename "$dev")

    local usb_bus usb_device
    usb_bus=$(readlink -f "/sys/block/${devname}" 2>/dev/null | grep -oP '/usb\d+' | head -1 | grep -oP '\d+')
    if [[ -z "$usb_bus" ]]; then
        usb_bus=$(lsblk -dn -o HCTL "$dev" 2>/dev/null | cut -d: -f1)
    fi

    local usb_addr
    usb_addr=$(lsblk -dn -o HCTL "$dev" 2>/dev/null | cut -d: -f2)

    local usb_product usb_manufacturer usb_speed usb_version
    local found=0

    if [[ -n "$usb_bus" && -n "$usb_addr" ]]; then
        local usb_dev_path="/sys/bus/usb/devices/${usb_bus}-${usb_addr}"
        if [[ -d "$usb_dev_path" ]]; then
            usb_product=$(cat "${usb_dev_path}/product" 2>/dev/null || echo "")
            usb_manufacturer=$(cat "${usb_dev_path}/manufacturer" 2>/dev/null || echo "")
            usb_speed=$(cat "${usb_dev_path}/speed" 2>/dev/null || echo "")
            usb_version=$(cat "${usb_dev_path}/version" 2>/dev/null || echo "")
            found=1
        fi
    fi

    if (( found == 0 )); then
        local usb_syspath
        usb_syspath=$(readlink -f "/sys/block/${devname}/device" 2>/dev/null)
        while [[ -n "$usb_syspath" && "$usb_syspath" != "/" && ! -f "${usb_syspath}/product" ]]; do
            usb_syspath=$(dirname "$usb_syspath")
        done

        if [[ -f "${usb_syspath}/product" ]]; then
            usb_product=$(cat "${usb_syspath}/product" 2>/dev/null || echo "")
            usb_manufacturer=$(cat "${usb_syspath}/manufacturer" 2>/dev/null || echo "")
            usb_speed=$(cat "${usb_syspath}/speed" 2>/dev/null || echo "")
            usb_version=$(cat "${usb_syspath}/version" 2>/dev/null || echo "")
            found=1
        fi
    fi

    if (( found == 0 )); then
        local usb_line
        usb_line=$(lsusb 2>/dev/null | head -20 | while read -r line; do
            local bus_num dev_num
            bus_num=$(echo "$line" | grep -oP 'Bus \K\d+')
            dev_num=$(echo "$line" | grep -oP 'Device \K\d+')
            if [[ "$bus_num" == "${usb_bus}" && "$dev_num" == "${usb_addr}" ]]; then
                echo "$line"
                break
            fi
        done)

        if [[ -n "$usb_line" ]]; then
            print_kv "USB Device" "$usb_line"
            warning "Could not determine detailed USB version/speed from sysfs"
        else
            warning "Could not locate USB device info from sysfs or lsusb"
        fi
        return
    fi

    if [[ -n "$usb_product" ]]; then
        print_kv "Product" "$usb_product"
    fi
    if [[ -n "$usb_manufacturer" ]]; then
        print_kv "Manufacturer" "$usb_manufacturer"
    fi
    if [[ -n "$usb_version" ]]; then
        print_kv "USB Version" "$usb_version"
    fi

    if [[ -n "$usb_speed" ]]; then
        local speed_label=""
        local speed_num
        speed_num=$(echo "$usb_speed" | grep -oP '[\d.]+')
        local speed_int=${speed_num%.*}
        : "${speed_int:=0}"

        local speed_gbps="" speed_unit="Mbps"
        if (( speed_int >= 10000 )); then
            speed_label="USB 3.x SuperSpeed+ (Gen2 or higher)"
            speed_gbps=$(( speed_int / 1000 ))
            speed_unit="Gbps"
        elif (( speed_int >= 5000 )); then
            speed_label="USB 3.x SuperSpeed (Gen1)"
            speed_gbps=$(( speed_int / 1000 ))
            speed_unit="Gbps"
        elif (( speed_int >= 480 )); then
            speed_label="USB 2.0 Hi-Speed"
            speed_gbps="$speed_int"
            speed_unit="Mbps"
        else
            speed_label="USB 1.x Full/Low-Speed"
            speed_gbps="$speed_int"
            speed_unit="Mbps"
        fi

        print_kv "Negotiated Speed" "${speed_gbps} ${speed_unit} ($speed_label)"
        echo
        info "Compare the negotiated speed against the drive's advertised USB spec."
        info "USB 3.2 Gen1 = 5 Gbps | USB 3.2 Gen2 = 10 Gbps | USB 3.2 Gen2x2 = 20 Gbps"
    fi
}

show_partition_layout() {
    local dev="$1"
    print_section_header "PARTITION LAYOUT" "${PARTITION_ICON}"

    print_operation_start "Reading partition table"
    print_command_output
    fdisk -l "$dev" 2>/dev/null || warning "Could not read partition table"
    print_operation_end "Partition table read"

    echo
    print_subheader "Filesystem Overview"
    print_command_output
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,UUID "$dev" 2>/dev/null || warning "Could not read filesystem info"
}

show_health_summary() {
    local dev="$1"

    if ! command -v smartctl &>/dev/null; then
        print_section_header "HEALTH SUMMARY" "${HEALTH_ICON}"
        warning "smartctl not installed. Install smartmontools for health data:"
        warning "  sudo dnf install smartmontools"
        return
    fi

    if ! smartctl -i "$dev" &>/dev/null; then
        print_section_header "HEALTH SUMMARY" "${HEALTH_ICON}"
        warning "SMART is not supported or not enabled on this device."
        return
    fi

    print_section_header "HEALTH SUMMARY" "${HEALTH_ICON}"
    print_operation_start "Reading SMART health status"
    print_command_output

    local health_line
    health_line=$(smartctl -H "$dev" 2>/dev/null | grep -i "result" || echo "")
    if [[ -n "$health_line" ]]; then
        echo "$health_line"
    else
        smartctl -H "$dev" 2>/dev/null | tail -5
    fi
    print_operation_end "SMART health status read"

    echo
    print_subheader "Key Health Attributes"
    print_command_output

    local attrs
    attrs=$(smartctl -A "$dev" 2>/dev/null || echo "")

    if [[ -n "$attrs" ]]; then
        local temp power_on_hours realloc writes power_cycles
        temp=$(echo "$attrs" | grep -i "temperature" | head -1 | awk '{print $NF}' || echo "N/A")
        power_on_hours=$(echo "$attrs" | grep -i "power_on_hours\|power on hours" | head -1 | awk '{print $NF}' || echo "N/A")
        realloc=$(echo "$attrs" | grep -i "reallocated_sector\|realloc sector" | head -1 | awk '{print $NF}' || echo "N/A")
        writes=$(echo "$attrs" | grep -i "total_lba_written\|lifetime writes\|total host writes" | head -1 | awk '{print $NF}' || echo "N/A")
        power_cycles=$(echo "$attrs" | grep -i "power_cycle_count\|power cycle" | head -1 | awk '{print $NF}' || echo "N/A")

        print_kv "Temperature" "${temp}°C"
        print_kv "Power-On Hours" "$power_on_hours"
        print_kv "Reallocated Sectors" "$realloc"
        print_kv "Power Cycles" "$power_cycles"
        if [[ "$writes" != "N/A" ]]; then
            print_kv "Total Writes" "$writes"
        fi
    fi
}

show_extended_health() {
    local dev="$1"

    if ! command -v smartctl &>/dev/null; then
        error "smartctl not installed. Install smartmontools for health data:"
        error "  sudo dnf install smartmontools"
        exit 1
    fi

    if ! smartctl -i "$dev" &>/dev/null; then
        warning "SMART is not supported or not enabled on this device."
        return
    fi

    print_section_header "EXTENDED SMART HEALTH" "${HEALTH_ICON}"

    print_operation_start "Reading SMART information"
    print_command_output
    smartctl -i "$dev" 2>/dev/null || warning "Could not read SMART info"
    print_operation_end "SMART information read"

    echo
    print_operation_start "Reading SMART attributes"
    print_command_output
    smartctl -A "$dev" 2>/dev/null || warning "Could not read SMART attributes"
    print_operation_end "SMART attributes read"

    echo
    print_operation_start "Reading SMART error log"
    print_command_output
    if smartctl -l error "$dev" 2>/dev/null; then
        :
    else
        echo "No errors logged."
    fi
    print_operation_end "SMART error log read"

    echo
    print_operation_start "Reading SMART self-test log"
    print_command_output
    if smartctl -l selftest "$dev" 2>/dev/null; then
        :
    else
        echo "No self-test logs available."
    fi
    print_operation_end "SMART self-test log read"
}

show_mount_points() {
    local dev="$1"
    print_section_header "MOUNT POINTS" "${MOUNT_ICON}"

    local mounted
    mounted=$(lsblk -no MOUNTPOINT,NAME,SIZE "$dev" 2>/dev/null | grep -v "^$" || true)

    if [[ -n "$mounted" ]]; then
        print_command_output
        echo "$mounted"
    else
        info "No partitions from this device are currently mounted."
    fi
}

main() {
    local do_health=0
    local device=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --health)
                do_health=1
                shift
                ;;
            --help|-h)
                usage
                ;;
            --version|-V)
                echo "$(basename "${BASH_SOURCE[0]}") ${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                if [[ -z "$device" ]]; then
                    device="$1"
                else
                    error "Unknown argument: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$device" ]]; then
        error "No device specified."
        echo "Usage: sudo drive-check.sh [OPTIONS] <device>"
        echo "Try 'sudo drive-check.sh --help' for more information."
        exit 1
    fi

    if [[ "$EUID" -ne 0 ]]; then
        error "This script must be run as root. Please use sudo."
        exit 1
    fi

    clear
    print_header "DRIVE INSPECTOR"
    echo -e "${BOLD}${GREEN}${START_ICON} Inspecting drive: ${BOLD}${CYAN}${device}${RESET}"
    echo

    check_dependencies
    print_separator

    DEVICE="$device"
    validate_device "$device"
    device="$DEVICE"
    info "Device '$device' validated"
    print_separator

    show_device_info "$device"
    show_capacity_verification "$device"
    show_usb_info "$device"
    show_partition_layout "$device"
    show_health_summary "$device"
    show_mount_points "$device"

    if (( do_health == 1 )); then
        show_extended_health "$device"
    fi

    echo
    print_header "INSPECTION COMPLETE"
    success "Drive inspection finished successfully (no modifications made)."
    info "Use --health for extended SMART attributes."
    print_separator
}

main "$@"
