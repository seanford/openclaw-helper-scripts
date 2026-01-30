#!/bin/bash
#
# openclaw-vm-setup.sh
#
# Set up a fresh Debian Trixie VM with OpenClaw and optional XFCE4 desktop.
# Designed for minimal Debian installs to get a full OpenClaw environment running.
#
# Repository: https://github.com/openclaw/openclaw
# Community:  https://discord.com/invite/clawd
#
# REQUIREMENTS:
#   - Fresh Debian Trixie (13) minimal install
#   - Must run as root
#   - Internet connection
#
# USAGE:
#   curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-vm-setup.sh | sudo bash
#
# LICENSE: MIT
#
set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="openclaw-vm-setup"

# Dry run mode (set via --dry-run flag)
DRY_RUN=false

# Command-line configurable options (empty = prompt interactively)
OPT_USERNAME=""
OPT_INSTALL_DESKTOP=""       # yes/no
OPT_PASSWORDLESS_SUDO=""     # yes/no
OPT_NON_INTERACTIVE=false

# Node.js version to install
NODE_VERSION="22"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Track what was installed for summary
INSTALLED_COMPONENTS=()

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}OpenClaw VM Setup${NC} v${VERSION}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Set up Debian Trixie with OpenClaw + optional desktop       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${BOLD}DRY-RUN MODE${NC} - No changes will be made                       ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    fi
    echo ""
}

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

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

EXAMPLES:
  # Interactive mode (prompts for all choices)
  sudo bash $0
  
  # Dry-run preview
  sudo bash $0 --dry-run
  
  # Full setup with desktop
  sudo bash $0 --user myagent --desktop --passwordless-sudo
  
  # Headless server setup
  sudo bash $0 --user myagent --no-desktop --non-interactive

ONE-LINER INSTALL:
  curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-vm-setup.sh | sudo bash

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --non-interactive)
                OPT_NON_INTERACTIVE=true
                shift
                ;;
            --user)
                OPT_USERNAME="$2"
                shift 2
                ;;
            --desktop)
                OPT_INSTALL_DESKTOP="yes"
                shift
                ;;
            --no-desktop)
                OPT_INSTALL_DESKTOP="no"
                shift
                ;;
            --passwordless-sudo)
                OPT_PASSWORDLESS_SUDO="yes"
                shift
                ;;
            --no-passwordless-sudo)
                OPT_PASSWORDLESS_SUDO="no"
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$VERSION"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

print_step() {
    echo ""
    echo -e "${BLUE}▶${NC} ${BOLD}$1${NC}"
}

print_substep() {
    echo -e "  ${CYAN}→${NC} $1"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_info() {
    echo -e "  ${CYAN}ℹ${NC} $1"
}

print_dry_run() {
    echo -e "  ${YELLOW}[DRY-RUN]${NC} $1"
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        [[ "$default" == "y" ]]
        return $?
    fi
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -p "$prompt" response < /dev/tty
    response="${response:-$default}"
    
    [[ "$response" =~ ^[Yy]$ ]]
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        eval "$var_name=\"$default\""
        return
    fi
    
    read -p "$prompt [$default]: " response < /dev/tty
    eval "$var_name=\"\${response:-$default}\""
}

# Execute a command, or print it in dry-run mode
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would run: $*"
        return 0
    else
        "$@"
    fi
}

# Execute apt commands with progress
run_apt() {
    local action="$1"
    shift
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would run: apt-get $action $*"
        return 0
    fi
    
    DEBIAN_FRONTEND=noninteractive apt-get "$action" -y "$@"
}

# Execute command as the target user
run_as_user() {
    local user="$1"
    shift
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would run as $user: $*"
        return 0
    fi
    
    sudo -H -u "$user" bash -c "$*"
}

# -----------------------------------------------------------------------------
# Validation functions
# -----------------------------------------------------------------------------

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        print_error "This script must be run as root."
        echo ""
        echo "Usage: sudo bash $0"
        exit 1
    fi
}

check_debian_trixie() {
    if [[ ! -f /etc/os-release ]]; then
        print_warning "Cannot detect OS version"
        return 0
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "debian" ]]; then
        print_warning "This script is designed for Debian. Detected: $ID"
        if [[ "$OPT_NON_INTERACTIVE" != "true" ]]; then
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
        fi
    fi
    
    if [[ "$VERSION_CODENAME" != "trixie" ]] && [[ "$VERSION_ID" != "13" ]]; then
        print_warning "This script is designed for Debian Trixie (13). Detected: ${VERSION_CODENAME:-$VERSION_ID}"
        if [[ "$OPT_NON_INTERACTIVE" != "true" ]]; then
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
        fi
    fi
    
    print_success "Debian ${VERSION_CODENAME:-$VERSION_ID} detected"
}

check_internet() {
    print_substep "Checking internet connectivity..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would check internet connectivity"
        return 0
    fi
    
    if ! ping -c 1 -W 5 deb.debian.org &>/dev/null; then
        if ! ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
            print_error "No internet connection detected"
            exit 1
        fi
    fi
    
    print_success "Internet connection OK"
}

check_user_exists() {
    local user="$1"
    id "$user" &>/dev/null
}

validate_username() {
    local user="$1"
    
    if [[ -z "$user" ]]; then
        print_error "Username cannot be empty"
        return 1
    fi
    
    if [[ ! "$user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        print_error "Invalid username format. Use lowercase letters, numbers, underscore, hyphen."
        return 1
    fi
    
    if [[ ${#user} -gt 32 ]]; then
        print_error "Username too long (max 32 characters)"
        return 1
    fi
    
    return 0
}

# -----------------------------------------------------------------------------
# Installation functions
# -----------------------------------------------------------------------------

update_system() {
    print_step "Updating system packages..."
    
    run_apt update
    run_apt upgrade
    
    print_success "System updated"
    INSTALLED_COMPONENTS+=("System updates")
}

install_base_packages() {
    print_step "Installing base packages..."
    
    local packages=(
        # Essential
        curl
        wget
        git
        sudo
        ca-certificates
        gnupg
        lsb-release
        apt-transport-https
        software-properties-common
        
        # CLI tools
        jq
        ripgrep
        tmux
        htop
        tree
        unzip
        zip
        less
        vim
        nano
        
        # Build essentials (for native node modules)
        build-essential
        python3
        
        # Networking
        openssh-server
        net-tools
        dnsutils
        
        # Process management
        procps
        psmisc
        
        # Misc utilities
        locales
        tzdata
        file
        rsync
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: ${packages[*]}"
    else
        run_apt install "${packages[@]}"
    fi
    
    print_success "Base packages installed"
    INSTALLED_COMPONENTS+=("Base CLI tools (jq, ripgrep, tmux, htop, etc.)")
}

install_desktop() {
    print_step "Installing XFCE4 desktop environment..."
    
    local packages=(
        xfce4
        xfce4-goodies
        xfce4-terminal
        lightdm
        lightdm-gtk-greeter
        
        # Browsers
        firefox-esr
        
        # Fonts
        fonts-dejavu
        fonts-liberation
        fonts-noto
        
        # Useful desktop apps
        xdg-utils
        dbus-x11
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install XFCE4 desktop packages"
    else
        run_apt install "${packages[@]}"
        
        # Enable display manager
        systemctl enable lightdm 2>/dev/null || true
    fi
    
    print_success "XFCE4 desktop installed"
    INSTALLED_COMPONENTS+=("XFCE4 desktop environment")
}

create_user() {
    local username="$1"
    
    print_step "Setting up user: $username"
    
    if check_user_exists "$username"; then
        print_info "User '$username' already exists"
        
        # Ensure user is in sudo group
        if [[ "$DRY_RUN" == "true" ]]; then
            print_dry_run "Would ensure $username is in sudo group"
        else
            usermod -aG sudo "$username" 2>/dev/null || true
        fi
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            print_dry_run "Would create user: $username"
            print_dry_run "Would add $username to sudo group"
        else
            useradd -m -s /bin/bash "$username"
            usermod -aG sudo "$username"
            
            # Set a random password and lock it (user should use SSH keys)
            local temp_pass=$(openssl rand -base64 12)
            echo "$username:$temp_pass" | chpasswd
            
            print_success "User '$username' created"
            print_info "Temporary password set (use SSH keys or 'passwd $username' to change)"
        fi
    fi
    
    # Ensure home directory has correct permissions
    local home_dir="/home/$username"
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would set ownership of $home_dir"
    else
        chown -R "$username:$username" "$home_dir" 2>/dev/null || true
        chmod 755 "$home_dir"
    fi
    
    print_success "User setup complete"
    INSTALLED_COMPONENTS+=("User account: $username")
}

configure_passwordless_sudo() {
    local username="$1"
    
    print_step "Configuring passwordless sudo..."
    
    local sudoers_file="/etc/sudoers.d/$username"
    local sudoers_content="$username ALL=(ALL) NOPASSWD: ALL"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would create $sudoers_file"
        print_dry_run "Content: $sudoers_content"
    else
        echo "$sudoers_content" > "$sudoers_file"
        chmod 440 "$sudoers_file"
        
        # Validate sudoers syntax
        if ! visudo -c -f "$sudoers_file" &>/dev/null; then
            rm -f "$sudoers_file"
            print_error "Failed to configure sudoers (syntax error)"
            return 1
        fi
    fi
    
    print_success "Passwordless sudo configured for $username"
    INSTALLED_COMPONENTS+=("Passwordless sudo")
}

install_nodejs() {
    local username="$1"
    
    print_step "Installing Node.js $NODE_VERSION..."
    
    # Check if already installed with correct version
    if command -v node &>/dev/null; then
        local current_version=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
        if [[ "$current_version" == "$NODE_VERSION" ]]; then
            print_info "Node.js $NODE_VERSION already installed"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would add NodeSource repository"
        print_dry_run "Would install nodejs"
    else
        # Use NodeSource for Node.js
        local keyring_dir="/etc/apt/keyrings"
        mkdir -p "$keyring_dir"
        
        # Download and install NodeSource GPG key
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o "$keyring_dir/nodesource.gpg"
        
        # Add NodeSource repository
        echo "deb [signed-by=$keyring_dir/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
        
        # Update and install
        run_apt update
        run_apt install nodejs
    fi
    
    print_success "Node.js installed"
    INSTALLED_COMPONENTS+=("Node.js $NODE_VERSION (via NodeSource)")
}

install_pnpm() {
    local username="$1"
    local home_dir="/home/$username"
    
    print_step "Installing pnpm..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install pnpm globally via npm"
        print_dry_run "Would configure pnpm for $username"
    else
        # Install pnpm globally via npm
        npm install -g pnpm
        
        # Configure pnpm for the user
        run_as_user "$username" "pnpm setup" || true
        
        # Ensure pnpm paths are in profile
        local pnpm_home="$home_dir/.local/share/pnpm"
        local profile="$home_dir/.profile"
        
        if ! grep -q "PNPM_HOME" "$profile" 2>/dev/null; then
            cat >> "$profile" << EOF

# pnpm
export PNPM_HOME="$pnpm_home"
case ":\$PATH:" in
  *":\$PNPM_HOME:"*) ;;
  *) export PATH="\$PNPM_HOME:\$PATH" ;;
esac
# pnpm end
EOF
            chown "$username:$username" "$profile"
        fi
    fi
    
    print_success "pnpm installed"
    INSTALLED_COMPONENTS+=("pnpm")
}

install_openclaw() {
    local username="$1"
    local home_dir="/home/$username"
    
    print_step "Installing OpenClaw..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install openclaw globally via pnpm"
    else
        # Need to source profile for pnpm path, or use full path
        local pnpm_home="$home_dir/.local/share/pnpm"
        
        # Install openclaw globally as the user
        run_as_user "$username" "export PNPM_HOME='$pnpm_home' && export PATH=\"\$PNPM_HOME:\$PATH\" && pnpm add -g openclaw@latest"
    fi
    
    print_success "OpenClaw installed"
    INSTALLED_COMPONENTS+=("OpenClaw (global)")
}

run_openclaw_onboard() {
    local username="$1"
    local home_dir="/home/$username"
    
    print_step "Running OpenClaw onboarding..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would run 'openclaw onboard' as $username"
        print_dry_run "Note: In non-dry-run, this requires interactive setup"
        return 0
    fi
    
    local pnpm_home="$home_dir/.local/share/pnpm"
    
    print_info "Starting OpenClaw onboarding..."
    print_info "This will prompt for API keys and configuration."
    echo ""
    
    # Run onboard interactively
    sudo -H -u "$username" bash -c "export PNPM_HOME='$pnpm_home' && export PATH=\"\$PNPM_HOME:\$PATH\" && openclaw onboard" < /dev/tty
    
    print_success "OpenClaw onboarding complete"
    INSTALLED_COMPONENTS+=("OpenClaw configuration")
}

setup_systemd_service() {
    local username="$1"
    local home_dir="/home/$username"
    
    print_step "Setting up systemd user service for OpenClaw gateway..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would enable lingering for $username"
        print_dry_run "Would install openclaw-gateway.service"
        return 0
    fi
    
    # Enable lingering so user services start at boot
    loginctl enable-linger "$username"
    
    local pnpm_home="$home_dir/.local/share/pnpm"
    
    # Install the gateway service
    run_as_user "$username" "export PNPM_HOME='$pnpm_home' && export PATH=\"\$PNPM_HOME:\$PATH\" && openclaw gateway install" || true
    
    # Enable the service for the user
    local uid=$(id -u "$username")
    local runtime_dir="/run/user/$uid"
    
    # Create runtime directory if it doesn't exist
    if [[ ! -d "$runtime_dir" ]]; then
        mkdir -p "$runtime_dir"
        chown "$username:$username" "$runtime_dir"
        chmod 700 "$runtime_dir"
    fi
    
    # Enable the service
    run_as_user "$username" "export XDG_RUNTIME_DIR='$runtime_dir' && systemctl --user enable openclaw-gateway.service" || true
    
    print_success "Systemd user service configured"
    print_info "Service will start on user login or reboot"
    INSTALLED_COMPONENTS+=("Systemd gateway service")
}

configure_ssh() {
    local username="$1"
    local home_dir="/home/$username"
    
    print_step "Configuring SSH..."
    
    local ssh_dir="$home_dir/.ssh"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would create $ssh_dir"
        print_dry_run "Would set SSH directory permissions"
    else
        mkdir -p "$ssh_dir"
        touch "$ssh_dir/authorized_keys"
        chmod 700 "$ssh_dir"
        chmod 600 "$ssh_dir/authorized_keys"
        chown -R "$username:$username" "$ssh_dir"
        
        # Ensure SSH server is enabled
        systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true
    fi
    
    print_success "SSH configured"
    print_info "Add your public key to $ssh_dir/authorized_keys"
    INSTALLED_COMPONENTS+=("SSH server")
}

configure_locale() {
    print_step "Configuring locale..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would configure en_US.UTF-8 locale"
        return 0
    fi
    
    # Generate locale
    if [[ -f /etc/locale.gen ]]; then
        sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        locale-gen
    fi
    
    # Set default locale
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 2>/dev/null || true
    
    print_success "Locale configured (en_US.UTF-8)"
}

print_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Setup Complete!${NC}                                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
        echo ""
        echo "Run without --dry-run to execute the setup."
        return
    fi
    
    echo -e "${BOLD}Installed components:${NC}"
    for component in "${INSTALLED_COMPONENTS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $component"
    done
    
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo ""
    echo "  1. ${CYAN}Reboot the system:${NC}"
    echo "     sudo reboot"
    echo ""
    echo "  2. ${CYAN}SSH as the new user:${NC}"
    echo "     ssh $TARGET_USERNAME@$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'YOUR_IP')"
    echo ""
    echo "  3. ${CYAN}Start the OpenClaw gateway:${NC}"
    echo "     openclaw gateway start"
    echo ""
    echo "  4. ${CYAN}Verify everything is working:${NC}"
    echo "     openclaw status"
    echo ""
    
    if [[ "$INSTALL_DESKTOP" == "yes" ]]; then
        echo "  5. ${CYAN}For desktop access:${NC}"
        echo "     - Log in via the graphical login screen"
        echo "     - Or use VNC/RDP for remote desktop access"
        echo ""
    fi
    
    echo -e "${GREEN}OpenClaw is ready!${NC} 🎉"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    # Parse command-line arguments
    parse_args "$@"
    
    # Print header
    print_header
    
    # Check we're root
    check_root
    
    echo -e "${BOLD}This script will set up a fresh Debian system with OpenClaw.${NC}"
    echo ""
    echo "It will:"
    echo "  • Update the system"
    echo "  • Install essential packages and CLI tools"
    echo "  • Create a non-root user for OpenClaw"
    echo "  • Install Node.js, pnpm, and OpenClaw"
    echo "  • Configure systemd user service for the gateway"
    echo "  • Optionally install XFCE4 desktop"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" != "true" ]]; then
        if ! confirm "Do you want to continue?" "y"; then
            echo "Aborted."
            exit 0
        fi
    fi
    
    echo ""
    
    # Pre-flight checks
    print_step "Running pre-flight checks..."
    check_debian_trixie
    check_internet
    
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Determine username
    local default_username=$(hostname | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
    if [[ -z "$default_username" ]] || [[ "$default_username" == "localhost" ]]; then
        default_username="openclaw"
    fi
    
    if [[ -n "$OPT_USERNAME" ]]; then
        TARGET_USERNAME="$OPT_USERNAME"
        print_info "Using username from command line: $TARGET_USERNAME"
    elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        TARGET_USERNAME="$default_username"
        print_info "Using default username: $TARGET_USERNAME"
    else
        echo -e "${BOLD}User Configuration${NC}"
        echo ""
        echo "OpenClaw should run as a non-root user."
        echo "Suggested username based on hostname: ${CYAN}$default_username${NC}"
        echo ""
        prompt_input "Username for OpenClaw" "$default_username" TARGET_USERNAME
    fi
    
    if ! validate_username "$TARGET_USERNAME"; then
        exit 1
    fi
    
    # Determine desktop installation
    if [[ -n "$OPT_INSTALL_DESKTOP" ]]; then
        INSTALL_DESKTOP="$OPT_INSTALL_DESKTOP"
    elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        INSTALL_DESKTOP="no"
        print_info "Skipping desktop installation (non-interactive default)"
    else
        echo ""
        echo -e "${BOLD}Desktop Environment${NC}"
        echo ""
        echo "XFCE4 is a lightweight desktop environment."
        echo "Skip this for headless servers."
        echo ""
        if confirm "Install XFCE4 desktop environment?" "n"; then
            INSTALL_DESKTOP="yes"
        else
            INSTALL_DESKTOP="no"
        fi
    fi
    
    # Determine passwordless sudo
    if [[ -n "$OPT_PASSWORDLESS_SUDO" ]]; then
        PASSWORDLESS_SUDO="$OPT_PASSWORDLESS_SUDO"
    elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        PASSWORDLESS_SUDO="no"
        print_info "Skipping passwordless sudo (non-interactive default)"
    else
        echo ""
        echo -e "${BOLD}Sudo Configuration${NC}"
        echo ""
        echo "Passwordless sudo allows running admin commands without a password."
        echo "This is convenient but less secure."
        echo ""
        if confirm "Configure passwordless sudo for $TARGET_USERNAME?" "n"; then
            PASSWORDLESS_SUDO="yes"
        else
            PASSWORDLESS_SUDO="no"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}Configuration Summary:${NC}"
    echo "  Username:           $TARGET_USERNAME"
    echo "  Install desktop:    $INSTALL_DESKTOP"
    echo "  Passwordless sudo:  $PASSWORDLESS_SUDO"
    echo "  Node.js version:    $NODE_VERSION"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" != "true" ]]; then
        if ! confirm "Proceed with setup?" "y"; then
            echo "Aborted."
            exit 0
        fi
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Execute setup steps
    update_system
    install_base_packages
    configure_locale
    
    if [[ "$INSTALL_DESKTOP" == "yes" ]]; then
        install_desktop
    fi
    
    create_user "$TARGET_USERNAME"
    
    if [[ "$PASSWORDLESS_SUDO" == "yes" ]]; then
        configure_passwordless_sudo "$TARGET_USERNAME"
    fi
    
    configure_ssh "$TARGET_USERNAME"
    install_nodejs "$TARGET_USERNAME"
    install_pnpm "$TARGET_USERNAME"
    install_openclaw "$TARGET_USERNAME"
    
    # Run onboarding (interactive)
    if [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
        run_openclaw_onboard "$TARGET_USERNAME"
    else
        print_step "OpenClaw onboarding..."
        print_dry_run "Would run 'openclaw onboard' interactively"
    fi
    
    setup_systemd_service "$TARGET_USERNAME"
    
    # Print summary
    print_summary
}

# Run main with all arguments
main "$@"
