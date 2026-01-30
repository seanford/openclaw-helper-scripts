#!/bin/bash
#
# openclaw-vm-setup.sh
#
# Set up a fresh Debian Trixie VM with OpenClaw and optional desktop environment.
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

VERSION="2.0.0"
SCRIPT_NAME="openclaw-vm-setup"

# Dry run mode (set via --dry-run flag)
DRY_RUN=false

# Command-line configurable options (empty = prompt interactively)
OPT_USERNAME=""
OPT_DESKTOP_ENV=""           # xfce4/gnome/kde/lxqt/none
OPT_PASSWORDLESS_SUDO=""     # yes/no
OPT_NON_INTERACTIVE=false

# Package group options (empty = prompt or use defaults)
OPT_INSTALL_BROWSER=""
OPT_INSTALL_PYTHON=""
OPT_INSTALL_BUILD=""
OPT_INSTALL_NODE_EXTRAS=""
OPT_INSTALL_CLI=""
OPT_INSTALL_MEDIA=""

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

# Selected desktop environment
DESKTOP_ENV="none"

# Package group selections
INSTALL_BROWSER="no"
INSTALL_PYTHON="no"
INSTALL_BUILD="no"
INSTALL_NODE_EXTRAS="no"
INSTALL_CLI="no"
INSTALL_MEDIA="no"

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

Set up a fresh Debian Trixie VM with OpenClaw and optional desktop environment.

OPTIONS:
  --dry-run                 Show what would be done without making changes
  --non-interactive         Run without prompts (uses defaults)
  
  --user <name>             Username for OpenClaw (default: hostname)
  
  Desktop Environment:
  --desktop <env>           Install desktop: xfce4, gnome, kde, lxqt, none
  --desktop                 Alias for --desktop xfce4 (legacy)
  --no-desktop              Alias for --desktop none
  
  Package Groups (when desktop is selected):
  --with-browser            Install Chromium browser
  --no-browser              Skip browser installation
  --with-python             Install Python dev tools + uv
  --no-python               Skip Python tools
  --with-build              Install build tools (gcc, make, etc.)
  --no-build                Skip build tools
  --with-node-extras        Install node-gyp prerequisites
  --no-node-extras          Skip node extras
  --with-cli                Install CLI productivity tools
  --no-cli                  Skip CLI tools
  --with-media              Install media tools (ffmpeg, imagemagick)
  --no-media                Skip media tools (default)
  
  --passwordless-sudo       Configure passwordless sudo for user
  --no-passwordless-sudo    Require password for sudo (default)
  
  --help, -h                Show this help message
  --version                 Show version

EXAMPLES:
  # Interactive mode (prompts for all choices)
  sudo bash $0
  
  # Dry-run preview
  sudo bash $0 --dry-run
  
  # Full setup with XFCE desktop and all package groups
  sudo bash $0 --user myagent --desktop xfce4 --with-browser --with-python --passwordless-sudo
  
  # Headless server setup (minimal, non-interactive)
  sudo bash $0 --user myagent --no-desktop --non-interactive
  
  # KDE Plasma desktop with media tools
  sudo bash $0 --user myagent --desktop kde --with-media

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
                if [[ "${2:-}" =~ ^(xfce4|gnome|kde|lxqt|none)$ ]]; then
                    OPT_DESKTOP_ENV="$2"
                    shift 2
                else
                    # Legacy --desktop without argument means xfce4
                    OPT_DESKTOP_ENV="xfce4"
                    shift
                fi
                ;;
            --no-desktop)
                OPT_DESKTOP_ENV="none"
                shift
                ;;
            --with-browser)
                OPT_INSTALL_BROWSER="yes"
                shift
                ;;
            --no-browser)
                OPT_INSTALL_BROWSER="no"
                shift
                ;;
            --with-python)
                OPT_INSTALL_PYTHON="yes"
                shift
                ;;
            --no-python)
                OPT_INSTALL_PYTHON="no"
                shift
                ;;
            --with-build)
                OPT_INSTALL_BUILD="yes"
                shift
                ;;
            --no-build)
                OPT_INSTALL_BUILD="no"
                shift
                ;;
            --with-node-extras)
                OPT_INSTALL_NODE_EXTRAS="yes"
                shift
                ;;
            --no-node-extras)
                OPT_INSTALL_NODE_EXTRAS="no"
                shift
                ;;
            --with-cli)
                OPT_INSTALL_CLI="yes"
                shift
                ;;
            --no-cli)
                OPT_INSTALL_CLI="no"
                shift
                ;;
            --with-media)
                OPT_INSTALL_MEDIA="yes"
                shift
                ;;
            --no-media)
                OPT_INSTALL_MEDIA="no"
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
    
    # -y flag is not valid for 'update', only for install/upgrade/remove/etc.
    if [[ "$action" == "update" ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get "$action" "$@"
    else
        DEBIAN_FRONTEND=noninteractive apt-get "$action" -y "$@"
    fi
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
    
    # Use curl/wget instead of ping - ping may not be installed on minimal Debian
    # Try multiple methods in case some tools aren't available
    local connected=false
    
    if command -v curl &>/dev/null; then
        if curl -sI --connect-timeout 5 https://deb.debian.org &>/dev/null; then
            connected=true
        fi
    elif command -v wget &>/dev/null; then
        if wget -q --spider --timeout=5 https://deb.debian.org &>/dev/null; then
            connected=true
        fi
    elif command -v ping &>/dev/null; then
        # Fallback to ping if available
        if ping -c 1 -W 5 deb.debian.org &>/dev/null || ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
            connected=true
        fi
    else
        # No tools available to check - assume connected and let apt fail if not
        print_warning "Cannot verify internet (no curl/wget/ping) - assuming connected"
        connected=true
    fi
    
    if [[ "$connected" != "true" ]]; then
        print_error "No internet connection detected"
        exit 1
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
# Desktop Environment Selection
# -----------------------------------------------------------------------------

select_desktop_environment() {
    if [[ -n "$OPT_DESKTOP_ENV" ]]; then
        DESKTOP_ENV="$OPT_DESKTOP_ENV"
        print_info "Using desktop environment from command line: $DESKTOP_ENV"
        return
    fi
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        DESKTOP_ENV="none"
        print_info "Skipping desktop installation (non-interactive default)"
        return
    fi
    
    echo ""
    echo -e "${BOLD}Desktop Environment Selection${NC}"
    echo ""
    echo "Choose a desktop environment to install:"
    echo ""
    echo -e "  ${CYAN}1)${NC} XFCE4      ${GREEN}(lightweight, recommended)${NC}"
    echo -e "  ${CYAN}2)${NC} GNOME      (full-featured, modern)"
    echo -e "  ${CYAN}3)${NC} KDE Plasma (feature-rich, customizable)"
    echo -e "  ${CYAN}4)${NC} LXQt       ${GREEN}(very lightweight)${NC}"
    echo -e "  ${CYAN}5)${NC} None       (headless/CLI only)"
    echo ""
    
    local choice
    read -p "Select [1-5, default: 5]: " choice < /dev/tty
    choice="${choice:-5}"
    
    case "$choice" in
        1) DESKTOP_ENV="xfce4" ;;
        2) DESKTOP_ENV="gnome" ;;
        3) DESKTOP_ENV="kde" ;;
        4) DESKTOP_ENV="lxqt" ;;
        5|"") DESKTOP_ENV="none" ;;
        *)
            print_warning "Invalid selection, defaulting to none"
            DESKTOP_ENV="none"
            ;;
    esac
    
    echo ""
    print_info "Selected: $DESKTOP_ENV"
}

show_headless_warning() {
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${BOLD}Headless Mode Warning${NC}                                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}⚠${NC} Running without a desktop environment has limitations:"
    echo ""
    echo "    • No GUI browser for OAuth authentication"
    echo "    • WhatsApp/Discord linking may require a separate machine"
    echo "      with a browser to scan QR codes"
    echo "    • Some OpenClaw features work better with a browser available"
    echo ""
    echo -e "  ${CYAN}ℹ${NC} You can install a desktop environment later by running:"
    echo "      sudo apt install xfce4 xfce4-goodies lightdm"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" != "true" ]]; then
        if ! confirm "Continue with headless setup?"; then
            echo ""
            echo "Restarting desktop selection..."
            select_desktop_environment
            if [[ "$DESKTOP_ENV" == "none" ]]; then
                show_headless_warning
            fi
        fi
    fi
}

# -----------------------------------------------------------------------------
# Package Group Selection
# -----------------------------------------------------------------------------

select_package_groups() {
    # Only offer package groups if a desktop is being installed
    if [[ "$DESKTOP_ENV" == "none" ]]; then
        return
    fi
    
    echo ""
    echo -e "${BOLD}Additional Package Groups${NC}"
    echo ""
    echo "Select which package groups to install with your desktop:"
    echo ""
    
    # Browser & Web Tools
    select_browser_group
    
    # Python Development
    select_python_group
    
    # Build Tools
    select_build_group
    
    # Node.js Extras
    select_node_extras_group
    
    # CLI Productivity
    select_cli_group
    
    # Media Tools
    select_media_group
}

select_browser_group() {
    if [[ -n "$OPT_INSTALL_BROWSER" ]]; then
        INSTALL_BROWSER="$OPT_INSTALL_BROWSER"
        return
    fi
    
    echo -e "${CYAN}Browser & Web Tools:${NC}"
    echo "  • chromium (web browser)"
    echo "  • firefox-esr (alternative browser)"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        INSTALL_BROWSER="yes"
        print_info "Installing browser tools (non-interactive default)"
    else
        if confirm "Install Browser & Web Tools?" "y"; then
            INSTALL_BROWSER="yes"
        else
            INSTALL_BROWSER="no"
        fi
    fi
    echo ""
}

select_python_group() {
    if [[ -n "$OPT_INSTALL_PYTHON" ]]; then
        INSTALL_PYTHON="$OPT_INSTALL_PYTHON"
        return
    fi
    
    echo -e "${CYAN}Python Development:${NC}"
    echo "  • python3, python3-pip, python3-venv"
    echo "  • uv (fast Python package manager)"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        INSTALL_PYTHON="yes"
        print_info "Installing Python tools (non-interactive default)"
    else
        if confirm "Install Python Development tools?" "y"; then
            INSTALL_PYTHON="yes"
        else
            INSTALL_PYTHON="no"
        fi
    fi
    echo ""
}

select_build_group() {
    if [[ -n "$OPT_INSTALL_BUILD" ]]; then
        INSTALL_BUILD="$OPT_INSTALL_BUILD"
        return
    fi
    
    echo -e "${CYAN}Build Tools:${NC}"
    echo "  • build-essential, gcc, g++, make"
    echo "  • pkg-config, autoconf, automake"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        INSTALL_BUILD="yes"
        print_info "Installing build tools (non-interactive default)"
    else
        if confirm "Install Build Tools?" "y"; then
            INSTALL_BUILD="yes"
        else
            INSTALL_BUILD="no"
        fi
    fi
    echo ""
}

select_node_extras_group() {
    if [[ -n "$OPT_INSTALL_NODE_EXTRAS" ]]; then
        INSTALL_NODE_EXTRAS="$OPT_INSTALL_NODE_EXTRAS"
        return
    fi
    
    echo -e "${CYAN}Node.js Extras:${NC}"
    echo "  • node-gyp prerequisites (for native modules)"
    echo "  • libnode-dev, libuv1-dev"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        INSTALL_NODE_EXTRAS="yes"
        print_info "Installing Node.js extras (non-interactive default)"
    else
        if confirm "Install Node.js Extras?" "y"; then
            INSTALL_NODE_EXTRAS="yes"
        else
            INSTALL_NODE_EXTRAS="no"
        fi
    fi
    echo ""
}

select_cli_group() {
    if [[ -n "$OPT_INSTALL_CLI" ]]; then
        INSTALL_CLI="$OPT_INSTALL_CLI"
        return
    fi
    
    echo -e "${CYAN}CLI Productivity:${NC}"
    echo "  • jq, ripgrep, tmux, htop, ncdu"
    echo "  • curl, wget, unzip, zip, git"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        INSTALL_CLI="yes"
        print_info "Installing CLI tools (non-interactive default)"
    else
        if confirm "Install CLI Productivity tools?" "y"; then
            INSTALL_CLI="yes"
        else
            INSTALL_CLI="no"
        fi
    fi
    echo ""
}

select_media_group() {
    if [[ -n "$OPT_INSTALL_MEDIA" ]]; then
        INSTALL_MEDIA="$OPT_INSTALL_MEDIA"
        return
    fi
    
    echo -e "${CYAN}Media Tools (optional):${NC}"
    echo "  • ffmpeg (video/audio processing)"
    echo "  • imagemagick (image processing)"
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        INSTALL_MEDIA="no"
        print_info "Skipping media tools (non-interactive default)"
    else
        if confirm "Install Media Tools?" "n"; then
            INSTALL_MEDIA="yes"
        else
            INSTALL_MEDIA="no"
        fi
    fi
    echo ""
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
        
        # Process management
        procps
        psmisc
        
        # Networking
        openssh-server
        net-tools
        dnsutils
        
        # Misc utilities
        locales
        tzdata
        file
        rsync
        less
        vim
        nano
        tree
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: ${packages[*]}"
    else
        run_apt install "${packages[@]}"
    fi
    
    print_success "Base packages installed"
    INSTALLED_COMPONENTS+=("Base system packages")
}

install_browser_packages() {
    if [[ "$INSTALL_BROWSER" != "yes" ]]; then
        return
    fi
    
    print_step "Installing Browser & Web Tools..."
    
    local packages=(
        firefox-esr
    )
    
    # Try chromium first, fall back to chromium-browser
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: chromium (or chromium-browser) firefox-esr"
    else
        if apt-cache show chromium &>/dev/null; then
            packages+=(chromium)
        elif apt-cache show chromium-browser &>/dev/null; then
            packages+=(chromium-browser)
        else
            print_warning "Chromium not available in repositories, installing Firefox only"
        fi
        
        run_apt install "${packages[@]}"
    fi
    
    print_success "Browser packages installed"
    INSTALLED_COMPONENTS+=("Browsers (Chromium, Firefox ESR)")
}

install_python_packages() {
    if [[ "$INSTALL_PYTHON" != "yes" ]]; then
        return
    fi
    
    print_step "Installing Python Development tools..."
    
    local packages=(
        python3
        python3-pip
        python3-venv
        python3-dev
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: ${packages[*]}"
        print_dry_run "Would install uv via installer script"
    else
        run_apt install "${packages[@]}"
        
        # Install uv
        print_substep "Installing uv package manager..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    
    print_success "Python tools installed"
    INSTALLED_COMPONENTS+=("Python development (python3, pip, venv, uv)")
}

install_build_packages() {
    if [[ "$INSTALL_BUILD" != "yes" ]]; then
        return
    fi
    
    print_step "Installing Build Tools..."
    
    local packages=(
        build-essential
        gcc
        g++
        make
        pkg-config
        autoconf
        automake
        libtool
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: ${packages[*]}"
    else
        run_apt install "${packages[@]}"
    fi
    
    print_success "Build tools installed"
    INSTALLED_COMPONENTS+=("Build tools (gcc, g++, make, etc.)")
}

install_node_extras_packages() {
    if [[ "$INSTALL_NODE_EXTRAS" != "yes" ]]; then
        return
    fi
    
    print_step "Installing Node.js Extras..."
    
    local packages=(
        # node-gyp prerequisites
        python3
        make
        g++
    )
    
    # Add libuv-dev if available
    if apt-cache show libuv1-dev &>/dev/null; then
        packages+=(libuv1-dev)
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: ${packages[*]}"
    else
        run_apt install "${packages[@]}"
    fi
    
    print_success "Node.js extras installed"
    INSTALLED_COMPONENTS+=("Node.js extras (node-gyp prerequisites)")
}

install_cli_packages() {
    if [[ "$INSTALL_CLI" != "yes" ]]; then
        return
    fi
    
    print_step "Installing CLI Productivity tools..."
    
    local packages=(
        jq
        ripgrep
        tmux
        htop
        ncdu
        curl
        wget
        unzip
        zip
        git
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: ${packages[*]}"
    else
        run_apt install "${packages[@]}"
    fi
    
    print_success "CLI tools installed"
    INSTALLED_COMPONENTS+=("CLI productivity (jq, ripgrep, tmux, htop, ncdu)")
}

install_media_packages() {
    if [[ "$INSTALL_MEDIA" != "yes" ]]; then
        return
    fi
    
    print_step "Installing Media Tools..."
    
    local packages=(
        ffmpeg
        imagemagick
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install: ${packages[*]}"
    else
        run_apt install "${packages[@]}"
    fi
    
    print_success "Media tools installed"
    INSTALLED_COMPONENTS+=("Media tools (ffmpeg, imagemagick)")
}

install_desktop() {
    if [[ "$DESKTOP_ENV" == "none" ]]; then
        return
    fi
    
    print_step "Installing ${DESKTOP_ENV^^} desktop environment..."
    
    local packages=()
    local display_manager="lightdm"
    local dm_greeter="lightdm-gtk-greeter"
    
    case "$DESKTOP_ENV" in
        xfce4)
            packages=(
                xfce4
                xfce4-goodies
                xfce4-terminal
            )
            ;;
        gnome)
            packages=(
                gnome-core
                gnome-shell
                gnome-terminal
                nautilus
            )
            display_manager="gdm3"
            dm_greeter=""
            ;;
        kde)
            packages=(
                kde-plasma-desktop
                plasma-nm
                konsole
                dolphin
            )
            display_manager="sddm"
            dm_greeter=""
            ;;
        lxqt)
            packages=(
                lxqt
                lxqt-themes
                qterminal
            )
            ;;
    esac
    
    # Common desktop packages
    packages+=(
        # Display manager
        "$display_manager"
        
        # Fonts
        fonts-dejavu
        fonts-liberation
        fonts-noto
        
        # Desktop utilities
        xdg-utils
        dbus-x11
    )
    
    # Add greeter if needed
    if [[ -n "$dm_greeter" ]]; then
        packages+=("$dm_greeter")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_dry_run "Would install ${DESKTOP_ENV^^} desktop packages"
        print_dry_run "Packages: ${packages[*]}"
    else
        run_apt install "${packages[@]}"
        
        # Enable display manager
        systemctl enable "$display_manager" 2>/dev/null || true
    fi
    
    print_success "${DESKTOP_ENV^^} desktop installed"
    INSTALLED_COMPONENTS+=("${DESKTOP_ENV^^} desktop environment")
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
    
    if [[ "$DESKTOP_ENV" != "none" ]]; then
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
    echo "  • Install essential packages"
    echo "  • Create a non-root user for OpenClaw"
    echo "  • Install Node.js, pnpm, and OpenClaw"
    echo "  • Configure systemd user service for the gateway"
    echo "  • Optionally install a desktop environment and additional tools"
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
    
    # Desktop environment selection
    select_desktop_environment
    
    # Show warning if headless
    if [[ "$DESKTOP_ENV" == "none" ]]; then
        show_headless_warning
    fi
    
    # Package group selection (only if desktop is selected)
    select_package_groups
    
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
    echo "  Desktop:            $DESKTOP_ENV"
    if [[ "$DESKTOP_ENV" != "none" ]]; then
        echo "  Browser tools:      $INSTALL_BROWSER"
        echo "  Python tools:       $INSTALL_PYTHON"
        echo "  Build tools:        $INSTALL_BUILD"
        echo "  Node.js extras:     $INSTALL_NODE_EXTRAS"
        echo "  CLI tools:          $INSTALL_CLI"
        echo "  Media tools:        $INSTALL_MEDIA"
    fi
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
    
    # Install desktop environment if selected
    install_desktop
    
    # Install package groups
    install_browser_packages
    install_python_packages
    install_build_packages
    install_node_extras_packages
    install_cli_packages
    install_media_packages
    
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
