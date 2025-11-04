# Logging Library Guide

## Overview

The `lib/logging.sh` library provides standardized logging functions with support for multiple log levels, timestamps, and output destinations. It integrates with the colors library for consistent visual output.

## Usage

To use the logging library in your script, source both colors and logging libraries:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"
```

Then initialize the logging system:

```bash
init_logging
```

## Log Levels

The library supports four log levels (in order of severity):

1. **DEBUG** - Detailed debugging information
2. **INFO** - General informational messages
3. **WARN** - Warning messages for potentially problematic situations
4. **ERROR** - Error messages for failures

## Environment Variables

### `LOG_LEVEL`
Sets the minimum log level to display. Messages below this level will be filtered out.

```bash
export LOG_LEVEL=DEBUG    # Show all messages
export LOG_LEVEL=INFO     # Show INFO, WARN, and ERROR (default)
export LOG_LEVEL=WARN     # Show only WARN and ERROR
export LOG_LEVEL=ERROR    # Show only ERROR messages
```

### `LOG_FILE`
Path to log file when logging to file is enabled.

```bash
export LOG_FILE=/var/log/myscript.log
```

### `LOG_TO_FILE`
Set to "1" to enable logging to file instead of stderr.

```bash
export LOG_TO_FILE=1
```

## Available Functions

### Configuration Functions

#### `set_log_level(level)`
Sets the current log level for message filtering.

```bash
set_log_level "DEBUG"  # Enable debug logging
```

#### `set_log_file(path)`
Configures logging to a specified file.

```bash
set_log_file "/var/log/myscript.log"
```

#### `set_log_to_stderr()`
Configures logging back to stderr (default behavior).

```bash
set_log_to_stderr
```

#### `init_logging()`
Initializes the logging system based on environment variables.

```bash
init_logging
```

### Logging Functions

#### `log_debug(message)`
Logs a debug message if debug logging is enabled.

```bash
log_debug "Detailed debugging information"
```

#### `log_info(message)`
Logs an informational message if info logging is enabled.

```bash
log_info "Operation completed successfully"
```

#### `log_warn(message)`
Logs a warning message if warning logging is enabled.

```bash
log_warn "Potential issue detected"
```

#### `log_error(message)`
Logs an error message. Always logged regardless of log level.

```bash
log_error "Failed to process file"
```

### Utility Functions

#### `validate_log_level(level)`
Validates that a log level is one of the supported levels.

```bash
if validate_log_level "$level"; then
    echo "Valid log level"
else
    echo "Invalid log level"
fi
```

#### `should_log(level)`
Checks if a message should be logged based on current log level.

```bash
if should_log "DEBUG"; then
    # Log debug message
fi
```

#### `rotate_log_file(path, [max_size])`
Rotates a log file if it exceeds the specified size limit.

```bash
rotate_log_file "/var/log/myscript.log" 1048576  # 1MB limit
```

## Integration with Colors Library

The logging library automatically integrates with the colors library if it's sourced first. Messages are colored based on their level:

- DEBUG messages use `info()` function (blue)
- INFO messages use `info()` function (blue)
- WARN messages use `warning()` function (yellow)
- ERROR messages use `error()` function (red)

## Examples

### Basic Logging Setup
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# Initialize logging
init_logging

# Log messages at different levels
log_debug "Starting script with detailed debugging"
log_info "Script is running normally"
log_warn "Minor issue detected, continuing"
log_error "Critical error occurred"
```

### Conditional Logging
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# Set log level from environment or default to INFO
LOG_LEVEL="${LOG_LEVEL:-INFO}"
init_logging

# Only log if debug mode is enabled
if [[ "${DEBUG_MODE:-}" == "1" ]]; then
    set_log_level "DEBUG"
fi

# Conditional debug logging
log_debug "This will only show if DEBUG_MODE=1"
log_info "This will always show"
```

### File Logging
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

# Configure file logging
LOG_FILE="/var/log/myscript.log"
LOG_TO_FILE=1
init_logging

# These messages will go to file with timestamps
log_info "This goes to log file"
log_error "Errors also go to log file"
```

### Log Rotation
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

LOG_FILE="/var/log/myscript.log"
LOG_TO_FILE=1
init_logging

# Rotate log if it gets too large
rotate_log_file "$LOG_FILE" 10485760  # 10MB limit

# Continue with normal operation
log_info "Log file checked and rotated if needed"
```

## Best Practices

1. **Initialize early** - Call `init_logging()` after setting up environment
2. **Use appropriate levels** - Choose the right log level for each message
3. **Be consistent** - Use the same logging patterns throughout your script
4. **Consider performance** - Debug logging can impact performance in production
5. **Plan for rotation** - Use log rotation for long-running scripts

## Migration Guide

When updating existing scripts to use the logging library:

### Before
```bash
#!/bin/bash

# Manual logging
echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: Starting script"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Something went wrong" >&2
```

### After
```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"

init_logging

log_info "Starting script"
log_error "Something went wrong"
```

## Troubleshooting

### Messages not appearing
- Check if `init_logging()` was called
- Verify the `LOG_LEVEL` environment variable
- Ensure the library is sourced after colors.sh

### File logging not working
- Verify `LOG_TO_FILE` is set to "1"
- Check that `LOG_FILE` is set and writable
- Ensure the directory for the log file exists

### Colors not appearing in logs
- Source colors.sh before logging.sh
- Check if colors are disabled in the environment
- Verify terminal supports color output

### Log rotation not working
- Ensure the log file path is correct
- Check file permissions on the log file
- Verify the log file exists before calling rotation