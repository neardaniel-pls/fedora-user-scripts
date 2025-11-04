# Fedora User Scripts Collection

A collection of personal utility scripts **optimized for Fedora Linux systems**.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Fedora Version](https://img.shields.io/badge/Fedora-42%2B-blue.svg)](https://getfedora.org/)

## Overview

This repository contains shell scripts designed specifically for Fedora environments, with a focus on system maintenance, security, and file management utilities.

## Scripts

### clean-metadata.sh

- **Purpose:** Cleans metadata from PDF, PNG, and JPEG files and optimizes them.
- **Usage:** `scripts/maintenance/clean-metadata.sh [file|directory]`
- **Dependencies:** `exiftool`, `gs`, `pngquant`, `jpegoptim`, `numfmt`

### fedora-update.sh

- **Purpose:** Performs weekly maintenance on Fedora systems, including package updates and cache cleaning.
- **Usage:** `scripts/maintenance/fedora-update.sh`
- **Note:** This script is specific to Fedora and uses DNF package manager operations.

### secure-delete.sh

- **Purpose:** Securely deletes files and directories by overwriting them with random data.
- **Usage:** `scripts/security/secure-delete.sh [file|directory]`
- **Dependencies:** `shred`

### security-sweep.sh

- **Purpose:** Performs a comprehensive security sweep on Fedora systems, checking file integrity, rootkits, malware, and auditing security configurations.
- **Usage:** `sudo scripts/security/security-sweep.sh`
- **Dependencies:** `chkrootkit`, `clamav`, `lynis`
- **Note:** Fedora-specific security audit script for systems hardening. It will take a long time to run the complete check.

### run-searxng.sh

- **Purpose:** Runs the SearXNG instance in a Docker container.
- **Usage:** `scripts/searxng/run-searxng.sh`

### update-searxng.sh

- **Purpose:** Updates the SearXNG instance by pulling the latest changes from the git repository.
- **Usage:** `scripts/searxng/update-searxng.sh`
- **Note:** This script is included in `scripts/maintenance/fedora-update.sh`

---

## Initial Setup

For new users, a comprehensive guide for the initial setup of a Fedora system is available:

- [Fedora Initial Setup Guide](FEDORA_INITAL_SETUP.md)

## How-to

- [SearXNG Guide](scripts/how-to/searxng-guide.md)
- [Security Sweep Script Guide](scripts/how-to/security-sweep-guide.md)
- [Clean Metadata Guide](scripts/how-to/clean-metadata-guide.md)
- [Fedora Update Guide](scripts/how-to/fedora-update-guide.md)

---

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

3. Install dependencies (see individual script documentation)

### Dependencies

Each script has its own dependencies. Check the individual script documentation or run:
```bash
# Check for common dependencies
sudo dnf install exiftool ghostscript pngquant jpegoptim coreutils chkrootkit clamav lynis bleachbit
```

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For detailed guidelines, see our [Contributing Guide](CONTRIBUTING.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.

## Support

- 🐛 [Report Bugs](https://github.com/neardaniel-pls/fedora-user-scripts/issues/new?template=bug_report.md)
- 💡 [Request Features](https://github.com/neardaniel-pls/fedora-user-scripts/issues/new?template=feature_request.md)
- 📖 [Documentation](https://github.com/neardaniel-pls/fedora-user-scripts/wiki)

## Acknowledgments

Thanks to the Fedora community and all contributors who help improve this project.