# Proxmox Scripts

Scripts for creating and managing OpenClaw VMs on Proxmox VE.

## Scripts

### `openclaw-vm-create.sh`

Creates a Debian 13 (Trixie) VM on Proxmox VE with optional OpenClaw configuration.

**Requirements:**
- Proxmox VE 8.x or 9.x
- Run as root on the Proxmox host
- Internet connection (downloads Debian cloud image)

**Features:**
- Downloads official Debian 13 cloud image
- Interactive or non-interactive mode
- Configurable: CPU, RAM, disk, network, VLAN
- Cloud-init support for easy provisioning
- Automatic VM startup and IP detection
- Instructions to run OpenClaw setup script

### Quick Start

```bash
# Interactive mode (recommended for first use)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/proxmox/openclaw-vm-create.sh)"

# Non-interactive with defaults (4 cores, 4GB RAM, 64GB disk)
curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/proxmox/openclaw-vm-create.sh | bash -s -- --non-interactive

# Custom configuration
curl -fsSL ... | bash -s -- --hostname myvm --cores 8 --memory 8192 --disk 64G
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--vmid ID` | VM ID | auto |
| `--hostname NAME` | VM hostname | `openclaw` |
| `--cores N` | CPU cores | `4` |
| `--memory N` | RAM in MiB | `4096` |
| `--disk SIZE` | Disk size | `64G` |
| `--storage NAME` | Storage pool | auto-detect |
| `--bridge NAME` | Network bridge | `vmbr0` |
| `--vlan TAG` | VLAN tag | none |
| `--machine TYPE` | `i440fx` or `q35` | `i440fx` |
| `--cpu TYPE` | `kvm64` or `host` | `kvm64` |
| `--no-cloudinit` | Use nocloud image | - |
| `--no-start` | Don't start after creation | - |
| `--no-setup` | Don't show setup instructions | - |
| `--non-interactive` | Use defaults, no prompts | - |
| `--dry-run` | Show what would be done | - |

### After VM Creation

The VM boots with a Debian cloud image. To complete OpenClaw setup:

1. Access the VM console:
   ```bash
   qm terminal <VMID>
   ```

2. Log in (cloud-init defaults vary, often `debian`/`debian` or `root` with no password)

3. Run the OpenClaw setup script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-vm-setup.sh | sudo bash
   ```

### Cloud-Init Configuration

For automated provisioning, configure cloud-init before starting the VM:

```bash
# Set user credentials
qm set <VMID> --ciuser openclaw --cipassword 'yourpassword'

# Or use SSH keys
qm set <VMID> --ciuser openclaw --sshkeys ~/.ssh/id_ed25519.pub

# Set static IP (optional)
qm set <VMID> --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1

# Regenerate cloud-init drive
qm cloudinit update <VMID>
```

## Future Scripts

- **LXC container creation** — lightweight alternative to VMs
- **Bulk provisioning** — create multiple VMs from a config file
- **Backup/restore utilities** — automated snapshots and migrations
