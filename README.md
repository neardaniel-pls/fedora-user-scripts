# User Scripts (Fedora-Only)

A collection of personal utility scripts **optimized for Fedora Linux systems**.

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

## How-to

- [SearXNG Guide](scripts/how-to/searxng-guide.md)
- [Security Sweep Script Guide](scripts/how-to/security-sweep-guide.md)
- [Clean Metadata Guide](scripts/how-to/clean-metadata-guide.md)
- [Fedora Update Guide](scripts/how-to/fedora-update-guide.md)

---

## System Requirements

These scripts are designed for **Fedora Linux** distributions. While some scripts may work on other RPM-based systems, they are specifically tested and optimized for Fedora 42.

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.