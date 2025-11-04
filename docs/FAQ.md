# Frequently Asked Questions

## General Questions

### Q: Which Fedora versions are supported?
**A:** Scripts are tested and confirmed working on:
- ✅ Fedora 42
- ✅ Fedora 43
- ❓ Other versions (untested but may work)

### Q: Can I use these scripts on other Linux distributions?
**A:** While designed for Fedora, some scripts may work on other RPM-based systems. However:
- Package manager commands (dnf) are Fedora-specific
- Paths and dependencies may differ
- No support provided for non-Fedora systems

### Q: Do I need to be root to run these scripts?
**A:** It depends on the script:
- **No root needed**: clean-metadata.sh, run-searxng.sh, update-searxng.sh
- **Root required**: security-sweep.sh, fedora-update.sh (for system updates), secure-delete.sh

### Q: How do I report security vulnerabilities?
**A:** Please report security issues privately:
- Email: [create a security email address]
- Or use GitHub's private vulnerability reporting
- Don't open public issues for security vulnerabilities

## Script-Specific Questions

### clean-metadata.sh
**Q: Does it modify the original files?**
**A:** No, by default it creates new files with `_cleaned_opt` suffix. Use `--replace` to overwrite originals.

**Q: Can I recover metadata after cleaning?**
**A:** No, metadata removal is permanent. Always backup important files before cleaning.

### security-sweep.sh
**Q: Why does it take so long to run?**
**A:** The comprehensive scan checks multiple security aspects. Run individual scans with `-i`, `-r`, `-m`, `-a` flags for faster execution.

**Q: Can I exclude home directories?**
**A:** Yes, use the `-e` flag to exclude home directories for privacy.

### SearXNG Scripts
**Q: Do I need Docker installed?**
**A:** Yes, the scripts expect SearXNG to be installed in a Docker environment.

**Q: Can I change the default port?**
**A:** Yes, set `SEARXNG_PORT=8080` (or any port) before running:
```bash
SEARXNG_PORT=8080 ./scripts/searxng/run-searxng.sh
```

### fedora-update.sh
**Q: Will this remove important packages?**
**A:** No, it only:
- Updates existing packages
- Cleans package cache
- Removes old kernels (configurable)
- Doesn't remove user-installed packages

## Troubleshooting

### Permission Issues
**Q: Getting "Permission denied" errors?**
**A:** Try these solutions:
```bash
# Make scripts executable
chmod +x scripts/**/*.sh

# Use sudo for system operations
sudo ./scripts/security/security-sweep.sh

# Check file ownership
ls -la scripts/
```

### Dependency Issues
**Q: Script complains about missing commands?**
**A:** Install missing dependencies:
```bash
# For metadata cleaning
sudo dnf install exiftool ghostscript pngquant jpegoptim

# For security tools
sudo dnf install chkrootkit clamav lynis

# For all common dependencies
sudo dnf install exiftool ghostscript pngquant jpegoptim coreutils chkrootkit clamav lynis bleachbit
```

### Path Issues
**Q: "Command not found" when running scripts?**
**A:** Check your path:
```bash
# Use absolute path
~/fedora-user-scripts/scripts/maintenance/clean-metadata.sh

# Or add to PATH
echo 'export PATH="$PATH:~/fedora-user-scripts/scripts"' >> ~/.bashrc
source ~/.bashrc
```

## Performance Questions

### Q: Why are scripts slow on large directories?
**A:** Some operations are inherently resource-intensive:
- Metadata cleaning processes each file individually
- Security scans check every file
- Malware scans examine file contents

**Tips for better performance:**
- Process smaller batches of files
- Exclude unnecessary directories
- Use SSD storage for better I/O
- Ensure sufficient RAM

## Contributing

### Q: How do I contribute to the project?
**A:** See our [Contributing Guide](../CONTRIBUTING.md), but quick steps are:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

### Q: What coding standards should I follow?
**A:** Follow the existing patterns:
- Use `set -euo pipefail` for error handling
- Include comprehensive headers
- Add proper error checking
- Document security considerations

## Still Have Questions?

- 📖 Check [full documentation](docs/README.md)
- 🔍 Search [existing issues](https://github.com/neardaniel-pls/fedora-user-scripts/issues)
- 🐛 [Open new issue](https://github.com/neardaniel-pls/fedora-user-scripts/issues/new)
- 💬 [Start a discussion](https://github.com/neardaniel-pls/fedora-user-scripts/discussions)

---

**Last Updated**: 2025-11-04  
**Version**: 1.0.0