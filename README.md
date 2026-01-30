# OpenClaw Helper Scripts

A collection of utility scripts for [OpenClaw](https://github.com/openclaw/openclaw) installations.

## Scripts

| Script | Description |
|--------|-------------|
| `openclaw-prep.sh` | Prepare a Linux system for OpenClaw installation (run BEFORE install) |
| `openclaw-vm-setup.sh` | Set up a fresh Debian Trixie VM with OpenClaw |
| `openclaw-migrate.sh` | Migrate/rename users, update paths, standardize layouts |

---

## openclaw-prep.sh

Prepare a Debian/Ubuntu system for OpenClaw installation. Run this **before** `pnpm add -g openclaw`.

### Quick Start

#### One-liner (download and run interactively)

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-prep.sh | bash
```

#### Non-interactive with defaults

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-prep.sh | bash -s -- --non-interactive
```

#### Dry-run preview

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-prep.sh | bash -s -- --dry-run
```

### What It Installs

- **Node.js LTS** — via nvm (recommended) or NodeSource repository
- **pnpm** — via corepack (recommended) or standalone installer
- **git** — for version control
- **Build tools** — build-essential, python3, gcc, make (for native modules)
- **CLI tools** — jq, ripgrep, tmux, curl, wget, unzip
- **Linuxbrew/Homebrew** — optional, prompt to install
- **~/.local/bin** — added to PATH if not present

### Features

- **Idempotent** — safe to re-run; skips already-installed components
- **Interactive or scripted** — prompts for choices or use CLI flags
- **Dry-run mode** — preview all changes before executing
- **curl|bash compatible** — reads prompts from /dev/tty
- **Works as user or root** — uses sudo when needed

### Usage

```
Usage: openclaw-prep.sh [OPTIONS]

OPTIONS:
  --dry-run                 Show what would be done without making changes
  --non-interactive         Run without prompts (uses sensible defaults)
  
  Node.js installation method:
  --node-nvm                Install Node.js via nvm (recommended)
  --node-nodesource         Install Node.js via NodeSource repository
  --node-skip               Skip Node.js installation
  
  pnpm installation method:
  --pnpm-corepack           Install pnpm via corepack (recommended)
  --pnpm-standalone         Install pnpm via standalone installer
  --pnpm-skip               Skip pnpm installation
  
  Optional components:
  --homebrew                Install Linuxbrew/Homebrew
  --no-homebrew             Skip Homebrew installation
  --build-tools             Install build tools
  --no-build-tools          Skip build tools installation
  
  --help, -h                Show this help message
  --version                 Show version
```

### Examples

```bash
# Interactive mode (recommended)
./openclaw-prep.sh

# Non-interactive with all defaults (nvm + corepack, no homebrew)
./openclaw-prep.sh --non-interactive

# Specific choices
./openclaw-prep.sh --node-nvm --pnpm-corepack --no-homebrew --build-tools

# NodeSource instead of nvm
./openclaw-prep.sh --node-nodesource --pnpm-corepack
```

### After Running

```bash
# 1. Reload shell configuration
source ~/.bashrc

# 2. Install OpenClaw
pnpm add -g openclaw

# 3. Run onboarding
openclaw onboard
```

---

## openclaw-vm-setup.sh

Set up a fresh Debian Trixie (13) VM with OpenClaw and an optional XFCE4 desktop environment.

### Quick Start

#### One-liner (download and run)

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-vm-setup.sh | sudo bash
```

#### Dry-run first

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-vm-setup.sh | sudo bash -s -- --dry-run
```

### Features

- **Interactive or scripted** — prompts for choices or use CLI flags
- **Dry-run mode** — preview all changes before executing
- **User creation** — creates a non-root user for OpenClaw (defaults to hostname)
- **Full prerequisites** — installs Node.js, pnpm, git, and CLI tools
- **OpenClaw install** — installs OpenClaw globally via pnpm
- **Onboarding** — runs `openclaw onboard` to configure API keys
- **Systemd service** — sets up the gateway as a user service
- **Desktop optional** — XFCE4 desktop for GUI access
- **Idempotent** — can be re-run safely

### Usage

```
Usage: openclaw-vm-setup.sh [OPTIONS]

Set up a fresh Debian Trixie VM with OpenClaw and optional XFCE4 desktop.

OPTIONS:
  --dry-run                 Show what would be done without making changes
  --non-interactive         Run without prompts (uses defaults)
  
  --user <name>             Username for OpenClaw (default: hostname)
  
  --desktop                 Install XFCE4 desktop environment
  --no-desktop              Don't install desktop (headless server)
  
  --passwordless-sudo       Configure passwordless sudo for user
  --no-passwordless-sudo    Require password for sudo (default)
  
  --help, -h                Show this help message
  --version                 Show version
```

### Examples

#### Interactive mode (recommended for first-time users)

```bash
sudo bash openclaw-vm-setup.sh
```

#### Preview changes (dry-run)

```bash
sudo bash openclaw-vm-setup.sh --dry-run
```

#### Headless server setup

```bash
sudo bash openclaw-vm-setup.sh --user myagent --no-desktop --non-interactive
```

#### Full desktop setup

```bash
sudo bash openclaw-vm-setup.sh --user myagent --desktop --passwordless-sudo
```

### What Gets Installed

#### Base Packages
- **Essential:** curl, wget, git, sudo, ca-certificates, gnupg
- **CLI tools:** jq, ripgrep, tmux, htop, tree, unzip, vim, nano
- **Build tools:** build-essential, python3
- **Networking:** openssh-server, net-tools, dnsutils

#### Node.js Stack
- Node.js 22 (via NodeSource)
- pnpm (global package manager)
- OpenClaw (installed globally)

#### Desktop (Optional)
- XFCE4 desktop environment
- LightDM display manager
- Firefox ESR
- Common fonts

### Post-Setup

After the script completes:

```bash
# 1. Reboot the system
sudo reboot

# 2. SSH as the new user
ssh myagent@YOUR_IP

# 3. Start the gateway
openclaw gateway start

# 4. Verify
openclaw status
```

### Requirements

- Fresh Debian Trixie (13) minimal install
- Root access
- Internet connection
- ~2GB disk space (more with desktop)

---

## openclaw-migrate.sh

Rename users, update paths, standardize directory layouts, and migrate from legacy configurations.

### Quick Start

### One-liner (download and run)

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-migrate.sh | sudo bash -s -- --dry-run
```

Remove `--dry-run` to execute the migration.

### Download first, then run

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-migrate.sh -o openclaw-migrate.sh
chmod +x openclaw-migrate.sh
sudo ./openclaw-migrate.sh --dry-run
```

## Features

- **Interactive or scripted** — prompts for choices or use CLI flags
- **Dry-run mode** — preview all changes before executing
- **User rename** — rename Linux user account and migrate home directory
- **Workspace standardization** — move workspace to `~/.openclaw/workspace`
- **Legacy support** — migrate from moltbot/clawdbot configurations
- **Backward compatibility** — create symlinks so old paths still work
- **Pre-flight checks** — validate disk space, SSH keys, running services
- **Safe** — prompts for VM snapshot before making changes

## Usage

```
Usage: openclaw-migrate.sh [OPTIONS]

Migrate OpenClaw installation - rename user, update paths, standardize layout.

OPTIONS:
  --dry-run                 Show what would be done without making changes
  --non-interactive         Run without prompts (requires explicit options)
  
  --old-user <name>         Current username (default: auto-detect)
  --new-user <name>         New username (required if renaming user)
  
  --rename-user             Rename the Linux user account
  --no-rename-user          Don't rename user (just update configs/paths)
  
  --standardize-workspace   Move workspace to ~/.openclaw/workspace
  --no-standardize-workspace Keep workspace in current location
  
  --migrate-legacy-dirs     Rename .moltbot/.clawdbot to .openclaw
  --no-migrate-legacy-dirs  Keep legacy directory names
  
  --create-symlinks         Create backward compatibility symlinks
  --no-create-symlinks      Don't create symlinks
  
  --help, -h                Show this help message
  --version                 Show version
```

## Examples

### Interactive mode (recommended for first-time users)

```bash
sudo ./openclaw-migrate.sh
```

The script will:
1. Auto-detect your OpenClaw installation
2. Run pre-flight checks
3. Prompt for each migration option
4. Show a summary before executing

### Preview changes (dry-run)

```bash
sudo ./openclaw-migrate.sh --dry-run
```

### Rename user with full migration

```bash
sudo ./openclaw-migrate.sh \
    --old-user moltbot \
    --new-user k2so \
    --rename-user \
    --standardize-workspace \
    --create-symlinks
```

### Update configs only (no user rename)

```bash
sudo ./openclaw-migrate.sh \
    --old-user moltbot \
    --no-rename-user \
    --standardize-workspace
```

### Non-interactive (for automation/CI)

```bash
sudo ./openclaw-migrate.sh --non-interactive \
    --old-user moltbot \
    --new-user myagent \
    --rename-user \
    --standardize-workspace \
    --create-symlinks
```

## What Gets Migrated

### User Rename (optional)
- Linux user account name
- Primary group name
- Home directory location (`/home/old` → `/home/new`)
- Sudoers configuration

### Configuration Updates
- `~/.openclaw/openclaw.json` — all paths updated
- Legacy configs (`moltbot.json`, `clawdbot.json`) — renamed to `openclaw.json`
- Systemd user services — paths updated
- Shell configs (`.profile`, `.bashrc`, `.zshrc`) — paths updated
- Crontab entries — paths updated

### Directory Migration
- `.moltbot/` → `.openclaw/`
- `.clawdbot/` → `.openclaw/`
- Workspace → `~/.openclaw/workspace` (optional)

### Backward Compatibility Symlinks (optional)
- `/home/olduser` → `/home/newuser`
- `~/.moltbot` → `~/.openclaw`
- `~/.clawdbot` → `~/.openclaw`
- Old workspace path → new workspace path

## Standard Layout

After migration with `--standardize-workspace`:

```
~/.openclaw/
├── openclaw.json        # Gateway configuration
├── agents/              # Agent state and sessions
├── credentials/         # Auth tokens
├── cron/                # Scheduled jobs
├── devices/             # Paired nodes
└── workspace/           # Your AGENTS.md, SOUL.md, memory/, etc.
```

This layout is compatible with:
- Fresh `openclaw onboard` installs
- Docker deployments
- Switching between stable/beta/dev versions
- Future OpenClaw tooling

## Pre-Migration Checklist

Before running the migration:

1. **Create a VM snapshot** — strongly recommended
2. **Note your SSH access** — after user rename, SSH as the new username
3. **Check running services** — the script will stop them automatically
4. **WhatsApp/Discord sessions** — may need re-authentication after migration

## Post-Migration Steps

After user rename:

```bash
# 1. Reboot
sudo reboot

# 2. SSH as new user
ssh newuser@hostname

# 3. Reinstall global packages (fixes hardcoded paths)
pnpm add -g openclaw@latest

# 4. Reinstall gateway daemon
openclaw gateway install --force

# 5. Start and verify
systemctl --user enable --now openclaw-gateway.service
openclaw status
```

After config-only migration:

```bash
# 1. Restart gateway
systemctl --user restart openclaw-gateway.service

# 2. Verify
openclaw status
```

## Multi-Agent Setup

To run separate OpenClaw agents (e.g., for family members):

1. Clone your VM
2. Boot the clone
3. Change hostname: `sudo hostnamectl set-hostname <agent-name>`
4. Run this migration script to rename the user
5. Run `openclaw onboard` for fresh setup

Each VM gets its own identity, messaging accounts, and workspace.

## Troubleshooting

### "User already exists"
The target username is already taken. Choose a different name.

### "Cannot run while logged in as X"  
SSH as root directly, or use VM console. The script cannot rename a user while processes are running as that user.

### Services don't start after migration
Run `openclaw gateway install --force` to regenerate service files.

### WhatsApp/Discord not working
Run `openclaw configure` to re-authenticate messaging channels.

## Requirements

- Linux (Debian/Ubuntu tested, should work on other distros)
- Root access (sudo)
- Bash 4.0+
- Standard utilities: `sed`, `grep`, `find`, `usermod`, `groupmod`

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

Issues and PRs welcome at [github.com/seanford/openclaw-helper-scripts](https://github.com/seanford/openclaw-helper-scripts)

## Related

- [OpenClaw](https://github.com/openclaw/openclaw) — The AI agent framework
- [OpenClaw Docs](https://docs.openclaw.ai) — Official documentation
- [OpenClaw Discord](https://discord.com/invite/clawd) — Community
# Fri Jan 30 18:14:19 UTC 2026
