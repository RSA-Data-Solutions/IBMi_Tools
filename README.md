# IBM i Tools — IBM i Sync (`ibmi-sync` / `isync`)

**Copyright (c) 2024-2026 RSA Data Solutions Inc. All Rights Reserved.**
**Author**: Sasikumar Manickam
**License**: Proprietary (see [LICENSE](LICENSE))

⚠️ This is proprietary commercial software. Unauthorized use, reproduction, or distribution is prohibited.

---

`ibmi-sync` (short name `isync`) keeps your IBM i source and IFS files in step with a local folder, so you can
edit with VS Code or AI tools and use Git:

- **Members** (library / source file / member): pull, push, compile, create, compare, list, search.
  Transfers use the IBM i **FTP** server, which converts EBCDIC ↔ ASCII for you.
- **IFS files and folders**: pull, push and sync over **SSH**.
- **Git**: init, commit, push, pull, log and diff for the synced folder.

It is one bash tool that runs on **Windows 11** (including **Azure Virtual Desktop**) through Git Bash, and on
**macOS** and **Linux** natively.

| | Windows 11 / Azure Virtual Desktop | macOS | Linux |
|---|---|---|---|
| Shell | Git Bash, from Git for Windows | Terminal (zsh or bash, 3.2+) | bash |
| Run from | Git Bash, **PowerShell**, cmd.exe | Terminal | Terminal |
| Needs admin rights | No | No | No |
| Folder sync | tar over SSH (rsync not needed) | rsync if both sides have it, else tar | same as macOS |

---

## Requirements

### On the IBM i

- **SSH server** running: `STRTCPSVR SERVER(*SSHD)`. Used for IFS files, folders and compiles.
- **FTP server** running: `STRTCPSVR SERVER(*FTP)`. Used for member transfers.
- Your user profile can log in over SSH and FTP and has authority to your libraries and IFS folders.
- Optional: `rsync` (`yum install rsync`). It is found in `/QOpenSys/pkgs/bin` even if that is not on your
  PATH. Without it, folder sync uses `tar`, which every IBM i has.

### Network (important on Azure Virtual Desktop)

From the machine you work on (for AVD, the **session hosts**), the IBM i must be reachable on:

| Port | Used for |
|---|---|
| TCP 22 | SSH: files, folders, compile, sessions |
| TCP 21 **and the IBM i FTP passive port range** | Member pull / push |

On AVD these usually have to be allowed in the Network Security Group / Azure Firewall / on-premises firewall.
FTP sends your password unencrypted, so use it only over a trusted network or VPN.

---

## Install on Windows 11 / Azure Virtual Desktop

Everything installs into your own user profile. **No administrator rights are needed**, which matters on locked-down
AVD session hosts.

1. **Install Git for Windows** from <https://git-scm.com/download/win>.
   - Without admin rights, choose **"Install only for me"** (it installs under `%LOCALAPPDATA%\Programs\Git`).
     Your IT team can also deploy it to the AVD image.
   - Keep the defaults. They include Git Bash, `ssh`, `scp`, `curl` and `tar`, which is everything the tool uses.
2. **Open "Git Bash"** from the Start menu.
3. **Clone the repository.** Use `git clone`, not a ZIP download: the repository's `.gitattributes` keeps the
   scripts' line endings correct, and a ZIP does not.
   ```bash
   git clone https://github.com/RSA-Data-Solutions/IBMi_Tools.git
   cd IBMi_Tools/ibmi-sync
   ./install.sh
   ```
   The installer:
   - copies the tool to `~/bin` (`C:\Users\<you>\bin`) and its libraries to `~/.local/bin/ibmi-sync`;
   - adds `ibmi-sync.cmd` and `isync.cmd` launchers so the tool also runs from **PowerShell** and **cmd.exe**;
   - adds `C:\Users\<you>\bin` to your **Windows user PATH**. If PowerShell is restricted by policy it uses
     `reg.exe`; if both are blocked it prints the folder to add by hand;
   - adds `~/bin` to Git Bash's PATH (`~/.bashrc`, plus a `~/.bash_profile` that loads it).
4. **Open a new terminal** (Git Bash, PowerShell or Windows Terminal) and check:
   ```powershell
   isync version
   ```
5. **Set up an SSH key** (see [SSH key](#ssh-key-recommended-required-to-avoid-repeated-passwords-on-windows))
   and **create your profile** (see [Configure](#configure)).

### How it works on Windows

- `isync` in PowerShell or cmd runs `isync.cmd`, which starts the same bash script with Git Bash's `bash.exe`.
  The launcher finds Git in the usual places (`Program Files`, `%LOCALAPPDATA%\Programs`, Scoop, or next to
  `git.exe` on your PATH). It never uses `C:\Windows\System32\bash.exe`, which is WSL. If Git is somewhere else,
  set `IBMI_SYNC_BASH` to the full path of `Git\bin\bash.exe`.
- `~` means `C:\Users\<you>`. The configuration is in `C:\Users\<you>\.ibmi\config.yaml`; synced files default
  to `C:\Users\<you>\ibmi-sync-data\<profile>`.
- **SSH connection sharing is off by default** on Windows: Git Bash's OpenSSH only emulates the Unix sockets that
  OpenSSH connection sharing needs, which is unreliable. Each command opens its own SSH connection instead, so
  use an **SSH key**, or you will type your password for every command.
- **Folder sync uses `tar` over SSH**, because Git Bash has no `rsync`. Nothing extra to install.
- `isync config edit` opens **Notepad** (set `EDITOR` to use something else). Windows line endings in
  `config.yaml` are fine.
- Member transfers keep your FTP password in `~/.ibmi/.ftp_password_cache.<profile>` for 4 hours. Windows
  ignores `chmod 600`, but your profile folder is private to you, including on multi-session AVD hosts.

---

## Install on macOS / Linux

You need `bash`, `ssh`, `scp`, `git`, `curl` and `tar`. macOS has them (Git comes with the Xcode command line
tools: `xcode-select --install`). On Linux, install them with your package manager, e.g.
`sudo apt install git curl openssh-client rsync`. `rsync` is optional.

```bash
git clone https://github.com/RSA-Data-Solutions/IBMi_Tools.git
cd IBMi_Tools/ibmi-sync
./install.sh
source ~/.zshrc        # zsh (the macOS default); bash users: source ~/.bashrc (Linux) or ~/.bash_profile (macOS)
isync version
```

The installer copies the tool to `~/bin` and its libraries to `~/.local/bin/ibmi-sync`, and adds `~/bin` to
your shell's PATH. It writes to `~/.zshrc` for zsh, `~/.bash_profile` for bash on macOS, and `~/.bashrc` for bash
on Linux. It never needs `sudo`.

SSH connection sharing (OpenSSH `ControlMaster`) is on by default on macOS and Linux. `isync session start`
logs in once and later commands reuse that connection for up to 4 hours.

---

## SSH key (recommended; required to avoid repeated passwords on Windows)

Run in Git Bash, or in Terminal on macOS/Linux:

```bash
ssh-keygen -t ed25519                     # press Enter for the defaults
cat ~/.ssh/id_ed25519.pub | ssh MYUSER@my.ibmi.host \
  'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && chmod go-w ~'
ssh MYUSER@my.ibmi.host 'echo ok'         # should not ask for a password
```

The IBM i SSH server ignores keys if your home directory or `.ssh` is writable by others. The `chmod`s above
take care of that. Your IBM i home directory must exist (e.g. `/home/MYUSER`).

You can also use a host alias from `~/.ssh/config` (port, key file, jump host) as the profile's `host`.

---

## Configure

Create a profile interactively:

```bash
isync profile create
```

or edit the file directly with `isync config edit`. It is `~/.ibmi/config.yaml`:

```yaml
default_profile: "production"

profiles:
  production:
    host: "my.ibmi.host"          # or an alias from ~/.ssh/config
    user: "MYUSER"
    library: "MYLIB"
    srcfile: "QRPGLESRC"
    remote_base: "/home/MYUSER"
    local_dir: "~/ibmi-sync-data/production"
    git_repo: ""                  # optional
    git_branch: "main"
    description: "Production IBM i system"

# Optional; these are the defaults
session:
  multiplex: "auto"               # SSH connection sharing: auto (off on Windows, on elsewhere), yes, no
  connect_timeout: 10
  server_alive_interval: 60
  server_alive_count_max: 3
```

Until `host` and `user` are filled in, commands stop with `Profile 'production' has no real host ... Set it
with: ibmi-sync config edit`.

---

## Usage

```bash
isync                                   # interactive menu
isync session start                     # log in (shares the connection where supported)

# Members (library/source file from the profile, or override with --library= / --srcfile=)
isync member pull MYPGM                 # -> ./MYPGM.rpgle in the current folder
isync member push MYPGM                 # creates the member if needed
isync member sync MYPGM                 # push + compile
isync member compile MYPGM
isync member create NEWPGM SQLRPGLE     # type also detected from the file extension (.sqlrpgle, .rpgle, .clle, ...)
isync member list
isync member compare MYPGM

# IFS files and folders (local paths are relative to the profile's local_dir)
isync file pull /home/MYUSER/app/config.json
isync file push config.json /home/MYUSER/app/config.json
isync folder pull /home/MYUSER/app app
isync folder push app /home/MYUSER/app

# Git, in the synced folder
isync git status
isync git commit "Update config" && isync git push

isync session stop
isync help                              # every command and option
```

Useful options: `--profile=NAME`, `--library=LIB`, `--srcfile=FILE`, `--debug`, `--no-color`.

Environment variables:

| Variable | Effect |
|---|---|
| `IBMI_SSH_MUX=0` / `1` | Turn SSH connection sharing off / on (overrides `session.multiplex`) |
| `IBMI_FOLDER_TRANSFER=tar` | Always use tar for folder sync, even when rsync is available |
| `IBMI_SYNC_BASH` | Windows: full path of the `bash.exe` the `.cmd` launchers should use |
| `IBMI_DEBUG=1` | Debug output |

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `$'\r': command not found` or `bad interpreter` | Scripts got Windows line endings, usually from a ZIP download or a clone made before `.gitattributes` existed. Clone again with `git clone`, or in the clone run `git rm -rq --cached . && git reset -q --hard`, then `./install.sh`. |
| PowerShell: `isync : The term 'isync' is not recognized` | Open a **new** window after installing. If it still fails, add `C:\Users\<you>\bin` under Start → "Edit environment variables for your account" → Path. |
| `ibmi-sync: Git Bash was not found` | Install Git for Windows, or set `IBMI_SYNC_BASH` to `...\Git\bin\bash.exe`. |
| Password asked for every command (Windows) | Expected without an SSH key, because connection sharing is off on Windows. Set up an [SSH key](#ssh-key-recommended-required-to-avoid-repeated-passwords-on-windows). |
| `Permission denied (publickey,...)` | Key not in `~/.ssh/authorized_keys` on the IBM i, or home/`.ssh` permissions too open (see SSH key). |
| `Connection timed out` / member pull hangs | Port 22, 21 or the FTP passive ports are blocked (on AVD: NSG / firewall rules). |
| `Could not open a shared SSH connection` | The socket path was too long, or socket support is missing. The tool continues without sharing; set `session.multiplex: "no"` to skip the attempt. |
| `Profile 'x' has no real host` | Fill in `host` / `user` with `isync config edit`. |

---

## Uninstall

```bash
cd IBMi_Tools/ibmi-sync
./uninstall.sh
```

This removes `ibmi-sync`, `isync`, the Windows launchers and the libraries, and takes out the PATH lines the
installer added. It backs up `~/.ibmi` first and asks before deleting your configuration or synced data. On
Windows, `C:\Users\<you>\bin` stays on your user PATH, because other tools may use it.

---

## More documentation

See [`docs/`](docs/): [Getting started](docs/GETTING_STARTED.md), [Features](docs/FEATURES.md),
[Changelog](docs/CHANGELOG.md).

**Repository**: https://github.com/RSA-Data-Solutions/IBMi_Tools ·
**Issues**: https://github.com/RSA-Data-Solutions/IBMi_Tools/issues
