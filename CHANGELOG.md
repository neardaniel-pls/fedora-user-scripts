# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.3] - 2026-06-12

### Added
- **scripts/lib/ui.sh**: `check_dependencies()` — centralized dependency checking, replacing local copies in 4 scripts
- **scripts/lib/ui.sh**: `human_size()` and `print_kv()` — shared formatting helpers, replacing local copies in drive-check.sh and clean-downloads.sh
- **scripts/lib/ui.sh**: `version_check()` — unified version display for 12 scripts
- **scripts/lib/ui.sh**: `enable_logging()` and `_log()` — opt-in file logging, replacing local overrides in security-sweep.sh and lynis-harden.sh
- **scripts/lib/ui.sh**: `fix_ownership()` — shared ownership fix for container volume mounts, replacing local copies in both SearXNG scripts
- **gui/fedora_scripts_manager/config.py**: Shared Python module with `is_config_safe()` and `resolve_scripts_dir()`, eliminating duplication between window.py and the Nautilus extension

### Changed
- **clean-system.sh**: Refactored with `_clean_scan()`/`_clean_report()` helpers, eliminating ~120 lines of repeated cleanup logic
- **update-hosts.sh**: Deduplicated git operations with `git_cmd()` wrapper; converted help from printf to heredoc
- **window.py**: Import `resolve_scripts_dir` from shared config.py instead of local implementation
- **nautilus extension**: Import from shared config.py instead of local `_is_config_safe`/`_get_scripts_dir`

### Fixed
- **ui.sh**: Fix `print_header()` using hardcoded emoji instead of `${SECTION_ICON}`

### Documentation
- Document `QUIET` env var in `config.example.sh`
- Document shared ui.sh functions and Python config module in `DEV_GUIDELINES.md`

## [1.3.2] - 2026-06-09

### Added
- **scripts/lib/ui.sh**: Shared UI library extracting config loading, color/icon detection, and output functions from all 13 scripts (~1700 lines of duplication eliminated)

### Fixed
- **clean-metadata.sh**: Fix data loss in `--replace` mode — backup file before overwrite instead of shredding original first
- **clean-system.sh**: Fix journal size regex extracting floats that crash bash arithmetic; fix container size parsing reading header row instead of data; deduplicate identical DNF cache branches; fix `--docker`/`--containers` header inconsistency
- **secure-delete.sh**: Use `exit 1` instead of `return 1` (top-level context) when shred fails; abort on shred failure instead of proceeding with `rm -rf`
- **security-sweep.sh**: Track temp files and clean up on interrupt
- **update-hosts.sh**: Add error handling to `cd` commands preventing operations in wrong directory
- **update-searxng.sh**: Auto-fix git repository ownership when `.git/index` is not writable by current user; remove dead `pull_output` variable
- **update-ollama-openwebui.sh**: Validate `--restore-date` argument exists before `shift 2`; fix broken doc link in help text
- **start-ollama-openwebui.sh**: Fix broken doc link in help text
- **script_card.py**: Fix file dialog crash (`None` return from `_create_file_dialog`); add missing `GLib` import for dialog cancellation handling; expand device path regex to accept hyphens, dots, underscores
- **output_viewer.py**: Move VTE `child-exited` signal to `_build_vte_terminal()` to prevent multiple handler connections
- **window.py**: Add `do_close_request` to stop orphaned processes on window close; remove hardcoded developer paths; conditionally include `HOSTS_REPO_PATH` only when directory exists
- **nautilus extension**: Run script execution in background thread to prevent Nautilus UI freeze; add config safety and XDG path resolution; remove hardcoded developer paths
- **ui.sh**: Add config file ownership and permission validation matching Python `_is_config_safe` logic

### Documentation
- Fix 6 broken internal links in Ollama/OpenWebUI guides and script help text
- Remove phantom `bleachbit` dependency from README and Quick Start
- Update stale version refs (1.1.0/1.3.0 → 1.3.1) in docs/README, QUICK_START, FAQ
- Fix FAQ inaccuracies: `secure-delete.sh` does not require root; `fedora-update.sh` does not remove kernels
- Fix `clean-metadata-guide.md` "Security Hardened Edition" version label
- Fix "PREREQUITE" typo in update-hosts guide
- Standardize "Last Updated" dates to June 2026 across all guides
- Update copyright year to 2025-2026 in GUI About dialog
- Improve PR template with checklist items
- Add missing config variables to `config.example.sh` (`SEARXNG_VENV`, `MAX_BACKUPS`, `CLEAN_DL_DIR`, etc.)
- Fix `DEV_GUIDELINES.md` misleading "Not committed to the repo" statement

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
