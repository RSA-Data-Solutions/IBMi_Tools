# Getting Started with IBM i Unified Sync Tool

Welcome! This guide will help you get up and running quickly with the new unified IBM i Sync Tool.

## What's New

You now have a **single, unified tool** that combines:

- **Member-based development** (RPGLE, CLLE, SQL, PF, LF, etc.) ← from `sync_ibmi.sh`
- **File-based development** (PHP, Python, Node.js, configs) ← from `sync_files.sh`
- **Git integration** (GitHub automation)
- **Session management** (no password re-entry)
- **Multi-profile support** (multiple IBM i systems)
- **Dual development model** (traditional members AND modern files)

Both traditional IBM i source members and modern IFS files work seamlessly with the same unified tool.

All accessible globally as the `ibmi-sync` command.

## 5-Minute Setup

### Step 1: Install

```bash
cd ibmi-sync
./install.sh
```

The installer will:

- Check prerequisites
- Create configuration directories
- Install the tool globally
- Optionally migrate your old tool settings
- Guide you through first-time setup

### Step 2: Verify Installation

```bash
# Show version
ibmi-sync version

# Show all commands
ibmi-sync help
```

### Step 3: Create Your First Profile

```bash
ibmi-sync profile create
```

Answer the questions:

- Profile name: `production`
- IBM i Host: `<pub400.com>`
- IBM i User ID: Your username
- Library: Your library name
- Source file: `<SourceFile>` (or your source file)
- Remote base: `/home/youruser`
- Local directory: `~/ibmi-sync-data/production`

### Step 4: Start a Session

```bash
ibmi-sync session start
```

This authenticates you once. You'll then have 4 hours of passwordless access!

### Step 5: Try a Command

```bash
# List available members
ibmi-sync member list

# Or download a file
ibmi-sync file list /home/youruser
```

## Common Tasks

### Member Development (RPGLE, CLLE, SQL, PF, LF)

```bash
# 1. Download a member (RPGLE)
ibmi-sync member pull <Member>

# 2. Edit it
code ~/ibmi-sync-data/production/members/<Member>.rpgle

# 3. Upload and compile
ibmi-sync member sync <Member>

# 4. Commit to Git (if using version control)
ibmi-sync git commit "Fixed bug in <Member>"
ibmi-sync git push
```

**Working with different member types:**

```bash
# CLLE program
ibmi-sync session set --srcfile=<CLLESourceFile>
ibmi-sync member pull <Member>     # Saves as <Member>.clle

# SQL procedure
ibmi-sync session set --srcfile=<SQLSourceFile>
ibmi-sync member pull <Member>     # Saves as <Member>.sql

# Physical file definition
ibmi-sync session set --srcfile=<DDSSourceFile>
ibmi-sync member pull <Member>     # Saves as <Member>.dds

# Display file
ibmi-sync session set --srcfile=<DSPFSourceFile>
ibmi-sync member pull <Member>     # Saves as <Member>.dds
```

### File Development (PHP, Python, Node.js, IFS Files)

```bash
# 1. Download a folder
ibmi-sync folder pull /home/user/myapp myapp

# 2. Edit files
code ~/ibmi-sync-data/production/myapp/

# 3. Upload back
ibmi-sync folder push myapp /home/user/myapp

# 4. Commit
ibmi-sync git commit "Updated application files"
ibmi-sync git push
```

**Examples for different file types:**

```bash
# PHP web application
ibmi-sync folder pull /www/mysite mysite
# Edit PHP, HTML, CSS, JavaScript files
ibmi-sync folder push mysite /www/mysite

# Python scripts
ibmi-sync file pull /home/user/scripts/process.py
# Edit Python script
ibmi-sync file push process.py /home/user/scripts/

# Node.js application
ibmi-sync folder pull /home/user/nodeapp nodeapp
# Edit package.json, JavaScript files
ibmi-sync folder push nodeapp /home/user/nodeapp

# Configuration files
ibmi-sync file pull /home/user/config/app.json
# Edit JSON configuration
ibmi-sync file push app.json /home/user/config/

# Shell scripts
ibmi-sync file pull /home/user/bin/deploy.sh
# Edit shell script
ibmi-sync file push deploy.sh /home/user/bin/
```

### Switching Between Systems

If you have multiple IBM i systems:

```bash
# List profiles
ibmi-sync profile list

# Switch to development
ibmi-sync profile switch development

# Now commands use the development profile
ibmi-sync member list  # Shows members from dev system
```

## Helpful Commands

```bash
# Session management
ibmi-sync session status          # See active sessions
ibmi-sync session stop-all        # Close all connections

# Profile management
ibmi-sync profile list            # See all profiles
ibmi-sync profile test production # Test connection
ibmi-sync profile edit production # Edit settings

# Configuration
ibmi-sync config edit             # Edit configuration
ibmi-sync config validate         # Check for errors

# Get help
ibmi-sync help                    # Show all commands
ibmi-sync member help             # Help with specific topic (if available)
```

## Configuration File

Your settings are in: `~/.ibmi/config.yaml`

Edit it with:

```bash
ibmi-sync config edit
```

Key settings:

- **Profiles**: Different IBM i systems
- **Session**: How long to keep connections alive
- **Sync settings**: Backup options, file exclusions
- **Git settings**: Auto-commit, auto-push options

## Troubleshooting

### "Command not found: ibmi-sync"

Your shell PATH needs to be updated:

```bash
# For bash
source ~/.bashrc

# For zsh
source ~/.zshrc

# Or restart your terminal
```

### SSH Connection Issues

```bash
# Test connection
ibmi-sync profile test production

# If that fails, check SSH setup
ssh -v youruser@<pub400.com> "echo test"

# Set up SSH keys (recommended)
ssh-keygen -t ed25519
ssh-copy-id youruser@<pub400.com>
```

### Member Not Found

```bash
# Verify member exists
ibmi-sync member list

# Check configuration
ibmi-sync config show

# Verify settings
ibmi-sync profile edit production
```

### Slow Performance

```bash
# Make sure session is active
ibmi-sync session status

# Start a new session if needed
ibmi-sync session start

# Check rsync is installed (for faster folder sync)
which rsync
```

## File Locations

```
~/.ibmi/                    # Configuration & sessions
  ├── config.yaml          # Your settings
  └── logs/                # Activity logs

~/ibmi-sync-data/          # Your synced files
  ├── production/          # By profile
  │   ├── members/         # Member files (.rpgle)
  │   └── files/           # Downloaded files/folders
  └── development/

~/bin/ibmi-sync/           # Installation directory
  ├── ibmi-sync            # Main program
  └── lib/                 # Libraries
```

## Advanced Features

### Multiple Profiles

```bash
# Create profiles for prod, dev, test
ibmi-sync profile create   # prod
ibmi-sync profile create   # dev
ibmi-sync profile create   # test

# Use specific profile
ibmi-sync member list --profile=dev
ibmi-sync file pull /home/user/config.json --profile=prod
```

### Batch Operations

```bash
# Download multiple members
for member in PROG1 PROG2 PROG3; do
  ibmi-sync member pull $member
done

# Upload and compile all
for member in PROG1 PROG2 PROG3; do
  ibmi-sync member sync $member
done
```

### Git Workflows

```bash
# Initialize Git repository
ibmi-sync git init

# Track changes
ibmi-sync git commit "Initial commit"
ibmi-sync git push

# Pull latest
ibmi-sync git pull

# View history
ibmi-sync git log 20
```

## Comparing to Old Tools

| Old Tool                      | New Command                    | Plus Features                        |
| ----------------------------- | ------------------------------ | ------------------------------------ |
| `~/sync_ibmi.sh pull PROG`  | `ibmi-sync member pull PROG` | Works globally, no password re-entry |
| `~/sync_ibmi.sh push PROG`  | `ibmi-sync member push PROG` | Faster with session management       |
| `~/sync_files.sh pull-file` | `ibmi-sync file pull`        | Same functions, unified interface    |
| `~/sync_files.sh git-push`  | `ibmi-sync git push`         | Part of unified tool                 |

**Old tools are still in the repository** if you need them:

- `ibm-i-sync-git-repo/sync_ibmi.sh`
- `ibm-i-file-sync/sync_files.sh`

## Need Help?

1. **Show all commands**

   ```bash
   ibmi-sync help
   ```
2. **See comprehensive documentation**

   ```bash
   cat ~/bin/ibmi-sync/README.md
   less ~/bin/ibmi-sync/README.md
   ```
3. **Check your configuration**

   ```bash
   ibmi-sync config show
   ```
4. **Review configuration file**

   ```bash
   ibmi-sync config edit
   ```
5. **Check logs**

   ```bash
   tail -f ~/.ibmi/logs/ibmi-sync-*.log
   ```

## Uninstalling

If you need to remove the tool:

```bash
cd ibmi-sync
./uninstall.sh
```

The uninstall script will:

- Stop active sessions
- Backup your configuration
- Remove the tool
- Clean up PATH settings

Your configuration and data will be preserved in backups.

## Next Steps

1. ✅ Install the tool
2. ✅ Create a profile
3. ✅ Start a session
4. ✅ Try a command
5. ✅ Read the full README (~/bin/ibmi-sync/README.md)
6. ✅ Share with your team!

---

## Quick Reference

```bash
# Session
ibmi-sync session start              # Authenticate once
ibmi-sync session status             # Check status
ibmi-sync session stop-all           # Close all connections

# Members (RPGLE)
ibmi-sync member pull PROG           # Download
ibmi-sync member push PROG           # Upload
ibmi-sync member sync PROG           # Upload + compile
ibmi-sync member list                # List all
ibmi-sync member compile PROG        # Compile only

# Files
ibmi-sync file pull /path/file       # Download file
ibmi-sync file push local /path      # Upload file
ibmi-sync folder pull /path folder   # Download folder
ibmi-sync folder push folder /path   # Upload folder

# Git
ibmi-sync git init                   # Initialize
ibmi-sync git commit "message"       # Commit
ibmi-sync git push                   # Push to GitHub
ibmi-sync git log 10                 # Show history

# Configuration
ibmi-sync profile list               # See profiles
ibmi-sync profile create             # New profile
ibmi-sync profile switch dev         # Change profile
ibmi-sync config edit                # Edit settings
ibmi-sync help                       # Show help
```

---

**Happy IBM i Development! 🚀**

Questions? Check the full README or the implementation summary.
