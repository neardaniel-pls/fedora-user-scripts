# Common Library Guide

## Overview

The `lib/common.sh` library provides shared utility functions for all user-scripts. It standardizes common operations like dependency checking, argument parsing, temporary file handling, and error handling.

## Usage

To use the common library in your script, add this line near the beginning of your script:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
```

Then initialize the script environment:

```bash
init_script "1.0.0"  # Optional version parameter
```

## Available Functions

### Script Initialization

#### `init_script([version])`
Initializes common script environment including strict mode, error handling, and cleanup traps.

```bash
init_script "1.0.0"  # Sets SCRIPT_VERSION to "1.0.0"
init_script           # Sets SCRIPT_VERSION to "unknown"
```

### Dependency Checking

#### `check_dependencies(command1, command2, ...)`
Verifies that all required commands are available on the system.

```bash
check_dependencies "git" "curl" "jq"
```

### Argument Parsing

#### `parse_common_args(args...)`
Parses common command-line arguments (--help, --version, --verbose).
Sets global variables: VERBOSE_MODE, SHOW_HELP, SHOW_VERSION.

```bash
parse_common_args "$@"
if [ "$SHOW_HELP" -eq 1 ]; then
    show_usage
    exit 0
fi
```

### Temporary File Management

#### `create_temp_dir([prefix])`
Creates a secure temporary directory with restricted permissions.
Automatically sets up cleanup trap to remove directory on exit.

```bash
create_temp_dir "myscript"  # Creates /tmp/myscript.XXXXXX
create_temp_dir           # Creates /tmp/script.XXXXXX
```

#### `create_temp_file([prefix], [suffix])`
Creates a secure temporary file with restricted permissions.
Automatically sets up cleanup trap to remove file on exit.

```bash
create_temp_file "data" "log"  # Creates /tmp/data.XXXXXX.log
create_temp_file "temp"           # Creates /tmp/temp.XXXXXX.tmp
```

### Error Handling

#### `die(message)`
Displays an error message and exits with status 1.

```bash
die "Critical error occurred"
```

#### `confirm_action(prompt, [timeout])`
Gets user confirmation for actions with optional timeout.

```bash
if confirm_action "Continue with operation?" 10; then
    echo "User confirmed"
fi
```

### Version Management

#### `show_version()`
Displays standardized version information for scripts.

```bash
show_version  # Uses SCRIPT_VERSION variable
```

### System Utilities

#### `require_root()`
Checks if the script is running with root privileges.

```bash
require_root  # Exits if not running as root
```

#### `get_os_info()`
Detects the operating system and version.
Sets global variables: OS_NAME, OS_VERSION.

```bash
get_os_info
echo "Running on $OS_NAME $OS_VERSION"
```

### File Utilities

#### `validate_file(path, [description])`
Validates that a file exists and is readable.

```bash
if validate_file "/path/to/file" "configuration file"; then
    echo "File is valid"
fi
```

#### `validate_dir(path, [description])`
Validates that a directory exists and is accessible.

```bash
if validate_dir "/path/to/dir" "data directory"; then
    echo "Directory is valid"
fi
```

## Global Variables Set

After calling `init_script`, these variables are available:

- `SCRIPT_NAME`: Name of the script
- `SCRIPT_DIR`: Directory where the script is located
- `SCRIPT_VERSION`: Version string (if provided)
- `TEMP_DIR`: Path to temporary directory (if `create_temp_dir` was called)
- `TEMP_FILE`: Path to temporary file (if `create_temp_file` was called)

## Best Practices

1. **Always initialize** the script environment with `init_script`
2. **Use dependency checking** before performing operations
3. **Leverage temporary file functions** for secure file handling
4. **Use consistent error handling** with `die` for fatal errors
5. **Validate inputs** using provided validation functions
6. **Check for root privileges** when needed with `require_root`

## Migration Guide

When updating existing scripts to use common library:

### Before
```bash
#!/bin/bash
set -euo pipefail

# Check dependencies
for cmd in git curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed" >&2
        exit 1
    fi
done

# Parse arguments
VERBOSE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v) VERBOSE=1; shift ;;
        *) shift ;;
    esac
done

# Create temp dir
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
```

### After
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Initialize script
init_script "1.0.0"

# Check dependencies
check_dependencies "git" "curl"

# Parse arguments
parse_common_args "$@"

# Create temp dir
create_temp_dir
```

## Examples

### Basic Script Structure
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

# Initialize script
init_script "1.0.0"

# Parse common arguments
parse_common_args "$@"

# Show help if requested
if [ "$SHOW_HELP" -eq 1 ]; then
    echo "Usage: $SCRIPT_NAME [options]"
    echo "  -h, --help    Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  --version     Show version information"
    exit 0
fi

# Show version if requested
if [ "$SHOW_VERSION" -eq 1 ]; then
    show_version
    exit 0
fi

# Check dependencies
check_dependencies "required-tool1" "required-tool2"

# Main script logic
info "Script started"
success "Script completed"
```

### Advanced Example with Error Handling
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

init_script "2.0.0"
parse_common_args "$@"

# Validate input file
if [ $# -eq 0 ]; then
    error "No input file specified"
    echo "Usage: $SCRIPT_NAME <file>"
    exit 1
fi

input_file="$1"
validate_file "$input_file" "Input file"

# Create temporary directory
create_temp_dir "myscript"

# Process file
info "Processing $input_file..."
if ! process_file "$input_file" > "$TEMP_DIR/output"; then
    die "Failed to process file"
fi

success "File processed successfully"
```

## Troubleshooting

### Script fails after adding library
- Verify the path to the library is correct
- Check if the library file is readable
- Ensure you're calling `init_script` after sourcing the library

### Temporary files not cleaned up
- The library automatically sets up cleanup traps
- Make sure you're using `create_temp_dir` or `create_temp_file`
- Don't manually override the EXIT trap

### Dependencies not found
- Use `check_dependencies` with all required commands
- The function provides clear error messages about missing dependencies
- Exit codes are properly handled

### Version not showing
- Make sure to pass version to `init_script`
- Use `show_version` to display version information
- Check if SCRIPT_VERSION is set correctly