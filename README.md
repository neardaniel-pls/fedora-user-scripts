# User Scripts

A collection of personal utility scripts.

## Scripts

### clean-metadata.sh

- **Purpose:** Cleans metadata from PDF, PNG, and JPEG files and optimizes them.
- **Usage:** `scripts/clean-metadata.sh [file|directory]`
- **Dependencies:** `exiftool`, `gs`, `pngquant`, `jpegoptim`, `numfmt`

### fedora-update.sh

- **Purpose:** Performs weekly maintenance on Fedora systems, including package updates and cache cleaning.
- **Usage:** `scripts/fedora-update.sh`

### secure-delete.sh

- **Purpose:** Securely deletes files and directories by overwriting them with random data.
- **Usage:** `scripts/secure-delete.sh [file|directory]`
- **Dependencies:** `shred`

### run-searxng.sh

- **Purpose:** Runs the SearXNG instance in a Docker container.
- **Usage:** `scripts/run-searxng.sh`

### update-searxng.sh

- **Purpose:** Updates the SearXNG instance by pulling the latest changes from the git repository.
- **Usage:** `scripts/update-searxng.sh`

---

## How-to

- [SearXNG Guide](how-to/searxng-guide.md)

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.