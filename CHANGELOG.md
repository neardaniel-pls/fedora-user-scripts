# Changelog

All notable changes to Fedora User Scripts Collection will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Repository**: https://github.com/neardaniel-pls/fedora-user-scripts

## [Unreleased]

### Added
- Simplified GitHub templates (PR, feature request, bug report) for better usability
- Streamlined documentation structure with significant size reductions:
  - Clean Metadata Guide: 584 → 78 lines (87% reduction)
  - Fedora Update Guide: 223 → 73 lines (67% reduction)
  - SearXNG Guide: 143 → 73 lines (49% reduction)
  - Security Sweep Guide: 216 → 103 lines (52% reduction)
  - FAQ: 179 → 118 lines (34% reduction)
  - Quick Start Guide: 146 → 96 lines (34% reduction)
  - Documentation README: 81 → 69 lines (15% reduction)
- Eliminated redundant installation instructions across guides
- Consolidated troubleshooting information in centralized locations
- Maintained security considerations throughout all documentation

### Changed
- Improved template focus on essential information only
- Reduced documentation verbosity while preserving critical content
- Enhanced user experience with more concise guides

## [1.0.0] - 2025-11-04

### Added
- Initial release of Fedora User Scripts Collection
- Metadata cleaning and optimization script (`clean-metadata.sh`)
- Fedora system maintenance script (`fedora-update.sh`)
- Security sweep utility (`security-sweep.sh`)
- Secure file deletion script (`secure-delete.sh`)
- SearXNG management scripts (`run-searxng.sh`, `update-searxng.sh`)
- BleachBit automation script (`bleachbit-automation.sh`)
- Script template for new development (`template.sh`)
- Comprehensive documentation guides for all scripts
- Fedora 42+ initial setup guide

### Security
- All scripts implement security best practices
- Input validation and path traversal protection
- Secure temporary file handling
- Privacy-focused metadata removal

## Compatibility Matrix

| Version | Fedora 40 | Fedora 41 | Fedora 42 | Fedora 43 |
|---------|-----------|-----------|-----------|------------|
| 1.0.0   | ?         | ?         | ✅        | ✅        |

Legend:
- ✅ Tested and confirmed working
- ? Not tested (may work, but unverified)

## Contributing to Changelog

When contributing to this project:
- Add entries to the "Unreleased" section
- Follow the established format
- Include version number and date for releases
- Document breaking changes prominently

## Additional Resources

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)