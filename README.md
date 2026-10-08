# IBM i Tools - Complete Package

**Copyright (c) 2024-2026 RSA Data Solutions Inc. All Rights Reserved.**  
**Author**: Sasikumar Manickam  
**License**: Proprietary (See LICENSE file)

⚠️ **IMPORTANT**: This is proprietary commercial software. Unauthorized use, reproduction, or distribution is strictly prohibited.

---

This repository contains two comprehensive toolsets for IBM i development:

## 📦 Package 1: IBM i Member Sync (Member & File Development)

**Location**: `ibmi-sync/`

Syncs IBM i members (library/source file/member) with local filesystem for member-based and file-based development.

### Features

- Member-based for core business logic (RPGLE programs)
- File-based for web interfaces (PHP/Node.js apps)
- File-based for configuration and automation scripts
- Version control (Git) for both paradigms

---

## 📦 Package 2: IBM i File/Folder Sync with Git Integration

**Location**: `ibmi-sync/`
Syncs files and folders between IBM i IFS and desktop with Git/GitHub integration.

### Features

- Bidirectional file/folder sync
- Git version control
- GitHub integration
- Full workflow automation (IBM i → Local → GitHub)
- VS Code integration

### Quick Start

```bash
cd ibmi-sync
./install.sh
ibmi-sync config
ibmi-sync pull-folder /home/user/myproject
```

### Use Cases

- General file/folder synchronization
- IFS development
- Version control with Git
- Automated sync to GitHub
- Multi-environment management

---

## 🎯 Which Tool Should I Use?

### Use **IBM i Member Sync** when:

**Member-Based Development:**
- Working with RPGLE, SQLRPGLE, CLLE source members
- Developing SQL procedures and functions
- Creating/maintaining PF, LF, DSPF files
- Need to compile programs on IBM i
- Working with library/source file/member structure
- Developing traditional IBM i programs

**File-Based Development (via IFS):**
- PHP, Python, Node.js applications in IFS
- Configuration files and scripts
- Modern web development on IBM i

### Use **File/Folder Sync** when:

- Working with IFS files and folders at scale
- Need Git version control and GitHub integration
- Want to push entire projects to GitHub
- Managing complex directory structures
- Need bidirectional folder synchronization
- Working with multi-file modern projects

### Use Both when:

- **Hybrid Development**: RPGLE backend + PHP/Node.js frontend
- **Mixed Workflows**: Members for programs + IFS for configs
- **Multi-Paradigm Projects**: Traditional and modern code together
- **Team Collaboration**: Different developers prefer different models

---

## 📚 Documentation

### IBM i Member Sync

- **README.md** - Complete guide
- **QUICK_REFERENCE.md** - Command cheat sheet
- **INSTALLATION_GUIDE.md** - Detailed installation

### File/Folder Sync

- **README.md** - Complete guide
- **QUICK_REFERENCE.md** - Command cheat sheet
- **INSTALLATION_GUIDE.md** - Detailed installation
- **config.example** - Configuration template

---

## 🚀 Installation

Both tools can be installed independently:

```bash
# Install IBM i Sync Tool
cd ibmi-sync
./install.sh
```

### Cross-Platform Support

The IBM i Sync Tool supports Windows, Linux, and macOS:

- **Windows**: Run `install.bat` or `install.ps1` from PowerShell (if available) or use Git Bash
- **Linux/macOS**: Run `./install.sh` from bash/zsh

The installation automatically handles platform-specific configurations and creates appropriate wrappers for each system.

---

## 🔧 Configuration

Both tools use the same IBM i system:
- **Host**: <pub400.com>
- **User**: <UserID> (configure during installation)

### Member Sync Configuration

Edit `~/.ibmi/config.yaml`:
```yaml
host: "<pub400.com>"
user: "<UserID>"
library: "<Library>"
srcfile: "<SourceFile>"
```

### File/Folder Sync Configuration

Edit `~/.ibmi/config.yaml`:
```yaml
host: "<pub400.com>"
user: "<UserID>"
remote_base_dir: "/home/${user}"
git_repo_url: "https://github.com/RSA-Data-Solutions/IBMi_Tools.git"
```

---

## 📖 Common Workflows

### RPGLE Development Workflow

```bash
# Pull member
ibmi-sync pull <Member>

# Edit with AI tools
code ~/ibmi-local/<Member>.rpgle

# Sync and compile
ibmi-sync sync <Member>
```

### File/Folder Development Workflow

```bash
# Pull project
ibmi-sync pull-folder /home/user/myproject

# Edit locally
code ~/ibmi-files-workspace

# Commit and push to GitHub
ibmi-sync full-sync /home/user/myproject myproject "Updated files"
```

### Combined Workflow

```bash
# Work on RPGLE programs
ibmi-sync pull <Member>
code ~/ibmi-local/<Member>.rpgle
ibmi-sync sync <Member>

# Work on IFS configuration files
ibmi-sync pull-folder /home/user/config
code ~/ibmi-files/config
ibmi-sync push-folder config
```

---

## 🔐 Prerequisites

- SSH access to <pub400.com>
- SSH key authentication (recommended)
- Git installed (for File/Folder Sync)
- rsync installed (for File/Folder Sync)
- VS Code (optional but recommended)

---

## 🆘 Support

### Documentation

- Each package has its own README.md and QUICK_REFERENCE.md
- INSTALLATION_GUIDE.md provides detailed setup instructions

### Troubleshooting

- SSH connection issues: Set up SSH keys
- Permission errors: Check IBM i permissions
- Git push fails: Configure GitHub authentication

---

## 📝 License

Copyright (c) 2024-2026 RSA Data Solutions Inc. All Rights Reserved.

This is proprietary software. See LICENSE file for details.

Author: Sasikumar Manickam

---

## 🎉 Getting Started

1. **Choose your tool(s)** based on your needs
2. **Run installation** for the chosen tool(s)
3. **Configure** SSH keys and settings
4. **Read documentation** for your specific tool
5. **Start developing** with modern workflows!

---

**Repository**: https://github.com/RSA-Data-Solutions/IBMi_Tools.git
**Owner**: RSA Data Solutions Inc.
**Author**: Sasikumar Manickam
**Last Updated**: January 2026

## 🛠️ Troubleshooting

### Windows Issues

If you're running on Windows with Git Bash:

1. Make sure `rsync` is installed (install Git for Windows with rsync option)
2. Ensure `~/bin` is in your PATH
3. Verify SSH keys are properly configured

### Common Errors

- `Permission denied (publickey)`: Check SSH keys
- `command not found`: Ensure PATH is updated
- `rsync not found`: Install rsync for Git Bash

---

## 📖 Resources

- **Documentation**: https://github.com/RSA-Data-Solutions/IBMi_Tools
- **Issues**: https://github.com/RSA-Data-Solutions/IBMi_Tools/issues
- **Repository**: https://github.com/RSA-Data-Solutions/IBMi_Tools.git
- **Owner**: RSA Data Solutions Inc.
- **Author**: Sasikumar Manickam
- **Last Updated**: January 2026
