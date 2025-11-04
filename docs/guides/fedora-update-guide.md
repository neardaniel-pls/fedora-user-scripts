# Guide: Fedora Update Script

This guide provides instructions on how to use the `fedora-update.sh` script, a comprehensive tool for keeping your Fedora system up-to-date and clean.

## 1. Overview

The `fedora-update.sh` script automates routine system maintenance tasks, ensuring your Fedora installation remains current, efficient, and free of unnecessary files. It performs all operations in a single run and is designed to be executed manually as needed.

The script performs the following operations:
- **Package Updates**: Updates all system packages using `dnf` or `dnf5`.
- **Flatpak Updates**: Updates Flatpak applications and runtimes.
- **Dependency Cleanup**: Removes orphaned or unnecessary dependencies.
- **Cache Cleaning**: Clears out package manager caches to free up disk space.
- **SearxNG Integration**: Updates a custom SearxNG instance if configured.
- **Interactive Menu**: Provides options to restart, shut down, or exit after completion.

## 2. Dependencies

The script relies on standard Fedora tools that are typically pre-installed.

- `dnf` or `dnf5`: The Fedora package manager.
- `flatpak` (optional): For updating Flatpak applications.
- `sudo`: For running commands with administrative privileges.

## 3. Installation & Setup

### First Time Setup

1. **Make the script executable**:
   ```bash
   chmod +x /path/to/fedora-update.sh
   ```

2. **(Optional) Create an alias for easy access**:

   Add this to your `~/.bashrc`:
   ```bash
   alias fedup='/path/to/fedora-update.sh'
   ```

   Then reload your shell:
   ```bash
   source ~/.bashrc
   ```

3. **Test the installation**:
   ```bash
   fedup
   ```
   You should see the script start running.

### SearxNG Update (Optional)

If you have a custom SearxNG instance, you can configure the script to update it automatically.

**Configure the script path**:

Edit this line in the script:
```bash
SEARXNG_UPDATE_SCRIPT="${HOME}/user-scripts/scripts/searxng/update-searxng.sh"
```

Change the path if your SearxNG update script is located elsewhere.

**Important**: Your SearxNG update script must have restricted permissions for security:
```bash
chmod 700 ~/user-scripts/scripts/searxng/update-searxng.sh
```

The file permissions should display as `-rwx------` (owner can read/write/execute, no group or other access). If permissions are too open, the script will skip the update and show a warning.

## 4. How to Run the Script

The script requires `sudo` privileges for most of its operations and will prompt for your password once at the beginning.

### Basic Usage

To run the script:

```bash
/path/to/fedora-update.sh
```

Or if you created the alias:
```bash
fedup
```

The script will then proceed with the following steps automatically:
1. Verify `sudo` privileges.
2. Update repository cache.
3. Upgrade system packages.
4. Remove unnecessary packages.
5. Clean the package cache.
6. Update Flatpak apps and runtimes.
7. Update SearxNG (if installed and configured).

## 5. Understanding the Output

The script provides color-coded, real-time feedback on its operations.

**Example output:**

```
🚀 Weekly Fedora maintenance (updates and cleaning)...
Verifying sudo privileges...
📦 Updating repository cache...
✓ Repository cache updated
⬆️ Updating packages (upgrade)...
✓ Package upgrade completed
🧹 Removing unnecessary packages (autoremove)...
✓ Unnecessary packages removed
🧽 Cleaning package cache (clean all)...
✓ Package cache cleaned
📱 Updating Flatpaks...
✓ AppStream metadata updated
✓ Flatpak apps/runtimes updated
✓ Unused Flatpaks removed
🔍 Updating SearxNG...
✓ SearxNG updated
=================================================================
✅ Weekly maintenance completed!
=================================================================
```

**Color meanings:**
- 🟢 **Green checkmarks**: Operation completed successfully.
- 🟡 **Yellow warnings**: Non-critical issues or informational messages.
- 🔵 **Blue/Bold headers**: Section identifiers.

## 6. Interactive Menu

After the update and cleaning processes are complete, you will be presented with an interactive menu:

```
What would you like to do now?
1) 🔄 Restart the system
2) ⚡ Shut down the system
3) 🚪 Exit
Choose (1-3):
```

### Menu Options

**1) Restart the system**: Safely reboots the system.
- The script will ask for confirmation: type `yes` to confirm.
- You have 10 seconds to confirm.
- After confirmation, there's a 5-second countdown before the reboot executes.

**2) Shut down the system**: Powers off the system.
- Same confirmation process as restart.
- The system will shut down after the 5-second countdown.

**3) Exit**: Closes the script without any further action.

### Timeout Behavior

If no option is chosen within 30 seconds, the script will automatically exit without performing any action.

## 7. Troubleshooting

### SearxNG update is skipped with "insecure permissions" warning

**Symptom:**
```
⚠️ Warning: /home/user/user-scripts/scripts/searxng/update-searxng.sh has insecure permissions. Skipping.
```

**Solution**: Ensure the SearxNG update script has strict permissions:
```bash
chmod 700 ~/user-scripts/scripts/searxng/update-searxng.sh
```

Verify with:
```bash
ls -la ~/user-scripts/scripts/searxng/update-searxng.sh
```

The output should show: `-rwx------` (700 permissions).

### Flatpak update shows "Flatpak is not installed"

**Symptom:**
```
ℹ️ Flatpak is not installed; skipping the Flatpaks section.
```

**Explanation**: This is informational and not an error. The script detected that Flatpak is not installed on your system.

**Solution** (if you want Flatpak updates): Install Flatpak:
```bash
sudo dnf install flatpak
```

### Script hangs during updates

**Explanation**: Some package updates may require user interaction or take time to download and install depending on your internet connection.

**Solution**:
- Wait for the script to complete (do not interrupt).
- If it hangs for an extended period, press Ctrl+C and check your internet connection.
- Run individual `dnf` commands to identify problematic packages:
  ```bash
  dnf upgrade --dry-run
  ```

### Password prompt appears but script doesn't proceed

**Explanation**: The script requires your `sudo` password to perform system operations.

**Solution**: Enter your password when prompted. The script will verify your `sudo` privileges once at the beginning and proceed with the updates.

## 8. Best Practices

- **Run manually as needed**: Execute the script whenever you want to perform system maintenance.
- **Review updates**: Pay attention to the package updates being installed. If something doesn't look right, press Ctrl+C to stop the script.
- **Check available disk space**: The script cleans package caches, but you may want to check available disk space before running large updates.
- **No data collection**: The script runs entirely locally and does not collect or transmit any data.
- **Safe to interrupt**: If needed, you can press Ctrl+C to stop the script at any time (except during the destructive operation countdown).

---

**Last Updated**: October 2025