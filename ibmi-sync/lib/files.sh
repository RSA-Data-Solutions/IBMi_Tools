#!/bin/bash

# IBM i Unified Sync Tool - File/Folder Operations
# Handles synchronization of files and folders between IBM i and local system

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/session.sh"

# ============================================================================
# File Operations
# ============================================================================

# Download file from IBM i
file_pull() {
    local profile=$1
    local remote_path=$2
    local local_path=${3:-}

    if [ -z "$remote_path" ]; then
        die "Remote path required"
    fi

    config_load_profile "$profile"

    # Use basename if local path not specified
    if [ -z "$local_path" ]; then
        local_path=$(basename "$remote_path")
    fi

    local full_local_path="${IBMI_LOCAL_DIR}/${local_path}"

    print_info "Pulling file: $remote_path..."

    # Create directory if needed
    ensure_dir "$(dirname "$full_local_path")"

    # Download file
    start_spinner "Downloading..."
    session_scp "$profile" \
        "${IBMI_USER}@${IBMI_HOST}:${remote_path}" \
        "$full_local_path"

    if [ $? -eq 0 ]; then
        stop_spinner
        print_success "Downloaded: $full_local_path"
        return 0
    else
        stop_spinner_error
        print_error "Failed to download file"
        return 1
    fi
}

# Upload file to IBM i
file_push() {
    local profile=$1
    local local_path=$2
    local remote_path=$3

    if [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        die "Usage: file_push <local_file> <remote_path>"
    fi

    config_load_profile "$profile"

    local full_local_path="${IBMI_LOCAL_DIR}/${local_path}"

    if [ ! -f "$full_local_path" ]; then
        die "Local file not found: $full_local_path"
    fi

    print_info "Pushing file: $local_path..."

    # Upload file
    start_spinner "Uploading..."
    session_scp "$profile" \
        "$full_local_path" \
        "${IBMI_USER}@${IBMI_HOST}:${remote_path}"

    if [ $? -eq 0 ]; then
        stop_spinner
        print_success "Uploaded: $remote_path"
        return 0
    else
        stop_spinner_error
        print_error "Failed to upload file"
        return 1
    fi
}

# List remote directory
file_list() {
    local profile=$1
    local remote_path=$2

    if [ -z "$remote_path" ]; then
        remote_path="$IBMI_REMOTE_BASE"
    fi

    config_load_profile "$profile"

    print_title "Listing: $remote_path"
    print_separator

    session_exec "$profile" "ls -lah \"$remote_path\""

    return $?
}

# ============================================================================
# Folder Operations
# ============================================================================

# Folder transfers use rsync when both ends have it, otherwise a tar stream over ssh.
# Git Bash on Windows has no rsync, and many IBM i systems only have it under /QOpenSys/pkgs/bin
# (not on an ssh session's PATH) or not at all. IBMI_FOLDER_TRANSFER=tar forces the tar path.
# Sets FOLDER_RSYNC_PATH to the remote rsync binary when rsync is usable.
folder_use_rsync() {
    local profile=$1
    FOLDER_RSYNC_PATH=""
    [ "${IBMI_FOLDER_TRANSFER:-auto}" = "tar" ] && return 1
    command_exists rsync || return 1
    FOLDER_RSYNC_PATH=$(session_stream "$profile" \
        'command -v rsync 2>/dev/null || { [ -x /QOpenSys/pkgs/bin/rsync ] && echo /QOpenSys/pkgs/bin/rsync; }' \
        2>/dev/null | tail -n 1)
    [ -n "$FOLDER_RSYNC_PATH" ]
}

# Copy the contents of a remote folder into a local folder.
folder_copy_down() {
    local profile=$1 remote_path=$2 local_path=$3
    if folder_use_rsync "$profile"; then
        session_rsync "$profile" "${IBMI_USER}@${IBMI_HOST}:${remote_path}/" "$local_path/" \
            -avz --rsync-path="$FOLDER_RSYNC_PATH" 2>&1 | tail -n 5
    else
        print_debug "Folder transfer via tar over ssh"
        session_stream "$profile" "cd \"$remote_path\" && tar -cf - ." | tar -xf - -C "$local_path"
    fi
}

# Copy the contents of a local folder into a remote folder (created if needed).
folder_copy_up() {
    local profile=$1 local_path=$2 remote_path=$3
    if folder_use_rsync "$profile"; then
        session_rsync "$profile" "$local_path/" "${IBMI_USER}@${IBMI_HOST}:${remote_path}/" \
            -avz --rsync-path="$FOLDER_RSYNC_PATH" 2>&1 | tail -n 5
    else
        print_debug "Folder transfer via tar over ssh"
        # ustar: readable by the AIX tar in IBM i PASE (GNU tar's default long-name format is not)
        tar --format ustar -cf - -C "$local_path" . |
            session_stream "$profile" "mkdir -p \"$remote_path\" && cd \"$remote_path\" && tar -xf -"
    fi
}

# Pull folder from IBM i
folder_pull() {
    local profile=$1
    local remote_path=$2
    local local_path=${3:-}

    if [ -z "$remote_path" ]; then
        die "Remote path required"
    fi

    config_load_profile "$profile"

    # Use basename if local path not specified
    if [ -z "$local_path" ]; then
        local_path=$(basename "$remote_path")
    fi

    local full_local_path="${IBMI_LOCAL_DIR}/${local_path}"

    print_info "Pulling folder: $remote_path → $full_local_path..."

    # Create directory
    ensure_dir "$full_local_path"

    # Download folder (rsync or tar over ssh)
    start_spinner "Downloading..."
    folder_copy_down "$profile" "$remote_path" "$full_local_path"

    if [ $? -eq 0 ]; then
        stop_spinner
        print_success "Downloaded folder: $full_local_path"
        return 0
    else
        stop_spinner_error
        print_error "Failed to download folder"
        return 1
    fi
}

# Upload folder to IBM i
folder_push() {
    local profile=$1
    local local_path=$2
    local remote_path=$3

    if [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        die "Usage: folder_push <local_folder> <remote_path>"
    fi

    config_load_profile "$profile"

    local full_local_path="${IBMI_LOCAL_DIR}/${local_path}"

    if [ ! -d "$full_local_path" ]; then
        die "Local folder not found: $full_local_path"
    fi

    print_info "Pushing folder: $local_path → $remote_path..."

    # Create remote directory first
    session_exec "$profile" "mkdir -p \"$remote_path\"" >/dev/null 2>&1

    # Upload folder (rsync or tar over ssh)
    start_spinner "Uploading..."
    folder_copy_up "$profile" "$full_local_path" "$remote_path"

    if [ $? -eq 0 ]; then
        stop_spinner
        print_success "Uploaded folder: $remote_path"
        return 0
    else
        stop_spinner_error
        print_error "Failed to upload folder"
        return 1
    fi
}

# ============================================================================
# Sync Operations
# ============================================================================

# Sync from IBM i (auto-detect file or folder)
file_sync_from() {
    local profile=$1
    local remote_path=$2
    local local_path=${3:-}

    if [ -z "$remote_path" ]; then
        die "Remote path required"
    fi

    config_load_profile "$profile"

    # Check if remote path is file or directory
    print_debug "Checking remote path: $remote_path"

    local is_dir=$(session_exec "$profile" \
        "[ -d \"$remote_path\" ] && echo 'yes' || echo 'no'" 2>/dev/null)

    if [ "$is_dir" = "yes" ]; then
        folder_pull "$profile" "$remote_path" "$local_path"
    else
        file_pull "$profile" "$remote_path" "$local_path"
    fi

    return $?
}

# Sync to IBM i (auto-detect file or folder)
file_sync_to() {
    local profile=$1
    local local_path=$2
    local remote_path=$3

    if [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        die "Usage: file_sync_to <local_path> <remote_path>"
    fi

    config_load_profile "$profile"

    local full_local_path="${IBMI_LOCAL_DIR}/${local_path}"

    if [ ! -e "$full_local_path" ]; then
        die "Local path not found: $full_local_path"
    fi

    # Check if local path is file or directory
    if [ -d "$full_local_path" ]; then
        folder_push "$profile" "$local_path" "$remote_path"
    else
        file_push "$profile" "$local_path" "$remote_path"
    fi

    return $?
}

# ============================================================================
# File Comparison
# ============================================================================

# Compare local and remote file
file_compare() {
    local profile=$1
    local local_path=$2
    local remote_path=$3

    if [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        die "Usage: file_compare <local_path> <remote_path>"
    fi

    config_load_profile "$profile"

    local full_local_path="${IBMI_LOCAL_DIR}/${local_path}"

    if [ ! -f "$full_local_path" ]; then
        die "Local file not found: $full_local_path"
    fi

    print_title "Comparing: $local_path ↔ $remote_path"
    print_separator

    # Download remote file to temp location
    local temp_remote="/tmp/$(basename $remote_path).remote"

    session_scp "$profile" \
        "${IBMI_USER}@${IBMI_HOST}:${remote_path}" \
        "$temp_remote" >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        rm -f "$temp_remote"
        die "Failed to download remote file for comparison"
    fi

    # Show diff
    if command_exists diff; then
        diff -u "$full_local_path" "$temp_remote" || true
    else
        print_info "Diff not available, showing file sizes:"
        print_info "Local: $(wc -c < "$full_local_path" | tr -d ' ') bytes"
        print_info "Remote: $(wc -c < "$temp_remote" | tr -d ' ') bytes"
    fi

    # Cleanup
    rm -f "$temp_remote"

    print_separator

    return 0
}

# ============================================================================
# Folder Sync
# ============================================================================

# Full folder sync (bidirectional)
folder_sync() {
    local profile=$1
    local local_path=$2
    local remote_path=$3
    local direction=${4:-both}

    if [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        die "Usage: folder_sync <local_path> <remote_path> [pull|push|both]"
    fi

    case "$direction" in
        pull)
            folder_pull "$profile" "$remote_path" "$local_path"
            ;;
        push)
            folder_push "$profile" "$local_path" "$remote_path"
            ;;
        both)
            # Ask which direction
            print_info "Sync both directions? (pull first, then push)"
            if confirm "Pull first?"; then
                folder_pull "$profile" "$remote_path" "$local_path" || return 1
            fi
            if confirm "Push changes?"; then
                folder_push "$profile" "$local_path" "$remote_path" || return 1
            fi
            ;;
        *)
            die "Invalid direction: $direction (pull|push|both)"
            ;;
    esac

    return $?
}

# Watch folder for changes and auto-sync
folder_watch() {
    local profile=$1
    local local_path=$2
    local remote_path=$3
    local interval=${4:-5}

    if [ -z "$local_path" ] || [ -z "$remote_path" ]; then
        die "Usage: folder_watch <local_path> <remote_path> [interval]"
    fi

    config_load_profile "$profile"

    local full_local_path="${IBMI_LOCAL_DIR}/${local_path}"

    if [ ! -d "$full_local_path" ]; then
        die "Local folder not found: $full_local_path"
    fi

    print_title "Watching folder: $full_local_path"
    print_info "Syncing every $interval seconds (Ctrl+C to stop)..."
    print_separator

    # Get initial timestamp
    local last_sync=$(date +%s)

    while true; do
        # Find files modified since last sync
        local modified=$(find "$full_local_path" -type f -newermt @$last_sync 2>/dev/null)

        if [ -n "$modified" ]; then
            print_info "Changes detected, syncing..."
            folder_push "$profile" "$local_path" "$remote_path"
            last_sync=$(date +%s)
        fi

        sleep "$interval"
    done

    return 0
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get file info
file_info() {
    local profile=$1
    local remote_path=$2

    if [ -z "$remote_path" ]; then
        die "Remote path required"
    fi

    config_load_profile "$profile"

    print_title "File Info: $remote_path"
    print_separator

    session_exec "$profile" "stat \"$remote_path\" 2>/dev/null || ls -lh \"$remote_path\""

    return $?
}

# Delete remote file
file_delete() {
    local profile=$1
    local remote_path=$2

    if [ -z "$remote_path" ]; then
        die "Remote path required"
    fi

    if ! confirm "Delete remote file: $remote_path?"; then
        print_warning "Cancelled"
        return 0
    fi

    config_load_profile "$profile"

    print_info "Deleting: $remote_path..."

    session_exec "$profile" "rm -f \"$remote_path\""

    if [ $? -eq 0 ]; then
        print_success "File deleted: $remote_path"
        return 0
    else
        print_error "Failed to delete file"
        return 1
    fi
}

# ============================================================================
# Export functions
# ============================================================================

export -f file_pull
export -f file_push
export -f file_list
export -f file_sync_from
export -f file_sync_to
export -f file_compare
export -f folder_pull
export -f folder_push
export -f folder_sync
export -f folder_watch
