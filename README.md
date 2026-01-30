# OpenClaw Helper Scripts

A collection of utility scripts for [OpenClaw](https://github.com/openclaw/openclaw) installations.

## Quick Links

| Category | Scripts | Description |
|----------|---------|-------------|
| [**Setup**](setup/) | `openclaw-prep.sh`, `openclaw-vm-setup.sh` | Fresh installations |
| [**Migration**](migration/) | `openclaw-migrate.sh`, `openclaw-post-migrate.sh` | Existing installations |

---

## Setup Scripts

For **new installations** — preparing a system or VM for OpenClaw.

### [openclaw-prep.sh](setup/openclaw-prep.sh)

Prepare a Linux system for OpenClaw. Run **before** `pnpm add -g openclaw`.

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-prep.sh | bash
```

Installs: Node.js, pnpm, git, build tools, CLI utilities, optional Homebrew.

### [openclaw-vm-setup.sh](setup/openclaw-vm-setup.sh)

Set up a fresh Debian Trixie VM with OpenClaw and optional desktop.

```bash
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-vm-setup.sh | sudo bash
```

Features: Desktop selection (XFCE4/GNOME/KDE/LXQt/None), package groups, user setup, OpenClaw install.

📖 [Full setup documentation](setup/README.md)

---

## Migration Scripts

For **existing installations** — renaming users, updating paths, migrating from legacy configs.

### [openclaw-migrate.sh](migration/openclaw-migrate.sh)

Migrate an OpenClaw installation: rename users, update paths, standardize layouts.

```bash
# Run as root
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/migration/openclaw-migrate.sh | sudo bash -s -- --dry-run
```

Features: Auto-detection, user rename, merge to existing user, legacy migration (moltbot/clawdbot), symlinks.

### [openclaw-post-migrate.sh](migration/openclaw-post-migrate.sh)

Finalize migration: reinstall OpenClaw, set up gateway service.

```bash
# Run as the NEW user (not root)
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/migration/openclaw-post-migrate.sh | bash
```

Features: Account verification, pnpm reinstall, gateway setup, optional old user removal.

📖 [Full migration documentation](migration/README.md)

---

## Common Options

All scripts support:

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without executing |
| `--non-interactive` | Use defaults, no prompts |
| `--help` | Show usage information |
| `--version` | Show script version |

---

## Color Coding

Scripts use consistent color coding:

| Color | Meaning |
|-------|---------|
| 🔴 Red | Errors, failures |
| 🟢 Green | Success, confirmations |
| 🟡 Yellow | Warnings, caution |
| 🔵 Blue | Section headers, steps |
| 🔷 Cyan | Highlights, values |
| 🟣 Magenta | User prompts (needs input) |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Credits

Created by [Sean Ford](https://github.com/seanford) with [OpenClaw](https://github.com/openclaw/openclaw) + [Claude](https://www.anthropic.com/claude) (Anthropic's claude-opus-4-5 model).

## License

[MIT](LICENSE)

## Links

- [OpenClaw](https://github.com/openclaw/openclaw) — The AI agent framework
- [OpenClaw Docs](https://docs.openclaw.ai) — Official documentation
- [OpenClaw Discord](https://discord.com/invite/clawd) — Community
