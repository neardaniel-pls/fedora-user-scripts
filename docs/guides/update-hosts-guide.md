# Guide: StevenBlack Hosts Update Script

This guide provides instructions on how to use the `update-hosts.sh` script, a utility for updating the StevenBlack hosts repository with customizable extensions for blocking unwanted content.

## Overview

The `update-hosts.sh` script automates the process of updating your system's hosts file using the StevenBlack hosts repository. This helps block access to malicious, advertising, and inappropriate websites.

The script performs:
- **Repository Update**: Pulls the latest changes from the StevenBlack hosts repository
- **Extension Selection**: Allows interactive selection of content categories to block
- **Hosts File Generation**: Creates and installs a new hosts file with specified extensions
- **Permission Handling**: Properly manages permissions when running with sudo
- **Local Changes Protection**: Automatically stashes local changes before updating

## Dependencies

Install required tools using `dnf`:

```bash
sudo dnf install git python3
```

## Prerequisites

1. **StevenBlack hosts repository**: Clone the repository to your system:
   ```bash
   git clone https://github.com/StevenBlack/hosts.git ~/Documents/code/hosts
   ```

2. **Repository location**: The script expects the repository at:
   - `~/Documents/code/hosts` (when run as regular user)
   - `~/Documents/code/hosts` (when run with sudo, uses original user's home)

3. **Custom path**: Override the default path with environment variable:
   ```bash
   export HOSTS_REPO_PATH="/custom/path/to/hosts"
   ```

## Installation & Setup

1. Make the script executable:
   ```bash
   chmod +x /path/to/update-hosts.sh
   ```

2. (Optional) Create an alias in `~/.bashrc`:
   ```bash
   alias updatehosts='bash "$HOME/fedora-user-scripts/scripts/maintenance/update-hosts.sh"'
   source ~/.bashrc
   ```

## Usage

### Basic Usage

Run the script:

```bash
# Direct execution
./update-hosts.sh

# With alias
updatehosts

# With sudo (if needed)
sudo ./update-hosts.sh
```

### Extension Selection

The script provides an interactive menu for selecting extensions:

```
Available extensions:
1. fakenews
2. gambling
3. porn
4. social

Enter the numbers of extensions you want to use (comma-separated, e.g., 1,2):
Press Enter to use default extensions (gambling,porn) or input your selection:
```

### Pre-configured Extensions

Set extensions via environment variable to skip interactive selection:

```bash
# Use specific extensions
export HOSTS_EXTENSIONS="fakenews,gambling,porn,social"
./update-hosts.sh

# Or run inline
HOSTS_EXTENSIONS="fakenews,social" ./update-hosts.sh
```

### Default Extensions

If no selection is made, the script uses:
- `gambling,porn` (default)

## Available Extensions

| Extension | Description |
|-----------|-------------|
| `fakenews` | Blocks fake news websites |
| `gambling` | Blocks gambling and betting sites |
| `porn` | Blocks adult content websites |
| `social` | Blocks social media platforms |

## Configuration

### Environment Variables

- `HOSTS_REPO_PATH`: Custom path to the hosts repository
- `HOSTS_EXTENSIONS`: Comma-separated list of extensions to use
- `NO_COLOR`: Disable colored output
- `USE_ICONS`: Disable Unicode icons (set to 0)

### Examples

```bash
# Custom repository path
HOSTS_REPO_PATH="/opt/hosts" ./update-hosts.sh

# Pre-select extensions
HOSTS_EXTENSIONS="fakenews,gambling" ./update-hosts.sh

# Disable colors and icons
NO_COLOR=1 USE_ICONS=0 ./update-hosts.sh
```

## Operation Flow

1. **Prerequisite Check**: Verifies repository, git, python3, and updateHostsFile.py
2. **Repository Update**: Stashes local changes, pulls latest updates
3. **Extension Selection**: Interactive menu or uses pre-configured extensions
4. **Hosts Generation**: Runs `updateHostsFile.py` with selected extensions
5. **Installation**: Automatically replaces `/etc/hosts` with new file

## Output Features

The script provides rich, colored output with:
- **Section Headers**: Clear separation of operations
- **Progress Indicators**: Shows current operation status
- **Success/Error Messages**: Clear feedback on operations
- **Icons**: Visual indicators for different message types

Example output:
```
─────────────────────────────────────────────────────────
🔧 PREREQUITE CHECK
─────────────────────────────────────────────────────────

✅ Hosts repository found at: /home/user/Documents/code/hosts
✅ git is available
✅ python3 is available
✅ updateHostsFile.py found in the hosts repository
```

## Security & Privacy

- **Local Processing**: All operations performed locally
- **Permission Management**: Properly handles sudo execution
- **Change Protection**: Automatically stashes local modifications
- **No Telemetry**: No data collection or external communication

## Troubleshooting

### Common Issues

- **Repository not found**: Clone the hosts repository to `~/Documents/code/hosts`
- **Permission denied**: Use `chmod +x` on the script
- **Git failures**: Check internet connection and repository status
- **Python script missing**: Ensure `updateHostsFile.py` exists in the repository

### Error Messages

- `❌ Hosts repository not found`: Clone the repository or set `HOSTS_REPO_PATH`
- `❌ git is not installed`: Install with `sudo dnf install git`
- `❌ python3 is not installed`: Install with `sudo dnf install python3`
- `❌ updateHostsFile.py not found`: Update repository or check path

### Recovery

If local changes were stashed during update:
```bash
cd ~/Documents/code/hosts
git stash list
git stash pop  # Restore stashed changes
```

## Advanced Usage

### Automation

For automated updates without interaction:
```bash
# Cron job for weekly updates
0 2 * * 0 HOSTS_EXTENSIONS="gambling,porn,fakenews" /path/to/update-hosts.sh
```

### Custom Extensions

The script supports any extensions available in the StevenBlack hosts repository. Check the repository for newly added extensions.

### Manual Hosts File

The generated hosts file is available at:
```
~/Documents/code/hosts/hosts
```

---

**Last Updated**: December 2025  
**Script Version**: Interactive Extension Selection Edition