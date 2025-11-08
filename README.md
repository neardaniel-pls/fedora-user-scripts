# Fedora User Scripts Collection

A collection of personal utility scripts **optimized for Fedora Linux systems**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Fedora Version](https://img.shields.io/badge/Fedora-42%2B-blue.svg)](https://getfedora.org/)

## Overview

This repository contains shell scripts designed specifically for Fedora environments, with a focus on system maintenance, security, and file management utilities.

## Scripts

### clean-metadata.sh
- **Purpose:** Cleans metadata from PDF, PNG, and JPEG files and optimizes them
- **Usage:** `scripts/maintenance/clean-metadata.sh [file|directory]`
- **Dependencies:** `exiftool`, `gs`, `pngquant`, `jpegoptim`, `numfmt`

### fedora-update.sh
- **Purpose:** Performs weekly maintenance on Fedora systems, including package updates and cache cleaning
- **Usage:** `scripts/maintenance/fedora-update.sh`
- **Note:** This script is specific to Fedora and uses DNF package manager operations

### secure-delete.sh
- **Purpose:** Securely deletes files and directories by overwriting them with random data
- **Usage:** `scripts/security/secure-delete.sh [file|directory]`
- **Dependencies:** `shred`

### security-sweep.sh
- **Purpose:** Performs comprehensive security sweep on Fedora systems, checking file integrity, rootkits, malware, and auditing security configurations
- **Usage:** `sudo scripts/security/security-sweep.sh`
- **Dependencies:** `chkrootkit`, `clamav`, `lynis`
- **Note:** Fedora-specific security audit script for systems hardening

### run-searxng.sh
- **Purpose:** Runs SearXNG instance using Python virtual environment
- **Usage:** `scripts/searxng/run-searxng.sh`
- **Dependencies:** python3, virtual environment, SearXNG installation at $HOME/Documents/code/searxng/

### update-searxng.sh
- **Purpose:** Updates SearXNG instance by pulling latest changes from git repository
- **Usage:** `scripts/searxng/update-searxng.sh`
- **Dependencies:** `git`
- **Note:** This script is included in `scripts/maintenance/fedora-update.sh`

## Documentation

### 📚 [Documentation Hub](docs/README.md)
Comprehensive documentation with guides, API reference, and examples

### 🚀 [Quick Start Guide](docs/QUICK_START.md)
Get up and running in 5 minutes!

### 📖 [Guides](docs/guides/)
Detailed documentation for each script:
- [Clean Metadata Guide](docs/guides/clean-metadata-guide.md)
- [Fedora Update Guide](docs/guides/fedora-update-guide.md)
- [SearXNG Guide](docs/guides/searxng-guide.md)
- [Security Sweep Script Guide](docs/guides/security-sweep-guide.md)

### ❓ [FAQ](docs/FAQ.md)
Frequently asked questions and troubleshooting

### 📋 [Development Workflow](DEVELOPMENT_WORKFLOW.md)
Guide for contributing to the project

## System Requirements

These scripts are designed for **Fedora Linux** distributions. While some scripts may work on other RPM-based systems, they are specifically tested and optimized for:

- ✅ Fedora 42
- ✅ Fedora 43
- ❓ Other versions (untested)

## Installation

### Quick Start

1. Clone the repository:
```bash
git clone https://github.com/neardaniel-pls/fedora-user-scripts.git
cd fedora-user-scripts
```

2. Make scripts executable:
```bash
chmod +x scripts/**/*.sh
```

3. Install dependencies (see individual script documentation):
```bash
# Check for common dependencies
sudo dnf install exiftool ghostscript pngquant jpegoptim coreutils chkrootkit clamav lynis bleachbit
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 🐛 [Report Bugs](https://github.com/neardaniel-pls/fedora-user-scripts/issues/new?template=bug_report.md)
- 💡 [Request Features](https://github.com/neardaniel-pls/fedora-user-scripts/issues/new?template=feature_request.md)
- 📖 [Documentation](https://github.com/neardaniel-pls/fedora-user-scripts/wiki)
- 🙏 [Acknowledgments](https://github.com/neardaniel-pls/fedora-user-scripts/blob/main/README.md#acknowledgments)

---

**Note**: For comprehensive Fedora system administration guides, see the companion [fedora-system-setup](https://github.com/yourusername/fedora-system-setup) repository.