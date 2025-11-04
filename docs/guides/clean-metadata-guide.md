# Guide: Clean Metadata Script

This guide provides instructions on how to use the `clean-metadata.sh` script, a privacy-focused tool for removing sensitive metadata from documents and images while optimizing file sizes.

## Overview

The `clean-metadata.sh` script automates metadata removal and file optimization to help protect your privacy when sharing or archiving files. It works with PDF, PNG, and JPEG files.

The script performs:
- **Metadata Removal**: Strips all EXIF, IPTC, XMP, and embedded metadata using `exiftool`
- **File Optimization**: Compresses files using format-specific tools
- **Batch Processing**: Supports processing individual files or entire directories recursively
- **Smart Comparison**: Automatically skips optimization if the result would be larger

## Dependencies

Install required tools using `dnf`:

```bash
sudo dnf install exiftool ghostscript pngquant jpegoptim coreutils
```

## Installation & Setup

1. Make the script executable:
   ```bash
   chmod +x /path/to/clean-metadata.sh
   ```

2. (Optional) Create an alias in `~/.bashrc`:
   ```bash
   alias cleanmeta='bash "$HOME/user-scripts/scripts/maintenance/clean-metadata.sh"'
   source ~/.bashrc
   ```

## Command-line Options

- `--help` / `-h`: Display usage information
- `--verbose`: Show metadata before cleaning (useful for verification)
- `--replace`: Replace the original file instead of creating a `_cleaned_opt` copy

## Usage

### Basic Usage

```bash
# Single file
cleanmeta /path/to/file.pdf

# Directory (recursive)
cleanmeta ~/Documents/

# Multiple files/directories
cleanmeta file1.pdf file2.png ~/Downloads/
```

### Output Files

By default, creates a new file with `_cleaned_opt` suffix:
- Original: `document.pdf`
- Processed: `document_cleaned_opt.pdf`

With `--replace`, the original file is securely deleted and replaced with the cleaned version.

## Configuration

Control optimization quality with environment variables:

```bash
# PNG quality (default: 65-80)
PNG_QUALITY=75-85 cleanmeta image.png

# JPEG quality (default: 80)
JPEG_QUALITY=85 cleanmeta photo.jpg

# PDF settings (default: /ebook)
PDF_SETTINGS=/screen cleanmeta book.pdf
```

## Security & Privacy

- All data stays local - no external transmission
- No telemetry or usage statistics collected
- Symlink and path traversal protection
- Secure deletion with `shred` when using `--replace`

## Troubleshooting

### Common Issues

- **Permission denied**: Use `chmod +x` on the script
- **Dependency not found**: Install missing packages with dnf
- **Symlink rejected**: Use actual file path, not symlink
- **File already processed**: Rename file to remove `_cleaned` or `_cleaned_opt` suffix

### Error Messages

- `⚠️ Unsupported file type`: Only PDF, PNG, JPG, and JPEG are supported
- `⚠️ Optimized file is not smaller`: Normal for already-optimized files
- `❌ File already exists`: Output file exists, rename or use `--replace`

---

**Last Updated**: October 2025  
**Script Version**: Security Hardened Edition