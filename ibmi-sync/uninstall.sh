#!/bin/bash

# IBM i Unified Sync Tool - Uninstallation Script

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
    echo -e "${BLUE}║${NC}  IBM i Unified Sync Tool - Uninstallation${NC}"
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

confirm() {
    local prompt=$1
    local response

    echo -ne "${YELLOW}${prompt}${NC} (y/n) "
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
# Uninstallation
# ============================================================================

stop_sessions() {
    print_step "Stopping active sessions..."

    if [ -d "$HOME/.ibmi/sessions" ]; then
        for session_file in "$HOME/.ibmi/sessions"/*.session 2>/dev/null; do
            if [ -f "$session_file" ]; then
                # Extract socket path and close connection
                local socket=$(grep '"socket"' "$session_file" | cut -d'"' -f4)
                if [ -S "$socket" ]; then
                    # Try to gracefully close
                    ssh -S "$socket" -O exit user@host 2>/dev/null || true
                fi
            fi
        done
    fi

    print_success "Sessions stopped"
}

backup_config() {
    print_step "Backing up configuration..."

    if [ -d "$HOME/.ibmi" ]; then
        local backup_dir="$HOME/ibmi-sync-backup-$(date +%Y%m%d-%H%M%S)"
        cp -r "$HOME/.ibmi" "$backup_dir"
        print_success "Configuration backed up to: $backup_dir"
    fi
}

remove_installation() {
    print_step "Removing installation..."

    # Remove symlink or directory at $BIN_DIR/ibmi-sync
    if [ -e "$BIN_DIR/ibmi-sync" ] || [ -L "$BIN_DIR/ibmi-sync" ]; then
        if [ -d "$BIN_DIR/ibmi-sync" ] && [ ! -L "$BIN_DIR/ibmi-sync" ]; then
            # It's a directory, not a symlink
            rm -rf "$BIN_DIR/ibmi-sync"
        else
            # It's a file or symlink
            rm -f "$BIN_DIR/ibmi-sync"
        fi
        print_success "Removed: $BIN_DIR/ibmi-sync"
    fi

    # Remove installation directory
    if [ -d "$INSTALL_PREFIX" ]; then
        rm -rf "$INSTALL_PREFIX"
        print_success "Removed installation directory"
    fi
}

update_shell_config() {
    print_step "Updating shell configuration..."

    local shell_config=$(get_shell_config)

    if [ -z "$shell_config" ]; then
        print_warning "Could not find shell config file"
        return 0
    fi

    # Remove IBM i Sync Tool PATH entries
    if grep -q "IBM i Sync Tool" "$shell_config"; then
        # Create backup
        cp "$shell_config" "$shell_config.backup-ibmi"

        # Remove our entries (this is a simple approach)
        sed -i.bak '/IBM i Sync Tool/,+3d' "$shell_config"

        print_success "Updated $shell_config"
        print_warning "Backup saved as: ${shell_config}.backup-ibmi"
    fi
}

remove_config() {
    print_step "Removing configuration..."

    if [ -d "$HOME/.ibmi" ]; then
        if confirm "Remove configuration directory ($HOME/.ibmi)?"; then
            rm -rf "$HOME/.ibmi"
            print_success "Removed configuration directory"
        else
            print_warning "Keeping configuration directory"
        fi
    fi
}

remove_data() {
    print_step "Removing data..."

    if [ -d "$HOME/ibmi-sync-data" ]; then
        if confirm "Remove data directory ($HOME/ibmi-sync-data)?"; then
            rm -rf "$HOME/ibmi-sync-data"
            print_success "Removed data directory"
        else
            print_warning "Keeping data directory"
        fi
    fi
}

# ============================================================================
# Verification
# ============================================================================

verify_removal() {
    print_step "Verifying removal..."

    local issues=0

    if [ -d "$INSTALL_PREFIX" ]; then
        print_error "Installation directory still exists: $INSTALL_PREFIX"
        ((issues++))
    else
        print_success "Installation directory removed"
    fi

    if [ -L "$BIN_DIR/ibmi-sync" ]; then
        print_error "Symlink still exists: $BIN_DIR/ibmi-sync"
        ((issues++))
    else
        print_success "Symlink removed"
    fi

    if command -v ibmi-sync >/dev/null 2>&1; then
        print_warning "ibmi-sync command still in PATH (may be cached)"
        print_warning "Try: hash -r (bash) or rehash (zsh)"
    else
        print_success "ibmi-sync command no longer in PATH"
    fi

    return $issues
}

# ============================================================================
# Post-Uninstallation Info
# ============================================================================

show_post_uninstall_info() {
    echo ""
    echo -e "${GREEN}Uninstallation complete!${NC}\n"

    echo "Post-uninstallation steps:"
    echo ""
    echo "1. Refresh your shell session:"
    echo "   source $(get_shell_config)"
    echo ""
    echo "Or start a new terminal."
    echo ""
    echo "To reinstall later:"
    echo "   cd /path/to/ibmi-sync && ./install.sh"
    echo ""
}

# ============================================================================
# Main Uninstallation Flow
# ============================================================================

main() {
    print_header

    echo "This will uninstall IBM i Unified Sync Tool"
    echo ""

    if ! confirm "Continue with uninstallation?"; then
        print_warning "Uninstallation cancelled"
        exit 0
    fi

    print_step "IBM i Unified Sync Tool Uninstaller"
    echo ""

    # Run all uninstallation steps
    stop_sessions
    backup_config
    remove_installation
    update_shell_config

    # Optional removals
    echo ""
    remove_config
    remove_data

    # Verify
    verify_removal
    local verify_status=$?

    # Show final info
    show_post_uninstall_info

    if [ $verify_status -ne 0 ]; then
        print_warning "Some items may need manual cleanup"
        return 1
    fi

    return 0
}

# Run uninstallation
main
