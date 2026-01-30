# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Proxmox Scripts
- **openclaw-vm-create.sh** - Create Debian 13 VMs on Proxmox VE
  - Downloads official Debian 13 cloud image
  - Interactive and non-interactive modes
  - Configurable: VM ID, hostname, CPU, RAM, disk, storage, network, VLAN
  - Machine type selection (i440fx/q35)
  - CPU type selection (kvm64/host)
  - Cloud-init support for easy provisioning
  - Automatic VM startup and IP detection
  - Instructions for running OpenClaw setup inside VM

## [1.0.0] - 2026-01-30

### Added

#### Setup Scripts
- **openclaw-prep.sh** - Prepare Linux systems for OpenClaw installation
  - Node.js installation (nvm or NodeSource)
  - pnpm installation (corepack or standalone)
  - Build tools and CLI utilities
  - Optional Homebrew installation
  - Multi-distro support (Debian/Ubuntu/Fedora/Arch)

- **openclaw-vm-setup.sh** - Fresh Debian Trixie VM setup
  - Desktop environment selection (XFCE4/GNOME/KDE/LXQt/None)
  - Package groups with individual prompts
  - User creation and sudo configuration
  - OpenClaw installation and onboarding
  - Gateway service setup

#### Migration Scripts
- **openclaw-migrate.sh** - Migrate existing OpenClaw installations
  - Auto-detection of OpenClaw installations
  - User account renaming
  - Merge to existing user option
  - Legacy name migration (moltbot/clawdbot/clawd → openclaw)
  - Workspace standardization
  - Systemd service migration
  - Shell config updates
  - Crontab migration
  - Backward compatibility symlinks

- **openclaw-post-migrate.sh** - Finalize migration
  - Account verification
  - OpenClaw reinstallation via pnpm
  - Gateway daemon setup
  - Optional old user removal

### Features
- Dry-run mode for all scripts
- Non-interactive mode for automation
- Color-coded output (errors, warnings, prompts)
- curl|bash compatible (reads prompts from /dev/tty)
- Idempotent operations where possible

[Unreleased]: https://github.com/seanford/openclaw-helper-scripts/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/seanford/openclaw-helper-scripts/releases/tag/v1.0.0
