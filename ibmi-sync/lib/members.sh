#!/bin/bash

# IBM i Unified Sync Tool - Member Operations
# Handles synchronization of IBM i RPGLE/COBOL members

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/session.sh"

# ============================================================================
# Password Caching (4 hour expiry)
# ============================================================================

PASSWORD_CACHE_FILE="$HOME/.ibmi/.ftp_password_cache"
PASSWORD_CACHE_DURATION=14400  # 4 hours in seconds

# Get cached password if valid
get_cached_password() {
    local profile=$1
    local cache_file="${PASSWORD_CACHE_FILE}.${profile}"

    if [ ! -f "$cache_file" ]; then
        return 1
    fi

    # Read timestamp and password
    local timestamp=$(head -n 1 "$cache_file")
    local password=$(tail -n 1 "$cache_file")
    local current_time=$(date +%s)
    local age=$((current_time - timestamp))

    # Check if password is still valid (less than 4 hours old)
    if [ $age -lt $PASSWORD_CACHE_DURATION ]; then
        echo "$password"
        return 0
    else
        # Expired, remove it
        rm -f "$cache_file"
        return 1
    fi
}

# Save password to cache
save_password_cache() {
    local profile=$1
    local password=$2
    local cache_file="${PASSWORD_CACHE_FILE}.${profile}"

    # Create cache file with timestamp and password
    local timestamp=$(date +%s)
    echo "$timestamp" > "$cache_file"
    echo "$password" >> "$cache_file"
    chmod 600 "$cache_file"
}

# Clear password cache
clear_password_cache() {
    local profile=${1:-*}
    rm -f "${PASSWORD_CACHE_FILE}.${profile}" 2>/dev/null
}

# ============================================================================
# Helper Functions
# ============================================================================

# Detect source type from file extension
# Note: SQL files use TXT as source type in IBM i
detect_source_type() {
    local filename=$1
    local extension="${filename##*.}"

    case "$(to_lower "$extension")" in
        sqlrpgle) echo "SQLRPGLE" ;;
        sqlrpg) echo "SQLRPG" ;;
        rpgle) echo "RPGLE" ;;
        rpg) echo "RPG" ;;
        clle|cle) echo "CLLE" ;;
        clp|cl) echo "CLP" ;;
        cmd) echo "CMD" ;;
        dds) echo "DDS" ;;
        bnd) echo "BND" ;;
        c) echo "C" ;;
        cbl|cblle) echo "CBL" ;;
        sql|sqldml|sqlproc) echo "TXT" ;;  # SQL source members use TXT type
        txt|*) echo "TXT" ;;
    esac
}

# ============================================================================
# Member Sync Operations
# ============================================================================

# Download member from IBM i
member_pull() {
    local profile=$1
    local member=$2

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    # Convert member name to uppercase (IBM i is case-sensitive for member names)
    member=$(echo "$member" | tr '[:lower:]' '[:upper:]')

    print_info "Pulling member: $library/$srcfile($member)..."

    # Determine file extension based on source file name
    local extension=".txt"  # Default to .txt for unknown types
    case "$srcfile" in
        QRPGLESRC|*RPGLESRC) extension=".rpgle" ;;
        QRPGSRC|*RPGSRC) extension=".rpg" ;;
        QCLLESRC|*CLLESRC) extension=".clle" ;;
        QCLSRC|*CLSRC) extension=".clp" ;;
        QCMDSRC|*CMDSRC) extension=".cmd" ;;
        QDDSSRC|*DDSSRC) extension=".dds" ;;
        QBNDSRC|*BNDSRC) extension=".bnd" ;;
        QCSRC|*CSRC) extension=".c" ;;
        QCBLLESRC|*CBLLESRC) extension=".cbl" ;;
        QCBLSRC|*CBLSRC) extension=".cbl" ;;
        QSQLSRC|*SQLSRC) extension=".sql" ;;
        SQLDMLSRC|*SQLDMLSRC) extension=".sqldml" ;;
        SQLINDSRC|*SQLINDSRC) extension=".txt" ;;
        SQLTBLSRC|*SQLTBLSRC) extension=".txt" ;;
        QTXTSRC|*TXTSRC) extension=".txt" ;;
        *)
            # Default to .txt for any unmapped source file
            extension=".txt"
            ;;
    esac

    # Pull to current directory by default (where command was executed)
    local local_file="$(pwd)/${member}${extension}"

    # URL-encode special characters in library name (# becomes %23)
    local encoded_library=$(echo "$library" | sed 's/#/%23/g')

    # Try to get cached password first
    local password=$(get_cached_password "$profile")
    local using_cache=0

    if [ -n "$password" ]; then
        print_info "Downloading via FTP (using cached credentials)..."
        using_cache=1
    else
        print_info "Downloading via FTP (you will be prompted for password)..."
        # Prompt for password and capture it
        read -sp "Enter host password for user '$IBMI_USER': " password
        echo ""
    fi

    # Use curl with FTP for member transfer with automatic EBCDIC/ASCII conversion
    # Use ASCII mode, passive mode, and set IBM i naming format
    curl --use-ascii \
        --ftp-pasv \
        --quote "SITE NAMEFMT 1" \
        --user "${IBMI_USER}:${password}" \
        "ftp://${IBMI_HOST}/QSYS.LIB/${encoded_library}.LIB/${srcfile}.FILE/${member}.MBR" \
        -o "$local_file" 2>&1

    local status=$?

    if [ $status -eq 0 ] && [ -f "$local_file" ] && [ -s "$local_file" ]; then
        # Save password to cache on success (if not already cached)
        if [ $using_cache -eq 0 ]; then
            save_password_cache "$profile" "$password"
            print_debug "Password cached for 4 hours"
        fi
        print_success "Downloaded: $library/$srcfile($member) → $local_file"
        return 0
    else
        print_error "Failed to download member (curl exit code: $status)"
        # Clear cache on authentication failure
        if [ $status -eq 67 ]; then
            clear_password_cache "$profile"
            print_warning "Cached credentials cleared due to authentication failure"
        fi
        return 1
    fi
}

# Upload member to IBM i
member_push() {
    local profile=$1
    local member=$2

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    # Convert member name to uppercase (IBM i is case-sensitive for member names)
    member=$(echo "$member" | tr '[:lower:]' '[:upper:]')

    # Priority 1: Check current directory first (where command was executed)
    local current_dir="$(pwd)"
    local local_file=$(find "$current_dir" -maxdepth 1 -iname "${member}.*" -type f | head -1)

    if [ -z "$local_file" ] || [ ! -f "$local_file" ]; then
        # Priority 2: Check configured local directory
        local_file=$(find "$IBMI_LOCAL_DIR" -maxdepth 1 -iname "${member}.*" -type f | head -1)
    fi

    if [ -z "$local_file" ] || [ ! -f "$local_file" ]; then
        # Try without extension in current directory
        if [ -f "${current_dir}/${member}" ]; then
            local_file="${current_dir}/${member}"
        elif [ -f "${IBMI_LOCAL_DIR}/${member}" ]; then
            local_file="${IBMI_LOCAL_DIR}/${member}"
        else
            print_error "Local file not found: ${member}.* (searched for any extension)"
            print_info "Checked locations:"
            print_info "  1. Current directory: ${current_dir}/${member}.*"
            print_info "  2. Configured directory: ${IBMI_LOCAL_DIR}/${member}.*"
            return 1
        fi
    fi

    print_info "Pushing member: $member to $library/$srcfile..."
    print_info "Using local file: $local_file"

    # URL-encode special characters in library name (# becomes %23)
    local encoded_library=$(echo "$library" | sed 's/#/%23/g')

    # Try to get cached password first
    local password=$(get_cached_password "$profile")
    local using_cache=0

    if [ -n "$password" ]; then
        print_info "Uploading via FTP (using cached credentials)..."
        using_cache=1
    else
        print_info "Uploading via FTP (you will be prompted for password)..."
        # Prompt for password and capture it
        read -sp "Enter host password for user '$IBMI_USER': " password
        echo ""
    fi

    # Upload directly to member via FTP with ASCII mode for EBCDIC conversion
    # ASCII mode automatically converts from local ASCII/UTF-8 to IBM i EBCDIC
    curl --use-ascii \
        --ftp-pasv \
        --quote "SITE NAMEFMT 1" \
        --user "${IBMI_USER}:${password}" \
        -T "$local_file" \
        "ftp://${IBMI_HOST}/QSYS.LIB/${encoded_library}.LIB/${srcfile}.FILE/${member}.MBR" 2>&1

    local status=$?

    if [ $status -eq 0 ]; then
        # Save password to cache on success (if not already cached)
        if [ $using_cache -eq 0 ]; then
            save_password_cache "$profile" "$password"
            print_debug "Password cached for 4 hours"
        fi
        print_success "Uploaded: $local_file → $library/$srcfile($member)"
        return 0
    elif [ $status -eq 18 ]; then
        # Error 18 with 426 usually means member doesn't exist or wrong attributes
        print_warning "Upload failed (curl error 18) - attempting to create member and retry..."

        # Detect source type from file extension
        local srctype=$(detect_source_type "$local_file")
        print_info "Detected source type: $srctype from file extension"

        # URL-encode library name for FTP RCMD
        local create_result=$(curl --ftp-pasv \
            --quote "SITE NAMEFMT 1" \
            --quote "RCMD ADDPFM FILE(${library}/${srcfile}) MBR(${member}) SRCTYPE(${srctype})" \
            --user "${IBMI_USER}:${password}" \
            "ftp://${IBMI_HOST}/" 2>&1)

        if [ $? -eq 0 ]; then
            print_success "Member created with source type: $srctype"
        elif echo "$create_result" | grep -q "Member.*already exists"; then
            print_warning "Member already exists - attempting to clear and recreate with correct source type..."

            # Delete the existing member
            local delete_result=$(curl --ftp-pasv \
                --quote "SITE NAMEFMT 1" \
                --quote "RCMD RMVM FILE(${library}/${srcfile}) MBR(${member})" \
                --user "${IBMI_USER}:${password}" \
                "ftp://${IBMI_HOST}/" 2>&1)

            # Recreate with correct source type
            curl --ftp-pasv \
                --quote "SITE NAMEFMT 1" \
                --quote "RCMD ADDPFM FILE(${library}/${srcfile}) MBR(${member}) SRCTYPE(${srctype})" \
                --user "${IBMI_USER}:${password}" \
                "ftp://${IBMI_HOST}/" 2>&1 > /dev/null

            if [ $? -eq 0 ]; then
                print_success "Member recreated with source type: $srctype"
            else
                print_error "Failed to recreate member"
                return 1
            fi
        else
            print_error "Failed to create member"
            return 1
        fi

        print_info "Retrying upload..."

        # Retry the upload
        curl --use-ascii \
            --ftp-pasv \
            --quote "SITE NAMEFMT 1" \
            --user "${IBMI_USER}:${password}" \
            -T "$local_file" \
            "ftp://${IBMI_HOST}/QSYS.LIB/${encoded_library}.LIB/${srcfile}.FILE/${member}.MBR" 2>&1

        local retry_status=$?
        if [ $retry_status -eq 0 ]; then
            if [ $using_cache -eq 0 ]; then
                save_password_cache "$profile" "$password"
            fi
            print_success "Uploaded: $local_file → $library/$srcfile($member)"
            return 0
        else
            print_error "Retry failed (curl exit code: $retry_status)"
            return 1
        fi
    else
        print_error "Failed to upload member (curl exit code: $status)"
        # Clear cache on authentication failure
        if [ $status -eq 67 ]; then
            clear_password_cache "$profile"
            print_warning "Cached credentials cleared due to authentication failure"
        fi
        return 1
    fi
}

# Compile member on IBM i
member_compile() {
    local profile=$1
    local member=$2

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    print_title "Compiling: $library/$member"

    # Execute compilation
    session_exec "$profile" \
        "system \"CRTBNDRPG PGM(${library}/${member}) SRCFILE(${library}/${srcfile}) SRCMBR(${member})\" 2>&1"

    if [ $? -eq 0 ]; then
        print_success "Compilation successful: $member"
        return 0
    else
        print_error "Compilation failed - check output above"
        return 1
    fi
}

# Upload and compile member (sync operation)
member_sync() {
    local profile=$1
    local member=$2

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    # Push member first
    member_push "$profile" "$member" || return 1

    # Then compile
    member_compile "$profile" "$member" || return 1

    return 0
}

# List all members in source file
member_list() {
    local profile=$1

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    print_title "Members in: $library/$srcfile"
    print_separator

    # Get member list from IBM i
    session_exec "$profile" \
        "system \"DSPFD FILE(${library}/${srcfile}) TYPE(*MBRLIST)\" 2>&1"

    return 0
}

# Pull all members from source file
member_pull_all() {
    local profile=$1

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    print_title "Pulling all members from: $library/$srcfile"

    # Get member list
    local members=$(session_exec "$profile" \
        "system \"DSPFD FILE(${library}/${srcfile}) TYPE(*MBRLIST)\" 2>&1" | \
        grep -E '^\s+[A-Z0-9_]+\s+' | awk '{print $1}')

    if [ -z "$members" ]; then
        print_warning "No members found in source file"
        return 1
    fi

    # Pull each member
    local count=0
    local failed=0

    for member in $members; do
        if member_pull "$profile" "$member"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    print_separator
    print_success "Pulled $count member(s)"
    if [ $failed -gt 0 ]; then
        print_warning "Failed: $failed member(s)"
        return 1
    fi

    return 0
}

# Get member information (size, modification date, etc.)
member_info() {
    local profile=$1
    local member=$2

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    print_title "Member Info: $member"
    print_separator

    # Get member details
    session_exec "$profile" \
        "system \"DSPMBRDS FILE(${library}/${srcfile}) MBR(${member})\" 2>&1"

    # Also show local file info
    if [ -f "${IBMI_LOCAL_DIR}/${member}.rpgle" ]; then
        echo ""
        print_info "Local file:"
        ls -lh "${IBMI_LOCAL_DIR}/${member}.rpgle"
    fi

    return 0
}

# Delete member with confirmation
member_delete() {
    local profile=$1
    local member=$2

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    # Convert member name to uppercase (IBM i is case-sensitive)
    member=$(echo "$member" | tr '[:lower:]' '[:upper:]')

    if ! confirm "Delete member $member from $library/$srcfile?"; then
        print_warning "Cancelled"
        return 0
    fi

    print_info "Deleting member: $member..."

    # Try to get cached password first
    local password=$(get_cached_password "$profile")
    local using_cache=0

    if [ -z "$password" ]; then
        read -sp "Enter host password for user '$IBMI_USER': " password
        echo ""
    else
        using_cache=1
    fi

    # Delete member using FTP RCMD (doesn't require SSH session)
    local result=$(curl --ftp-pasv \
        --quote "SITE NAMEFMT 1" \
        --quote "RCMD RMVM FILE(${library}/${srcfile}) MBR(${member})" \
        --user "${IBMI_USER}:${password}" \
        "ftp://${IBMI_HOST}/" 2>&1)

    local status=$?

    if [ $status -eq 0 ]; then
        if [ $using_cache -eq 0 ]; then
            save_password_cache "$profile" "$password"
        fi
        print_success "Member deleted: $library/$srcfile($member)"
        return 0
    else
        print_error "Failed to delete member"
        echo "$result" | grep -i "error\|fail" || echo "$result"
        if [ $status -eq 67 ]; then
            clear_password_cache "$profile"
        fi
        return 1
    fi
}

# Create a new member
member_create() {
    local profile=$1
    local member=$2
    local srctype=${3:-}

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    # Convert member name to uppercase (IBM i is case-sensitive)
    member=$(echo "$member" | tr '[:lower:]' '[:upper:]')

    # If source type not specified, try to detect from local file
    if [ -z "$srctype" ]; then
        local current_dir="$(pwd)"
        local local_file=$(find "$current_dir" -maxdepth 1 -iname "${member}.*" -type f | head -1)

        if [ -z "$local_file" ]; then
            local_file=$(find "$IBMI_LOCAL_DIR" -maxdepth 1 -iname "${member}.*" -type f | head -1)
        fi

        if [ -n "$local_file" ] && [ -f "$local_file" ]; then
            srctype=$(detect_source_type "$local_file")
            print_info "Auto-detected source type: $srctype from file: $local_file"
        else
            srctype="TXT"
            print_info "No local file found - using default source type: TXT"
        fi
    else
        srctype=$(echo "$srctype" | tr '[:lower:]' '[:upper:]')
    fi

    print_info "Creating member: $library/$srcfile($member) with source type $srctype..."

    # Create member using FTP RCMD (doesn't require SSH session)
    local password=$(get_cached_password "$profile")
    local using_cache=0

    if [ -z "$password" ]; then
        read -sp "Enter host password for user '$IBMI_USER': " password
        echo ""
    else
        using_cache=1
    fi

    # Use FTP quote command to create member
    local result=$(curl --ftp-pasv \
        --quote "SITE NAMEFMT 1" \
        --quote "RCMD ADDPFM FILE(${library}/${srcfile}) MBR(${member}) SRCTYPE(${srctype})" \
        --user "${IBMI_USER}:${password}" \
        "ftp://${IBMI_HOST}/" 2>&1)

    local status=$?

    if [ $status -eq 0 ] || echo "$result" | grep -q "Member.*already exists"; then
        if [ $using_cache -eq 0 ]; then
            save_password_cache "$profile" "$password"
        fi
        print_success "Member created: $library/$srcfile($member)"
        return 0
    else
        print_error "Failed to create member"
        echo "$result" | grep -i "error\|fail"
        if [ $status -eq 67 ]; then
            clear_password_cache "$profile"
        fi
        return 1
    fi
}

# Search for members matching pattern
member_search() {
    local profile=$1
    local pattern=$2

    if [ -z "$pattern" ]; then
        die "Search pattern required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    # Convert * to % for SQL LIKE
    pattern="${pattern//\*/\%}"

    print_title "Searching for members matching: $pattern"
    print_separator

    # Get matching members
    session_exec "$profile" \
        "system \"DSPFD FILE(${library}/${srcfile}) TYPE(*MBRLIST)\" 2>&1" | \
        grep -i "$pattern"

    return 0
}

# Compare local and remote member
member_compare() {
    local profile=$1
    local member=$2

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    config_load_profile "$profile"

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    local local_file="${IBMI_LOCAL_DIR}/${member}.rpgle"
    local temp_remote="/tmp/${member}_remote.rpgle"

    if [ ! -f "$local_file" ]; then
        die "Local file not found: $local_file"
    fi

    print_info "Downloading remote member for comparison..."

    # Download remote member to temp file
    session_exec "$profile" \
        "system \"CPYTOSTMF FROMMBR('/QSYS.LIB/${library}.LIB/${srcfile}.FILE/${member}.MBR') TOSTMF('$temp_remote') STMFOPT(*REPLACE)\" 2>&1" \
        >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        die "Failed to download remote member"
    fi

    # Create local temp copy
    local temp_local="/tmp/${member}_local.rpgle"
    cp "$local_file" "$temp_local"

    # Show diff
    print_title "Diff: Local vs Remote ($member)"
    print_separator

    diff -u "$temp_local" "$temp_remote" || true

    print_separator

    # Cleanup
    rm -f "$temp_local" "$temp_remote"

    return 0
}

# Pull member with specific compile parameters
member_pull_and_compile() {
    local profile=$1
    local member=$2
    local compile_parms=${3:-}

    if [ -z "$member" ]; then
        die "Member name required"
    fi

    # Pull the member
    member_pull "$profile" "$member" || return 1

    # Get effective library and srcfile (command-line > session > profile)
    local library="${IBMI_OVERRIDE_LIBRARY:-$(get_effective_library "$profile")}"
    local srcfile="${IBMI_OVERRIDE_SRCFILE:-$(get_effective_srcfile "$profile")}"

    # Compile with parameters
    if [ -n "$compile_parms" ]; then
        session_exec "$profile" \
            "system \"CRTBNDRPG PGM(${library}/${member}) SRCFILE(${library}/${srcfile}) SRCMBR(${member}) $compile_parms\" 2>&1"
    else
        member_compile "$profile" "$member"
    fi

    return $?
}

# Batch pull multiple members
member_pull_batch() {
    local profile=$1
    shift
    local -a members=("$@")

    if [ ${#members[@]} -eq 0 ]; then
        die "At least one member required"
    fi

    config_load_profile "$profile"

    print_title "Pulling ${#members[@]} member(s)..."

    local count=0
    local failed=0

    for member in "${members[@]}"; do
        if member_pull "$profile" "$member"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    print_separator
    print_success "Pulled $count member(s)"
    if [ $failed -gt 0 ]; then
        print_warning "Failed: $failed member(s)"
        return 1
    fi

    return 0
}

# Batch push multiple members
member_push_batch() {
    local profile=$1
    shift
    local -a members=("$@")

    if [ ${#members[@]} -eq 0 ]; then
        die "At least one member required"
    fi

    config_load_profile "$profile"

    print_title "Pushing ${#members[@]} member(s)..."

    local count=0
    local failed=0

    for member in "${members[@]}"; do
        if member_push "$profile" "$member"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    print_separator
    print_success "Pushed $count member(s)"
    if [ $failed -gt 0 ]; then
        print_warning "Failed: $failed member(s)"
        return 1
    fi

    return 0
}

# ============================================================================
# Export functions
# ============================================================================

export -f member_pull
export -f member_push
export -f member_compile
export -f member_sync
export -f member_list
export -f member_pull_all
export -f member_info
export -f member_delete
export -f member_search
export -f member_compare
