#!/bin/bash

# IBM i Unified Sync Tool - Configuration Management
# Handles profile configuration, loading, and validation

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ============================================================================
# Configuration Paths
# ============================================================================

CONFIG_DIR="$HOME/.ibmi"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SESSION_DIR="$CONFIG_DIR/sessions"
LOCK_FILE="$CONFIG_DIR/ibmi-sync.lock"

# ============================================================================
# Initialization
# ============================================================================

# Initialize configuration system
config_init() {
    ensure_dir "$CONFIG_DIR"
    ensure_dir "$SESSION_DIR"

    # Create default config if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        config_create_default
    fi
}

# ============================================================================
# Config File Management
# ============================================================================

# Create default configuration
config_create_default() {
    print_info "Creating default configuration at $CONFIG_FILE"

    cat > "$CONFIG_FILE" << 'EOF'
# IBM i Unified Sync Tool Configuration

# Default profile to use
default_profile: "production"

# Profile definitions
profiles:
  production:
    # IBM i system connection
    host: "<pub400.com>"
    user: "<UserID>"

    # Member sync settings (for RPGLE development)
    library: "<Library>"
    srcfile: "<SourceFile>"

    # File sync settings
    remote_base: "/home/<UserID>"
    local_dir: "~/ibmi-sync-data/production"

    # Git settings (optional)
    git_repo: ""
    git_branch: "main"

    # Description
    description: "Production IBM i system"

# SSH session settings
session:
  # Keep SSH connection alive for 4 hours
  control_persist: "4h"

  # Where to store SSH control socket
  control_path: "~/.ibmi/ssh-%r@%h:%p"

  # Connection timeout in seconds
  connect_timeout: 10

  # Keep-alive interval
  server_alive_interval: 60

  # Max keep-alive failures before disconnecting
  server_alive_count_max: 3

# UI settings
ui:
  # Enable colored output
  colors: true

  # Show progress bars
  progress: true

  # Confirm destructive operations (push, delete)
  confirm_destructive: true

  # Enable pager for long output
  use_pager: false

# Logging settings
logging:
  # Enable logging
  enabled: true

  # Log file location
  log_dir: "~/.ibmi/logs"

  # Log level: debug, info, warning, error
  level: "info"

# Sync settings
sync:
  # Automatically backup before overwriting
  auto_backup: true

  # Exclude patterns (like .gitignore)
  exclude_patterns:
    - "*.tmp"
    - "*.log"
    - ".DS_Store"
    - "node_modules/"

  # Follow symlinks
  follow_symlinks: false

  # Preserve permissions
  preserve_permissions: true

  # Preserve timestamps
  preserve_timestamps: true

EOF

    print_success "Default configuration created"
}

# Validate configuration file
config_validate() {
    if [ ! -f "$CONFIG_FILE" ]; then
        die "Configuration file not found: $CONFIG_FILE"
    fi

    # Check if config is readable YAML (basic check)
    if ! grep -q "default_profile:" "$CONFIG_FILE"; then
        die "Invalid configuration file (missing default_profile)"
    fi

    if ! grep -q "profiles:" "$CONFIG_FILE"; then
        die "Invalid configuration file (missing profiles)"
    fi
}

# ============================================================================
# Profile Management
# ============================================================================

# Get current profile (from argument or default)
get_current_profile() {
    local profile=${1:-}

    # If profile specified, use it
    if [ -n "$profile" ]; then
        echo "$profile"
        return 0
    fi

    # Otherwise get default from config
    if [ ! -f "$CONFIG_FILE" ]; then
        die "Configuration file not found. Run 'ibmi-sync config init' first."
    fi

    # Extract default profile from YAML
    local default=$(grep "^default_profile:" "$CONFIG_FILE" | cut -d':' -f2 | tr -d '\r')
    
    # Trim whitespace using parameter expansion
    default="${default#"${default%%[![:space:]]*}"}"
    default="${default%"${default##*[![:space:]]}"}"

    # Remove quotes if present
    default="${default%\"}"
    default="${default#\"}"

    if [ -z "$default" ]; then
        die "No default profile configured"
    fi

    echo "$default"
}

# List all available profiles
config_list_profiles() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Configuration file not found"
        return 1
    fi

    print_title "Available Profiles:"

    # Parse profiles from YAML (CRs removed first: config.yaml may have Windows line endings)
    tr -d '\r' < "$CONFIG_FILE" | awk '/^  [a-zA-Z_]/ && !/^    / {
        sub(/^  /, "");
        gsub(/:$/, "");
        profile = $0;
        getline;
        while (getline && /^    /) {
            if (/host:/) {
                host = $2;
                print "  " profile " (" host ")";
                break;
            }
        }
    }'
}

# Get profile value by key
config_get() {
    local profile=$1
    local key=$2

    if [ ! -f "$CONFIG_FILE" ]; then
        die "Configuration file not found"
    fi

    # Use awk to extract value from YAML profile section
    awk -v profile="$profile" -v key="$key" '
        { sub(/\r$/, "") }   # config.yaml saved with Windows line endings
        /^  '"$profile"':$/ {
            in_profile = 1
            next
        }
        /^  [a-zA-Z_]+:$/ && in_profile {
            in_profile = 0
        }
        in_profile && $1 ~ /^'"$key"':$/ {
            gsub(/\r/, "");
            sub(/^[^:]*: */, "");
            gsub(/"/, "");
            print
        }
    ' "$CONFIG_FILE"
}

# Get all profile values as variables
config_load_profile() {
    local profile=$1

    print_debug "Loading profile: $profile"

    # Validate profile exists (use -F to treat as literal string, not regex)
    if ! grep -qF "  $profile:" "$CONFIG_FILE"; then
        die "Profile not found: $profile"
    fi

    # Extract all values for the profile
    export IBMI_PROFILE="$profile"
    export IBMI_HOST=$(config_get "$profile" "host")
    export IBMI_USER=$(config_get "$profile" "user")
    export IBMI_LIBRARY=$(config_get "$profile" "library")
    export IBMI_SRCFILE=$(config_get "$profile" "srcfile")
    export IBMI_REMOTE_BASE=$(config_get "$profile" "remote_base")
    export IBMI_LOCAL_DIR=$(expand_path "$(config_get "$profile" "local_dir")")
    export IBMI_GIT_REPO=$(config_get "$profile" "git_repo")
    export IBMI_GIT_BRANCH=$(config_get "$profile" "git_branch")

    # Validate required values: empty, blank or "<placeholder>" means the profile was never filled in
    local field value
    for field in host user; do
        value=$(config_get "$profile" "$field")
        if [ -z "$(trim "$value")" ] || [[ "$value" == *"<"*">"* ]]; then
            die "Profile '$profile' has no real $field (found: '${value}'). Set it with: ibmi-sync config edit"
        fi
    done

    print_debug "Profile loaded: $IBMI_PROFILE on $IBMI_HOST as $IBMI_USER"
}

# Get session configuration
config_get_session() {
    local key=$1
    local value

    value=$(awk -v key="$key" '
        { sub(/\r$/, "") }   # config.yaml saved with Windows line endings
        /^session:/ {
            in_session = 1
            next
        }
        /^[a-z]+:/ && in_session && !/^  / {
            in_session = 0
        }
        in_session && $1 ~ /^'"$key"':$/ {
            gsub(/\r/, "");
            sub(/^[^:]*: */, "");
            gsub(/"/, "");
            print
        }
    ' "$CONFIG_FILE" | head -n 1)

    # Configs created by `config init` have no session: block; ssh rejects empty -o values.
    if [ -z "$(trim "$value")" ]; then
        case "$key" in
            control_persist) value="4h" ;;
            control_path) value="~/.ibmi/ssh-%r@%h:%p" ;;
            connect_timeout) value="10" ;;
            server_alive_interval) value="60" ;;
            server_alive_count_max) value="3" ;;
            multiplex) value="auto" ;;
        esac
    fi
    echo "$value"
}

# ============================================================================
# Session Management
# ============================================================================

# Get session file path for profile
get_session_file() {
    local profile=$1
    echo "$SESSION_DIR/${profile}.session"
}

# Save session data
save_session() {
    local profile=$1
    local host=$2
    local user=$3
    local socket=$4
    local library=${5:-}
    local srcfile=${6:-}

    local session_file=$(get_session_file "$profile")

    cat > "$session_file" << EOF
{
  "profile": "$profile",
  "host": "$host",
  "user": "$user",
  "socket": "$socket",
  "library": "$library",
  "srcfile": "$srcfile",
  "timestamp": $(date +%s),
  "pid": $$
}
EOF

    chmod 600 "$session_file"
    print_debug "Session saved: $session_file"
}

# Load session data
load_session() {
    local profile=$1
    local session_file=$(get_session_file "$profile")

    if [ ! -f "$session_file" ]; then
        return 1
    fi

    # Source the session file (it's JSON but we'll extract with grep)
    local host=$(grep '"host"' "$session_file" | cut -d'"' -f4)
    local user=$(grep '"user"' "$session_file" | cut -d'"' -f4)
    local socket=$(grep '"socket"' "$session_file" | cut -d'"' -f4)
    local library=$(grep '"library"' "$session_file" | cut -d'"' -f4)
    local srcfile=$(grep '"srcfile"' "$session_file" | cut -d'"' -f4)

    export IBMI_SESSION_HOST="$host"
    export IBMI_SESSION_USER="$user"
    export IBMI_SESSION_SOCKET="$socket"
    export IBMI_SESSION_LIBRARY="$library"
    export IBMI_SESSION_SRCFILE="$srcfile"

    return 0
}

# Clear session data
clear_session() {
    local profile=$1
    local session_file=$(get_session_file "$profile")

    if [ -f "$session_file" ]; then
        rm -f "$session_file"
        print_debug "Session cleared: $profile"
    fi
}

# ============================================================================
# Config Editing
# ============================================================================

# Edit configuration file in default editor
config_edit() {
    if [ ! -f "$CONFIG_FILE" ]; then
        die "Configuration file not found"
    fi

    if [ -z "${EDITOR:-}" ] && is_windows && command_exists notepad; then
        # Notepad waits until it is closed; it needs a Windows path
        notepad "$(cygpath -w "$CONFIG_FILE")"
    else
        local editor=${EDITOR:-nano}
        command_exists "${editor%% *}" || editor="vi"
        $editor "$CONFIG_FILE"
    fi
    check_status "Failed to edit configuration"
}

# Create new profile interactively
config_create_profile() {
    local profile
    local host
    local user
    local library
    local srcfile
    local remote_base
    local local_dir
    local description

    echo ""
    print_title "Create New Profile"

    profile=$(read_input "Profile name:")
    [ -z "$profile" ] && die "Profile name cannot be empty"

    # Check if profile already exists (use -F to treat as literal string, not regex)
    if grep -qF "  $profile:" "$CONFIG_FILE"; then
        die "Profile already exists: $profile"
    fi

    host=$(read_input "IBM i Host:" "<pub400.com>")
    user=$(read_input "IBM i User ID:")
    [ -z "$user" ] && die "User ID cannot be empty"

    library=$(read_input "Library name:" "$user")
    srcfile=$(read_input "Source file name:" "<SourceFile>")
    remote_base=$(read_input "Remote base directory:" "/home/$user")
    local_dir=$(read_input "Local directory:" "~/ibmi-sync-data/$profile")
    description=$(read_input "Description:" "$profile IBM i system")

    # Add profile to config
    cat >> "$CONFIG_FILE" << EOF

  $profile:
    host: "$host"
    user: "$user"
    library: "$library"
    srcfile: "$srcfile"
    remote_base: "$remote_base"
    local_dir: "$local_dir"
    git_repo: ""
    git_branch: "main"
    description: "$description"
EOF

    print_success "Profile created: $profile"
}

# Edit existing profile
config_edit_profile() {
    local profile=$1

    if [ -z "$profile" ]; then
        profile=$(read_input "Profile to edit:")
    fi

    if ! grep -qF "  $profile:" "$CONFIG_FILE"; then
        die "Profile not found: $profile"
    fi

    print_warning "Manual editing required. Opening config file..."
    config_edit
}

# Set one value inside a profile (adds the key if it is missing). Portable: no sed -i.
config_set_value() {
    local profile=$1
    local key=$2
    local value=$3
    local tmp="$CONFIG_FILE.tmp.$$"

    grep -qF "  $profile:" "$CONFIG_FILE" || die "Profile not found: $profile"

    awk -v p="  $profile:" -v key="$key" -v val="$value" '
        function emit() { print "    " key ": \"" val "\""; done = 1 }
        { sub(/\r$/, "") }
        $0 == p { inp = 1; print; next }
        inp && ($0 ~ /^  [a-zA-Z_]/ || $0 ~ /^[^ #]/) { if (!done) emit(); inp = 0 }
        inp && $1 == key ":" { emit(); next }
        { print }
        END { if (inp && !done) emit() }
    ' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
}

# Delete profile
config_delete_profile() {
    local profile=$1

    if [ -z "$profile" ]; then
        profile=$(read_input "Profile to delete:")
    fi

    if ! grep -qF "  $profile:" "$CONFIG_FILE"; then
        die "Profile not found: $profile"
    fi

    if ! confirm "Delete profile '$profile'?"; then
        print_warning "Cancelled"
        return 1
    fi

    # Remove profile section from YAML
    local tmp="$CONFIG_FILE.tmp.$$"
    awk -v p="  $profile:" '
        { sub(/\r$/, "") }
        $0 == p { skip = 1; next }
        skip && /^  [a-zA-Z_]/ { skip = 0 }
        skip && /^[^ #]/ { skip = 0 }
        !skip { print }
    ' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"

    print_success "Profile deleted: $profile"
}

# ============================================================================
# Lock Management
# ============================================================================

# Acquire lock
acquire_lock() {
    local timeout=${1:-10}
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if mkdir "$LOCK_FILE" 2>/dev/null; then
            echo $$ > "$LOCK_FILE/pid"
            print_debug "Lock acquired"
            return 0
        fi
        sleep 0.1
        ((elapsed++))
    done

    print_warning "Could not acquire lock (another operation may be in progress)"
    return 1
}

# Release lock
release_lock() {
    if [ -d "$LOCK_FILE" ]; then
        rm -rf "$LOCK_FILE"
        print_debug "Lock released"
    fi
}

# ============================================================================
# Session Context Management
# ============================================================================

# Set session context (library and/or srcfile override)
session_set_context() {
    local profile=$1
    local library=$2
    local srcfile=$3

    # Load current session
    if ! load_session "$profile"; then
        die "No active session for profile: $profile. Start a session first with 'isync session start'"
    fi

    # Use current values if not specified
    library=${library:-$IBMI_SESSION_LIBRARY}
    srcfile=${srcfile:-$IBMI_SESSION_SRCFILE}

    # Re-save session with new context
    save_session "$profile" "$IBMI_SESSION_HOST" "$IBMI_SESSION_USER" "$IBMI_SESSION_SOCKET" "$library" "$srcfile"

    print_success "Session context updated for profile: $profile"
    if [ -n "$library" ]; then
        print_info "  Library:     $library"
    fi
    if [ -n "$srcfile" ]; then
        print_info "  Source File: $srcfile"
    fi
}

# Show current session context
session_show_context() {
    local profile=$1

    config_load_profile "$profile"

    if load_session "$profile"; then
        echo ""
        print_title "Current Session Context: $profile"
        echo "  ${CYAN}Profile Defaults:${NC}"
        echo "    Library:     ${IBMI_LIBRARY}"
        echo "    Source File: ${IBMI_SRCFILE}"

        if [ -n "$IBMI_SESSION_LIBRARY" ] || [ -n "$IBMI_SESSION_SRCFILE" ]; then
            echo ""
            echo "  ${YELLOW}Session Overrides:${NC}"
            if [ -n "$IBMI_SESSION_LIBRARY" ]; then
                echo "    Library:     ${IBMI_SESSION_LIBRARY} ${GREEN}(overriding ${IBMI_LIBRARY})${NC}"
            fi
            if [ -n "$IBMI_SESSION_SRCFILE" ]; then
                echo "    Source File: ${IBMI_SESSION_SRCFILE} ${GREEN}(overriding ${IBMI_SRCFILE})${NC}"
            fi
        fi

        echo ""
        echo "  ${CYAN}Effective Values:${NC}"
        echo "    Library:     ${IBMI_SESSION_LIBRARY:-$IBMI_LIBRARY}"
        echo "    Source File: ${IBMI_SESSION_SRCFILE:-$IBMI_SRCFILE}"
        echo ""
    else
        print_warning "No active session for profile: $profile"
        echo "  Profile defaults: Library=$IBMI_LIBRARY, Source File=$IBMI_SRCFILE"
    fi
}

# Get effective library (session override or profile default)
get_effective_library() {
    local profile=$1

    # Load profile if not already loaded
    if [ -z "$IBMI_LIBRARY" ]; then
        config_load_profile "$profile" 2>/dev/null
    fi

    # Try to load session overrides
    load_session "$profile" 2>/dev/null

    # Return session override or profile default
    echo "${IBMI_SESSION_LIBRARY:-$IBMI_LIBRARY}"
}

# Get effective srcfile (session override or profile default)
get_effective_srcfile() {
    local profile=$1

    # Load profile if not already loaded
    if [ -z "$IBMI_SRCFILE" ]; then
        config_load_profile "$profile" 2>/dev/null
    fi

    # Try to load session overrides
    load_session "$profile" 2>/dev/null

    # Return session override or profile default
    echo "${IBMI_SESSION_SRCFILE:-$IBMI_SRCFILE}"
}

# ============================================================================
# Export functions
# ============================================================================

export -f config_init
export -f config_load_profile
export -f config_get
export -f config_list_profiles
export -f config_get_session
export -f save_session
export -f load_session
export -f clear_session
export -f session_set_context
export -f session_show_context
export -f get_effective_library
export -f get_effective_srcfile
