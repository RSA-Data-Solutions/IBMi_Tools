# IBM i Tools - Complete Package

**Copyright (c) 2024-2026 RSA Data Solutions Inc. All Rights Reserved.**  
**Author**: Sasikumar Manickam  
**License**: Proprietary (See LICENSE file)

⚠️ **IMPORTANT**: This is proprietary commercial software. Unauthorized use, reproduction, or distribution is strictly prohibited.

---

This repository contains two comprehensive toolsets for IBM i development:

## 📦 Package 1: IBM i Member Sync (Member & File Development)

**Location**: `ibm-i-sync-git-repo/`

Syncs IBM i members (library/source file/member) with local filesystem for member-based and file-based development. Supports RPGLE, CLLE, SQL, PF, LF, and other traditional IBM i source types.

### Features

- Pull/push members (RPGLE, CLLE, SQL, PF, LF, and more)
- Compile members on IBM i
- Support for all IBM i source types
- VS Code integration
- Local development with AI tools
- Dual development model support

### Quick Start

```bash
cd ibm-i-sync-git-repo
./install.sh
~/sync_ibmi.sh pull <SourceFile>
```

### Use Cases

- Member-based development (RPGLE, CLLE, SQL, etc.)
- File-based development (PHP, Python, Node.js, configs)
- Working with IBM i source members (PF, LF, display files)
- Compiling programs on IBM i
- AI-assisted coding with modern editors
- Mixed development workflows

---

## 🔄 Dual Development Model

IBM i development supports **two complementary paradigms**:

### Member-Based Development (Traditional)
Working with IBM i source members through library/source file/member structure:
- **RPGLE, SQLRPGLE** - RPG programs
- **CLLE, CLP** - Control Language programs  
- **SQL** - SQL procedures and functions
- **PF, LF** - Physical and Logical files (DDS)
- **DSPF, PRTF** - Display and Printer files
- **CMD** - Command definitions

**Use the Member Sync tool** for this traditional IBM i development model.

### File-Based Development (Modern)
Working with IFS files using standard file systems:
- **PHP, Python, Node.js** - Modern web applications
- **Shell scripts** - Automation and utilities
- **Configuration files** - JSON, XML, YAML, properties
- **HTML, CSS, JavaScript** - Web resources
- **Markdown, text files** - Documentation

**Use the File/Folder Sync tool** for this modern development model.

### Hybrid Workflows
Many teams use **both models simultaneously**:
- Member-based for core business logic (RPGLE programs)
- File-based for web interfaces (PHP/Node.js apps)
- File-based for configuration and automation scripts
- Version control (Git) for both paradigms

---

## 📦 Package 2: IBM i File/Folder Sync with Git Integration

**Location**: `ibm-i-file-sync/`

Syncs files and folders between IBM i IFS and desktop with Git/GitHub integration.

### Features

- Bidirectional file/folder sync
- Git version control
- GitHub integration
- Full workflow automation (IBM i → Local → GitHub)
- VS Code integration

### Quick Start

```bash
cd ibm-i-file-sync
./install.sh
~/sync_files.sh config
~/sync_files.sh pull-folder /home/user/myproject
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
# Install Member Sync
cd ibm-i-sync-git-repo
./install.sh

# Install File/Folder Sync
cd ibm-i-file-sync
./install.sh
```

---

## 🔧 Configuration

Both tools use the same IBM i system:
- **Host**: <pub400.com>
- **User**: <UserID> (configure during installation)

### Member Sync Configuration

Edit `~/sync_ibmi.sh`:
```bash
IBMI_HOST="<pub400.com>"
IBMI_USER="<UserID>"
LIBRARY="<Library>"
SRCFILE="<SourceFile>"
```

### File/Folder Sync Configuration

Edit `~/sync_files.sh`:
```bash
IBMI_HOST="<pub400.com>"
IBMI_USER="<UserID>"
REMOTE_BASE_DIR="/home/${IBMI_USER}"
GIT_REPO_URL="https://github.com/RSA-Data-Solutions/IBMi_Tools.git"
```

---

## 📖 Common Workflows

### RPGLE Development Workflow

```bash
# Pull member
~/sync_ibmi.sh pull <Member>

# Edit with AI tools
code ~/ibmi-local/<Member>.rpgle

# Sync and compile
~/sync_ibmi.sh sync <Member>
```

### File/Folder Development Workflow

```bash
# Pull project
~/sync_files.sh pull-folder /home/user/myproject

# Edit locally
code ~/ibmi-files-workspace

# Commit and push to GitHub
~/sync_files.sh full-sync /home/user/myproject myproject "Updated files"
```

### Combined Workflow

```bash
# Work on RPGLE programs
~/sync_ibmi.sh pull <Member>
code ~/ibmi-local/<Member>.rpgle
~/sync_ibmi.sh sync <Member>

# Work on IFS configuration files
~/sync_files.sh pull-folder /home/user/config
code ~/ibmi-files/config
~/sync_files.sh push-folder config
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
