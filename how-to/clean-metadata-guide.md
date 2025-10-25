# Guide: Clean Metadata Script

This guide provides instructions on how to use the `clean-metadata.sh` script, a privacy-focused tool for removing sensitive metadata from documents and images while optimizing file sizes.

## 1. Overview

The `clean-metadata.sh` script automates metadata removal and file optimization to help protect your privacy when sharing or archiving files. It is designed to be run on-demand and works with PDF, PNG, and JPEG files.

The script performs the following operations:
- **Metadata Removal**: Strips all EXIF, IPTC, XMP, and embedded metadata using `exiftool`
- **PDF Optimization**: Compresses PDFs using Ghostscript while removing embedded streams and metadata
- **PNG Optimization**: Reduces PNG file size using `pngquant` while maintaining visual quality
- **JPEG Optimization**: Compresses JPEG files using `jpegoptim` while removing metadata
- **Smart Comparison**: Automatically skips optimization if the result would be larger than the cleaned version
- **Batch Processing**: Supports processing individual files or entire directories recursively

## 2. Dependencies

Before running the script, you must ensure that the required tools are installed. You can install them using `dnf`:

```bash
sudo dnf install exiftool ghostscript pngquant jpegoptim coreutils
```

**Package breakdown**:
- `exiftool` — Metadata removal tool
- `ghostscript` — PDF processing and optimization
- `pngquant` — PNG compression
- `jpegoptim` — JPEG compression and optimization
- `coreutils` — Contains `numfmt` for human-readable file sizes (pre-installed on Fedora)

The script will check for these dependencies and will exit if they are not found.

## 3. Installation & Setup

### First Time Setup

Follow these steps to set up the script on your system:

1. **Make the script executable**:
   ```bash
   chmod +x /path/to/clean-metadata.sh
   ```

2. **(Optional) Create an alias for easy access**:
   
   Add this to your `~/.bashrc`:
   ```bash
   alias cleanmeta='bash "$HOME/user-scripts/scripts/clean-metadata.sh"'
   ```
   
   Then reload your shell:
   ```bash
   source ~/.bashrc
   ```

3. **Test the installation**:
   ```bash
   cleanmeta --help
   ```
   
   You should see the usage message. If not, verify all dependencies are installed.

## 4. How to Run the Script

The script does not require root privileges and can be run as a regular user.

### Basic Usage (Single File)

To clean metadata and optimize a single file:

```bash
cleanmeta /path/to/file.pdf
```

Or if you created the alias:
```bash
cleanmeta ~/Documents/sensitive-file.png
```

### Processing Directories

To process all supported files in a directory (recursively):

```bash
cleanmeta ~/Documents/
```

The script will find and process all `.pdf`, `.png`, `.jpg`, and `.jpeg` files in the directory and its subdirectories.

### Processing Multiple Files

You can also specify multiple files or directories at once:

```bash
cleanmeta file1.pdf file2.png ~/Downloads/
```

### Handling Spaces in Filenames

For files with spaces, use quotes or escape the spaces:

```bash
cleanmeta "My Document.pdf"
```

Or:

```bash
cleanmeta My\ Document.pdf
```

### Skip Already Processed Files

The script automatically skips files that have already been processed (those containing `_cleaned` or `_cleaned_opt` in their filename), preventing duplicate processing.

## 5. Understanding the Output

The script provides real-time feedback on its operations.

### On-Screen Output

For each file processed, you'll see:

```
────────────────────────────────────────────
📋 Processing: /path/to/file.pdf
[PDF]           Author                          : John Doe
[PDF]           Create Date                     : 2025:06:15 10:30:00Z
[XMP-dc]        Title                           : Sensitive Document
🧹 Cleaning all metadata...
📰 Optimizing PDF...
✓ Metadata removed:
   (clean)
📊 Size: Before:    2.5MB → After:    2.1MB | Δ -   512KB
────────────────────────────────────────────
```

### Output Components

- **📋 Processing**: Shows the file being processed
- **Metadata listing**: Displays significant metadata that will be removed (Author, Title, Creator, dates, etc.)
- **🧹 Cleaning**: Removes all metadata
- **📰/🌆/📸 Optimizing**: Indicates which optimization is being applied (PDF/PNG/JPEG)
- **✓ Metadata removed**: Confirms that all metadata has been successfully stripped
- **📊 Size**: Shows the original size, final size, and change in bytes

## 6. Output Files

For each processed file, the script creates a new file with the suffix `_cleaned_opt`:

**Original**: `document.pdf`  
**Processed**: `document_cleaned_opt.pdf`

The original file is never modified. You can safely delete the original once you've verified the cleaned version is acceptable.

## 7. File Optimization Details

The script applies format-specific optimizations:

### PDF Optimization

- **Setting**: ebook quality (`/ebook`)
- **Result**: Typically 10-40% size reduction
- **Side effect**: Slight visual quality reduction (acceptable for most documents)
- **Privacy benefit**: Removes embedded streams and object structures

### PNG Optimization

- **Quality**: 65-80% (visually lossless)
- **Speed**: Prioritizes quality over compression speed
- **Result**: Typically 30-70% size reduction depending on image complexity

### JPEG Optimization

- **Quality**: Maximum 80% (balanced quality/size)
- **Metadata**: All metadata and comments removed
- **Result**: Typically 10-30% size reduction

### Smart Comparison

If the optimized file ends up larger than the cleaned (non-optimized) version, the script automatically skips optimization and uses the smaller cleaned file instead.

## 8. Supported File Types

| Format | Metadata Removed | Optimization | Output Size Impact |
|--------|-----------------|--------------|-------------------|
| PDF | ✅ Yes | ✅ Yes (ebook quality) | Often reduced |
| PNG | ✅ Yes | ✅ Yes (pngquant) | Usually 30-70% smaller |
| JPEG | ✅ Yes | ✅ Yes (jpegoptim) | Typically 10-30% smaller |
| JPG | ✅ Yes | ✅ Yes (jpegoptim) | Typically 10-30% smaller |

## 9. Privacy Considerations

The `clean-metadata.sh` script is designed with privacy as the primary goal:

- **All data stays local**: Cleaned files are stored only on your local system
- **No external transmission**: The script never sends any data to external servers
- **No telemetry**: The script collects no usage statistics or personal information
- **Transparent operations**: You can see exactly what metadata is being removed before processing
- **User control**: You manually invoke the script; no automatic background processing

### What Gets Removed

**From all files**:
- EXIF data (camera model, GPS location, timestamps)
- IPTC data (keywords, author, copyright)
- XMP data (creation tool, modification dates)
- File comments and descriptions

**From PDFs additionally**:
- Author, Creator, Title, Subject
- Embedded producer information
- Modification dates and timestamps
- Document ID and version information

## 10. Common Use Cases

### Before Sharing a Document

Clean metadata before sending to colleagues or uploading to the web:

```bash
cleanmeta ~/Documents/quarterly-report.pdf
# Then share: ~/Documents/quarterly-report_cleaned_opt.pdf
```

### Batch Processing Screenshots

Remove metadata from a folder of screenshots:

```bash
cleanmeta ~/Pictures/Screenshots/
```

### Preparing Images for Web

Optimize and clean images before uploading to a website:

```bash
cleanmeta ~/website-images/
```

### Archiving Sensitive Documents

Clean sensitive files before archiving:

```bash
cleanmeta ~/sensitive-files/
# Then archive the _cleaned_opt versions
```

## 11. Performance Notes

- **Small files** (< 1 MB): Process in seconds
- **Medium files** (1-10 MB): Process in 10-60 seconds
- **Large files** (> 10 MB): May take 60+ seconds depending on format
- **Batch processing**: Significantly faster than processing files individually (I/O optimization)

## 12. Troubleshooting

### Error: Dependency Not Found

If you receive an error about a missing dependency:

```bash
sudo dnf install exiftool ghostscript pngquant jpegoptim coreutils
```

Then retry the command.

### File Not Found Warning

If you see `⚠️ Not found: filename`, verify the file path exists:

```bash
ls /path/to/file
```

### Already Processed File Warning

If the script says a file is being ignored as already processed, it contains `_cleaned` or `_cleaned_opt` in its filename. To process it again, rename it:

```bash
mv file_cleaned_opt.pdf file.pdf
cleanmeta file.pdf
```

### Optimized File Larger Than Cleaned

This is normal for some files. The script automatically uses the smaller cleaned version without optimization. This can happen if:
- The original file has little compressible data
- The file is already well-optimized
- The format doesn't compress well for that particular image/document

### Character Encoding Issues with Filenames

If filenames contain special characters, use quotes:

```bash
cleanmeta "файл с кириллицей.pdf"
```

## 13. Best Practices

- **Review before sharing**: Always open the `_cleaned_opt` file to verify it looks correct before deleting the original
- **Test with non-critical files first**: If this is your first time using the script, practice with unimportant files
- **Keep originals temporarily**: Don't delete the original files immediately; verify the cleaned versions are acceptable
- **Batch processing**: Process folders instead of individual files for better performance
- **Archive cleaned versions**: For sensitive documents, keep only the cleaned versions in your archive
- **Schedule regular cleanup**: Periodically run the script on documents before archiving

## 14. Examples

### Clean a Single PDF and Verify

```bash
cleanmeta ~/Documents/contract.pdf
# Review the output
file ~/Documents/contract_cleaned_opt.pdf
# If satisfied, delete original:
rm ~/Documents/contract.pdf
```

### Process All Screenshots

```bash
cleanmeta ~/Pictures/Screenshots/
ls ~/Pictures/Screenshots/*_cleaned_opt.png
```

### Clean Multiple Directories

```bash
cleanmeta ~/Documents/ ~/Downloads/ ~/Pictures/
```

### Create a Private Archive

```bash
mkdir ~/private-archive
cleanmeta ~/sensitive-docs/ --output ~/private-archive/
# Archive the cleaned files
tar -czf archive.tar.gz ~/private-archive/*_cleaned_opt*
```

## 15. Support & Contribution

This is a community tool designed for privacy-conscious Fedora users. The script is open-source and respects your privacy completely.

For issues, improvements, or questions, refer to the script documentation or your system administrator.