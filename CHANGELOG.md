# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2026-06-09

### Fixed
- **update-searxng.sh**: Auto-stash uncommitted changes before pulling instead of failing, with safe restore and conflict handling
- **fedora-update.sh**: Remove stderr suppression on SearxNG update so error messages are visible

## [1.3.0] - 2026-06-08

### Added
- **clean-system.sh**: System-wide cache, temp, and junk file cleanup utility with selective targets and dry-run support

### Documentation
- Clean System Guide in `docs/guides/`

## [1.2.1] - 2026-06-06

### Added
- **GUI**: Lynis Hardening script card in the Scripts Manager GUI (`scripts_registry.py`)

### Fixed
- **lynis-harden.sh**: Fix `sed` delimiter conflict causing core dump disable to fail when `kernel.core_pattern` already existed
- **lynis-harden.sh**: Fix skipped items appearing inline without section headers — now grouped under a "SKIPPED ITEMS" section

## [1.2.0] - 2026-06-05

### Added
- **lynis-harden.sh**: Apply Lynis security audit hardening recommendations with interactive menu, backup/undo, and dry-run support

### Documentation
- Lynis Hardening Guide in `docs/guides/`

## [1.1.0] - 2026-04-29

### Added
- **clean-metadata.sh**: Clean metadata from PDF, PNG, and JPEG files and optimize them
- **fedora-update.sh**: Weekly maintenance with package updates, cache cleaning, and interactive restart menu
- **secure-delete.sh**: Securely delete files and directories by overwriting with random data
- **security-sweep.sh**: Comprehensive security sweep (integrity, rootkits, malware, audit)
- **run-searxng.sh**: Run SearXNG instance using Python virtual environment
- **update-searxng.sh**: Update SearXNG instance from git repository
- **update-hosts.sh**: Update StevenBlack hosts repository with customizable extensions
- **update-ollama-openwebui.sh**: Update Ollama and Open Web UI with automatic backup
- **start-ollama-openwebui.sh**: Start Ollama and Open Web UI services
- **drive-check.sh**: Inspect storage drives for model, capacity, partitions, and SMART health
- **clean-downloads.sh**: Sort Downloads into categorized subdirectories with optional age-based purge
- **GTK4/Libadwaita GUI app**: Browse, configure, and run all scripts from a graphical interface
- **Nautilus context menu**: Right-click PDF/PNG/JPEG files to clean metadata
- **setup.sh**: Installer for GUI app, Nautilus extension, and desktop entry
- **docs/**: Full documentation hub with guides, quick start, and FAQ for each script
- **config.example.sh**: Shared configuration file for all scripts

### Documentation
- 10 individual script guides in `docs/guides/`
- Quick Start Guide
- FAQ
- GUI & Desktop Integration Guide
