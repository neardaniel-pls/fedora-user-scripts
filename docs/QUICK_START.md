# Quick Start Guide

Get up and running with Fedora User Scripts Collection in 5 minutes!

## 🚀 5-Minute Setup

### Prerequisites
- Fedora 42 or 43 (other versions untested)
- Git installed
- sudo access (for some scripts)

### Step 1: Clone Repository (30 seconds)
```bash
git clone https://github.com/neardaniel-pls/fedora-user-scripts.git
cd fedora-user-scripts
```

### Step 2: Install Dependencies (2 minutes)
```bash
# Install all common dependencies at once
sudo dnf install exiftool ghostscript pngquant jpegoptim coreutils chkrootkit clamav lynis bleachbit git python3

# For SearXNG (if using)
sudo dnf install python3 python3-pip python3-virtualenv docker

# For update-hosts script, also clone the StevenBlack hosts repository:
git clone https://github.com/StevenBlack/hosts.git ~/Documents/code/hosts
```

### Step 3: Make Scripts Executable (30 seconds)
```bash
# Make all scripts executable
chmod +x scripts/**/*.sh
```

### Step 4: Test Installation (1 minute)
```bash
# Test a simple script
./scripts/maintenance/fedora-update.sh --help

# Test security script (requires sudo)
sudo ./scripts/security/security-sweep.sh -h
```

### Step 5: Run Your First Script (30 seconds)
```bash
# Clean metadata from a file
./scripts/maintenance/clean-metadata.sh ~/Documents/example.pdf

# Or run system maintenance
./scripts/maintenance/fedora-update.sh
```

## 🎯 Common First Tasks

### Clean Metadata from Files
```bash
# Single file
./scripts/maintenance/clean-metadata.sh document.pdf

# Entire directory
./scripts/maintenance/clean-metadata.sh ~/Documents/
```

### Run Security Check
```bash
# Full security sweep (takes time)
sudo ./scripts/security/security-sweep.sh

# Quick check only
sudo ./scripts/security/security-sweep.sh -i -r
```

### Start SearXNG
```bash
# Start privacy search engine
./scripts/searxng/run-searxng.sh

# Access at http://localhost:8888
```

### Update Hosts File
```bash
# Update StevenBlack hosts file with default extensions
./scripts/maintenance/update-hosts.sh

# Or with specific extensions
HOSTS_EXTENSIONS="fakenews,gambling" ./scripts/maintenance/update-hosts.sh
```

## 🔧 Configuration (Optional)

### Set Up Aliases (1 minute)
Add to your `~/.bashrc` for easier access:
```bash
# Add these lines
alias cleanmeta='bash ~/fedora-user-scripts/scripts/maintenance/clean-metadata.sh'
alias secscan='sudo ~/fedora-user-scripts/scripts/security/security-sweep.sh'
alias fedora-update='bash ~/fedora-user-scripts/scripts/maintenance/fedora-update.sh'
alias updatehosts='bash ~/fedora-user-scripts/scripts/maintenance/update-hosts.sh'

# Reload shell
source ~/.bashrc
```

## 📚 Next Steps

1. **Read Detailed Guides**: Check [docs/guides/](guides/) for detailed instructions
2. **Explore Scripts**: See [main README](../README.md) for all available scripts
3. **Customize**: Adjust scripts to your needs

## ❓ Need Help?

### Quick Fixes
- **Permission Denied**: Use `sudo` for security scripts
- **Command Not Found**: Run `chmod +x scripts/**/*.sh`
- **Dependencies Missing**: Run Step 2 again

### Get Support
- 📖 [Full Documentation](docs/README.md)
- 🐛 [Report Issues](https://github.com/neardaniel-pls/fedora-user-scripts/issues)
- 💡 [Request Features](https://github.com/neardaniel-pls/fedora-user-scripts/issues/new?template=feature_request.md)

## ✅ You're Ready!

You now have Fedora User Scripts Collection installed and ready to use. Try these common commands:

```bash
# Clean metadata
cleanmeta ~/Downloads/sensitive.pdf

# Update system
fedora-update

# Security check
secscan

# Start SearXNG
./scripts/searxng/run-searxng.sh

# Update hosts file
updatehosts
```

**Happy scripting!** 🎉

---

**Time Estimate**: Based on typical system and network speeds  
**Last Updated**: 2025-11-04  
**Version**: 1.0.0