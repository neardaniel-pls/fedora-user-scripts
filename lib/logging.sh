#!/bin/bash
#
# logging.sh - Standardized logging library for user-scripts
#
# DESCRIPTION:
#   This library provides standardized logging functions with support for multiple
#   log levels, timestamps, and output destinations. It integrates with the
#   colors library for consistent visual output.
#
# USAGE:
#   Source this library after colors.sh:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/logging.sh"
#
# ENVIRONMENT VARIABLES:
#   LOG_LEVEL: Minimum log level to display (DEBUG, INFO, WARN, ERROR)
#   LOG_FILE: Path to log file (optional)
#   LOG_TO_FILE: Set to 1 to log to file instead of stderr
#

# --- Log Levels ---
# Define log levels with numeric values for comparison
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# --- Default Configuration ---
# Default log level if not specified
LOG_LEVEL_CURRENT="${LOG_LEVEL:-$LOG_LEVEL_INFO}"
# Default to stderr unless LOG_TO_FILE is set
LOG_DESTINATION="${LOG_DESTINATION:-stderr}"

# --- Log Level Validation ---
#
# validate_log_level - Check if log level is valid
#
# DESCRIPTION:
#   Validates that the provided log level is one of the supported levels.
#
# PARAMETERS:
#   $1 - Log level to validate
#
# RETURNS:
#   0 - Valid log level
#   1 - Invalid log level
#
validate_log_level() {
    local level="$1"
    
    case "$level" in
        DEBUG|INFO|WARN|ERROR)
            return 0
            ;;
        *)
            echo "Invalid log level: $level" >&2
            echo "Valid levels: DEBUG, INFO, WARN, ERROR" >&2
            return 1
            ;;
    esac
}

# --- Log Level Comparison ---
#
# should_log - Check if message should be logged based on current level
#
# DESCRIPTION:
#   Compares message level with current log level to determine
#   if the message should be displayed.
#
# PARAMETERS:
#   $1 - Message log level
#
# RETURNS:
#   0 - Message should be logged
#   1 - Message should be filtered out
#
should_log() {
    local message_level="$1"
    local current_level_num
    local message_level_num
    
    # Convert current level to numeric
    case "$LOG_LEVEL_CURRENT" in
        DEBUG) current_level_num=$LOG_LEVEL_DEBUG ;;
        INFO)  current_level_num=$LOG_LEVEL_INFO ;;
        WARN)  current_level_num=$LOG_LEVEL_WARN ;;
        ERROR) current_level_num=$LOG_LEVEL_ERROR ;;
        *) current_level_num=$LOG_LEVEL_INFO ;;
    esac
    
    # Convert message level to numeric
    case "$message_level" in
        DEBUG) message_level_num=$LOG_LEVEL_DEBUG ;;
        INFO)  message_level_num=$LOG_LEVEL_INFO ;;
        WARN) message_level_num=$LOG_LEVEL_WARN ;;
        ERROR) message_level_num=$LOG_LEVEL_ERROR ;;
        *) message_level_num=$LOG_LEVEL_INFO ;;
    esac
    
    # Check if message level should be displayed
    [ "$message_level_num" -ge "$current_level_num" ]
}

# --- Logging Functions ---
#
# log_debug - Log debug message
#
# DESCRIPTION:
#   Logs a debug message if debug logging is enabled.
#
# PARAMETERS:
#   $1 - Message to log
#
log_debug() {
    if should_log "DEBUG"; then
        _log_message "DEBUG" "$1"
    fi
}

#
# log_info - Log informational message
#
# DESCRIPTION:
#   Logs an informational message if info logging is enabled.
#
# PARAMETERS:
#   $1 - Message to log
#
log_info() {
    if should_log "INFO"; then
        _log_message "INFO" "$1"
    fi
}

#
# log_warn - Log warning message
#
# DESCRIPTION:
#   Logs a warning message if warning logging is enabled.
#
# PARAMETERS:
#   $1 - Message to log
#
log_warn() {
    if should_log "WARN"; then
        _log_message "WARN" "$1"
    fi
}

#
# log_error - Log error message
#
# DESCRIPTION:
#   Logs an error message. Always logged regardless of log level.
#
# PARAMETERS:
#   $1 - Message to log
#
log_error() {
    _log_message "ERROR" "$1"
}

# --- Internal Logging Function ---
#
# _log_message - Internal function to format and output log messages
#
# DESCRIPTION:
#   Formats a log message with timestamp and level.
#   Outputs to stderr or file based on configuration.
#   Uses colors library if available for visual distinction.
#
# PARAMETERS:
#   $1 - Log level (DEBUG, INFO, WARN, ERROR)
#   $2 - Message to log
#
_log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    local formatted_message
    
    # Create timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Format message with level and timestamp
    formatted_message="[$timestamp] [$level] $message"
    
    # Output based on destination
    if [[ "$LOG_DESTINATION" == "file" && -n "${LOG_FILE:-}" ]]; then
        # Output to file
        echo "$formatted_message" >> "$LOG_FILE"
    else
        # Output to stderr with colors if available
        if command -v info >/dev/null 2>&1; then
            # Use colors library if available
            case "$level" in
                DEBUG) info "$formatted_message" ;;
                INFO)  info "$formatted_message" ;;
                WARN)  warning "$formatted_message" ;;
                ERROR) error "$formatted_message" ;;
                *) info "$formatted_message" ;;
            esac
        else
            # Fallback to plain output
            echo "$formatted_message" >&2
        fi
    fi
}

# --- Configuration Functions ---
#
# set_log_level - Set the current log level
#
# DESCRIPTION:
#   Sets the minimum log level for message display.
#   Validates the level before setting it.
#
# PARAMETERS:
#   $1 - New log level (DEBUG, INFO, WARN, ERROR)
#
set_log_level() {
    local new_level="$1"
    
    if validate_log_level "$new_level"; then
        LOG_LEVEL_CURRENT="$new_level"
        log_info "Log level set to $new_level"
    else
        log_error "Invalid log level: $new_level"
        return 1
    fi
}

#
# set_log_file - Configure logging to file
#
# DESCRIPTION:
#   Sets up logging to a specified file.
#   Creates the file if it doesn't exist.
#
# PARAMETERS:
#   $1 - Path to log file
#
set_log_file() {
    local file_path="$1"
    
    if [[ -n "$file_path" ]]; then
        LOG_DESTINATION="file"
        LOG_FILE="$file_path"
        
        # Create file if it doesn't exist
        if [[ ! -f "$file_path" ]]; then
            touch "$file_path" || {
                echo "Failed to create log file: $file_path" >&2
                return 1
            }
        fi
        
        log_info "Logging to file: $file_path"
    else
        log_error "Log file path not specified"
        return 1
    fi
}

#
# set_log_to_stderr - Configure logging to stderr
#
# DESCRIPTION:
#   Sets logging destination back to stderr.
#
set_log_to_stderr() {
    LOG_DESTINATION="stderr"
    unset LOG_FILE
    log_info "Logging to stderr"
}

# --- Log Rotation ---
#
# rotate_log_file - Rotate log file if it exceeds size limit
#
# DESCRIPTION:
#   Rotates a log file by renaming it with timestamp
#   and creating a new empty log file.
#
# PARAMETERS:
#   $1 - Path to log file
#   $2 - Maximum size in bytes (default: 1MB)
#
rotate_log_file() {
    local file_path="$1"
    local max_size="${2:-1048576}"  # Default 1MB
    
    if [[ ! -f "$file_path" ]]; then
        return 0
    fi
    
    # Check file size
    local file_size
    file_size=$(stat -c%s "$file_path" 2>/dev/null || echo 0)
    
    # Rotate if file is too large
    if [ "$file_size" -gt "$max_size" ]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        local backup_path="${file_path}.${timestamp}"
        
        mv "$file_path" "$backup_path" || {
            log_error "Failed to rotate log file: $file_path"
            return 1
        }
        
        # Create new empty log file
        touch "$file_path" || {
            log_error "Failed to create new log file: $file_path"
            return 1
        }
        
        log_info "Log file rotated: $backup_path"
    fi
    
    return 0
}

# --- Initialization ---
#
# init_logging - Initialize logging system
#
# DESCRIPTION:
#   Sets up the logging system based on environment variables.
#   Should be called after sourcing both colors and logging libraries.
#
init_logging() {
    # Validate log level if specified
    if [[ -n "${LOG_LEVEL:-}" ]]; then
        if ! validate_log_level "$LOG_LEVEL"; then
            echo "Invalid LOG_LEVEL: $LOG_LEVEL" >&2
            exit 1
        fi
    fi
    
    # Set up file logging if configured
    if [[ "${LOG_TO_FILE:-}" == "1" && -n "${LOG_FILE:-}" ]]; then
        set_log_file "$LOG_FILE"
    fi
    
    log_debug "Logging initialized with level: $LOG_LEVEL_CURRENT"
}