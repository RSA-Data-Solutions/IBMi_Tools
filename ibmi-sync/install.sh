#!/bin/bash

# IBM i Unified Sync Tool - Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PREFIX="${HOME}/.local/bin/ibmi-sync"
BIN_DIR="${HOME}/bin"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  IBM i Unified Sync Tool - Installation${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "\n${BLUE}→${NC} $*"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

die() {
    print_error "$*"
    exit 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect platform
detect_platform() {
    if [ -n "${IBMI_PLATFORM:-}" ]; then
        echo "$IBMI_PLATFORM"
        return 0
    fi
    case "$(uname -s 2>/dev/null)" in
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;   # Git Bash (Git for Windows), MSYS2, Cygwin
        Darwin) echo "macos" ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

PLATFORM="$(detect_platform)"

# Shell startup file for the user's login shell
get_shell_config() {
    case "$(basename "${SHELL:-bash}")" in
        zsh) echo "$HOME/.zshrc" ;;
        bash)
            if [ "$PLATFORM" = "macos" ]; then
                # Terminal.app starts login shells, which read ~/.bash_profile
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        *) echo "$HOME/.profile" ;;
    esac
}

# Add a folder to the Windows *user* PATH (no administrator rights needed) so that
# ibmi-sync.cmd / isync.cmd work from PowerShell and cmd.exe.
add_windows_user_path() {
    local dir=$1
    local windir
    windir=$(cygpath -w "$dir")
    # print_* use "echo -e": double the backslashes so C:\Users\...\bin is not read as escapes (\b, \n)
    local shown=${windir//\\/\\\\}

    # 1. PowerShell (also notifies running programs of the change)
    local ps_dir=${windir//\'/\'\'}
    local result
    result=$(powershell.exe -NoProfile -NonInteractive -Command "
        \$d = '$ps_dir'
        \$p = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not \$p) { \$p = '' }
        if ((\$p -split ';') -contains \$d) { 'present' } else {
            [Environment]::SetEnvironmentVariable('Path', ((\$p.TrimEnd(';') + ';' + \$d).TrimStart(';')), 'User')
            'added'
        }" 2>/dev/null | tr -d '\r')
    case "$result" in
        *present*) print_success "$shown is already on your Windows PATH"; return 0 ;;
        *added*) print_success "Added $shown to your Windows user PATH (open a new terminal to use it)"; return 0 ;;
    esac

    # 2. reg.exe (PowerShell may run in Constrained Language Mode on locked-down desktops)
    local query current
    if query=$(MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' reg.exe query 'HKCU\Environment' /v Path 2>&1); then
        current=$(printf '%s\n' "$query" | tr -d '\r' | sed -n 's/^ *Path *REG_[A-Z_]* *//p')
    elif printf '%s' "$query" | grep -qi 'unable to find'; then
        current=""   # no user PATH yet
    else
        query=""     # reg.exe blocked: never write a PATH we could not read (it would replace the user's)
    fi
    if [ -n "$query" ]; then
        if printf '%s' ";$current;" | grep -qiF ";$windir;"; then
            print_success "$shown is already on your Windows PATH"
            return 0
        fi
        local newpath="${current:+${current%;};}$windir"
        if MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' reg.exe add 'HKCU\Environment' /v Path /t REG_EXPAND_SZ \
            /d "$newpath" /f >/dev/null 2>&1; then
            print_success "Added $shown to your Windows user PATH (sign out and in, or open a new terminal)"
            return 0
        fi
    fi

    # 3. Manual
    print_warning "Could not change your Windows PATH automatically (blocked by policy?)."
    echo "  Add this folder to your user PATH: Start > 'Edit environment variables for your account' > Path > New:"
    echo "    $windir"
}

# ============================================================================
# Checks
# ============================================================================

check_prerequisites() {
    print_step "Checking prerequisites..."

    local missing=()

    # Check required commands
    for cmd in bash ssh scp git curl tar; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    # Check for rsync (optional but recommended)
    if ! command_exists rsync; then
        print_success "rsync not found: folder sync will use tar over ssh instead (fine)"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        die "Missing required commands: ${missing[*]}"
    fi

    print_success "All prerequisites met"
}

check_ssh_keys() {
    print_step "Checking SSH configuration..."

    if [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_ecdsa" ]; then
        print_warning "No SSH key found"
        echo "To avoid password prompts, generate an SSH key:"
        echo "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
    else
        print_success "SSH keys found"
    fi
}

# ============================================================================
# Installation
# ============================================================================

install_files() {
    print_step "Installing files..."

    # Create install directory for libraries and config
    mkdir -p "$INSTALL_PREFIX"

    # Copy libraries and config (not the main executable)
    if [ -d "$SCRIPT_DIR/lib" ]; then
        cp -r "$SCRIPT_DIR/lib" "$INSTALL_PREFIX/"
    fi
    if [ -d "$SCRIPT_DIR/config" ]; then
        cp -r "$SCRIPT_DIR/config" "$INSTALL_PREFIX/"
    fi
    if [ -f "$SCRIPT_DIR/README.md" ]; then
        cp "$SCRIPT_DIR/README.md" "$INSTALL_PREFIX/"
    fi

    # Make library scripts executable
    chmod +x "$INSTALL_PREFIX/lib"/*.sh 2>/dev/null || true

    # Create bin directory and copy main executable directly
    mkdir -p "$BIN_DIR"

    # Remove existing file or directory
    if [ -e "$BIN_DIR/ibmi-sync" ] || [ -L "$BIN_DIR/ibmi-sync" ]; then
        if [ -d "$BIN_DIR/ibmi-sync" ] && [ ! -L "$BIN_DIR/ibmi-sync" ]; then
            rm -rf "$BIN_DIR/ibmi-sync"
        else
            rm -f "$BIN_DIR/ibmi-sync"
        fi
    fi

    # Copy main executable directly to bin
    cp "$SCRIPT_DIR/ibmi-sync" "$BIN_DIR/ibmi-sync"
    chmod +x "$BIN_DIR/ibmi-sync"

    # Create isync symlink for shorthand
    if [ -L "$BIN_DIR/isync" ] || [ -e "$BIN_DIR/isync" ]; then
        rm -f "$BIN_DIR/isync"
    fi
    
    # A tiny forwarding script instead of a symlink: Git Bash's "ln -s" silently makes a
    # copy that would go stale on the next upgrade.
    cat > "$BIN_DIR/isync" << 'ISYNC'
#!/bin/bash
# IBM i Sync Tool - "isync" shorthand for ibmi-sync
exec "$(dirname "${BASH_SOURCE[0]}")/ibmi-sync" "$@"
ISYNC
    chmod +x "$BIN_DIR/isync" 2>/dev/null || true

    # Windows: launchers so that ibmi-sync / isync also work from PowerShell and cmd.exe
    if [ "$PLATFORM" = "windows" ]; then
        local launcher
        for launcher in ibmi-sync.cmd isync.cmd; do
            if [ -f "$SCRIPT_DIR/$launcher" ]; then
                cp "$SCRIPT_DIR/$launcher" "$BIN_DIR/$launcher"
            fi
        done
        print_success "Windows launchers installed: $BIN_DIR/ibmi-sync.cmd, isync.cmd"
    fi

    print_success "Files installed to: $INSTALL_PREFIX"
    print_success "Executable installed to: $BIN_DIR/ibmi-sync"
    print_success "Shorthand alias created: $BIN_DIR/isync"
}

update_path() {
    print_step "Updating PATH..."

    local shell_config=$(get_shell_config)

    # If shell config file doesn't exist, create it
    if [ ! -f "$shell_config" ]; then
        touch "$shell_config"
        print_warning "Created new shell config file: $shell_config"
    fi

    # Check if already in PATH
    if grep -q "export PATH.*$BIN_DIR" "$shell_config"; then
        print_success "PATH already updated in $shell_config"
        return 0
    fi

    # Add to PATH
    cat >> "$shell_config" << EOF

# IBM i Sync Tool - Added by installer
if [ -d "$BIN_DIR" ]; then
    export PATH="$BIN_DIR:\$PATH"
fi
EOF

    print_success "PATH updated in $shell_config"
    echo "  Run: source $shell_config (or restart your terminal)"
}

update_windows_path() {
    [ "$PLATFORM" = "windows" ] || return 0
    print_step "Updating Windows PATH (for PowerShell and cmd.exe)..."

    # Git Bash runs ~/.bash_profile, not ~/.bashrc; without one it prints a warning and makes one.
    if [ ! -f "$HOME/.bash_profile" ] && [ "$(get_shell_config)" = "$HOME/.bashrc" ]; then
        printf '%s\n' '# Created by the IBM i Sync Tool installer' 'test -f ~/.bashrc && . ~/.bashrc' > "$HOME/.bash_profile"
        print_success "Created ~/.bash_profile (loads ~/.bashrc)"
    fi

    add_windows_user_path "$BIN_DIR"
}

create_directories() {
    print_step "Creating directories..."

    mkdir -p "$HOME/.ibmi/logs"
    mkdir -p "$HOME/.ibmi/sessions"
    mkdir -p "$HOME/ibmi-sync-data"

    print_success "Directories created"
}

initialize_config() {
    print_step "Initializing configuration..."

    # Run the tool to create default config
    if [ ! -f "$HOME/.ibmi/config.yaml" ]; then
        if "$BIN_DIR/ibmi-sync" config init >/dev/null 2>&1; then
            print_success "Configuration initialized (edit it with: ibmi-sync config edit)"
        else
            print_warning "Could not create ~/.ibmi/config.yaml; run 'ibmi-sync config init' to see why"
        fi
    else
        print_success "Configuration already exists"
    fi
}

# ============================================================================
# First-Time Setup
# ============================================================================

first_time_setup() {
    print_step "First-time setup..."

    echo -e "\n${BLUE}Welcome to IBM i Sync Tool!${NC}"
    echo ""
    echo "Let's set up your first profile."
    echo ""

    local proceed
    read -p "Create a profile now? (y/n) " -n 1 -r proceed || proceed=n
    echo ""

    if [[ ! $proceed =~ ^[Yy]$ ]]; then
        print_warning "You can create a profile later with: ibmi-sync profile create"
        return 0
    fi

    # Create profile
    "$BIN_DIR/ibmi-sync" profile create
}

# ============================================================================
# Migration from Old Tools
# ============================================================================

# Default profile name from ~/.ibmi/config.yaml
default_profile_name() {
    grep '^default_profile:' "$HOME/.ibmi/config.yaml" 2>/dev/null | cut -d':' -f2 | tr -d ' "\r'
}

# set_profile_values key value [key value ...] - writes into the default profile using the
# tool's own config library (only the profile's lines change; comments are left alone)
set_profile_values() {
    local profile
    profile=$(default_profile_name)
    [ -n "$profile" ] || { print_warning "No default profile in ~/.ibmi/config.yaml; not migrated"; return 0; }
    cp "$HOME/.ibmi/config.yaml" "$HOME/.ibmi/config.yaml.bak"
    (
        source "$INSTALL_PREFIX/lib/common.sh"
        source "$INSTALL_PREFIX/lib/config.sh"
        while [ $# -ge 2 ]; do
            [ -n "$2" ] && config_set_value "$profile" "$1" "$2"
            shift 2
        done
    )
}

migrate_old_tools() {
    print_step "Checking for old tool installations..."

    local migrated=false

    # Check for old member sync tool
    if [ -f "$HOME/sync_ibmi.sh" ]; then
        print_warning "Found old member sync tool: ~/sync_ibmi.sh"

        local migrate
        read -p "Migrate configuration from old tool? (y/n) " -n 1 -r migrate || migrate=n
        echo ""

        if [[ $migrate =~ ^[Yy]$ ]]; then
            # Extract config from old script
            local host=$(grep "^IBMI_HOST=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)
            local user=$(grep "^IBMI_USER=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)
            local library=$(grep "^LIBRARY=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)
            local srcfile=$(grep "^SRCFILE=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)

            if [ -n "$host" ] && [ -n "$user" ]; then
                mkdir -p "$HOME/ibmi-sync-backup"
                cp "$HOME/sync_ibmi.sh" "$HOME/ibmi-sync-backup/sync_ibmi.sh.bak"
                print_success "Old tool backed up to ~/ibmi-sync-backup/"

                set_profile_values host "$host" user "$user" library "$library" srcfile "$srcfile" \
                    remote_base "/home/$user"
                print_success "Configuration migrated into profile '$(default_profile_name)'"
                migrated=true
            fi
        fi
    fi

    # Check for old file sync tool
    if [ -f "$HOME/sync_files.sh" ]; then
        print_warning "Found old file sync tool: ~/sync_files.sh"

        local migrate
        read -p "Migrate configuration from old tool? (y/n) " -n 1 -r migrate || migrate=n
        echo ""

        if [[ $migrate =~ ^[Yy]$ ]]; then
            # Extract config from old script
            local host=$(grep "^IBMI_HOST=" "$HOME/sync_files.sh" | cut -d'"' -f2)
            local user=$(grep "^IBMI_USER=" "$HOME/sync_files.sh" | cut -d'"' -f2)
            local git_repo=$(grep "^GIT_REPO_URL=" "$HOME/sync_files.sh" | cut -d'"' -f2)

            if [ -n "$host" ] && [ -n "$user" ]; then
                mkdir -p "$HOME/ibmi-sync-backup"
                cp "$HOME/sync_files.sh" "$HOME/ibmi-sync-backup/sync_files.sh.bak"
                set_profile_values host "$host" user "$user" git_repo "$git_repo"
                print_success "File sync configuration migrated into profile '$(default_profile_name)'"
                migrated=true
            fi
        fi
    fi

    if [ "$migrated" = false ]; then
        print_warning "No old tools found to migrate"
    fi
}

# ============================================================================
# Verification
# ============================================================================

verify_installation() {
    print_step "Verifying installation..."

    # Check if command is available
    if ! command_exists ibmi-sync; then
        print_warning "ibmi-sync command not in PATH"
        print_warning "Run: source $(get_shell_config)"
        echo ""
        print_warning "Or add $BIN_DIR to your PATH manually"
    else
        print_success "ibmi-sync command available"

        # Get version
        local version=$("$BIN_DIR/ibmi-sync" version)
        echo "  Version: $version"
    fi

    # Check config file
    if [ -f "$HOME/.ibmi/config.yaml" ]; then
        print_success "Configuration file: $HOME/.ibmi/config.yaml"
    else
        print_error "Configuration file not found"
    fi

    # Check directories
    if [ -d "$HOME/.ibmi" ]; then
        print_success "Configuration directory: $HOME/.ibmi"
    fi
}

# ============================================================================
# Post-Installation Info
# ============================================================================

show_post_install_info() {
    print_header

    echo -e "${GREEN}Installation complete!${NC}\n"

    echo "Next steps:"
    echo ""
    echo "1. Update your shell configuration:"
    echo "   source $(get_shell_config)"
    if [ "$PLATFORM" = "windows" ]; then
        echo "   PowerShell / cmd.exe: open a NEW window, then 'isync help' works there too"
    fi
    echo ""
    echo "2. Start SSH session:"
    echo "   isync session start"
    echo ""
    echo "3. Try your first sync:"
    echo "   isync member list"
    echo ""
    echo "Quick Tips:"
    echo "   • Use 'isync' as shorthand for 'ibmi-sync'"
    echo "   • Use 'isync help' to see all available commands"
    echo "   • Use 'isync --no-color' to disable colored output"
    echo ""
    echo "Documentation:"
    echo "   isync help"
    echo ""
    echo "Configuration file:"
    echo "   $HOME/.ibmi/config.yaml"
    echo ""
    echo "Happy IBM i development! 🚀"
    echo ""
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
    print_header

    print_step "IBM i Unified Sync Tool Installer"
    echo "Version: 1.2.0"
    echo "Platform: $PLATFORM"
    echo ""

    # Run all installation steps
    check_prerequisites
    check_ssh_keys
    create_directories
    install_files
    update_path
    update_windows_path
    initialize_config
    migrate_old_tools
    verify_installation

    # Offer first-time setup
    echo ""
    first_time_setup

    # Show final info
    show_post_install_info
}

# Run installation
main
