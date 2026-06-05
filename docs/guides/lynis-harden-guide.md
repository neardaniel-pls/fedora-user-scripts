# Guide: Lynis Hardening Script

This guide provides instructions on how to use the `lynis-harden.sh` script, a tool for applying Lynis security audit recommendations on a Fedora system.

## Overview

The `lynis-harden.sh` script applies security hardening measures based on suggestions from a Lynis audit. It works hand-in-hand with `security-sweep.sh` — you scan first, then harden based on results.

The script offers:
- **Interactive menu** to select which hardening items to apply
- **Backup and undo** — every modified file is backed up and can be restored
- **Dry-run mode** — preview changes before applying them
- **Non-interactive mode** — apply all safe defaults in one command

### Hardening Items

#### Tier 1 (Safe, enabled by default)

| ID | Item | What it does |
|----|------|-------------|
| AUTH-9230 | Password Hashing Rounds | Increases SHA-512 hashing rounds (min 5000, max 10000) in `/etc/login.defs` |
| AUTH-9286 | Password Min/Max Age | Sets `PASS_MIN_DAYS=1`, `PASS_MAX_DAYS=365` in `/etc/login.defs` |
| AUTH-9328 | Default Umask 027 | Sets `UMASK 027` in `/etc/login.defs` for stricter default file permissions |
| KRNL-5820 | Disable Core Dumps | Blocks core dump creation via `/etc/security/limits.conf` and sysctl |
| NETW-3200 | Disable Unused Protocols | Blacklists `dccp`, `sctp`, `rds`, `tipc` kernel modules |
| BANN-7126 | Login Banner (console) | Adds legal warning banner to `/etc/issue` |
| BANN-7130 | Login Banner (network) | Adds legal warning banner to `/etc/issue.net` |
| KRNL-6000 | Sysctl Hardening | Applies kernel network/security parameter tweaks (ASLR, ICMP, etc.) |

#### Tier 2 (Optional, disabled by default)

| ID | Item | What it does |
|----|------|-------------|
| USB-1000 | Disable USB Storage | Prevents `usb-storage` kernel module from loading |
| STRG-1846 | Disable Firewire Storage | Prevents firewire storage modules from loading |
| HRDN-7222 | Restrict Compilers | Makes `gcc`, `g++`, `make` executable by root only |
| FINT-4350 | Install AIDE | Installs and initializes AIDE file integrity monitoring |

## Dependencies

Standard Fedora tools are typically pre-installed:
- `sed`, `grep`, `cp`, `sysctl`, `modprobe`: Core utilities
- `lynis` (optional): For re-running the audit to verify improvements

Install Lynis if not already present:
```bash
sudo dnf install lynis
```

## Installation & Setup

1. Make the script executable:
   ```bash
   chmod +x /path/to/lynis-harden.sh
   ```

2. (Optional) Create an alias in `~/.bashrc`:
   ```bash
   alias harden='sudo bash "$HOME/fedora-user-scripts/scripts/security/lynis-harden.sh"'
   source ~/.bashrc
   ```

## Usage

The script must be run with `sudo` privileges.

### Interactive Mode (Default)

```bash
sudo lynis-harden.sh
```

Displays a numbered menu where you can:
- Toggle individual items on/off by number (1-12)
- Press `a` to toggle all items
- Press `Enter` to apply selected items
- Press `q` to quit without changes

Tier 1 items are **enabled by default** (shown as `[x]`). Tier 2 items are **disabled by default** (shown as `[ ]`).

### Apply All Tier 1 (Non-Interactive)

```bash
sudo lynis-harden.sh --all
```

Applies all Tier 1 hardening items without prompting. Tier 2 items are skipped.

### Preview Changes (Dry-Run)

```bash
sudo lynis-harden.sh --dry-run
```

Shows exactly what would be changed without modifying any files. Use with `--all` to preview all Tier 1 changes:
```bash
sudo lynis-harden.sh --all --dry-run
```

### Undo Last Changes

```bash
sudo lynis-harden.sh --undo
```

Restores all files modified in the last run from backups. Supports dry-run:
```bash
sudo lynis-harden.sh --undo --dry-run
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| (none) | Interactive menu to select hardening items |
| `--all` | Apply all Tier 1 hardening (non-interactive) |
| `--dry-run` | Preview changes without applying them |
| `--undo` | Revert last set of changes from backups |
| `-h`, `--help` | Display help message |
| `-V`, `--version` | Display script version |

## Interpreting Results

### Output Indicators

- **[ℹ️] Info**: General progress information
- **[✅] Success**: Hardening item applied successfully
- **[⚠️] Warning**: Item skipped or needs attention
- **[❌] Error**: Step failed
- **[👁️] [DRY-RUN]**: Preview only, no changes made

### Summary Report

At completion, a summary shows how many items were applied vs skipped.

If Lynis is installed, the script offers to re-run a Lynis audit so you can see the updated hardening index.

## Backup & Undo

### How Backups Work

- Every file is backed up to `/var/backups/lynis-harden/` before modification
- Backups use timestamps (e.g., `login.defs.20251025-143000`)
- A manifest file tracks all backed up files
- If a file is modified by multiple hardening items, only the **original** is kept
- The backup directory has `700` permissions (root only)

### Restoring

```bash
sudo lynis-harden.sh --undo
```

This reads the manifest and restores each file to its original state. The manifest is deleted after a successful undo.

### Important Notes

- You can only undo the **most recent** set of changes
- Running the script again creates a new manifest (overwrites the previous one)
- For full effect after undo, reboot or reload kernel modules

## Log Files

### Hardening Logs

A detailed log is saved to `/var/log/` with filename displayed at start (e.g., `/var/log/lynis-harden-20251025-143000.log`).

Log permissions are set to `600` (root only) for security.

### Log Rotation

Script keeps the 7 most recent `lynis-harden` logs and deletes older ones.

## Typical Workflow

1. **Scan** with `security-sweep.sh` to get a Lynis audit
2. **Review** the Lynis suggestions in the output
3. **Preview** changes with `lynis-harden.sh --dry-run`
4. **Apply** with `lynis-harden.sh` (interactive) or `lynis-harden.sh --all`
5. **Verify** by re-running Lynis when prompted
6. **Undo** with `lynis-harden.sh --undo` if anything goes wrong

## Troubleshooting

### Common Issues

- **Permission denied**: Always run with `sudo`
- **No backup manifest found**: Nothing to undo — either no hardening has been applied, or undo was already run
- **sysctl errors on apply**: Some sysctl values may not apply until reboot — this is normal
- **USB drives stop working**: You enabled the USB storage disable option. To fix: `sudo rm /etc/modprobe.d/disable-usb-storage.conf && sudo modprobe usb-storage`
- **Compiler not found as non-root**: You enabled the compiler restriction. To fix: `sudo chmod 0755 /usr/bin/gcc /usr/bin/g++ /usr/bin/make`

### Error Messages

- `Cannot write to /var/log`: Run with `sudo`
- `No backup manifest found`: Nothing to undo

## Best Practices

- Always run `--dry-run` before applying changes on a new system
- Run `security-sweep.sh` first to get a baseline Lynis score
- Start with Tier 1 items only — they are safe for desktops
- Only enable Tier 2 items if you understand the trade-offs
- Keep backups intact until you've verified the system works correctly after hardening
- Re-run Lynis after hardening to confirm the improved score

---

**Last Updated**: June 2026
