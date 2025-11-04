# Guide: Fedora Security Sweep Script

This guide provides instructions on how to use the `security-sweep.sh` script, a comprehensive tool for performing on-demand security scans on a Fedora system.

## Overview

The `security-sweep.sh` script automates security checks to identify potential system corruption, malware, rootkits, and configuration weaknesses.

The script performs:
- **System File Integrity Check**: Verifies installed packages using `rpm -Va`
- **Rootkit Scan**: Checks for known rootkits using `chkrootkit`
- **Malware Scan**: Scans filesystem for viruses using `ClamAV`
- **Security Audit**: Performs system security audit using `Lynis`
- **Package Verification**: Checks for broken packages using `dnf check`

## Dependencies

Install required scanning tools:

```bash
sudo dnf install chkrootkit clamav lynis
```

Note: `rpm` and `dnf` come pre-installed with Fedora.

## Installation & Setup

1. Make the script executable:
   ```bash
   chmod +x /path/to/security-sweep.sh
   ```

2. (Optional) Create an alias in `~/.bashrc`:
   ```bash
   alias security_sweep='sudo bash "$HOME/user-scripts/scripts/security/security-sweep.sh"'
   source ~/.bashrc
   ```

## Usage

The script must be run with `sudo` privileges.

### Basic Usage (All Scans)

```bash
sudo security-sweep.sh
```

### Running Specific Scans

Use command-line options to run specific scans:

- `-i`: Run Integrity check (`rpm -Va`)
- `-r`: Run Rootkit scan (`chkrootkit`)
- `-m`: Run Malware scan (`ClamAV`)
- `-a`: Run Security Audit (`Lynis`)
- `-p`: Run Package check (`dnf check`)
- `-e`: Exclude `/home` directories from malware scan (privacy)
- `-h`: Display help message

**Examples**:

```bash
# Run only malware scan
sudo security-sweep.sh -m

# Run malware scan excluding home directories
sudo security-sweep.sh -m -e

# Run integrity and rootkit scans
sudo security-sweep.sh -i -r
```

## Interpreting Results

### Output Indicators

- **[ℹ️] Info**: General progress information
- **[✅] Success**: Step completed successfully
- **[⚠️] Warning**: Scan found potential issues
- **[❌] Error**: Command or step failed

### Summary Report

At completion, a summary table shows final status:
- **Passed**: Scan ran with no issues found
- **Findings**: Scan detected items that warrant review
- **Completed**: Scan finished its process
- **Error**: Scan failed to run
- **Not Run**: Scan was not selected

## Log Files

### Security Logs

A detailed log is saved to `/var/log/` with filename displayed at start (e.g., `/var/log/security-sweep-20251025-143000.log`).

Log permissions are set to `600` (root only) for security.

### Additional Logs

- **Lynis**: Creates detailed log at `/var/log/lynis.log`

### Log Rotation

Script keeps the 7 most recent `security-sweep` logs and deletes older ones.

## Privacy Considerations

- All data stays local - stored only in `/var/log/`
- No external transmission (except `freshclam` for virus definitions)
- Use `-e` flag to exclude `/home` directories from malware scan
- No telemetry or usage statistics collected

## Troubleshooting

### Common Issues

- **Alias not working with sudo**: Include `sudo` in the alias definition
- **Permission denied**: Always run with `sudo`
- **Missing dependencies**: Install with `sudo dnf install chkrootkit clamav lynis`
- **ClamAV update fails**: Script proceeds with existing database; update manually with `sudo freshclam`

### Error Messages

- `⚠️ Warning: ... has insecure permissions`: Fix with `chmod 700`
- `Permission denied`: Use `sudo` when running the script

## Best Practices

- Run regularly (monthly or quarterly) for consistent monitoring
- Review findings and investigate suspicious items
- Keep scanning tools updated for current threat detection
- Run during low-use periods (ClamAV scans are I/O intensive)

---

**Last Updated**: October 2025
