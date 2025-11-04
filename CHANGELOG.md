# Changelog

All notable changes to the Fedora User Scripts Collection will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Repository**: https://github.com/neardaniel-pls/fedora-user-scripts

## [Unreleased]

### Added
- Project management files (LICENSE, CONTRIBUTING.md, CHANGELOG.md)
- Comprehensive improvement plan documentation
- Folder structure analysis and recommendations
- Documentation consolidation with new docs/ structure
- Quick start guide for 5-minute setup
- Comprehensive FAQ section
- Development workflow guide

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

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

## Version History

### Version 1.0.0
- **Release Date**: 2025-11-04
- **Status**: Initial Release
- **Fedora Compatibility**: Tested on Fedora 42 and 43 (other versions untested)
- **Key Features**:
  - System maintenance automation
  - Security scanning and auditing
  - Privacy-focused file processing
  - Service management utilities

### Future Versions
- **v1.1.0**: Planned improvements based on user feedback
- **v1.2.0**: Enhanced testing infrastructure
- **v2.0.0**: Major restructuring and new features

## Release Notes

### v1.0.0 Release Notes
- This is the initial release of the user scripts collection
- All scripts have been tested on Fedora 42
- Documentation is comprehensive and includes troubleshooting guides
- Scripts follow security best practices
- MIT license applied for maximum compatibility

## Upgrade Guide

### From v1.0.0 to v1.1.0 (Future)
- Backup existing configurations
- Review breaking changes in release notes
- Update script paths if reorganization occurred
- Test critical scripts after upgrade

## Compatibility Matrix

| Version | Fedora 40 | Fedora 41 | Fedora 42 | Fedora 43 |
|---------|-----------|-----------|-----------|------------|
| 1.0.0   | ?         | ?         | ✅        | ✅        |

Legend:
- ✅ Tested and confirmed working
- ? Not tested (may work, but unverified)

## Security Updates

Security updates will be documented here with:
- CVE numbers (if applicable)
- Description of vulnerability
- Affected versions
- Recommended actions

## Contributing to Changelog

When contributing to this project:
- Add entries to the "Unreleased" section
- Follow the established format
- Include version number and date for releases
- Document breaking changes prominently

## Additional Resources

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [How to Write Good Changelogs](https://github.com/olivierlacan/keep-a-changelog/blob/master/CHANGELOG.md)