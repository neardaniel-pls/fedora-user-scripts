# Guide: Fedora Security Sweep Script

This guide provides instructions on how to use the `security-sweep.sh` script, a comprehensive tool for performing on-demand security scans on a Fedora system.

## 1. Overview

The `security-sweep.sh` script automates a series of security checks to help identify potential system corruption, malware, rootkits, and configuration weaknesses. It is designed to be run on-demand and provides a summary report of its findings.

The script performs the following scans:
- **System File Integrity Check**: Verifies the integrity of all installed packages using `rpm -Va`.
- **Rootkit Scan**: Checks for known rootkits using `chkrootkit`.
- **Malware Scan**: Scans the filesystem for viruses, trojans, and other malware using `ClamAV`.
- **Security Audit**: Performs a broad system security audit using `Lynis` to identify hardening opportunities and vulnerabilities.
- **Package & Dependency Verification**: Checks for broken or duplicate packages using `dnf check`.

## 2. Dependencies

Before running the script, you must ensure that the required scanning tools are installed. You can install them using `dnf` (or `dnf5`):

```bash
sudo dnf install chkrootkit clamav lynis
```

**Note**: `rpm` and `dnf` come pre-installed with Fedora, so only the scanning tools need installation.

The script will check for these dependencies and will exit if they are not found.

## 3. Installation & Setup

### First Time Setup

Follow these steps to set up the script on your system:

1. **Make the script executable**:
   ```bash
   chmod +x /path/to/security-sweep.sh
   ```

2. **(Optional) Create an alias for easy access**:
   
   Add this to your `~/.bashrc`:
   ```bash
   alias security_sweep='sudo bash "$HOME/user-scripts/scripts/security/security-sweep.sh"'
   ```
   
   Then reload your shell:
   ```bash
   source ~/.bashrc
   ```
   
   **Note**: The script requires root privileges. If you create an alias without `sudo`, you'll need to manually use `sudo` when running the command.

3. **Test the installation**:
   ```bash
   sudo security-sweep.sh -h
   ```
   
   You should see the help message.

## 4. How to Run the Script

The script must be run with root privileges using `sudo`.

### Basic Usage (All Scans)

To perform all security scans, run:

```bash
sudo security-sweep.sh
```

Or if you created the alias:
```bash
sudo security_sweep
```

### Running Specific Scans

You can run one or more specific scans using command-line options. If any option is provided, only the specified scan(s) will run.

- `-i`: Run Integrity check (`rpm -Va`)
- `-r`: Run Rootkit scan (`chkrootkit`)
- `-m`: Run Malware scan (`ClamAV`)
- `-a`: Run Security Audit (`Lynis`)
- `-p`: Run Package check (`dnf check`)
- `-e`: **(Privacy)** Exclude `/home` directories from the malware scan
- `-h`: Display the help message

**Examples**:

Run only the malware scan:
```bash
sudo security-sweep.sh -m
```

Run a malware scan while excluding home directories for privacy:
```bash
sudo security-sweep.sh -m -e
```

Run the integrity check and the rootkit scan:
```bash
sudo security-sweep.sh -i -r
```

Combine multiple flags (integrity scan + malware scan, exclude home):
```bash
sudo security-sweep.sh -i -m -e
```

### Performance Note

The **ClamAV malware scan can take 30+ minutes** on the first run as it downloads virus definitions and scans the entire filesystem. Subsequent scans are typically much faster once the definitions are cached.

## 5. Interpreting the Results

The script provides real-time status updates and concludes with a summary report.

### On-Screen Output

- **[ℹ️] Info**: General information about the script's progress.
- **[✅] Success**: Indicates that a step was completed successfully.
- **[⚠️] Warning**: Indicates that a scan completed but found potential issues.
- **[❌] Error**: Indicates that a command or step failed to execute.

### Summary Report

At the end of the execution, a summary table provides the final status of each scan:

- **Passed**: The scan ran and found no issues.
- **Findings**: The scan ran and detected potential items. This doesn't necessarily mean a security problem—it means items that warrant review.
- **Completed**: The scan (e.g., Lynis audit) finished its process.
- **Error**: The scan failed to run.
- **Not Run**: The scan was not selected to run.

## 6. Log Files and Security

### Secure Log Files

A detailed, plain-text log of the entire operation is saved to `/var/log/`. The exact filename is displayed when the script starts (e.g., `/var/log/security-sweep-20251025-143000.log`).

For security, the log file permissions are automatically set to `600`, meaning only the `root` user can read or write to it. This protects sensitive system information in the logs.

### Additional Logs

- **Lynis**: Additionally, Lynis creates its own detailed log at `/var/log/lynis.log` with comprehensive audit findings.

### Log Rotation

To prevent the log directory from filling up, the script includes automatic log rotation. It will keep the **7 most recent** `security-sweep` logs and delete any older ones each time it runs.

## 7. Privacy Considerations

The `security-sweep.sh` script is designed with privacy in mind:

- **All data stays local**: Scan results are stored only on your local system in `/var/log/`
- **No external transmission**: The script never sends any data to external servers or services (except `freshclam` for updating ClamAV virus definitions, which is a standard security update)
- **Privacy option available**: Use the `-e` flag to exclude `/home` directories from the malware scan if you want to protect personal files
- **No telemetry**: The script collects no usage statistics or personal information

## 8. Troubleshooting

### Alias Not Working with `sudo`

If you created an alias but it doesn't work with `sudo`, make sure you included `sudo` in the alias definition itself:

```bash
# Correct (will work with sudo):
alias security_sweep='sudo bash "$HOME/user-scripts/scripts/security/security-sweep.sh"'

# Incorrect (won't work with sudo - sudo doesn't expand aliases):
alias security_sweep='bash "$HOME/user-scripts/scripts/security/security-sweep.sh"'
# You would need to run: sudo security_sweep (but this fails because sudo doesn't see the alias)
```

**Solution**: Include `sudo` directly in the alias, then simply run `security_sweep` without typing sudo each time.

### Permissions Denied

If you get permission errors, make sure you're running the script with `sudo`:

```bash
# Wrong:
security-sweep.sh

# Correct:
sudo security-sweep.sh
```

### Missing Dependencies

If the script reports missing dependencies, install them:

```bash
sudo dnf install chkrootkit clamav lynis
```

### ClamAV Database Update Fails

If `freshclam` (ClamAV's database updater) fails, the script will proceed with the existing database. You can manually update ClamAV later:

```bash
sudo freshclam
```

## 9. Best Practices

- **Run regularly**: Schedule monthly or quarterly security sweeps for consistent monitoring
- **Review findings**: Pay attention to warnings and investigate findings that appear suspicious
- **Keep tools updated**: Regularly update ClamAV, Lynis, and chkrootkit for current threat detection
- **Archive logs**: Keep logs from multiple scans to track changes over time
- **Run during low-use periods**: ClamAV scans can be I/O intensive; run during off-hours if possible

## 10. Support & Contribution

This is a community tool designed for Fedora system administrators and security-conscious users. For issues, improvements, or questions, refer to the script documentation or your system administrator.
