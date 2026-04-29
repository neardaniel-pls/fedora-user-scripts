# Guide: Clean Downloads Script

This guide provides instructions on how to use the `clean-downloads.sh` script, a file organization and cleanup utility for your Downloads directory.

## Overview

The `clean-downloads.sh` script sorts files in your Downloads folder into categorized subdirectories by file type. It can also purge files older than a configurable number of days. All operations support dry-run mode for safe preview.

The script performs:
- **File Organization**: Sorts files into categories (Images, Documents, Archives, Videos, Audio, Code, Fonts, Other)
- **Age-Based Purge**: Deletes files older than a specified number of days
- **Conflict Resolution**: Handles duplicate filenames by appending a number suffix
- **Dry-Run Preview**: Shows what would happen without making changes

## Dependencies

Install required tools:

```bash
sudo dnf install file
```

- `file`: For MIME type detection (standard on most Fedora installations)

## Installation & Setup

1. Make the script executable:
   ```bash
   chmod +x scripts/maintenance/clean-downloads.sh
   ```

2. (Optional) Create an alias in `~/.bashrc`:
   ```bash
   alias cleandl='bash "$HOME/Documents/code/fedora-user-scripts/scripts/maintenance/clean-downloads.sh"'
   source ~/.bashrc
   ```

## Usage

### Organize Downloads (Default)

```bash
./scripts/maintenance/clean-downloads.sh
```

This sorts all files in `~/Downloads` into subdirectories:
```
~/Downloads/
├── Images/       (jpg, png, gif, svg, webp, raw, heic, ...)
├── Documents/    (pdf, doc, txt, csv, md, epub, ...)
├── Archives/     (zip, tar, gz, 7z, rar, rpm, iso, ...)
├── Videos/       (mp4, mkv, avi, mov, webm, ...)
├── Audio/        (mp3, flac, ogg, opus, wav, aac, ...)
├── Code/         (js, py, go, rs, sh, html, json, yaml, ...)
├── Fonts/        (ttf, otf, woff, woff2, ...)
└── Other/        (anything not matched)
```

### Preview Before Organizing

```bash
./scripts/maintenance/clean-downloads.sh --dry-run
```

### Delete Old Files

```bash
# Delete files older than 30 days
./scripts/maintenance/clean-downloads.sh --purge 30
```

### Organize and Purge Together

```bash
# Preview both operations
./scripts/maintenance/clean-downloads.sh --organize --purge 30 --dry-run

# Apply both operations
./scripts/maintenance/clean-downloads.sh --organize --purge 30
```

### Target a Different Directory

```bash
./scripts/maintenance/clean-downloads.sh ~/Documents/Unsorted
```

### Help

```bash
./scripts/maintenance/clean-downloads.sh --help
```

## Options

| Flag | Description |
|------|-------------|
| `--organize` | Sort files into categorized subdirectories (default if no action specified) |
| `--purge <days>` | Delete files older than the specified number of days |
| `--dry-run` | Preview actions without moving or deleting anything |
| `--help`, `-h` | Display help message and exit |
| `--version`, `-V` | Display script version |
| `[directory]` | Target directory (default: `~/Downloads`) |

## Category Mappings

| Category | Extensions |
|-----------|-----------|
| Images | jpg, jpeg, png, gif, bmp, svg, webp, ico, tiff, raw, cr2, nef, arw, dng, heic, heif |
| Documents | pdf, doc, docx, odt, odp, ods, txt, rtf, md, csv, epub, xls, xlsx, ppt, pptx |
| Archives | zip, tar, gz, bz2, xz, 7z, rar, zst, deb, rpm, apk, dmg, iso |
| Videos | mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpg, mpeg |
| Audio | mp3, flac, ogg, opus, wav, aac, m4a, wma, aiff |
| Code | js, ts, py, rb, go, rs, java, c, cpp, h, sh, html, css, json, xml, yaml, sql, php |
| Fonts | ttf, otf, woff, woff2, eot |
| Other | Any file not matched by the above categories |

## Safety

- **System directories are protected**: The script refuses to operate on `/`, `/etc`, `/usr`, `/var`, etc.
- **Filename conflicts are handled**: If a file with the same name exists in the target category, a number suffix is appended
- **Dry-run mode**: Always available with `--dry-run` for safe preview
- **Purge only affects top-level files**: The `--purge` flag only deletes files directly in the target directory, not in subdirectories

## Troubleshooting

### "Directory not found"
The default target is `~/Downloads`. Specify a different directory as an argument.

### Files not being categorized
Check if the file has an extension. Files without extensions go to the "Other" category.

### Permission denied
Ensure you have read/write access to the target directory.
