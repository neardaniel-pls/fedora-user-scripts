# Colors Library Guide

## Overview

The `lib/colors.sh` library provides standardized color definitions and output formatting functions for all user-scripts. It ensures consistent visual appearance across all scripts while providing flexibility for different environments.

## Features

- **Automatic color detection**: Detects if colors should be enabled based on terminal capabilities
- **Icon support**: Optional Unicode icons for better visual feedback
- **Non-interactive mode**: Automatically disables colors when output is redirected
- **Consistent formatting**: Standardized message structure across all scripts

## Usage

To use the colors library in your script, add this line near the beginning of your script:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/colors.sh"
```

## Available Functions

### Output Functions

#### `info(message)`
Displays an informational message in blue with an info icon.

```bash
info "Operation in progress..."
```

#### `success(message)`
Displays a success message in green with a checkmark icon.

```bash
success "Operation completed successfully."
```

#### `warning(message)`
Displays a warning message in yellow with a warning icon.

```bash
warning "This operation may take some time."
```

#### `error(message)`
Displays an error message in red with an error icon. Outputs to stderr.

```bash
error "Failed to process file."
```

### Formatting Functions

#### `print_header(text)`
Displays a formatted header with the provided text.

```bash
print_header "Initializing System"
```

#### `print_separator()`
Displays a separator line for visual separation.

```bash
print_separator
```

#### `print_subheader(text)`
Displays a formatted subheader with the provided text.

```bash
print_subheader "Processing files..."
```

## Environment Variables

### `NO_COLOR`
Set to any value to disable colors completely.

```bash
NO_COLOR=1 ./script.sh
```

### `USE_ICONS`
Set to `0` to disable icons (default: `1`).

```bash
USE_ICONS=0 ./script.sh
```

## Color Constants

The library defines these color constants (available when colors are enabled):

- `BOLD`: Bold text formatting
- `BLUE`: Blue color
- `GREEN`: Green color
- `YELLOW`: Yellow color
- `RED`: Red color
- `RESET`: Reset all formatting

## Icon Constants

The library defines these icon constants (available when icons are enabled):

- `INFO_ICON`: ℹ️
- `SUCCESS_ICON`: ✅
- `WARNING_ICON`: ⚠️
- `ERROR_ICON`: ❌

## Examples

### Basic Usage

```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

info "Starting script..."
success "All systems ready."
warning "Proceed with caution."
error "Critical error occurred."
```

### With Headers

```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

print_header "System Maintenance"
info "Checking dependencies..."
print_separator
print_subheader "Processing files"
success "All files processed."
print_separator
```

### Custom Formatting

```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

echo -e "${BOLD}${GREEN}Custom message${RESET}"
echo -e "${BLUE}${INFO_ICON} Custom info${RESET}"
```

## Best Practices

1. **Always source the library** at the beginning of your script
2. **Use the provided functions** instead of manual color formatting
3. **Test with color disabled** using `NO_COLOR=1` to ensure readability
4. **Use icons consistently** - don't mix icon and non-icon messages
5. **Respect user preferences** by checking the environment variables

## Migration Guide

When updating existing scripts to use the colors library:

1. Replace color variable definitions with the library source
2. Replace `echo -e "${color}message${reset}"` with appropriate functions
3. Replace manual icon usage with the provided functions
4. Test the script with and without colors enabled

### Before

```bash
bold="\033[1m"
blue="\033[34m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
reset="\033[0m"

echo -e "${bold}${blue}ℹ️  Information${reset}"
echo -e "${bold}${green}✅ Success${reset}"
echo -e "${bold}${yellow}⚠️  Warning${reset}"
echo -e "${bold}${red}❌ Error${reset}" >&2
```

### After

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/colors.sh"

info "Information"
success "Success"
warning "Warning"
error "Error"
```

## Troubleshooting

### Colors not showing
- Check if output is being redirected (colors are automatically disabled)
- Verify the terminal supports colors
- Check if `NO_COLOR` environment variable is set

### Icons not showing
- Verify `USE_ICONS` is not set to `0`
- Check if the terminal supports Unicode characters
- Ensure the font includes the icon characters

### Script fails after adding library
- Verify the path to the library is correct
- Check if the library file is readable
- Ensure the script has execute permissions