# Migration Scripts

Scripts for migrating existing OpenClaw installations.

## Scripts

| Script | Description |
|--------|-------------|
| [`openclaw-migrate.sh`](openclaw-migrate.sh) | Migrate/rename users, update paths, standardize layouts |
| [`openclaw-post-migrate.sh`](openclaw-post-migrate.sh) | Finalize migration: reinstall OpenClaw, set up gateway |

---

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Run openclaw-migrate.sh as ROOT                         │
│     (Renames user, updates configs, creates symlinks)       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Reboot (if user was renamed)                            │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Run openclaw-post-migrate.sh as NEW USER                │
│     (Reinstalls OpenClaw, sets up gateway service)          │
└─────────────────────────────────────────────────────────────┘
```

---

## openclaw-migrate.sh

Rename users, update paths, standardize directory layouts, and migrate from legacy configurations (moltbot, clawdbot).

### Quick Start

**Must run as root** (SSH as root or use VM console):

```bash
# Interactive with dry-run preview
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/migration/openclaw-migrate.sh | sudo bash -s -- --dry-run

# Interactive (actual migration)
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/migration/openclaw-migrate.sh | sudo bash
```

### Features

- **Auto-detection**: Finds OpenClaw installation automatically
- **User rename**: Renames Linux user account and home directory
- **Merge to existing**: Can migrate configs to an existing user
- **Legacy support**: Migrates from moltbot/clawdbot configurations
- **Path updates**: Updates all config files, services, crontabs
- **Workspace standardization**: Moves workspace to `~/.openclaw/workspace`
- **Symlinks**: Creates backward compatibility symlinks
- **Shell setup**: Adds PATH and aliases to shell config

### Options

```
--dry-run                   Preview without making changes
--non-interactive           Use auto-detection and defaults

--old-user <name>           Current username (default: auto-detect)
--new-user <name>           New username

--rename-user               Rename the Linux user account
--no-rename-user            Don't rename user

--standardize-workspace     Move workspace to ~/.openclaw/workspace
--no-standardize-workspace  Keep workspace in current location

--create-symlinks           Create backward compatibility symlinks
--no-create-symlinks        Don't create symlinks

--setup-shell               Add PATH and aliases to shell config
--no-setup-shell            Don't modify shell config
```

### What Gets Updated

| Location | Changes |
|----------|---------|
| **User account** | Renamed via `usermod`, group renamed |
| **Home directory** | Moved to `/home/<newuser>` |
| **Config files** | Paths updated in `openclaw.json`, etc. |
| **Systemd services** | Files renamed, paths updated |
| **Shell configs** | Paths and commands updated |
| **Crontab** | Paths and commands updated |
| **Workspace files** | Paths in markdown files updated |

---

## openclaw-post-migrate.sh

Run after migration to finalize the setup. Reinstalls OpenClaw (fixes hardcoded paths) and sets up the gateway service.

### Quick Start

**Must run as the NEW user** (not root):

```bash
# Standard
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/migration/openclaw-post-migrate.sh | bash

# With old user cleanup
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/migration/openclaw-post-migrate.sh | bash -s -- --remove-old-user moltbot

# Dry-run preview
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/migration/openclaw-post-migrate.sh | bash -s -- --dry-run
```

### What It Does

1. **Verifies** you're in the correct account (checks for `.openclaw/`)
2. **Reinstalls OpenClaw** via pnpm (fixes hardcoded paths)
3. **Installs gateway daemon** with `openclaw gateway install --force`
4. **Enables lingering** for background services
5. **Starts gateway service**
6. **Verifies** installation with `openclaw status`
7. **Optionally removes** old user account

### Options

```
--dry-run                   Preview without making changes
--skip-reinstall            Skip pnpm reinstall
--skip-gateway              Skip gateway daemon setup
--skip-verify               Skip verification
--configure                 Run 'openclaw configure' for channel re-auth
--remove-old-user <name>    Remove old user account after verification
```

### When to Run

| Migration Type | When to Run Post-Migrate |
|----------------|--------------------------|
| User renamed | After reboot, logged in as new user |
| Merged to existing user | Immediately, logged in as target user |
| No user change | Immediately (optional, for verification) |

---

## Troubleshooting

### "Cannot run while logged in as X"
SSH as root directly, or use VM console. The migrate script cannot rename a user while processes are running as that user.

### Services don't start after migration
Run `openclaw gateway install --force` to regenerate service files.

### WhatsApp/Discord not working
Run `openclaw configure` to re-authenticate messaging channels.

### "No OpenClaw installation found"
Make sure you're logged into the correct (new) user account, not the old one or root.
