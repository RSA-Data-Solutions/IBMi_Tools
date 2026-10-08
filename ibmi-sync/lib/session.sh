#!/bin/bash

# IBM i Unified Sync Tool - SSH Session Manager
# Manages SSH ControlMaster connections for persistent sessions

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# ============================================================================
# SSH Configuration
# ============================================================================

# Create SSH config for ControlMaster
setup_ssh_config() {
    local ssh_dir="$HOME/.ssh"
    local ssh_config="$ssh_dir/config"
    local ibmi_host_config="$ssh_dir/ibmi-config"

    ensure_dir "$ssh_dir"

    # Create ibmi-specific SSH config
    cat > "$ibmi_host_config" << 'EOF'
# IBM i Sync Tool - SSH Configuration
# This config is automatically managed and should not be edited

Host ibmi-sync-*
    ControlMaster auto
    ControlPath ~/.ibmi/ssh-%r@%h:%p
    ControlPersist 4h
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    CompressionLevel 6
    BatchMode no
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts

# Individual host configurations
# Will be added dynamically per profile

EOF

    chmod 600 "$ibmi_host_config"
    print_debug "SSH config created"
}

# Add host to SSH config if not exists
add_ssh_host_config() {
    local profile=$1
    local host=$2
    local user=$3
    local ssh_config="$HOME/.ssh/ibmi-config"

    # Check if host already in config
    if grep -q "^Host $host$" "$ssh_config"; then
        print_debug "Host already in SSH config: $host"
        return 0
    fi

    # Add host configuration
    cat >> "$ssh_config" << EOF

Host $host
    User $user
    IdentityFile ~/.ssh/id_rsa
    IdentityFile ~/.ssh/id_ed25519
    PubkeyAuthentication yes
    PasswordAuthentication yes
    PreferredAuthentications publickey,keyboard-interactive,password

EOF

    print_debug "Host added to SSH config: $host"
}

# ============================================================================
# Connection options
# ============================================================================

# Whether to share one SSH connection per profile (OpenSSH ControlMaster).
# session.multiplex (auto|yes|no) or IBMI_SSH_MUX=0/1. "auto" turns it off on Windows:
# Git Bash's OpenSSH only emulates the Unix sockets ControlMaster needs and it is unreliable
# there, so each command opens its own connection instead (use an SSH key to avoid prompts).
ssh_mux_enabled() {
    local mode="${IBMI_SSH_MUX:-$(config_get_session 'multiplex' 2>/dev/null)}"
    case "$(to_lower "$mode")" in
        1|yes|true|on) return 0 ;;
        0|no|false|off) return 1 ;;
    esac
    ! is_windows
}

# Fill the SSH_OPTS array: timeouts/keep-alives, plus the shared connection when there is one.
build_ssh_opts() {
    local socket=${1:-${IBMI_SESSION_SOCKET:-}}
    SSH_OPTS=(
        -o "ConnectTimeout=$(config_get_session 'connect_timeout')"
        -o "ServerAliveInterval=$(config_get_session 'server_alive_interval')"
        -o "ServerAliveCountMax=$(config_get_session 'server_alive_count_max')"
    )
    if [ -n "$socket" ] && ssh_mux_enabled; then
        SSH_OPTS+=(-o "ControlPath=$socket" -o "ControlMaster=no")
    fi
}

# Load or (re)start the session for a profile. Messages go to stderr so that callers can
# stream data through ssh on stdout.
session_ensure() {
    local profile=$1

    # Load profile if not already loaded
    if [ -z "$IBMI_PROFILE" ] || [ "$IBMI_PROFILE" != "$profile" ]; then
        config_load_profile "$profile"
    fi

    {
        if ! load_session "$profile"; then
            print_warning "No active session. Starting one..."
            session_start "$profile" || die "Failed to start session"
            load_session "$profile"
        elif ! session_check "$profile" "$IBMI_SESSION_SOCKET"; then
            print_warning "Session expired. Reconnecting..."
            session_start "$profile" || die "Failed to reconnect"
            load_session "$profile"
        fi
    } >&2
}

# Run a remote command with stdin/stdout passed through (for piping data, e.g. tar).
session_stream() {
    local profile=$1
    local cmd=$2

    session_ensure "$profile"
    build_ssh_opts
    ssh "${SSH_OPTS[@]}" "${IBMI_SESSION_USER}@${IBMI_SESSION_HOST}" "$cmd"
}

# ============================================================================
# Session Management
# ============================================================================

# Start SSH session for profile
session_start() {
    local profile=$1

    print_debug "Starting session for profile: $profile"

    # Load profile configuration
    config_load_profile "$profile"

    # Get SSH settings from config
    local control_path="$(expand_path "$(config_get_session 'control_path')")"
    local connect_timeout=$(config_get_session 'connect_timeout')
    local server_alive_interval=$(config_get_session 'server_alive_interval')
    local server_alive_count_max=$(config_get_session 'server_alive_count_max')

    # Replace %r, %h, %p in control path template
    local socket_path="${control_path//'%r'/$IBMI_USER}"
    socket_path="${socket_path//'%h'/$IBMI_HOST}"
    socket_path="${socket_path//'%p'/22}"

    # Expand ~
    socket_path="$(expand_path "$socket_path")"

    ensure_dir "$(dirname "$socket_path")"

    if ! ssh_mux_enabled; then
        socket_path=""
    fi

    # Check if session already exists
    if [ -n "$socket_path" ] && session_check "$profile" "$socket_path"; then
        print_info "Session already active for profile: $profile"
        save_session "$profile" "$IBMI_HOST" "$IBMI_USER" "$socket_path" "$IBMI_LIBRARY" "$IBMI_SRCFILE"
        return 0
    fi

    print_info "Authenticating to $IBMI_HOST as $IBMI_USER..."

    local status
    if [ -n "$socket_path" ]; then
        # Start SSH ControlMaster connection
        # -f: background, -N: no command, -M: master mode
        ssh \
            -fN \
            -M \
            -S "$socket_path" \
            -o ConnectTimeout=$connect_timeout \
            -o ServerAliveInterval=$server_alive_interval \
            -o ServerAliveCountMax=$server_alive_count_max \
            "${IBMI_USER}@${IBMI_HOST}" 2>&1
        status=$?
        if [ $status -ne 0 ]; then
            # e.g. "path ... too long for Unix domain socket" or no socket support: work without sharing
            print_warning "Could not open a shared SSH connection; continuing without connection sharing"
            socket_path=""
            build_ssh_opts ""
            ssh "${SSH_OPTS[@]}" "${IBMI_USER}@${IBMI_HOST}" true 2>&1
            status=$?
        fi
    else
        # No shared connection (Windows default): just prove that we can log in.
        build_ssh_opts ""
        ssh "${SSH_OPTS[@]}" "${IBMI_USER}@${IBMI_HOST}" true 2>&1
        status=$?
        if [ $status -eq 0 ] && [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.ssh/id_ecdsa" ]; then
            print_warning "Connection sharing is off on this platform, so every command logs in again."
            print_warning "Set up an SSH key to avoid a password prompt each time (see README: SSH key)."
        fi
    fi

    if [ $status -eq 0 ]; then
        print_success "Session started successfully"
        save_session "$profile" "$IBMI_HOST" "$IBMI_USER" "$socket_path" "$IBMI_LIBRARY" "$IBMI_SRCFILE"

        # Display profile configuration
        echo ""
        print_title "Profile Configuration: $profile"
        echo -e "  ${CYAN}Connection:${NC}"
        echo "    Host:        $IBMI_HOST"
        echo "    User:        $IBMI_USER"
        echo ""
        echo -e "  ${CYAN}IBM i Settings:${NC}"
        echo "    Library:     $IBMI_LIBRARY"
        echo "    Source File: $IBMI_SRCFILE"
        echo ""
        echo -e "  ${CYAN}Local Settings:${NC}"
        echo "    Local Dir:   $IBMI_LOCAL_DIR"
        if [ -n "$IBMI_GIT_REPO" ]; then
            echo "    Git Repo:    $IBMI_GIT_REPO"
            echo "    Git Branch:  $IBMI_GIT_BRANCH"
        fi
        echo ""
        print_info "To edit this profile: ${BOLD}isync profile edit $profile${NC}"
        echo ""

        return 0
    else
        print_error "Failed to start session (exit code: $status)"
        return 1
    fi
}

# Check if session is active
session_check() {
    local profile=$1
    local socket_path=$2

    # If socket not provided, construct it from config
    if [ -z "$socket_path" ]; then
        if [ ! -f "$(get_session_file "$profile")" ]; then
            return 1
        fi

        load_session "$profile"
        socket_path="$IBMI_SESSION_SOCKET"
    fi

    # No shared connection (multiplexing off): a saved session is all there is to check
    if [ -z "$socket_path" ] || ! ssh_mux_enabled; then
        [ -f "$(get_session_file "$profile")" ]
        return $?
    fi

    # Try to check connection
    # (the all-sessions view has no profile loaded, so fall back to the saved session's user/host)
    ssh -S "$socket_path" -O check "${IBMI_USER:-$IBMI_SESSION_USER}@${IBMI_HOST:-$IBMI_SESSION_HOST}" >/dev/null 2>&1
    return $?
}

# Stop SSH session
session_stop() {
    local profile=$1

    print_debug "Stopping session for profile: $profile"

    # Load session data
    if ! load_session "$profile"; then
        print_warning "No active session for profile: $profile"
        return 0
    fi

    # Close ControlMaster connection (none when multiplexing is off)
    if [ -n "$IBMI_SESSION_SOCKET" ]; then
        ssh -S "$IBMI_SESSION_SOCKET" -O exit "${IBMI_SESSION_USER}@${IBMI_SESSION_HOST}" 2>/dev/null
    fi

    # Clear session data
    clear_session "$profile"

    print_success "Session stopped: $profile"
    return 0
}

# Stop all active sessions
session_stop_all() {
    print_info "Stopping all active sessions..."

    local count=0
    for session_file in "$SESSION_DIR"/*.session; do
        if [ -f "$session_file" ]; then
            local profile=$(basename "$session_file" .session)
            session_stop "$profile"
            ((count++))
        fi
    done 2>/dev/null

    if [ $count -eq 0 ]; then
        print_info "No active sessions"
    else
        print_success "Stopped $count session(s)"
    fi
}

# Show session status
session_status() {
    local profile=$1

    if [ -z "$profile" ]; then
        # Show all sessions
        print_title "Active Sessions:"

        local count=0
        for session_file in "$SESSION_DIR"/*.session; do
            if [ -f "$session_file" ]; then
                local p=$(basename "$session_file" .session)
                local host=$(grep '"host"' "$session_file" | cut -d'"' -f4)
                local user=$(grep '"user"' "$session_file" | cut -d'"' -f4)
                local timestamp=$(grep '"timestamp"' "$session_file" | cut -d':' -f2 | cut -d',' -f1)

                if session_check "$p"; then
                    local age=$(($(date +%s) - timestamp))
                    local age_str
                    if [ $age -lt 60 ]; then
                        age_str="${age}s"
                    elif [ $age -lt 3600 ]; then
                        age_str="$((age / 60))m"
                    else
                        age_str="$((age / 3600))h"
                    fi

                    echo -e "  ${GREEN}✓${NC} $p ($user@$host, age: $age_str)"
                    ((count++))
                else
                    echo -e "  ${RED}✗${NC} $p (stale)"
                fi
            fi
        done 2>/dev/null

        if [ $count -eq 0 ]; then
            print_info "No active sessions"
        else
            print_success "Total: $count active session(s)"
        fi

        return 0
    fi

    # Show status for specific profile
    config_load_profile "$profile"

    if load_session "$profile" && session_check "$profile"; then
        print_success "Session active: $profile ($IBMI_USER@$IBMI_HOST)"
        return 0
    else
        print_warning "No active session: $profile"
        return 1
    fi
}

# ============================================================================
# Command Execution via Session
# ============================================================================

# Execute command via SSH session
session_exec() {
    local profile=$1
    shift
    local cmd="$*"

    if [ -z "$cmd" ]; then
        die "Command required"
    fi

    session_ensure "$profile"
    build_ssh_opts

    # Execute command (through the shared connection when there is one)
    ssh "${SSH_OPTS[@]}" "${IBMI_SESSION_USER}@${IBMI_SESSION_HOST}" "$cmd"

    return $?
}

# Transfer file via SCP using session
session_scp() {
    local profile=$1
    local source=$2
    local destination=$3

    if [ -z "$source" ] || [ -z "$destination" ]; then
        die "Usage: session_scp <profile> <source> <destination>"
    fi

    session_ensure "$profile"
    build_ssh_opts

    # Transfer file (through the shared connection when there is one)
    scp "${SSH_OPTS[@]}" "$source" "$destination"

    return $?
}

# Sync directory via rsync using session
session_rsync() {
    local profile=$1
    local source=$2
    local destination=$3
    shift 3
    local extra_args=("$@")

    if [ -z "$source" ] || [ -z "$destination" ]; then
        die "Usage: session_rsync <profile> <source> <destination> [rsync args]"
    fi

    session_ensure "$profile"
    build_ssh_opts

    # rsync takes the ssh command as one string; double-quote each option (paths may contain spaces)
    local ssh_cmd="ssh" opt
    for opt in "${SSH_OPTS[@]}"; do
        ssh_cmd+=" \"$opt\""
    done

    rsync -e "$ssh_cmd" "${extra_args[@]}" "$source" "$destination"

    return $?
}

# ============================================================================
# Initialization
# ============================================================================

# Initialize session system
session_init() {
    setup_ssh_config
    config_init
    ensure_dir "$SESSION_DIR"
}

# ============================================================================
# Export functions
# ============================================================================

export -f session_start
export -f session_check
export -f session_stop
export -f session_stop_all
export -f session_status
export -f session_exec
export -f session_scp
export -f session_rsync
export -f session_init
export -f session_ensure
export -f session_stream
export -f ssh_mux_enabled
export -f build_ssh_opts
