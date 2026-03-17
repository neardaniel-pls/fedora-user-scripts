# Ollama and Open Web UI Update Guide

## Overview

This guide explains how to use the [`update-ollama-openwebui.sh`](../../scripts/ai/update-ollama-openwebui.sh) script to update Ollama and Open Web UI installations on Fedora Linux systems.

### What is Ollama?

Ollama is a tool for running large language models (LLMs) locally on your machine. It provides a simple command-line interface for downloading, running, and managing various AI models.

### What is Open Web UI?

Open Web UI is a user-friendly web interface for interacting with LLMs, including those running through Ollama. It provides a chat-like interface, model management, and conversation history.

### Why Use This Script?

The update script provides:
- **Automatic backups** before any destructive operations
- **Safe updates** with proper error handling
- **Restore functionality** to recover from backups if needed
- **Colored output** for better user experience
- **Flexible options** for different update scenarios

## Prerequisites

### System Requirements

- **Operating System**: Fedora Linux (tested on Fedora 42+)
- **Privileges**: sudo access for systemd operations
- **Disk Space**: Sufficient space for backups (Ollama models can be several GB)

### Required Software

Before using the update script, ensure you have the following installed:

```bash
# Install Podman (container engine)
sudo dnf install podman

# Install curl (for downloading Ollama installer)
sudo dnf install curl
```

### Initial Setup

If you haven't already installed Ollama and Open Web UI, follow these steps:

#### Install Ollama

```bash
# Download and run the official installer
curl -fsSL https://ollama.com/install.sh | sh

# Verify installation
ollama --version
sudo systemctl status ollama
```

#### Install Open Web UI

```bash
# Pull the Open Web UI image
podman pull ghcr.io/open-webui/open-webui:main

# Run the container
podman run -d \
  --network=host \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main

# Verify the container is running
podman ps | grep open-webui
```

Access Open Web UI at `http://localhost:8080` in your browser.

## Using the Update Script

### Basic Usage

The simplest way to update both Ollama and Open Web UI:

```bash
./scripts/ai/update-ollama-openwebui.sh
```

This will:
1. Create backups of both services
2. Update Open Web UI (pull latest image, recreate container)
3. Update Ollama (reinstall binary, restart service)
4. Verify both services are running correctly

### Command-Line Options

The script supports several options for different scenarios:

#### `--backup-only`

Create backups without performing updates:

```bash
./scripts/ai/update-ollama-openwebui.sh --backup-only
```

Use this when you want to:
- Create a backup before manual updates
- Schedule regular backups without updates
- Test the backup functionality

#### `--restore` and `--restore-date`

Restore from a specific backup:

```bash
./scripts/ai/update-ollama-openwebui.sh --restore --restore-date 20260314-143000
```

The restore date format is `YYYYMMDD-HHMMSS` (e.g., `20260314-143000` for March 14, 2026 at 14:30:00).

Use this when:
- An update caused issues
- You want to revert to a previous state
- Data was accidentally deleted or corrupted

#### `--no-backup`

Skip backup before update (not recommended):

```bash
./scripts/ai/update-ollama-openwebui.sh --no-backup
```

⚠️ **Warning**: This option is not recommended as it bypasses the safety mechanism of creating backups before updates. Only use this if you:
- Have a recent backup already
- Are testing in a non-production environment
- Understand the risks of not having a backup

#### `--help`

Display help information:

```bash
./scripts/ai/update-ollama-openwebui.sh --help
```

### Examples

#### Example 1: Regular Update

```bash
# Update both services with automatic backup
./scripts/ai/update-ollama-openwebui.sh
```

#### Example 2: Backup Before Manual Testing

```bash
# Create backups before trying something new
./scripts/ai/update-ollama-openwebui.sh --backup-only

# Now you can safely test manual updates
```

#### Example 3: Restore After Failed Update

```bash
# List available backups
ls -lh ~/backups/open-webui/
ls -lh ~/backups/ollama/

# Restore from a specific backup
./scripts/ai/update-ollama-openwebui.sh --restore --restore-date 20260314-143000
```

#### Example 4: Update Without Backup (Advanced)

```bash
# Only if you have a recent backup and understand the risks
./scripts/ai/update-ollama-openwebui.sh --no-backup
```

## Backup and Restore

### How Backups Work

The script creates backups before any destructive operations:

#### Open Web UI Backup

- **Location**: `~/backups/open-webui/`
- **Format**: `open-webui-backup-YYYYMMDD-HHMMSS.tar.gz`
- **Contents**: All data from the Open Web UI volume (conversations, settings, configurations)
- **Method**: Uses an Alpine container to archive the volume data

#### Ollama Backup

- **Location**: `~/backups/ollama/`
- **Format**: `ollama-backup-YYYYMMDD-HHMMSS.tar.gz`
- **Contents**: The entire `~/.ollama` directory (models, configurations, cache)
- **Method**: Uses tar to archive the data directory

### Where Backups Are Stored

```
~/
└── backups/
    ├── open-webui/
    │   ├── open-webui-backup-20260314-143000.tar.gz
    │   ├── open-webui-backup-20260321-150000.tar.gz
    │   └── ...
    └── ollama/
        ├── ollama-backup-20260314-143000.tar.gz
        ├── ollama-backup-20260321-150000.tar.gz
        └── ...
```

### How to Restore from Backup

#### Automatic Restore Using the Script

```bash
# Restore from a specific backup
./scripts/ai/update-ollama-openwebui.sh --restore --restore-date 20260314-143000
```

The script will:
1. Stop running services
2. Remove current containers/volumes
3. Extract backup data
4. Recreate containers with restored data
5. Start services
6. Verify everything is working

#### Manual Restore (Advanced)

If you need to manually restore:

**Open Web UI:**
```bash
# Stop the container
podman stop open-webui

# Remove the container
podman rm open-webui

# Remove the volume
podman volume rm open-webui

# Create a new volume
podman volume create open-webui

# Restore the backup
podman run --rm \
  -v open-webui:/data \
  -v ~/backups/open-webui:/backup:ro \
  alpine sh -c "cd /data && tar xzf /backup/open-webui-backup-20260314-143000.tar.gz"

# Start the container
podman run -d \
  --network=host \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

**Ollama:**
```bash
# Stop the service
sudo systemctl stop ollama

# Backup current data
mv ~/.ollama ~/.ollama.old

# Restore the backup
tar xzf ~/backups/ollama/ollama-backup-20260314-143000.tar.gz -C ~/

# Start the service
sudo systemctl start ollama

# Verify
ollama list

# Remove old data (if restore was successful)
rm -rf ~/.ollama.old
```

## Troubleshooting

### Common Issues

#### Issue: "Dependency 'podman' is not installed"

**Solution:**
```bash
sudo dnf install podman
```

#### Issue: "Failed to pull Open Web UI image"

**Possible causes:**
- Network connectivity issues
- Container registry is down
- Firewall blocking connections

**Solutions:**
1. Check your internet connection
2. Try again later
3. Check firewall settings:
```bash
sudo firewall-cmd --list-all
```

#### Issue: "Failed to stop Open Web UI container"

**Possible causes:**
- Container is already stopped
- Container doesn't exist
- Permission issues

**Solutions:**
1. Check container status:
```bash
podman ps -a | grep open-webui
```

2. Force stop if needed:
```bash
podman stop open-webui
podman rm open-webui
```

#### Issue: "Failed to update Ollama"

**Possible causes:**
- Network connectivity issues
- Ollama installer script changed
- Permission issues

**Solutions:**
1. Check your internet connection
2. Try manual update:
```bash
sudo systemctl stop ollama
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl start ollama
```

#### Issue: "Backup file not found"

**Possible causes:**
- Incorrect backup date format
- Backup was deleted
- Backup directory doesn't exist

**Solutions:**
1. List available backups:
```bash
ls -lh ~/backups/open-webui/
ls -lh ~/backups/ollama/
```

2. Use the correct backup date from the filename

#### Issue: "Open Web UI container is not running after update"

**Possible causes:**
- Container failed to start
- Port conflict (8080 already in use)
- Volume issue

**Solutions:**
1. Check container logs:
```bash
podman logs open-webui
```

2. Check what's using port 8080:
```bash
sudo lsof -i :8080
```

3. Remove and recreate the container manually

#### Issue: "Ollama models are missing after update"

**Possible causes:**
- Backup was not created
- Restore was not performed
- Models were in a different location

**Solutions:**
1. Check if models exist:
```bash
ollama list
```

2. If models are missing, restore from backup:
```bash
./scripts/ai/update-ollama-openwebui.sh --restore --restore-date <backup-date>
```

3. Re-download models if no backup is available:
```bash
ollama pull <model-name>
```

### Error Messages

#### "Failed to create Open Web UI backup"

This error occurs when the script cannot create a backup of the Open Web UI volume.

**Troubleshooting:**
1. Check if the container exists:
```bash
podman ps -a | grep open-webui
```

2. Check if the volume exists:
```bash
podman volume ls | grep open-webui
```

3. Check disk space:
```bash
df -h
```

#### "Failed to create Ollama backup"

This error occurs when the script cannot create a backup of the Ollama data directory.

**Troubleshooting:**
1. Check if Ollama is installed:
```bash
which ollama
```

2. Check if the data directory exists:
```bash
ls -la ~/.ollama
```

3. Check disk space:
```bash
df -h
```

#### "Failed to restore Open Web UI backup"

This error occurs when the script cannot restore the Open Web UI backup.

**Troubleshooting:**
1. Verify the backup file exists:
```bash
ls -lh ~/backups/open-webui/open-webui-backup-<date>.tar.gz
```

2. Check if the backup file is valid:
```bash
tar tzf ~/backups/open-webui/open-webui-backup-<date>.tar.gz | head
```

3. Check disk space for restore:
```bash
df -h
```

## Best Practices

### When to Update

- **Regular updates**: Update weekly or monthly to stay current with security fixes and new features
- **Before major changes**: Create a backup before making significant changes to your setup
- **After testing**: Test updates in a non-production environment first if possible

### Backup Recommendations

- **Keep multiple backups**: Don't rely on a single backup. Keep at least 3-5 recent backups
- **Regular backups**: Create backups regularly, even if you're not updating
- **Test restores**: Periodically test restoring from backups to ensure they work
- **Off-site backups**: Consider copying important backups to external storage or cloud storage

### Safety Tips

1. **Always backup before updating**: Never use `--no-backup` unless you have a recent backup
2. **Check release notes**: Before updating, check the [Open Web UI releases](https://github.com/open-webui/open-webui/releases) and [Ollama releases](https://github.com/ollama/ollama/releases) for breaking changes
3. **Update one component at a time**: If you encounter issues, update one component, test it, then update the other
4. **Monitor disk space**: Backups and updates require disk space. Monitor your available space
5. **Schedule updates during downtime**: Update when you're not actively using the services
6. **Keep a log**: Note which backups work and which updates cause issues

### Disk Space Management

Ollama models can be several GB each. Here are some tips for managing disk space:

```bash
# Check disk usage
df -h

# Check Ollama model sizes
du -sh ~/.ollama/models/*

# Remove unused models
ollama rm <model-name>

# Clean up old backups (keep only the last 5)
cd ~/backups/open-webui
ls -t | tail -n +6 | xargs rm -f

cd ~/backups/ollama
ls -t | tail -n +6 | xargs rm -f
```

## Advanced Usage

### Custom Configuration

If you have custom configurations for Open Web UI or Ollama, ensure they are included in your backups:

**Open Web UI:**
- Settings are stored in the volume backup
- Custom models or embeddings should be backed up separately if stored outside the volume

**Ollama:**
- All models and configurations are in `~/.ollama`
- Custom model files are included in the backup

### Integration with Other Scripts

You can integrate this update script with other maintenance scripts:

```bash
# Example: Update Fedora, then update AI tools
sudo ./scripts/maintenance/fedora-update.sh
./scripts/ai/update-ollama-openwebui.sh
```

### Automated Updates

For automated updates, consider using cron:

```bash
# Edit crontab
crontab -e

# Add weekly backup (every Sunday at 2 AM)
0 2 * * 0 /home/user/Documents/code/fedora-user-scripts/scripts/ai/update-ollama-openwebui.sh --backup-only > /tmp/ai-backup.log 2>&1

# Add weekly update (every Sunday at 3 AM)
0 3 * * 0 /home/user/Documents/code/fedora-user-scripts/scripts/ai/update-ollama-openwebui.sh > /tmp/ai-update.log 2>&1
```

⚠️ **Warning**: Automated updates can cause issues if something goes wrong. Always test manual updates first and ensure you have working backups.

## Additional Resources

### Official Documentation
- [Ollama Official Documentation](https://ollama.com/docs)
- [Open Web UI GitHub Repository](https://github.com/open-webui/open-webui)
- [Podman Documentation](https://docs.podman.io/)

### Related Guides
- [Ollama and Open Web UI Start Guide](start-ollama-openwebui-guide.md)
- [Fedora Update Guide](../guides/fedora-update-guide.md)
- [Security Sweep Guide](../guides/security-sweep-guide.md)

### Community Support
- [Ollama GitHub Issues](https://github.com/ollama/ollama/issues)
- [Open Web UI GitHub Issues](https://github.com/open-webui/open-webui/issues)
- [Fedora User Scripts GitHub Issues](https://github.com/neardaniel-pls/fedora-user-scripts/issues)

## Summary

The [`update-ollama-openwebui.sh`](../../scripts/ai/update-ollama-openwebui.sh) script provides a safe and convenient way to update Ollama and Open Web UI on Fedora systems. By following this guide and the best practices outlined, you can keep your AI tools up to date while minimizing the risk of data loss or service disruption.

Remember:
- Always backup before updating
- Keep multiple recent backups
- Test updates when possible
- Monitor disk space
- Check release notes for breaking changes

For questions or issues, please refer to the troubleshooting section or open an issue on the project's GitHub repository.
