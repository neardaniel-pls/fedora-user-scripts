# Guide: Drive Check Script

This guide provides instructions on how to use the `drive-check.sh` script, a read-only diagnostic tool for inspecting storage drives on Fedora systems.

## Overview

The `drive-check.sh` script displays comprehensive information about storage drives without modifying them in any way. It is useful for:

- **Verifying drive specs**: Confirm a USB drive's actual USB version, speed, and capacity against advertised claims
- **Health assessment**: Check SMART health status, temperature, power-on hours, and reallocated sectors
- **Partition inspection**: View partition tables, filesystem types, labels, UUIDs, and mount points
- **Capacity verification**: Compare reported size against marketing labels, accounting for GiB vs GB

The script performs:
- **Device Identification**: Model, serial, vendor, transport, drive type (HDD/SSD), WWID
- **Capacity Verification**: Reported size, sysfs size, SMART capacity, estimated marketing label
- **USB Details** (USB drives only): Product, manufacturer, USB version, negotiated speed with spec mapping
- **Partition Layout**: Partition table from `fdisk`, filesystem overview from `lsblk`
- **Health Summary**: SMART status, temperature, power-on hours, realloc sectors, power cycles, total writes
- **Extended Health** (`--health`): Full SMART attributes, error log, self-test log
- **Mount Points**: Currently mounted partitions from the device

## Dependencies

Install required tools:

```bash
sudo dnf install util-linux usbutils smartmontools
```

- `lsblk`, `fdisk`, `blockdev` (from `util-linux`): Block device information
- `lsusb` (from `usbutils`): USB device details
- `smartctl` (from `smartmontools`): SMART health data (optional — the script gracefully warns if missing)

## Installation & Setup

1. Make the script executable:
   ```bash
   chmod +x scripts/hardware/drive-check.sh
   ```

2. (Optional) Create an alias in `~/.bashrc`:
   ```bash
   alias drivecheck='sudo bash "$HOME/Documents/code/fedora-user-scripts/scripts/hardware/drive-check.sh"'
   source ~/.bashrc
   ```

## Usage

The script requires root privileges for full device access.

### Basic Usage

```bash
sudo ./drive-check.sh /dev/sdb
```

Or with the alias:
```bash
sudo drivecheck /dev/sdb
```

### Extended SMART Health

Show detailed SMART attributes, error log, and self-test log:

```bash
sudo ./drive-check.sh --health /dev/sdb
```

### Help

```bash
sudo ./drive-check.sh --help
```

## Options

| Flag | Description |
|------|-------------|
| `<device>` | Block device path to inspect (e.g., `/dev/sdb`) — **required** |
| `--health` | Show extended SMART health attributes (attributes, error log, self-test log) |
| `--help`, `-h` | Display help message and exit |

## Understanding the Output

### Device Identification

Displays the drive's model name, serial number, vendor, size, transport type, and whether it's an HDD or SSD.

### Capacity Verification

Shows the raw byte count from multiple sources (`blockdev`, sysfs, SMART) and estimates the likely marketing label. A small difference (< 1%) between reported and advertised size is normal due to binary (GiB) vs decimal (GB) conversion.

**Example:**
```
  Reported Size         29.8GiB (32010928128 bytes)
  Sysfs Size            29.8GiB (32010928128 bytes)
  Marketing Label       Likely marketed as 32GB
```

### USB Details (USB drives only)

For USB-connected drives, shows the USB version and negotiated speed, mapped to a human-readable spec label.

**Speed reference:**
- **5 Gbps** = USB 3.1 Gen1 / USB 3.0 SuperSpeed
- **10 Gbps** = USB 3.1 Gen2 SuperSpeed+
- **20 Gbps** = USB 3.2 Gen2x2

If the negotiated speed is lower than expected, possible causes include:
- A USB 2.0 cable or port being used instead of USB 3.x
- A USB hub bottleneck
- The drive itself not supporting the advertised speed

### Health Summary

Key SMART attributes at a glance:

| Attribute | What it means |
|-----------|---------------|
| Temperature | Current drive temperature in °C |
| Power-On Hours | Total hours the drive has been powered on |
| Reallocated Sectors | Bad sectors that have been remapped (0 is ideal) |
| Power Cycles | Number of times the drive was powered on/off |
| Total Writes | Lifetime data written to the drive |

If `smartctl` is not installed, the script will prompt you to install it. If SMART is not supported (common on some USB enclosures), the script will note that.

### Extended Health (`--health`)

Adds the full SMART information page, all attribute IDs, the error log, and the self-test log. Useful for diagnosing failing drives or investigating specific SMART warnings.

## Safety

- The script is **read-only** — it never writes to or modifies the drive
- System drives (root filesystem, boot partitions) are detected and rejected
- The device path is validated as a block device before any operations

## Troubleshooting

### "smartctl not installed"
Install smartmontools: `sudo dnf install smartmontools`

### "SMART is not supported or not enabled"
Some USB drive enclosures don't pass through SMART data. Try connecting the drive via SATA directly if possible.

### "Could not determine detailed USB version/speed from sysfs"
The USB sysfs topology couldn't be resolved. The script will fall back to `lsusb` output. This can happen with certain USB controller configurations.

### Permission denied
The script must be run with `sudo` for full block device access.
