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

# Get shell config file
get_shell_config() {
    if [ -f "$HOME/.zshrc" ]; then
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        echo "$HOME/.bash_profile"
    elif [ -f "$HOME/.bashrc" ]; then
        echo "$HOME/.bashrc"
    fi
}

# ============================================================================
# Checks
# ============================================================================

check_prerequisites() {
    print_step "Checking prerequisites..."

    local missing=()

    # Check required commands
    for cmd in bash ssh scp git; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    # Check for rsync (optional but recommended)
    if ! command_exists rsync; then
        print_warning "rsync not found (optional, used for folder sync)"
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
    ln -s "$BIN_DIR/ibmi-sync" "$BIN_DIR/isync"
    chmod +x "$BIN_DIR/isync" 2>/dev/null || true

    print_success "Files installed to: $INSTALL_PREFIX"
    print_success "Executable installed to: $BIN_DIR/ibmi-sync"
    print_success "Shorthand alias created: $BIN_DIR/isync"
}

update_path() {
    print_step "Updating PATH..."

    local shell_config=$(get_shell_config)

    if [ -z "$shell_config" ]; then
        print_warning "Could not find shell config file"
        print_warning "Please add $BIN_DIR to your PATH manually"
        return 0
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
        "$BIN_DIR/ibmi-sync" config init >/dev/null 2>&1 || true
        print_success "Configuration initialized"
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
    read -p "Create a profile now? (y/n) " -n 1 -r proceed
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

migrate_old_tools() {
    print_step "Checking for old tool installations..."

    local migrated=false

    # Check for old member sync tool
    if [ -f "$HOME/sync_ibmi.sh" ]; then
        print_warning "Found old member sync tool: ~/sync_ibmi.sh"

        local migrate
        read -p "Migrate configuration from old tool? (y/n) " -n 1 -r migrate
        echo ""

        if [[ $migrate =~ ^[Yy]$ ]]; then
            # Extract config from old script
            local host=$(grep "^IBMI_HOST=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)
            local user=$(grep "^IBMI_USER=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)
            local library=$(grep "^LIBRARY=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)
            local srcfile=$(grep "^SRCFILE=" "$HOME/sync_ibmi.sh" | cut -d'"' -f2)

            if [ -n "$host" ] && [ -n "$user" ]; then
                # Update config
                sed -i.bak "
                  s|host: .*|host: \"$host\"|;
                  s|user: .*|user: \"$user\"|;
                  s|library: .*|library: \"$library\"|;
                  s|srcfile: .*|srcfile: \"$srcfile\"|;
                " "$HOME/.ibmi/config.yaml"

                print_success "Configuration migrated"
                migrated=true

                # Optionally backup old tool
                if [ -d "$HOME/ibmi-sync-backup" ]; then
                    mkdir -p "$HOME/ibmi-sync-backup"
                    cp "$HOME/sync_ibmi.sh" "$HOME/ibmi-sync-backup/sync_ibmi.sh.bak"
                    print_success "Old tool backed up to ~/ibmi-sync-backup/"
                fi
            fi
        fi
    fi

    # Check for old file sync tool
    if [ -f "$HOME/sync_files.sh" ]; then
        print_warning "Found old file sync tool: ~/sync_files.sh"

        local migrate
        read -p "Migrate configuration from old tool? (y/n) " -n 1 -r migrate
        echo ""

        if [[ $migrate =~ ^[Yy]$ ]]; then
            # Extract config from old script
            local host=$(grep "^IBMI_HOST=" "$HOME/sync_files.sh" | cut -d'"' -f2)
            local user=$(grep "^IBMI_USER=" "$HOME/sync_files.sh" | cut -d'"' -f2)
            local git_repo=$(grep "^GIT_REPO_URL=" "$HOME/sync_files.sh" | cut -d'"' -f2)

            if [ -n "$host" ] && [ -n "$user" ]; then
                # These would already be set from sync_ibmi.sh if both exist
                print_success "File sync configuration noted"
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
    echo "Version: 1.0.0"
    echo "Platform: $(detect_platform)"
    echo ""

    # Run all installation steps
    check_prerequisites
    check_ssh_keys
    create_directories
    install_files
    update_path
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
