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

    # Check if session already exists
    if session_check "$profile" "$socket_path"; then
        print_info "Session already active for profile: $profile"
        save_session "$profile" "$IBMI_HOST" "$IBMI_USER" "$socket_path" "$IBMI_LIBRARY" "$IBMI_SRCFILE"
        return 0
    fi

    print_info "Authenticating to $IBMI_HOST as $IBMI_USER..."

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

    local status=$?

    if [ $status -eq 0 ]; then
        print_success "Session started successfully"
        save_session "$profile" "$IBMI_HOST" "$IBMI_USER" "$socket_path" "$IBMI_LIBRARY" "$IBMI_SRCFILE"

        # Display profile configuration
        echo ""
        print_title "Profile Configuration: $profile"
        echo "  ${CYAN}Connection:${NC}"
        echo "    Host:        $IBMI_HOST"
        echo "    User:        $IBMI_USER"
        echo ""
        echo "  ${CYAN}IBM i Settings:${NC}"
        echo "    Library:     $IBMI_LIBRARY"
        echo "    Source File: $IBMI_SRCFILE"
        echo ""
        echo "  ${CYAN}Local Settings:${NC}"
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

        if [ -z "$socket_path" ]; then
            return 1
        fi
    fi

    # Try to check connection
    ssh -S "$socket_path" -O check "${IBMI_USER}@${IBMI_HOST}" >/dev/null 2>&1
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

    # Close ControlMaster connection
    ssh -S "$IBMI_SESSION_SOCKET" -O exit "${IBMI_SESSION_USER}@${IBMI_SESSION_HOST}" 2>/dev/null

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

                    echo "  ${GREEN}✓${NC} $p ($user@$host, age: $age_str)"
                    ((count++))
                else
                    echo "  ${RED}✗${NC} $p (stale)"
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

    # Load profile if not already loaded
    if [ -z "$IBMI_PROFILE" ] || [ "$IBMI_PROFILE" != "$profile" ]; then
        config_load_profile "$profile"
    fi

    # Load session
    if ! load_session "$profile"; then
        print_warning "No active session. Starting one..."
        session_start "$profile" || die "Failed to start session"
        load_session "$profile"
    fi

    # Check if session is still active
    if ! session_check "$profile" "$IBMI_SESSION_SOCKET"; then
        print_warning "Session expired. Reconnecting..."
        session_start "$profile" || die "Failed to reconnect"
        load_session "$profile"
    fi

    # Execute command via ControlMaster
    ssh \
        -S "$IBMI_SESSION_SOCKET" \
        "${IBMI_SESSION_USER}@${IBMI_SESSION_HOST}" \
        "$cmd"

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

    # Load profile if not already loaded
    if [ -z "$IBMI_PROFILE" ] || [ "$IBMI_PROFILE" != "$profile" ]; then
        config_load_profile "$profile"
    fi

    # Load session
    if ! load_session "$profile"; then
        print_warning "No active session. Starting one..."
        session_start "$profile" || die "Failed to start session"
        load_session "$profile"
    fi

    # Check if session is still active
    if ! session_check "$profile" "$IBMI_SESSION_SOCKET"; then
        print_warning "Session expired. Reconnecting..."
        session_start "$profile" || die "Failed to reconnect"
        load_session "$profile"
    fi

    # Transfer file via ControlMaster
    scp \
        -o ControlPath="$IBMI_SESSION_SOCKET" \
        -o ControlMaster=no \
        "$source" "$destination"

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

    # Load profile if not already loaded
    if [ -z "$IBMI_PROFILE" ] || [ "$IBMI_PROFILE" != "$profile" ]; then
        config_load_profile "$profile"
    fi

    # Load session
    if ! load_session "$profile"; then
        print_warning "No active session. Starting one..."
        session_start "$profile" || die "Failed to start session"
        load_session "$profile"
    fi

    # Check if session is still active
    if ! session_check "$profile" "$IBMI_SESSION_SOCKET"; then
        print_warning "Session expired. Reconnecting..."
        session_start "$profile" || die "Failed to reconnect"
        load_session "$profile"
    fi

    # Sync via rsync with ControlMaster
    rsync \
        -e "ssh -S $IBMI_SESSION_SOCKET -o ControlMaster=no" \
        "${extra_args[@]}" \
        "$source" "$destination"

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
