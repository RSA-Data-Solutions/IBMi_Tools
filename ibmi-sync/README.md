# IBM i Unified Sync Tool

A modern, unified command-line tool for syncing IBM i members and files with your local development environment. Works seamlessly on WSL, macOS, and Linux.

**Key Features:**
- 🔄 **Unified Interface** - Single tool for members, files, and Git
- 🔐 **Session-Based Auth** - No password re-entry (SSH ControlMaster)
- 🔑 **Password Caching** - FTP password cached for 4 hours
- 🎯 **Multi-Profile Support** - Manage multiple IBM i systems
- 📂 **Library/Srcfile Switching** - Easy context switching between libraries
- 📦 **Member & File Sync** - RPGLE development and file synchronization
- 🎨 **Smart File Extensions** - Automatic extension detection (`.rpgle`, `.clle`, `.sql`, etc.)
- 🔗 **Git Integration** - Version control and GitHub automation
- 🎮 **Interactive Menu** - User-friendly command-line interface
- 🌍 **Cross-Platform** - Works on WSL, macOS, and Linux
- ⚡ **Fast** - Connection multiplexing for improved performance

## Installation

### Quick Install

```bash
cd ibmi-sync
chmod +x install.sh
./install.sh
```

### Manual Install

```bash
# Create installation directory
mkdir -p ~/bin/ibmi-sync

# Copy files
cp -r . ~/bin/ibmi-sync/
cd ~/bin/ibmi-sync

# Create symlink
ln -s ~/bin/ibmi-sync/ibmi-sync ~/bin/ibmi-sync

# Add to PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Prerequisites

- **Required**: bash, ssh, scp, git
- **Optional**: rsync (for faster folder sync)

### Verify Installation

```bash
ibmi-sync version
ibmi-sync help
```

## Quick Start

### 1. Initial Setup

```bash
# Create configuration
ibmi-sync config init

# Create your first profile
ibmi-sync profile create
```

### 2. Start a Session

```bash
# Begin SSH session (single authentication)
ibmi-sync session start

# View your current context
ibmi-sync session show

# No password prompts for the next 4 hours!
```

### 3. Sync Your First Member

```bash
# List available members
ibmi-sync member list

# Pull a member (auto-detects file extension)
ibmi-sync member pull <Member>

# Edit locally
code ~/ibmi-sync-data/production/members/<Member>.rpgle

# Create a new member (if needed)
ibmi-sync member create <NewMember>

# Sync changes back
ibmi-sync member push <Member>
ibmi-sync member compile <Member>

# Or do it in one step
ibmi-sync member sync <Member>
```

### 4. Working with Multiple Libraries

```bash
# Switch library/srcfile for the session
ibmi-sync session set --library=<TestLibrary> --srcfile=<CLLESourceFile>

# Or use one-time overrides
ibmi-sync member pull <Member> --library=<DevLibrary> --srcfile=<RPGLESourceFile>

# Check current context
ibmi-sync session show
```

## Configuration

Configuration is stored in `~/.ibmi/config.yaml`. Create or edit with:

```bash
ibmi-sync config edit
```

### Example Configuration

```yaml
default_profile: "production"

profiles:
  production:
    host: "<pub400.com>"
    user: "<UserID>"
    library: "<Library>"
    srcfile: "<SourceFile>"
    remote_base: "/home/<UserID>"
    local_dir: "~/ibmi-sync-data/production"
    git_repo: "https://github.com/org/repo.git"
    git_branch: "main"
    description: "Production IBM i system"

  development:
    host: "<dev-host>"
    user: "<DevUser>"
    library: "<DevLibrary>"
    srcfile: "<RPGLESourceFile>"
    remote_base: "/home/DEVUSER"
    local_dir: "~/ibmi-sync-data/development"

session:
  control_persist: "4h"
  control_path: "~/.ibmi/ssh-%r@%h:%p"
  connect_timeout: 10
  server_alive_interval: 60
  server_alive_count_max: 3
```

## Usage

### Command Line Interface

```bash
# Member operations
ibmi-sync member pull <Member>                    # Download member
ibmi-sync member push <Member>                    # Upload member
ibmi-sync member sync <Member>                    # Upload + compile
ibmi-sync member compile <Member>                 # Compile only
ibmi-sync member create <Member> [SRCTYPE]        # Create new member (default: TXT)
ibmi-sync member list                              # List all members
ibmi-sync member pull-all                          # Download all
ibmi-sync member info <Member>                    # Show member information
ibmi-sync member search "<Pattern>"                # Search for members
ibmi-sync member compare <Member>                 # Compare local vs remote
ibmi-sync member delete <Member>                  # Delete member

# Library/Srcfile context switching
ibmi-sync session set --library=<Library> --srcfile=<SourceFile>  # Set context for session
ibmi-sync session show                               # Show current context
ibmi-sync member pull <Member> --library=<TestLibrary>        # One-time override

# File operations
ibmi-sync file pull /home/user/config.json           # Download file
ibmi-sync file push config.json /home/user/config    # Upload file
ibmi-sync file list /home/user                       # List directory

# Folder operations
ibmi-sync folder pull /home/user/myapp myapp         # Download folder
ibmi-sync folder push myapp /home/user/myapp         # Upload folder

# Git operations
ibmi-sync git init                       # Initialize repository
ibmi-sync git status                     # Show status
ibmi-sync git commit "message"           # Commit changes
ibmi-sync git push                       # Push to GitHub
ibmi-sync git pull                       # Pull from GitHub

# Session management
ibmi-sync session start                  # Start SSH session
ibmi-sync session status                 # Show active sessions
ibmi-sync session stop                   # Stop session
ibmi-sync session stop-all               # Stop all sessions

# Profile management
ibmi-sync profile list                   # List profiles
ibmi-sync profile create                 # Create new profile
ibmi-sync profile switch prod            # Switch profile
ibmi-sync profile edit prod              # Edit profile
ibmi-sync profile delete prod            # Delete profile
ibmi-sync profile test prod              # Test connection

# Configuration
ibmi-sync config init                    # Initialize config
ibmi-sync config edit                    # Edit configuration
ibmi-sync config show                    # Show configuration
ibmi-sync config validate                # Validate configuration
```

### Global Options

```bash
--profile=NAME     Use specific profile
--library=LIB      Override library for member commands
--srcfile=FILE     Override source file for member commands
--verbose          Detailed output
--quiet            Minimal output
--debug            Enable debug mode
--dry-run          Show what would be done
--no-color         Disable colored output
```

### Examples

```bash
# Pull with specific profile
ibmi-sync member pull MYPROGRAM --profile=development

# Work with different library (one-time)
ibmi-sync member pull <Member> --library=<TestLibrary> --srcfile=<CLLESourceFile>

# Switch session context
isync session set --library=<ProdLibrary> --srcfile=<RPGLESourceFile>
isync member pull <Member1>
isync member pull <Member2>  # Uses <ProdLibrary>/<RPGLESourceFile>

# Create and push a new member
isync member create <Member> TXT
code ~/ibmi-sync-data/production/members/<Member>.txt
isync member push <Member>

# Push multiple members
ibmi-sync member push <Member1> --verbose
ibmi-sync member push <Member2> --verbose

# Full workflow with context switching
ibmi-sync session start
ibmi-sync session set --library=<DevLibrary>
ibmi-sync member pull <Member>
vim ~/ibmi-sync-data/production/members/<Member>.rpgle
ibmi-sync member sync <Member>
ibmi-sync git commit "Updated <Member>"
ibmi-sync git push
```

## Workflows

### RPGLE Development

```bash
# 1. Start session
ibmi-sync session start

# 2. Pull program
ibmi-sync member pull <Member>

# 3. Edit with IDE
code ~/ibmi-sync-data/production/members/<Member>.rpgle

# 4. Compile and test
ibmi-sync member compile <Member>

# 5. When ready, commit
ibmi-sync git commit "Fixed <Member> calculation bug"
ibmi-sync git push
```

### IFS File Development

```bash
# 1. Pull configuration folder
ibmi-sync folder pull /home/user/config myconfig

# 2. Edit files locally
code ~/ibmi-sync-data/production/myconfig/

# 3. Sync back
ibmi-sync folder push myconfig /home/user/config

# 4. Commit to Git
ibmi-sync git commit "Updated configuration"
ibmi-sync git push
```

### Full Sync to GitHub

```bash
# Initialize if needed
ibmi-sync git init

# One-step sync: IBM i → Local → Git → GitHub
ibmi-sync member pull <Member>
ibmi-sync git commit "Latest version"
ibmi-sync git push
```

## Multi-Profile Usage

### Create Multiple Profiles

```bash
# Create production profile
ibmi-sync profile create
# Enter: production, <pub400.com>, <UserID>, etc.

# Create development profile
ibmi-sync profile create
# Enter: development, dev-as400, DEVUSER, etc.
```

### Switch Between Profiles

```bash
# Use production (default)
ibmi-sync member list

# Use development
ibmi-sync member list --profile=development

# Switch default
ibmi-sync profile switch development
```

## Library/Srcfile Context Switching

### Three-Tier Configuration System

The tool uses a flexible three-tier configuration system for determining which library and source file to use:

1. **Profile Defaults** (lowest priority) - Set in `~/.ibmi/config.yaml`
2. **Session Overrides** (middle priority) - Persistent for the current session
3. **Command-Line Flags** (highest priority) - One-time overrides

### Working with Session Context

```bash
# Start session and view current context
isync session start
isync session show

# Output shows:
# Profile Defaults:
#   Library:     <Library>
#   Source File: <SourceFile>
#
# Session Overrides:
#   (none)
#
# Effective Values:
#   Library:     <Library>
#   Source File: <SourceFile>

# Switch to different library for this session
isync session set --library=<TestLibrary> --srcfile=<CLLESourceFile>

# Now all commands use <TestLibrary>/<CLLESourceFile>
isync member pull <Member1>
isync member pull <Member2>
isync member list

# Check context again
isync session show
# Now shows <TestLibrary>/<CLLESourceFile> as effective values
```

### One-Time Overrides

```bash
# Override library/srcfile for a single command
isync member pull <Member> --library=<ProdLibrary> --srcfile=<RPGLESourceFile>

# Session context remains unchanged
isync member pull ANOTHER  # Still uses session context
```

### Use Cases

**Development Workflow:**
```bash
# Work on development library
isync session set --library=<DevLibrary>
isync member pull <Member1>
isync member pull <Member2>

# Switch to test library
isync session set --library=<TestLibrary>
isync member push <Member1>
isync member push <Member2>

# Quick check on production (one-time)
isync member compare <Member1> --library=<ProdLibrary>
```

**Multi-Library Project:**
```bash
# Start with main library
isync session start
isync member pull <MainMember>

# Switch to utilities library
isync session set --library=<UtilLibrary> --srcfile=<RPGLESourceFile>
isync member pull <Util1>
isync member pull <Util2>

# Switch to SQL procedures
isync session set --srcfile=<SQLSourceFile>
isync member pull <Proc1>
```

### Automatic File Extension Detection

The tool automatically detects file extensions based on the source file name:

- **<RPGLESourceFile>** → `.rpgle`
- **<RPGSourceFile>** → `.rpg`
- **<CLLESourceFile>** → `.clle`
- **<CLPSourceFile>** → `.clp`
- **<CMDSourceFile>** → `.cmd`
- **<DDSSourceFile>** → `.dds`
- **<SQLSourceFile>** → `.sql`
- **<SQLDMLSourceFile>** → `.sqldml`
- **<SQLINDSourceFile>** → `.txt`
- **<SQLTBLSourceFile>** → `.txt`
- **Other** → `.txt` (default)

This means when you pull a member from <RPGLESourceFile>, it automatically saves as `.rpgle`, and when you pull from <CLLESourceFile>, it saves as `.clle`.

## Character Set Conversion (CCSID)

### How It Works

The tool automatically handles character set conversion between your local system and IBM i:

**Member Pull (Download):**
- IBM i stores members in **EBCDIC** (native format)
- Tool uses FTP ASCII mode to convert **EBCDIC → ASCII/UTF-8**
- Local file is saved as readable ASCII/UTF-8
- You can edit with any modern text editor

**Member Push (Upload):**
- Local file is in **ASCII/UTF-8** format
- Tool uses FTP ASCII mode to convert **ASCII → EBCDIC**
- IBM i receives properly formatted EBCDIC data
- File is readable on IBM i (5250, ACS, etc.)

### Important Notes

- **Do NOT use binary editors** on local files - they may corrupt the encoding
- **Always use text editors** (VS Code, vim, nano, etc.)
- **Line endings** are automatically handled (CRLF ↔ LF)
- **Special characters** are preserved during conversion
- **Password caching** - FTP password is cached for 4 hours to avoid repeated prompts

### Troubleshooting CCSID Issues

**Problem:** Characters look corrupted on IBM i (�, ▓, etc.)
**Solution:** The member was created correctly - this is working as intended. The tool uses ASCII mode FTP for proper conversion.

**Problem:** Local file has garbled characters
**Solution:**
```bash
# Re-pull the member with FTP ASCII conversion
isync member pull MEMBERNAME
```

**Problem:** Special characters (é, ñ, £, etc.) not displaying correctly
**Solution:** Ensure your terminal and editor support UTF-8:
```bash
# Check locale
echo $LANG  # Should show UTF-8

# Set if needed
export LANG=en_US.UTF-8
```

## SSH Key Setup (Recommended)

To eliminate password prompts entirely:

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# Copy public key to IBM i
ssh-copy-id <UserID>@<pub400.com>

# Test (should not ask for password)
ssh <UserID>@<pub400.com> "echo 'Success'"
```

## Session Management

### How Sessions Work

IBM i Sync Tool uses SSH ControlMaster for persistent sessions:

1. First time you run a command, it prompts for password/passphrase
2. SSH connection is established and stays alive
3. Subsequent commands reuse the connection (no password prompts)
4. Connection stays active for 4 hours (configurable)

### Manage Sessions

```bash
# Check active sessions
ibmi-sync session status

# Start new session
ibmi-sync session start

# Stop specific session
ibmi-sync session stop production

# Stop all sessions
ibmi-sync session stop-all
```

### Connection Issues

If you have connection problems:

```bash
# Test connection
ibmi-sync profile test production

# Manually reconnect
ibmi-sync session stop production
ibmi-sync session start

# Check SSH config
cat ~/.ssh/config
```

## Advanced Usage

### Batch Operations

```bash
# Pull multiple members
for member in <Member1> <Member2> <Member3>; do
  ibmi-sync member pull $member
done

# Push and compile all
for member in <Member1> <Member2> <Member3>; do
  ibmi-sync member sync $member
done
```

### Automated Workflows

```bash
# Daily sync to GitHub
*/30 * * * * ibmi-sync folder pull /home/user/myapp myapp && \
             ibmi-sync git commit "Automated sync" && \
             ibmi-sync git push 2>/dev/null
```

### Member Search and Compare

```bash
# Search for members
ibmi-sync member search "<Pattern>*"

# Compare local vs remote
ibmi-sync member compare <Member>

# Get member information
ibmi-sync member info <Member>
```

### File Operations

```bash
# Sync directory bidirectionally
ibmi-sync folder sync myapp /home/user/myapp

# List remote directory
ibmi-sync file list /home/user

# Get file information
ibmi-sync file info /home/user/config.json
```

## Troubleshooting

### SSH Connection Issues

**Problem**: "Permission denied (publickey,gssapi-keyex,gssapi-with-mic)"

**Solution**:
```bash
# Set up SSH keys
ssh-keygen -t ed25519
ssh-copy-id <UserID>@<pub400.com>

# Or configure password authentication
# Edit ~/.ibmi/config.yaml to allow PasswordAuthentication
```

### Member Not Found

**Problem**: "Member not found: <Member>"

**Solution**:
```bash
# Check member exists
ibmi-sync member list

# Verify library and source file settings
ibmi-sync config edit

# Check IBM i permissions
```

### Member Push Issues

**Problem**: "Failed to upload - member may not exist (curl error 18)"

**Solution**:
```bash
# Member must exist before pushing
# Create the member first
isync member create <Member>

# Then push
isync member push <Member>
```

**Problem**: Uploaded member shows corrupted characters on IBM i

**Solution**: This should NOT happen with the current version. The tool uses ASCII mode FTP for automatic EBCDIC conversion. If you see corruption:
```bash
# Verify the tool is using ASCII mode (not binary)
# Re-push the member
isync member push <Member>

# If still corrupted, check your local file encoding
file /path/to/local/<Member>.rpgle
# Should show: ASCII text or UTF-8 Unicode text
```

**Problem**: Special characters (# in library names) cause errors

**Solution**: The tool automatically URL-encodes special characters. Library names with # are supported:
```bash
# This works correctly
isync session set --library=O#00729201
isync member push <Member>
```

### Slow Performance

**Problem**: Operations take a long time

**Solution**:
```bash
# Use session to pool connections
ibmi-sync session start

# Check network latency
ping <pub400.com>

# Enable compression in SSH config
```

### Configuration Issues

**Problem**: "Configuration file not found"

**Solution**:
```bash
# Initialize configuration
ibmi-sync config init

# Verify config exists
ls -la ~/.ibmi/config.yaml

# Validate configuration
ibmi-sync config validate
```

## Uninstallation

To remove IBM i Sync Tool:

```bash
cd ibmi-sync
./uninstall.sh

# Or manually:
rm -rf ~/bin/ibmi-sync
rm ~/bin/ibmi-sync
```

The uninstall script will:
- Stop all active SSH sessions
- Back up your configuration
- Remove installation files
- Clean up PATH entries

## Directory Structure

```
~/.ibmi/                              # Configuration directory
├── config.yaml                       # Main configuration file
├── logs/                             # Log files
│   └── ibmi-sync-YYYYMMDD.log
├── sessions/                         # Active session data
│   ├── production.session
│   └── development.session
└── ssh-*                             # SSH control sockets

~/ibmi-sync-data/                    # Data directory
├── production/                       # By profile
│   ├── members/                      # Member files
│   │   ├── PROGRAM1.rpgle
│   │   └── PROGRAM2.rpgle
│   └── files/                        # File copies
│       ├── config/
│       └── scripts/
└── development/

~/bin/ibmi-sync/                     # Installation directory
├── ibmi-sync                         # Main executable
├── lib/                              # Libraries
│   ├── common.sh
│   ├── config.sh
│   ├── session.sh
│   ├── members.sh
│   ├── files.sh
│   └── git.sh
└── config/
    └── default.yaml
```

## Security Considerations

- **SSH Keys**: Use ed25519 keys for better security
- **Credentials**: Stored only in SSH agent (no password files)
- **Configuration**: Keep `~/.ibmi/config.yaml` secure
- **Backups**: Use Git for version control of important files
- **Permissions**: File permissions are preserved during sync

## Performance Tips

1. **Use SSH Keys**: Eliminates authentication delays
2. **Start Session**: Keep connection alive with `ibmi-sync session start`
3. **Password Caching**: FTP password cached for 4 hours automatically
4. **Context Switching**: Use `session set` instead of `--library` flags for multiple operations
5. **Batch Operations**: Process multiple items together
6. **Use rsync**: Faster for large folder syncs
7. **Compression**: SSH compression helps over slow links

## Contributing

Found a bug or have a feature request? Please report it at:
https://github.com/RSA-Data-Solutions/IBMi_Tools/issues

## Migration from Old Tools

If you have the old `sync_ibmi.sh` or `sync_files.sh` tools:

1. Run the installer: `./install.sh`
2. The installer will detect old tools
3. Choose to migrate your configuration
4. Your old settings will be imported into the new unified tool

## Support

For issues, questions, or suggestions:

- **Documentation**: `ibmi-sync help`
- **Configuration**: `ibmi-sync config edit`
- **Troubleshooting**: See Troubleshooting section above
- **GitHub Issues**: https://github.com/RSA-Data-Solutions/IBMi_Tools/issues

## Version History

### v1.1.0 (January 2026)
- **Library/Srcfile Context Switching** - Three-tier configuration system (profile → session → command-line)
- **Password Caching** - FTP password cached for 4 hours to eliminate repeated prompts
- **Member Create Command** - Create new members before pushing
- **Smart File Extensions** - Automatic extension detection based on source file type
  - <RPGLESourceFile> → .rpgle, <CLLESourceFile> → .clle, <SQLDMLSourceFile> → .sqldml, etc.
- **CCSID Conversion** - Automatic ASCII/EBCDIC conversion for proper character encoding
- **Session Context Display** - View current library/srcfile context with `session show`
- **URL Encoding** - Proper handling of special characters (# in library names)
- **Enhanced Error Messages** - Clear guidance when member doesn't exist or push fails

### v1.0.0 (January 2026)
- Initial release
- Unified member and file sync
- SSH ControlMaster for session persistence
- Multi-profile support
- Git integration
- Cross-platform support (WSL, macOS, Linux)

## License

Copyright (c) 2024-2026 RSA Data Solutions Inc. All Rights Reserved.

This is proprietary software for commercial use. Unauthorized use, reproduction, 
or distribution is strictly prohibited. See LICENSE file for complete terms.

**Author**: Sasikumar Manickam  
**Owner**: RSA Data Solutions Inc.

---

**Happy IBM i Development! 🚀**

For the latest updates and documentation, visit:
https://github.com/RSA-Data-Solutions/IBMi_Tools
