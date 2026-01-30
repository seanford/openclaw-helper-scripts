#!/usr/bin/env bash
#
# openclaw-vm-create.sh
#
# Create a Debian 13 (Trixie) VM on Proxmox and optionally configure it for OpenClaw.
# Modeled after community-scripts/ProxmoxVE with OpenClaw integration.
#
# REQUIREMENTS:
#   - Run on Proxmox VE host (8.x or 9.x)
#   - Run as root
#   - Internet connection
#
# USAGE:
#   # Interactive
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/proxmox/openclaw-vm-create.sh)"
#
#   # Non-interactive with defaults
#   curl -fsSL ... | bash -s -- --non-interactive --hostname openclaw --start
#
# LICENSE: MIT
#
set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="openclaw-vm-create"

# -----------------------------------------------------------------------------
# Default Configuration
# -----------------------------------------------------------------------------
VMID=""
HOSTNAME="openclaw"
DISK_SIZE="64G"
CORE_COUNT="4"
RAM_SIZE="4096"
BRIDGE="vmbr0"
VLAN=""
MAC=""
STORAGE=""
ISO_STORAGE=""
MACHINE_TYPE="i440fx"  # i440fx or q35
CPU_TYPE="kvm64"       # kvm64 or host
DISK_CACHE=""          # empty or writethrough
USE_CLOUD_INIT="yes"
START_VM="yes"
WAIT_FOR_SSH="yes"
RUN_SETUP="yes"
SETUP_SCRIPT_URL="https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/setup/openclaw-vm-setup.sh"

# Runtime options
DRY_RUN=false
NON_INTERACTIVE=false
VERBOSE=false

# Generated values
GEN_MAC=""
TEMP_DIR=""

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Status indicators
CM="  ✔️  "
CROSS="  ✖️  "
INFO="  💡  "
ROCKET="  🚀  "

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    clear
    cat << 'EOF'
   ____                   ________               
  / __ \____  ___  ____  / ____/ /___ __      __
 / / / / __ \/ _ \/ __ \/ /   / / __ `/ | /| / /
/ /_/ / /_/ /  __/ / / / /___/ / /_/ /| |/ |/ / 
\____/ .___/\___/_/ /_/\____/_/\__,_/ |__/|__/  
    /_/                                          
    VM Creator for Proxmox
EOF
    echo ""
    echo -e "${CYAN}Version ${VERSION}${NC}"
    echo ""
}

msg_info() {
    echo -ne "  ${YELLOW}⏳${NC}  $1"
}

msg_ok() {
    # Clear line and print success (handles variable length messages)
    echo -e "\r\033[K${CM}${GREEN}$1${NC}"
}

msg_error() {
    echo -e "\r${CROSS}${RED}$1${NC}"
}

msg_warn() {
    echo -e "  ${YELLOW}⚠️${NC}  ${YELLOW}$1${NC}"
}

die() {
    msg_error "$1"
    exit 1
}

cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# -----------------------------------------------------------------------------
# Validation Functions
# -----------------------------------------------------------------------------

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "This script must be run as root on the Proxmox host."
    fi
}

check_proxmox() {
    if ! command -v pveversion &>/dev/null; then
        die "This script must be run on a Proxmox VE host."
    fi
    
    local pve_ver
    pve_ver="$(pveversion | awk -F'/' '{print $2}' | awk -F'-' '{print $1}')"
    
    if [[ "$pve_ver" =~ ^8\.([0-9]+) ]]; then
        local minor="${BASH_REMATCH[1]}"
        if ((minor > 9)); then
            die "Unsupported Proxmox VE version. Supported: 8.0-8.9, 9.0-9.1"
        fi
    elif [[ "$pve_ver" =~ ^9\.([0-9]+) ]]; then
        local minor="${BASH_REMATCH[1]}"
        if ((minor > 1)); then
            die "Unsupported Proxmox VE version. Supported: 8.0-8.9, 9.0-9.1"
        fi
    else
        die "Unsupported Proxmox VE version: $pve_ver"
    fi
    
    msg_ok "Proxmox VE $pve_ver detected"
}

check_arch() {
    if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
        die "This script only supports amd64 architecture."
    fi
}

get_next_vmid() {
    local try_id
    try_id=$(pvesh get /cluster/nextid)
    
    while true; do
        if [[ -f "/etc/pve/qemu-server/${try_id}.conf" ]] || [[ -f "/etc/pve/lxc/${try_id}.conf" ]]; then
            try_id=$((try_id + 1))
            continue
        fi
        if lvs --noheadings -o lv_name 2>/dev/null | grep -qE "(^|[-_])${try_id}($|[-_])"; then
            try_id=$((try_id + 1))
            continue
        fi
        break
    done
    
    echo "$try_id"
}

generate_mac() {
    echo "02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')"
}

# -----------------------------------------------------------------------------
# Storage Selection
# -----------------------------------------------------------------------------

select_iso_storage() {
    # Skip if already set via CLI
    if [[ -n "$ISO_STORAGE" ]]; then
        msg_ok "Using ISO storage: $ISO_STORAGE (from CLI)"
        return
    fi
    
    # Select storage for downloading the cloud image (needs directory access)
    local storage_list
    storage_list=$(pvesm status -content iso,images | awk 'NR>1 {print $1}' | sort -u)
    
    if [[ -z "$storage_list" ]]; then
        # Fallback: any storage with a path we can write to
        storage_list=$(pvesm status | awk 'NR>1 && ($2=="dir" || $2=="nfs" || $2=="cifs" || $2=="btrfs") {print $1}')
    fi
    
    if [[ -z "$storage_list" ]]; then
        die "No storage available for downloading images. Need dir/nfs/cifs storage."
    fi
    
    local count
    count=$(echo "$storage_list" | wc -l)
    
    if [[ $count -eq 1 ]]; then
        ISO_STORAGE=$(echo "$storage_list" | head -1)
        msg_ok "Using ISO storage: $ISO_STORAGE"
        return
    fi
    
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        ISO_STORAGE=$(echo "$storage_list" | head -1)
        msg_ok "Using ISO storage: $ISO_STORAGE (auto-selected)"
        return
    fi
    
    echo ""
    echo -e "${CYAN}Available storage for downloading image:${NC}"
    local i=1
    while read -r pool; do
        local info
        info=$(pvesm status -storage "$pool" | awk 'NR>1 {printf "Type: %-10s Free: %s", $2, $6}')
        echo "  $i) $pool ($info)"
        ((i++))
    done <<< "$storage_list"
    echo ""
    
    while true; do
        read -rp "$(echo -e "${MAGENTA}Select ISO/download storage [1]: ${NC}")" choice </dev/tty
        choice=${choice:-1}
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= count)); then
            ISO_STORAGE=$(echo "$storage_list" | sed -n "${choice}p")
            msg_ok "Using ISO storage: $ISO_STORAGE"
            return
        fi
        echo -e "${RED}Invalid selection. Try again.${NC}"
    done
}

select_storage() {
    local storage_list
    storage_list=$(pvesm status -content images | awk 'NR>1 {print $1}')
    
    if [[ -z "$storage_list" ]]; then
        die "No storage pools available for VM images."
    fi
    
    local count
    count=$(echo "$storage_list" | wc -l)
    
    if [[ $count -eq 1 ]]; then
        STORAGE=$(echo "$storage_list" | head -1)
        msg_ok "Using VM storage: $STORAGE"
        return
    fi
    
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        # Use first available storage in non-interactive mode
        STORAGE=$(echo "$storage_list" | head -1)
        msg_ok "Using VM storage: $STORAGE (auto-selected)"
        return
    fi
    
    echo ""
    echo -e "${CYAN}Available storage pools for VM disk:${NC}"
    local i=1
    while read -r pool; do
        local info
        info=$(pvesm status -storage "$pool" | awk 'NR>1 {printf "Type: %-10s Free: %s", $2, $6}')
        echo "  $i) $pool ($info)"
        ((i++))
    done <<< "$storage_list"
    echo ""
    
    while true; do
        read -rp "$(echo -e "${MAGENTA}Select VM storage pool [1]: ${NC}")" choice </dev/tty
        choice=${choice:-1}
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= count)); then
            STORAGE=$(echo "$storage_list" | sed -n "${choice}p")
            msg_ok "Using VM storage: $STORAGE"
            return
        fi
        echo -e "${RED}Invalid selection. Try again.${NC}"
    done
}

# -----------------------------------------------------------------------------
# Interactive Configuration
# -----------------------------------------------------------------------------

prompt_config() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        # Use defaults
        [[ -z "$VMID" ]] && VMID=$(get_next_vmid)
        [[ -z "$MAC" ]] && MAC=$(generate_mac)
        return
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}VM Configuration${NC}"
    echo ""
    
    # VM ID
    local default_vmid
    default_vmid=$(get_next_vmid)
    read -rp "$(echo -e "${MAGENTA}VM ID [$default_vmid]: ${NC}")" input </dev/tty
    VMID=${input:-$default_vmid}
    
    # Hostname
    read -rp "$(echo -e "${MAGENTA}Hostname [$HOSTNAME]: ${NC}")" input </dev/tty
    HOSTNAME=${input:-$HOSTNAME}
    
    # CPU Cores
    read -rp "$(echo -e "${MAGENTA}CPU Cores [$CORE_COUNT]: ${NC}")" input </dev/tty
    CORE_COUNT=${input:-$CORE_COUNT}
    
    # RAM
    read -rp "$(echo -e "${MAGENTA}RAM (MiB) [$RAM_SIZE]: ${NC}")" input </dev/tty
    RAM_SIZE=${input:-$RAM_SIZE}
    
    # Disk Size
    read -rp "$(echo -e "${MAGENTA}Disk Size [$DISK_SIZE]: ${NC}")" input </dev/tty
    DISK_SIZE=${input:-$DISK_SIZE}
    # Normalize disk size
    if [[ "$DISK_SIZE" =~ ^[0-9]+$ ]]; then
        DISK_SIZE="${DISK_SIZE}G"
    fi
    
    # Bridge
    read -rp "$(echo -e "${MAGENTA}Network Bridge [$BRIDGE]: ${NC}")" input </dev/tty
    BRIDGE=${input:-$BRIDGE}
    
    # VLAN (optional)
    read -rp "$(echo -e "${MAGENTA}VLAN Tag (empty for none): ${NC}")" input </dev/tty
    VLAN=${input:-}
    
    # Machine Type
    echo ""
    echo -e "${CYAN}Machine Type:${NC}"
    echo "  1) i440fx (default, better compatibility)"
    echo "  2) q35 (newer, PCIe support)"
    read -rp "$(echo -e "${MAGENTA}Select [1]: ${NC}")" input </dev/tty
    case "${input:-1}" in
        2) MACHINE_TYPE="q35" ;;
        *) MACHINE_TYPE="i440fx" ;;
    esac
    
    # CPU Type
    echo ""
    echo -e "${CYAN}CPU Type:${NC}"
    echo "  1) kvm64 (default, best compatibility)"
    echo "  2) host (better performance, less portable)"
    read -rp "$(echo -e "${MAGENTA}Select [1]: ${NC}")" input </dev/tty
    case "${input:-1}" in
        2) CPU_TYPE="host" ;;
        *) CPU_TYPE="kvm64" ;;
    esac
    
    # Cloud-init
    echo ""
    read -rp "$(echo -e "${MAGENTA}Use Cloud-init? [Y/n]: ${NC}")" input </dev/tty
    case "${input:-y}" in
        [Nn]*) USE_CLOUD_INIT="no" ;;
        *) USE_CLOUD_INIT="yes" ;;
    esac
    
    # Start VM
    read -rp "$(echo -e "${MAGENTA}Start VM after creation? [Y/n]: ${NC}")" input </dev/tty
    case "${input:-y}" in
        [Nn]*) START_VM="no" ;;
        *) START_VM="yes" ;;
    esac
    
    # Run setup script
    if [[ "$START_VM" == "yes" ]]; then
        read -rp "$(echo -e "${MAGENTA}Run OpenClaw setup script after boot? [Y/n]: ${NC}")" input </dev/tty
        case "${input:-y}" in
            [Nn]*) RUN_SETUP="no" ;;
            *) RUN_SETUP="yes" ;;
        esac
    else
        RUN_SETUP="no"
    fi
    
    # Generate MAC
    MAC=$(generate_mac)
    
    echo ""
}

confirm_settings() {
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  VM Configuration Summary${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}VM ID:${NC}        $VMID"
    echo -e "  ${BOLD}Hostname:${NC}     $HOSTNAME"
    echo -e "  ${BOLD}CPU Cores:${NC}    $CORE_COUNT"
    echo -e "  ${BOLD}RAM:${NC}          ${RAM_SIZE} MiB"
    echo -e "  ${BOLD}Disk:${NC}         $DISK_SIZE"
    echo -e "  ${BOLD}VM Storage:${NC}   $STORAGE"
    echo -e "  ${BOLD}ISO Storage:${NC}  $ISO_STORAGE"
    echo -e "  ${BOLD}Machine:${NC}      $MACHINE_TYPE"
    echo -e "  ${BOLD}CPU Type:${NC}     $CPU_TYPE"
    echo -e "  ${BOLD}Bridge:${NC}       $BRIDGE"
    [[ -n "$VLAN" ]] && echo -e "  ${BOLD}VLAN:${NC}         $VLAN"
    echo -e "  ${BOLD}MAC:${NC}          $MAC"
    echo -e "  ${BOLD}Cloud-init:${NC}   $USE_CLOUD_INIT"
    echo -e "  ${BOLD}Start VM:${NC}     $START_VM"
    echo -e "  ${BOLD}Run Setup:${NC}    $RUN_SETUP"
    echo ""
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        read -rp "$(echo -e "${MAGENTA}Proceed with VM creation? [Y/n]: ${NC}")" input </dev/tty
        case "${input:-y}" in
            [Nn]*) 
                echo -e "${YELLOW}Aborted.${NC}"
                exit 0
                ;;
        esac
    fi
}

# -----------------------------------------------------------------------------
# VM Creation
# -----------------------------------------------------------------------------

create_vm() {
    # Get the path for ISO storage
    local iso_path
    iso_path=$(pvesm path "${ISO_STORAGE}:iso/" 2>/dev/null | sed 's|/iso/$||' || true)
    
    if [[ -z "$iso_path" ]]; then
        # Try to get the base path from storage config
        iso_path=$(pvesm status -storage "$ISO_STORAGE" | awk 'NR>1 {print $7}' || true)
    fi
    
    if [[ -z "$iso_path" ]] || [[ ! -d "$iso_path" ]]; then
        # Fallback: get path from pvesm cfg
        iso_path=$(grep -A10 "^${ISO_STORAGE}:" /etc/pve/storage.cfg | grep -E "^\s+path\s+" | awk '{print $2}' || true)
    fi
    
    if [[ -z "$iso_path" ]] || [[ ! -d "$iso_path" ]]; then
        msg_warn "Could not determine ISO storage path, using /var/lib/vz"
        iso_path="/var/lib/vz"
    fi
    
    # Create temp download location within the storage
    TEMP_DIR="${iso_path}/tmp-openclaw-$$"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    msg_ok "Download location: $TEMP_DIR"
    
    # Determine image URL
    local image_url
    if [[ "$USE_CLOUD_INIT" == "yes" ]]; then
        image_url="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    else
        image_url="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-nocloud-amd64.qcow2"
    fi
    
    msg_info "Downloading Debian 13 cloud image..."
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${CYAN}[DRY RUN] Would download: $image_url${NC}"
    else
        echo -e "  ${CYAN}URL: $image_url${NC}"
        if ! curl -#fSL -o "debian-13.qcow2" "$image_url"; then
            msg_error "Failed to download Debian cloud image"
            exit 1
        fi
        if [[ ! -f "debian-13.qcow2" ]] || [[ ! -s "debian-13.qcow2" ]]; then
            msg_error "Downloaded file is missing or empty"
            exit 1
        fi
    fi
    msg_ok "Downloaded Debian 13 cloud image ($(du -h debian-13.qcow2 | cut -f1))"
    
    # Determine storage type for disk naming
    local storage_type
    storage_type=$(pvesm status -storage "$STORAGE" | awk 'NR>1 {print $2}')
    
    local disk_ext=""
    local disk_ref=""
    local disk_import=""
    local thin="discard=on,ssd=1,"
    local format_opt=",efitype=4m"
    
    case $storage_type in
        nfs|dir)
            disk_ext=".qcow2"
            disk_ref="$VMID/"
            disk_import="-format qcow2"
            thin=""
            ;;
        btrfs)
            disk_ext=".raw"
            disk_ref="$VMID/"
            disk_import="-format raw"
            thin=""
            ;;
        *)
            # LVM, ZFS, etc.
            disk_ext=""
            disk_ref=""
            disk_import=""
            ;;
    esac
    
    # Machine-specific options
    local machine_opt=""
    if [[ "$MACHINE_TYPE" == "q35" ]]; then
        machine_opt="-machine q35"
        format_opt=""
    fi
    
    # CPU option
    local cpu_opt=""
    if [[ "$CPU_TYPE" == "host" ]]; then
        cpu_opt="-cpu host"
    fi
    
    # VLAN option
    local vlan_opt=""
    if [[ -n "$VLAN" ]]; then
        vlan_opt=",tag=$VLAN"
    fi
    
    # Disk names
    local disk0="vm-${VMID}-disk-0${disk_ext}"
    local disk1="vm-${VMID}-disk-1${disk_ext}"
    local disk0_ref="${STORAGE}:${disk_ref}${disk0}"
    local disk1_ref="${STORAGE}:${disk_ref}${disk1}"
    
    msg_info "Creating VM $VMID..."
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "  ${CYAN}[DRY RUN] Would run:${NC}"
        echo "    qm create $VMID -agent 1 $machine_opt -tablet 0 -localtime 1 -bios ovmf $cpu_opt \\"
        echo "      -cores $CORE_COUNT -memory $RAM_SIZE -name $HOSTNAME \\"
        echo "      -net0 virtio,bridge=$BRIDGE,macaddr=$MAC$vlan_opt \\"
        echo "      -onboot 1 -ostype l26 -scsihw virtio-scsi-pci"
    else
        qm create "$VMID" -agent 1 $machine_opt -tablet 0 -localtime 1 -bios ovmf $cpu_opt \
            -cores "$CORE_COUNT" -memory "$RAM_SIZE" -name "$HOSTNAME" \
            -tags openclaw \
            -net0 "virtio,bridge=$BRIDGE,macaddr=$MAC$vlan_opt" \
            -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
    fi
    msg_ok "Created VM $VMID"
    
    msg_info "Allocating EFI disk..."
    if [[ "$DRY_RUN" != "true" ]]; then
        pvesm alloc "$STORAGE" "$VMID" "$disk0" 4M 1>/dev/null
    fi
    msg_ok "Allocated EFI disk"
    
    msg_info "Importing Debian image..."
    if [[ "$DRY_RUN" != "true" ]]; then
        qm importdisk "$VMID" "debian-13.qcow2" "$STORAGE" $disk_import 1>/dev/null
    fi
    msg_ok "Imported Debian image"
    
    msg_info "Configuring VM disks..."
    if [[ "$DRY_RUN" != "true" ]]; then
        if [[ "$USE_CLOUD_INIT" == "yes" ]]; then
            qm set "$VMID" \
                -efidisk0 "${disk0_ref}${format_opt}" \
                -scsi0 "${disk1_ref},${DISK_CACHE}${thin}size=${DISK_SIZE}" \
                -scsi1 "${STORAGE}:cloudinit" \
                -boot order=scsi0 \
                -serial0 socket >/dev/null
        else
            qm set "$VMID" \
                -efidisk0 "${disk0_ref}${format_opt}" \
                -scsi0 "${disk1_ref},${DISK_CACHE}${thin}size=${DISK_SIZE}" \
                -boot order=scsi0 \
                -serial0 socket >/dev/null
        fi
    fi
    msg_ok "Configured VM disks"
    
    msg_info "Resizing disk to $DISK_SIZE..."
    if [[ "$DRY_RUN" != "true" ]]; then
        qm resize "$VMID" scsi0 "$DISK_SIZE" >/dev/null
    fi
    msg_ok "Resized disk to $DISK_SIZE"
    
    # Set description
    local description="<div align='center'><h2>OpenClaw VM</h2><p>Debian 13 (Trixie)</p><p>Created by openclaw-vm-create.sh</p></div>"
    if [[ "$DRY_RUN" != "true" ]]; then
        qm set "$VMID" -description "$description" >/dev/null
    fi
    
    msg_ok "VM $VMID created successfully!"
}

start_vm() {
    if [[ "$START_VM" != "yes" ]]; then
        return
    fi
    
    msg_info "Starting VM $VMID..."
    if [[ "$DRY_RUN" != "true" ]]; then
        qm start "$VMID"
    fi
    msg_ok "Started VM $VMID"
}

wait_for_vm_ready() {
    if [[ "$START_VM" != "yes" ]] || [[ "$WAIT_FOR_SSH" != "yes" ]]; then
        return
    fi
    
    # Skip IP detection for nocloud images - they need manual network config
    if [[ "$USE_CLOUD_INIT" != "yes" ]]; then
        echo ""
        msg_warn "Nocloud image - network must be configured manually from console"
        echo -e "  ${CYAN}Access console: qm terminal $VMID${NC}"
        return
    fi
    
    echo ""
    echo -ne "  ${YELLOW}⏳${NC}  Waiting for VM to get IP address..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "  ${CYAN}[DRY RUN] Would wait for VM IP via qm guest cmd${NC}"
        return
    fi
    
    local ip=""
    local attempts=0
    local max_attempts=60  # 5 minutes
    
    while [[ -z "$ip" ]] && ((attempts < max_attempts)); do
        sleep 5
        ((attempts++))
        
        # Try to get IP from QEMU guest agent
        ip=$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null | \
            jq -r '.[].["ip-addresses"][]? | select(.["ip-address-type"]=="ipv4") | .["ip-address"]' 2>/dev/null | \
            grep -v "^127\." | head -1 || true)
        
        echo -ne "\r  ${YELLOW}⏳${NC}  Waiting for VM to get IP address... (${attempts}/${max_attempts})   "
    done
    echo ""
    
    if [[ -z "$ip" ]]; then
        msg_warn "Could not determine VM IP address. You may need to configure networking manually."
        return
    fi
    
    msg_ok "VM IP address: $ip"
    
    # Wait for SSH
    msg_info "Waiting for SSH to become available..."
    attempts=0
    max_attempts=24  # 2 minutes
    
    while ! nc -z "$ip" 22 2>/dev/null && ((attempts < max_attempts)); do
        sleep 5
        ((attempts++))
        printf "\r  ${YELLOW}⏳${NC}  Waiting for SSH to become available... (%d/%d)" "$attempts" "$max_attempts"
    done
    echo ""
    
    if ! nc -z "$ip" 22 2>/dev/null; then
        msg_warn "SSH not available. The VM may need manual configuration."
        return
    fi
    
    msg_ok "SSH is available at $ip"
    
    # Store IP for setup script
    VM_IP="$ip"
}

run_setup_script() {
    if [[ "$RUN_SETUP" != "yes" ]] || [[ -z "${VM_IP:-}" ]]; then
        return
    fi
    
    echo ""
    echo -e "${CYAN}${BOLD}Running OpenClaw setup script on VM...${NC}"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${CYAN}[DRY RUN] Would SSH to $VM_IP and run:${NC}"
        echo "    curl -fsSL $SETUP_SCRIPT_URL | sudo bash"
        return
    fi
    
    # For cloud-init images, default user is usually 'debian' with no password
    # We need to either:
    # 1. Configure cloud-init with SSH keys before boot
    # 2. Use the console to set up initial access
    # 3. Wait for user to provide credentials
    
    msg_warn "Cloud-init VMs require initial setup via console or cloud-init configuration."
    echo ""
    echo -e "${CYAN}To complete OpenClaw setup:${NC}"
    echo ""
    echo "  1. Access VM console: qm terminal $VMID"
    echo "  2. Log in (cloud-init default: debian/debian or root with no password)"
    echo "  3. Run the setup script:"
    echo ""
    echo -e "     ${GREEN}curl -fsSL $SETUP_SCRIPT_URL | sudo bash${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Create a Debian 13 VM on Proxmox with optional OpenClaw configuration.

Options:
    --vmid ID           VM ID (default: auto)
    --hostname NAME     VM hostname (default: openclaw)
    --cores N           CPU cores (default: 4)
    --memory N          RAM in MiB (default: 4096)
    --disk SIZE         Disk size (default: 64G)
    --storage NAME      VM storage pool (default: auto-detect)
    --iso-storage NAME  Storage for downloading image (default: auto-detect)
    --bridge NAME       Network bridge (default: vmbr0)
    --vlan TAG          VLAN tag (default: none)
    --machine TYPE      Machine type: i440fx or q35 (default: i440fx)
    --cpu TYPE          CPU type: kvm64 or host (default: kvm64)
    --no-cloudinit      Don't use cloud-init image
    --no-start          Don't start VM after creation
    --no-setup          Don't run OpenClaw setup script
    --non-interactive   Use defaults, don't prompt
    --dry-run           Show what would be done
    --help              Show this help

Examples:
    # Interactive mode
    $0

    # Quick defaults
    $0 --non-interactive

    # Custom configuration
    $0 --hostname myvm --cores 8 --memory 8192 --disk 64G

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --vmid) VMID="$2"; shift 2 ;;
            --hostname) HOSTNAME="$2"; shift 2 ;;
            --cores) CORE_COUNT="$2"; shift 2 ;;
            --memory) RAM_SIZE="$2"; shift 2 ;;
            --disk) DISK_SIZE="$2"; shift 2 ;;
            --storage) STORAGE="$2"; shift 2 ;;
            --iso-storage) ISO_STORAGE="$2"; shift 2 ;;
            --bridge) BRIDGE="$2"; shift 2 ;;
            --vlan) VLAN="$2"; shift 2 ;;
            --machine) MACHINE_TYPE="$2"; shift 2 ;;
            --cpu) CPU_TYPE="$2"; shift 2 ;;
            --no-cloudinit) USE_CLOUD_INIT="no"; shift ;;
            --no-start) START_VM="no"; shift ;;
            --no-setup) RUN_SETUP="no"; shift ;;
            --non-interactive) NON_INTERACTIVE=true; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            --help|-h) usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
    done
}

main() {
    parse_args "$@"
    
    print_header
    
    check_root
    check_arch
    check_proxmox
    
    # Select storage locations
    select_iso_storage
    
    if [[ -z "$STORAGE" ]]; then
        select_storage
    fi
    
    prompt_config
    confirm_settings
    
    echo ""
    create_vm
    start_vm
    wait_for_vm_ready
    run_setup_script
    
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  ✅ VM Creation Complete!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}VM ID:${NC}      $VMID"
    echo -e "  ${BOLD}Hostname:${NC}   $HOSTNAME"
    [[ -n "${VM_IP:-}" ]] && echo -e "  ${BOLD}IP:${NC}         $VM_IP"
    echo ""
    echo -e "  ${CYAN}Console:${NC}    qm terminal $VMID"
    echo -e "  ${CYAN}Start:${NC}      qm start $VMID"
    echo -e "  ${CYAN}Stop:${NC}       qm stop $VMID"
    echo -e "  ${CYAN}Destroy:${NC}    qm destroy $VMID"
    echo ""
    
    if [[ "$RUN_SETUP" == "yes" ]] && [[ -z "${VM_IP:-}" ]]; then
        echo -e "${YELLOW}Note: Run the OpenClaw setup script inside the VM:${NC}"
        echo ""
        echo -e "  ${GREEN}curl -fsSL $SETUP_SCRIPT_URL | sudo bash${NC}"
        echo ""
    fi
}

main "$@"
