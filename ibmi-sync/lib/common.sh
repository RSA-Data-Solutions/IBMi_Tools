#!/bin/bash

# IBM i Unified Sync Tool - Common Utilities
# Shared functions for logging, error handling, and UI

# ============================================================================
# Color Definitions
# ============================================================================

# Initialize colors - will be set to empty strings if --no-color is used
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Bold variants
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_CYAN='\033[1;36m'

# Function to disable colors
disable_colors() {
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    NC=''
    BOLD_RED=''
    BOLD_GREEN=''
    BOLD_YELLOW=''
    BOLD_BLUE=''
    BOLD_CYAN=''
}

# ============================================================================
# Output Functions
# ============================================================================

# Print success message
print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

# Print error message
print_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

# Print info message
print_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

# Print debug message (only if IBMI_DEBUG=1)
print_debug() {
    if [ "${IBMI_DEBUG:-0}" = "1" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $*" >&2
    fi
}

# Print title/header
print_title() {
    echo -e "\n${BOLD_CYAN}$*${NC}\n"
}

# Print separator
print_separator() {
    echo "───────────────────────────────────────────────────────────────"
}

# Print colored output without newline
print_colored() {
    local color=$1
    shift
    echo -ne "${!color}$*${NC}"
}

# ============================================================================
# Logging Functions
# ============================================================================

# Setup logging to file
setup_logging() {
    local log_dir="$HOME/.ibmi/logs"
    mkdir -p "$log_dir"
    IBMI_LOG_FILE="$log_dir/ibmi-sync-$(date +%Y%m%d).log"
}

# Log message to file
log_message() {
    if [ -z "$IBMI_LOG_FILE" ]; then
        setup_logging
    fi
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$IBMI_LOG_FILE"
}

# Get log file location
get_log_file() {
    if [ -z "$IBMI_LOG_FILE" ]; then
        setup_logging
    fi
    echo "$IBMI_LOG_FILE"
}

# ============================================================================
# Error Handling
# ============================================================================

# Exit with error message
die() {
    print_error "$@"
    exit 1
}

# Exit with success message
exit_success() {
    print_success "$@"
    exit 0
}

# Check if command succeeded, otherwise exit
check_status() {
    local status=$?
    local message="${1:-Command failed}"

    if [ $status -ne 0 ]; then
        print_error "$message (exit code: $status)"
        return $status
    fi
    return 0
}

# Assert value is not empty
assert_not_empty() {
    local value=$1
    local name=$2

    if [ -z "$value" ]; then
        die "$name cannot be empty"
    fi
}

# ============================================================================
# Progress Indicators
# ============================================================================

# Start progress spinner
start_spinner() {
    local message=$1
    echo -ne "${BLUE}${message}${NC} "

    # Store spinner PID for later
    local spinvar='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    (
        while true; do
            echo -ne "\b${spinvar:i++%${#spinvar}:1}"
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
}

# Stop progress spinner
stop_spinner() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
        echo -e "\b${GREEN}✓${NC}"
        unset SPINNER_PID
    fi
}

# Stop spinner with error
stop_spinner_error() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
        echo -e "\b${RED}✗${NC}"
        unset SPINNER_PID
    fi
}

# ============================================================================
# Input/Confirmation Functions
# ============================================================================

# Prompt user for confirmation (y/n)
confirm() {
    local prompt="${1:-Continue?}"
    local response

    echo -ne "${YELLOW}${prompt} (y/n): ${NC}"
    read -r response

    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Read password without echo
read_password() {
    local prompt="${1:-Enter password: }"
    local password

    echo -ne "$prompt"
    read -rs password
    echo ""
    echo "$password"
}

# Prompt user for input
read_input() {
    local prompt=$1
    local default=$2
    local response

    if [ -z "$default" ]; then
        echo -ne "${BLUE}${prompt}${NC} " >&2
    else
        echo -ne "${BLUE}${prompt} [${BOLD_BLUE}${default}${NC}${BLUE}]${NC} " >&2
    fi

    read -r response
    echo "${response:-$default}"
}

# ============================================================================
# File/Path Functions
# ============================================================================

# Get absolute path
get_absolute_path() {
    local path=$1

    if [[ $path == /* ]]; then
        echo "$path"
    else
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    fi
}

# Expand tilde in path
expand_path() {
    local path=$1

    if [[ $path == ~* ]]; then
        eval echo "$path"
    else
        echo "$path"
    fi
}

# Check if path exists and is readable
path_readable() {
    local path=$1
    if [ -r "$path" ]; then
        return 0
    fi
    return 1
}

# Check if path is writable
path_writable() {
    local path=$1
    if [ -w "$path" ]; then
        return 0
    fi
    return 1
}

# Create directory with parents
ensure_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || die "Failed to create directory: $dir"
    fi
}

# ============================================================================
# Platform Detection
# ============================================================================

# Detect platform
detect_platform() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    elif [ "$(uname)" = "Linux" ]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Check if running on WSL
is_wsl() {
    [ "$(detect_platform)" = "wsl" ]
}

# Check if running on macOS
is_macos() {
    [ "$(detect_platform)" = "macos" ]
}

# Check if running on Linux
is_linux() {
    [ "$(detect_platform)" = "linux" ]
}

# ============================================================================
# Command/Tool Checking
# ============================================================================

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Require command to exist
require_command() {
    local cmd=$1
    local package=${2:-$cmd}

    if ! command_exists "$cmd"; then
        die "$cmd not found. Please install: $package"
    fi
}

# Check all required commands
require_commands() {
    local missing=()

    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        die "Missing required commands: ${missing[*]}"
    fi
}

# ============================================================================
# String Functions
# ============================================================================

# Trim whitespace
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"   # Remove leading whitespace
    var="${var%"${var##*[![:space:]]}"}"   # Remove trailing whitespace
    echo "$var"
}

# Convert to uppercase
to_upper() {
    echo "$*" | tr '[:lower:]' '[:upper:]'
}

# Convert to lowercase
to_lower() {
    echo "$*" | tr '[:upper:]' '[:lower:]'
}

# Capitalize first letter
capitalize() {
    local str=$1
    echo "$(to_upper ${str:0:1})${str:1}"
}

# Check if string contains substring
string_contains() {
    local string=$1
    local substring=$2

    if [[ "$string" == *"$substring"* ]]; then
        return 0
    fi
    return 1
}

# ============================================================================
# Array Functions
# ============================================================================

# Join array elements with delimiter
join_array() {
    local delimiter=$1
    shift
    local -a array=("$@")
    local IFS=$delimiter
    echo "${array[*]}"
}

# Check if array contains element
array_contains() {
    local element=$1
    shift
    local -a array=("$@")

    for item in "${array[@]}"; do
        if [ "$item" = "$element" ]; then
            return 0
        fi
    done
    return 1
}

# ============================================================================
# Utility Functions
# ============================================================================

# Display usage/help
show_usage() {
    local cmd=$1
    local usage=$2

    echo "Usage: $cmd $usage"
}

# Get script directory
get_script_dir() {
    local dir
    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$dir"
}

# Get parent directory of script
get_parent_dir() {
    local parent
    parent="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    echo "$parent"
}

# Make sure we have a clean exit
trap 'cleanup' EXIT

cleanup() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
    fi
}

# ============================================================================
# Export functions
# ============================================================================

export -f disable_colors
export -f print_success
export -f print_error
export -f print_warning
export -f print_info
export -f print_debug
export -f print_title
export -f print_separator
export -f die
export -f check_status
export -f command_exists
export -f require_command
