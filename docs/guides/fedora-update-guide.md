# Guide: Fedora Update Script

This guide provides instructions on how to use the `fedora-update.sh` script, a comprehensive tool for keeping your Fedora system up-to-date and clean.

## Overview

The `fedora-update.sh` script automates routine system maintenance tasks:
- **Package Updates**: Updates all system packages using `dnf` or `dnf5`
- **Flatpak Updates**: Updates Flatpak applications and runtimes
- **Dependency Cleanup**: Removes orphaned or unnecessary dependencies
- **Cache Cleaning**: Clears package manager caches to free disk space
- **SearxNG Integration**: Updates a custom SearxNG instance if configured

## Dependencies

Standard Fedora tools are typically pre-installed:
- `dnf` or `dnf5`: The Fedora package manager
- `flatpak` (optional): For updating Flatpak applications
- `sudo`: For running commands with administrative privileges

## Installation & Setup

1. Make the script executable:
   ```bash
   chmod +x /path/to/fedora-update.sh
   ```

2. (Optional) Create an alias in `~/.bashrc`:
   ```bash
   alias fedup='/path/to/fedora-update.sh'
   source ~/.bashrc
   ```

3. (Optional) Configure SearxNG update path in the script:
   ```bash
   SEARXNG_UPDATE_SCRIPT="${HOME}/fedora-user-scripts/scripts/searxng/update-searxng.sh"
   ```

   Ensure the SearxNG script has restricted permissions:
   ```bash
   chmod 700 ~/fedora-user-scripts/scripts/searxng/update-searxng.sh
   ```

## Usage

Run the script with `sudo` privileges:

```bash
sudo /path/to/fedora-update.sh
```

Or with the alias:
```bash
sudo fedup
```

The script will:
1. Verify `sudo` privileges
2. Update repository cache
3. Upgrade system packages
4. Remove unnecessary packages
5. Clean package cache
6. Update Flatpak apps (if installed)
7. Update SearxNG (if configured)

## Interactive Menu

After completion, you'll see:
```
What would you like to do now?
1) 🔄 Restart the system
2) ⚡ Shut down the system
3) 🚪 Exit
Choose (1-3):
```

- **Restart**: Reboots the system after confirmation
- **Shut down**: Powers off the system after confirmation
- **Exit**: Closes the script without further action

If no option is chosen within 30 seconds, the script exits automatically.

## Troubleshooting

### Common Issues

- **SearxNG update skipped**: Ensure the update script has 700 permissions
- **Flatpak not installed**: This is informational, not an error
- **Script hangs**: Wait for completion or check internet connection
- **Password prompt**: Enter your `sudo` password when prompted

### Error Messages

- `⚠️ Warning: ... has insecure permissions`: Fix with `chmod 700`
- `ℹ️ Flatpak is not installed`: Install with `sudo dnf install flatpak` if needed

---

**Last Updated**: October 2025