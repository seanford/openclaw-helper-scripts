# OpenClaw Helper Scripts

A collection of utility scripts for [OpenClaw](https://github.com/openclaw/openclaw) installations.

## Scripts

| Script | Description |
|--------|-------------|
| `openclaw-migrate.sh` | Migrate/rename users, update paths, standardize layouts |

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
