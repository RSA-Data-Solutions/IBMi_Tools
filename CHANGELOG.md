# Changelog

All notable changes to IBM i Sync Tool will be documented in this file.

## [1.1.0] - 2026-01-29

### Added

#### Library/Srcfile Context Switching
- **Three-tier configuration system** (profile → session → command-line)
- `isync session set --library=LIB --srcfile=FILE` - Set persistent session context
- `isync session show` - Display current context with all configuration levels
- `--library=LIB` and `--srcfile=FILE` command-line flags for one-time overrides
- Session context stored in `~/.ibmi/sessions/<profile>.session`

#### Password Caching
- **FTP password caching** for 4 hours to eliminate repeated prompts
- Per-profile cache stored in `~/.ibmi/.ftp_password_cache.<profile>`
- Secure file permissions (600)
- Auto-clear on authentication failure (error 67)
- Cache created automatically on first successful FTP operation

#### Member Management
- **`isync member create <member> [srctype]`** - Create new members via FTP RCMD
- Default source type: TXT
- Supports all IBM i source types (RPGLE, CLLE, SQL, etc.)
- No SSH session required for member creation

#### Smart File Extensions
- **Automatic file extension detection** based on source file name
- Extension mappings:
  - QRPGLESRC → `.rpgle`
  - QRPGSRC → `.rpg`
  - QCLLESRC → `.clle`
  - QCLSRC → `.clp`
  - QCMDSRC → `.cmd`
  - QDDSSRC → `.dds`
  - QSQLSRC → `.sql`
  - SQLDMLSRC → `.sqldml`
  - SQLINDSRC → `.txt`
  - SQLTBLSRC → `.txt`
  - Default → `.txt`
- Push operation finds files with any extension automatically

#### CCSID Conversion
- **Automatic ASCII/EBCDIC conversion** using FTP ASCII mode
- `--use-ascii` flag for member pull operations
- `--use-ascii` flag for member push operations
- Proper character encoding for IBM i (EBCDIC) ↔ Local (ASCII/UTF-8)
- Line ending conversion (CRLF ↔ LF) handled automatically

#### Enhanced Features
- **URL encoding** for special characters in library names (# → %23)
- **Enhanced error messages** with actionable guidance
- **Session context display** showing profile defaults, session overrides, and effective values
- Support for libraries with special characters (e.g., O#00729201)

### Changed
- Member push now uses ASCII mode instead of binary for proper CCSID conversion
- Member pull uses ASCII mode for EBCDIC→ASCII conversion
- Member push finds files with any extension (not just .rpgle)
- Improved error messages for member creation and push operations
- Session file format updated to include library and srcfile context

### Fixed
- **CCSID corruption issue** - Files uploaded in ASCII mode now convert properly to EBCDIC
- **Multiple password prompts** - Password now cached for 4 hours
- **Member push errors** - Clear error messages when member doesn't exist
- **File extension hardcoding** - Extensions now determined by source file type
- **Special characters in library names** - URL encoding handles # and other characters
- FTP error 426 (data connection closed) - Members must be created before pushing

### Documentation
- Updated README.md with comprehensive feature documentation
- Added Library/Srcfile Context Switching section
- Added Character Set Conversion (CCSID) section
- Added troubleshooting for member push issues
- Added FEATURES.md with detailed feature descriptions
- Updated version history in README.md
- Added performance tips for password caching and context switching
- Enhanced examples with context switching workflows

---

## [1.0.0] - 2026-01-23

### Initial Release

#### Core Features
- Unified member and file synchronization
- SSH ControlMaster for persistent sessions
- Multi-profile support
- Git integration
- Cross-platform support (WSL, macOS, Linux)

#### Member Operations
- `member pull` - Download members from IBM i
- `member push` - Upload members to IBM i
- `member sync` - Upload and compile in one step
- `member compile` - Compile members on IBM i
- `member list` - List all members in source file
- `member pull-all` - Download all members
- `member info` - Show member information
- `member search` - Search for members
- `member compare` - Compare local vs remote
- `member delete` - Delete members

#### File Operations
- `file pull` - Download files from IFS
- `file push` - Upload files to IFS
- `file list` - List directory contents
- `folder pull` - Download folders recursively
- `folder push` - Upload folders recursively
- `folder sync` - Bidirectional folder sync

#### Session Management
- `session start` - Start SSH ControlMaster session
- `session status` - Show active sessions
- `session stop` - Stop specific session
- `session stop-all` - Stop all sessions
- 4-hour persistent connections
- Automatic reconnection on failure

#### Profile Management
- `profile list` - List all profiles
- `profile create` - Create new profile interactively
- `profile switch` - Switch default profile
- `profile edit` - Edit profile configuration
- `profile delete` - Delete profile
- `profile test` - Test connection
- YAML-based configuration

#### Git Integration
- `git init` - Initialize repository
- `git status` - Show Git status
- `git commit` - Commit changes
- `git push` - Push to remote
- `git pull` - Pull from remote
- `git log` - Show commit history
- `git diff` - Show changes

#### Configuration
- `config init` - Initialize configuration
- `config edit` - Edit configuration file
- `config show` - Display configuration
- `config validate` - Validate configuration
- YAML configuration format
- Per-profile settings

---

## Migration Guide

### From v1.0.0 to v1.1.0

#### Password Prompts
**Before:**
```bash
isync member pull <Member1>  # Password prompt 1
isync member pull <Member2>  # Password prompt 2
isync member push <Member1>  # Password prompt 3
```

**After:**
```bash
isync member pull <Member1>  # Password prompt (cached)
isync member pull <Member2>  # No prompt (uses cache)
isync member push <Member1>  # No prompt (uses cache)
```

#### Library Switching
**Before:**
```bash
# Edit ~/.ibmi/config.yaml
# Change library: "OLDLIB" to library: "NEWLIB"
# Save and exit
isync member pull PROG
```

**After:**
```bash
isync session set --library=NEWLIB
isync member pull <Member>
```

#### Creating Members
**Before:**
```bash
# 1. Log into 5250 or ACS
# 2. ADDPFM FILE(LIB/SRCFILE) MBR(<NewMember>)
# 3. Exit
# 4. isync member push <NewMember>
```

**After:**
```bash
isync member create <NewMember>
isync member push <NewMember>
```

#### File Extensions
**Before:**
```bash
isync member pull CLIPROG  # Saves as CLIPROG.rpgle (wrong!)
```

**After:**
```bash
isync member pull CLIPROG  # Saves as CLIPROG.clle (correct!)
```

---

## Breaking Changes

### None in v1.1.0
All changes are backward compatible. Existing configurations and workflows continue to work.

---

## Known Issues

### v1.1.0
- SSH session may timeout with error on some configurations (use direct SSH as fallback)
- Member list command may fail if source file is very large (>10,000 members)
- FTP passive mode required - active mode not supported

### Workarounds
- For SSH timeout: Tool automatically falls back to direct SSH
- For large source files: Use `member search` with pattern instead of `member list`
- For FTP mode: Ensure firewall allows passive FTP connections

---

## Upgrade Instructions

### From v1.0.0 to v1.1.0

1. **Pull latest code:**
   ```bash
   cd IBMi_Tools/ibmi-sync
   git pull origin main
   ```

2. **Reinstall:**
   ```bash
   ./install.sh
   ```

3. **Verify installation:**
   ```bash
   isync version
   # Should show: IBM i Unified Sync Tool v1.1.0
   ```

4. **Test new features:**
   ```bash
   isync session show
   isync member create TESTPROG
   isync member push TESTPROG
   ```

5. **No configuration changes required** - existing profiles work as-is

---

## Future Roadmap

### v1.2.0 (Planned)
- Member templates for common source types
- Batch member creation
- Auto-sync on file save (watch mode)
- Enhanced diff and merge tools
- Member backup/restore functionality

### v1.3.0 (Planned)
- Web UI for configuration and monitoring
- REST API for integration with other tools
- Webhook support for CI/CD pipelines
- Advanced search with filters
- Member dependency analysis

---

## Credits

**Contributors:**
- Core development and features
- Testing and feedback from IBM i developers
- Community contributions and bug reports

**Special Thanks:**
- Follett Higher Education for sponsoring development
- IBM i community for feature requests and testing

---

## Links

- **Repository:** https://github.com/msasikumar/IBMi_Tools
- **Issues:** https://github.com/msasikumar/IBMi_Tools/issues
- **Documentation:** See README.md in ibmi-sync directory
- **Feature Guide:** See FEATURES.md in ibmi-sync directory

---

**Note:** This changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.
