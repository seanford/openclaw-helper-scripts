# Setup Scripts

Scripts for fresh OpenClaw installations.

## Scripts

| Script | Description |
|--------|-------------|
| [`openclaw-prep.sh`](openclaw-prep.sh) | Prepare a Linux system for OpenClaw (run BEFORE install) |
| [`openclaw-vm-setup.sh`](openclaw-vm-setup.sh) | Set up a fresh Debian Trixie VM with OpenClaw |

---

## openclaw-prep.sh

Prepare a Debian/Ubuntu/Fedora/Arch system for OpenClaw installation. Run this **before** `pnpm add -g openclaw`.

### Quick Start

```bash
# Interactive
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-prep.sh | bash

# Non-interactive with defaults
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-prep.sh | bash -s -- --non-interactive

# Dry-run preview
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-prep.sh | bash -s -- --dry-run
```

### What It Installs

- **Node.js** (via nvm or NodeSource)
- **pnpm** (via corepack or standalone)
- **git**
- **Build tools** (build-essential, gcc, make, etc.)
- **CLI utilities** (jq, ripgrep, tmux, curl, wget, etc.)
- **Homebrew** (optional)

### Options

```
--dry-run              Preview without making changes
--non-interactive      Use defaults, no prompts
--node-method <nvm|nodesource>
--skip-node            Skip Node.js installation
--skip-pnpm            Skip pnpm installation
--skip-build-tools     Skip build tools
--skip-cli-tools       Skip CLI utilities
--with-homebrew        Install Homebrew
--no-homebrew          Skip Homebrew
```

---

## openclaw-vm-setup.sh

Set up a fresh Debian Trixie VM with OpenClaw and optional desktop environment.

### Quick Start

```bash
# Interactive
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-vm-setup.sh | sudo bash

# Dry-run preview
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-vm-setup.sh | sudo bash -s -- --dry-run
```

### Features

- **Desktop selection**: XFCE4, GNOME, KDE Plasma, LXQt, or None (headless)
- **Package groups** (prompted individually):
  - Browser & Web Tools (Chromium, Firefox)
  - Python Development (python3, uv)
  - Build Tools (gcc, make, etc.)
  - Node.js Extras (node-gyp prerequisites)
  - CLI Productivity (jq, ripgrep, tmux, etc.)
  - Media Tools (ffmpeg, imagemagick)
- **User setup**: Creates non-root user, configures sudo
- **OpenClaw**: Installs via pnpm, runs onboarding, sets up gateway service

### Options

```
--dry-run              Preview without making changes
--non-interactive      Use defaults, no prompts
--user <name>          Username to create (default: hostname)
--desktop <xfce4|gnome|kde|lxqt|none>
--passwordless-sudo    Enable passwordless sudo
--with-browser         Install browser packages
--with-python          Install Python + uv
--with-build           Install build tools
--with-cli             Install CLI tools
--with-media           Install media tools
```

---

## After Setup

Once setup completes, install OpenClaw:

```bash
pnpm add -g openclaw
openclaw onboard
```

Then start the gateway:

```bash
openclaw gateway install
systemctl --user enable --now openclaw-gateway.service
openclaw status
```
