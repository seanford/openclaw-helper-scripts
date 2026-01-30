#!/bin/bash
#
# openclaw-prep.sh
#
# Prepare a Linux system for OpenClaw installation.
# Run this BEFORE `pnpm add -g openclaw`.
#
# Repository: https://github.com/openclaw/openclaw
# Community:  https://discord.com/invite/clawd
#
# REQUIREMENTS:
#   - Debian/Ubuntu-based Linux distribution
#   - Can run as regular user (uses sudo when needed) or as root
#
# USAGE:
#   # Interactive mode
#   bash openclaw-prep.sh
#
#   # One-liner from web
#   curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-prep.sh | bash
#
#   # Non-interactive with defaults
#   bash openclaw-prep.sh --non-interactive
#
# LICENSE: MIT
#
set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="openclaw-prep"

# Modes
DRY_RUN=false
NON_INTERACTIVE=false

# Installation choices (empty = prompt interactively)
OPT_NODE_METHOD=""        # nvm, nodesource, skip
OPT_PNPM_METHOD=""        # corepack, standalone, skip
OPT_INSTALL_HOMEBREW=""   # yes, no
OPT_INSTALL_BUILD_TOOLS="" # yes, no

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Detect if running interactively
if [[ -t 0 ]]; then
    TTY_INPUT="/dev/stdin"
else
    TTY_INPUT="/dev/tty"
fi

# Distro detection
DISTRO=""
DISTRO_VERSION=""
PACKAGE_MANAGER=""

# Detected versions (after install)
INSTALLED_NODE=""
INSTALLED_PNPM=""
INSTALLED_GIT=""

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}OpenClaw System Preparation${NC} v${VERSION}                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Prepare your system for OpenClaw installation              ${CYAN}║${NC}"
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

Prepare a Linux system for OpenClaw installation. Run BEFORE 'pnpm add -g openclaw'.

OPTIONS:
  --dry-run                 Show what would be done without making changes
  --non-interactive         Run without prompts (uses sensible defaults)
  
  Node.js installation method:
  --node-nvm                Install Node.js via nvm (recommended)
  --node-nodesource         Install Node.js via NodeSource repository
  --node-skip               Skip Node.js installation (assume already installed)
  
  pnpm installation method:
  --pnpm-corepack           Install pnpm via corepack (recommended)
  --pnpm-standalone         Install pnpm via standalone installer
  --pnpm-skip               Skip pnpm installation
  
  Optional components:
  --homebrew                Install Linuxbrew/Homebrew
  --no-homebrew             Skip Homebrew installation
  --build-tools             Install build tools (build-essential, python3, etc.)
  --no-build-tools          Skip build tools installation
  
  --help, -h                Show this help message
  --version                 Show version

EXAMPLES:
  # Interactive mode (prompts for all choices)
  $0
  
  # Non-interactive with defaults (nvm + corepack, no homebrew)
  $0 --non-interactive
  
  # Dry-run preview
  $0 --dry-run
  
  # Specific choices
  $0 --node-nvm --pnpm-corepack --no-homebrew
  
  # One-liner from web (interactive)
  curl -fsSL https://raw.githubusercontent.com/seanford/openclaw-helper-scripts/main/openclaw-prep.sh | bash

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
                NON_INTERACTIVE=true
                shift
                ;;
            --node-nvm)
                OPT_NODE_METHOD="nvm"
                shift
                ;;
            --node-nodesource)
                OPT_NODE_METHOD="nodesource"
                shift
                ;;
            --node-skip)
                OPT_NODE_METHOD="skip"
                shift
                ;;
            --pnpm-corepack)
                OPT_PNPM_METHOD="corepack"
                shift
                ;;
            --pnpm-standalone)
                OPT_PNPM_METHOD="standalone"
                shift
                ;;
            --pnpm-skip)
                OPT_PNPM_METHOD="skip"
                shift
                ;;
            --homebrew)
                OPT_INSTALL_HOMEBREW="yes"
                shift
                ;;
            --no-homebrew)
                OPT_INSTALL_HOMEBREW="no"
                shift
                ;;
            --build-tools)
                OPT_INSTALL_BUILD_TOOLS="yes"
                shift
                ;;
            --no-build-tools)
                OPT_INSTALL_BUILD_TOOLS="no"
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

print_skip() {
    echo -e "  ${DIM}○${NC} ${DIM}$1${NC}"
}

# Prompt user with a question, reading from /dev/tty for curl|bash compatibility
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        [[ "$default" == "y" ]]
        return
    fi
    
    # Check if we can actually read from TTY
    if [[ ! -r "$TTY_INPUT" ]] && [[ "$TTY_INPUT" == "/dev/tty" ]]; then
        # Can't read from TTY, use default
        [[ "$default" == "y" ]]
        return
    fi
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    local response
    read -p "$prompt" response < "$TTY_INPUT" 2>/dev/null || response="$default"
    response="${response:-$default}"
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Prompt for a choice from a list
prompt_choice() {
    local prompt="$1"
    local default="$2"
    shift 2
    local options=("$@")
    
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        echo "$default"
        return
    fi
    
    echo ""
    echo -e "${BOLD}$prompt${NC}"
    local i=1
    for opt in "${options[@]}"; do
        if [[ "$opt" == "$default" ]]; then
            echo -e "  ${GREEN}$i)${NC} $opt ${DIM}(default)${NC}"
        else
            echo -e "  ${CYAN}$i)${NC} $opt"
        fi
        ((i++))
    done
    
    local choice
    read -p "Enter choice [1-${#options[@]}]: " choice < "$TTY_INPUT" 2>/dev/null || choice=""
    
    if [[ -z "$choice" ]]; then
        echo "$default"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
        echo "${options[$((choice-1))]}"
    else
        echo "$default"
    fi
}

# Execute a command, or print it in dry-run mode
run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: $*"
        return 0
    else
        "$@"
    fi
}

# Run with sudo if not root
run_sudo() {
    if [[ "$(id -u)" -eq 0 ]]; then
        run_cmd "$@"
    else
        run_cmd sudo "$@"
    fi
}

# Check if a command exists
has_command() {
    command -v "$1" &>/dev/null
}

# Get version of a command (first line of --version output)
get_version() {
    local cmd="$1"
    if has_command "$cmd"; then
        "$cmd" --version 2>/dev/null | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

# -----------------------------------------------------------------------------
# System detection
# -----------------------------------------------------------------------------

detect_distro() {
    print_step "Detecting system..."
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        DISTRO="${ID:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
    elif [[ -f /etc/lsb-release ]]; then
        # shellcheck source=/dev/null
        . /etc/lsb-release
        DISTRO="${DISTRIB_ID:-unknown}"
        DISTRO_VERSION="${DISTRIB_RELEASE:-unknown}"
    else
        DISTRO="unknown"
        DISTRO_VERSION="unknown"
    fi
    
    # Normalize distro name
    DISTRO=$(echo "$DISTRO" | tr '[:upper:]' '[:lower:]')
    
    # Detect package manager
    if has_command apt-get; then
        PACKAGE_MANAGER="apt"
    elif has_command dnf; then
        PACKAGE_MANAGER="dnf"
    elif has_command yum; then
        PACKAGE_MANAGER="yum"
    elif has_command pacman; then
        PACKAGE_MANAGER="pacman"
    else
        PACKAGE_MANAGER="unknown"
    fi
    
    print_success "Distro: ${CYAN}$DISTRO $DISTRO_VERSION${NC}"
    print_success "Package manager: ${CYAN}$PACKAGE_MANAGER${NC}"
    print_success "Architecture: ${CYAN}$(uname -m)${NC}"
    
    # Validate supported distro
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint|elementary|zorin|kali|raspbian)
            print_success "Supported Debian/Ubuntu-based distribution"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            print_warning "RHEL-based distribution detected — some features may differ"
            ;;
        arch|manjaro|endeavouros)
            print_warning "Arch-based distribution detected — some features may differ"
            ;;
        *)
            print_warning "Unknown distribution — proceeding with best effort"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------

check_existing_tools() {
    print_step "Checking existing installations..."
    
    local has_node=false
    local has_pnpm=false
    local has_git=false
    
    # Check Node.js
    if has_command node; then
        local node_ver=$(node --version 2>/dev/null || echo "unknown")
        print_success "Node.js: ${CYAN}$node_ver${NC}"
        has_node=true
        INSTALLED_NODE="$node_ver"
        
        # Check if it's a good version (v18+)
        local major_ver=$(echo "$node_ver" | sed 's/v\([0-9]*\).*/\1/')
        if [[ "$major_ver" =~ ^[0-9]+$ ]] && ((major_ver < 18)); then
            print_warning "Node.js $node_ver is older than recommended (v18+)"
        fi
    else
        print_info "Node.js: ${DIM}not installed${NC}"
    fi
    
    # Check nvm
    if [[ -d "$HOME/.nvm" ]] || has_command nvm; then
        print_success "nvm: ${CYAN}installed${NC}"
    fi
    
    # Check pnpm
    if has_command pnpm; then
        local pnpm_ver=$(pnpm --version 2>/dev/null || echo "unknown")
        print_success "pnpm: ${CYAN}$pnpm_ver${NC}"
        has_pnpm=true
        INSTALLED_PNPM="$pnpm_ver"
    else
        print_info "pnpm: ${DIM}not installed${NC}"
    fi
    
    # Check git
    if has_command git; then
        local git_ver=$(git --version 2>/dev/null | awk '{print $3}' || echo "unknown")
        print_success "git: ${CYAN}$git_ver${NC}"
        has_git=true
        INSTALLED_GIT="$git_ver"
    else
        print_info "git: ${DIM}not installed${NC}"
    fi
    
    # Check other useful tools
    local tools=("curl" "wget" "jq" "rg" "tmux" "unzip")
    local tool_status=""
    for tool in "${tools[@]}"; do
        if has_command "$tool"; then
            tool_status+="${GREEN}$tool${NC} "
        else
            tool_status+="${DIM}$tool${NC} "
        fi
    done
    print_info "CLI tools: $tool_status"
    
    # Check Homebrew
    if has_command brew; then
        print_success "Homebrew: ${CYAN}installed${NC}"
    else
        print_info "Homebrew: ${DIM}not installed${NC}"
    fi
    
    # Set defaults based on what's already installed
    if [[ "$has_node" == "true" ]] && [[ -z "$OPT_NODE_METHOD" ]]; then
        OPT_NODE_METHOD="skip"
    fi
    if [[ "$has_pnpm" == "true" ]] && [[ -z "$OPT_PNPM_METHOD" ]]; then
        OPT_PNPM_METHOD="skip"
    fi
}

# -----------------------------------------------------------------------------
# Installation functions
# -----------------------------------------------------------------------------

update_package_lists() {
    print_step "Updating package lists..."
    
    case "$PACKAGE_MANAGER" in
        apt)
            run_sudo apt-get update -qq
            ;;
        dnf|yum)
            run_sudo "$PACKAGE_MANAGER" check-update -q || true
            ;;
        pacman)
            run_sudo pacman -Sy --noconfirm
            ;;
    esac
    
    print_success "Package lists updated"
}

install_apt_packages() {
    local packages=("$@")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would install: ${packages[*]}"
        return 0
    fi
    
    # Filter to only missing packages
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            to_install+=("$pkg")
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_skip "All packages already installed"
        return 0
    fi
    
    DEBIAN_FRONTEND=noninteractive run_sudo apt-get install -y -qq "${to_install[@]}"
    print_success "Installed: ${to_install[*]}"
}

install_essential_packages() {
    print_step "Installing essential packages..."
    
    case "$PACKAGE_MANAGER" in
        apt)
            install_apt_packages ca-certificates curl wget gnupg lsb-release
            ;;
        dnf|yum)
            run_sudo "$PACKAGE_MANAGER" install -y -q ca-certificates curl wget gnupg2
            ;;
        pacman)
            run_sudo pacman -S --noconfirm --needed ca-certificates curl wget gnupg
            ;;
    esac
}

install_git() {
    print_step "Installing git..."
    
    if has_command git; then
        local ver=$(git --version | awk '{print $3}')
        print_skip "git already installed ($ver)"
        INSTALLED_GIT="$ver"
        return 0
    fi
    
    case "$PACKAGE_MANAGER" in
        apt)
            install_apt_packages git
            ;;
        dnf|yum)
            run_sudo "$PACKAGE_MANAGER" install -y -q git
            ;;
        pacman)
            run_sudo pacman -S --noconfirm --needed git
            ;;
    esac
    
    if [[ "$DRY_RUN" != "true" ]]; then
        INSTALLED_GIT=$(git --version 2>/dev/null | awk '{print $3}' || echo "installed")
        print_success "git installed ($INSTALLED_GIT)"
    fi
}

install_build_tools() {
    print_step "Installing build tools..."
    
    case "$PACKAGE_MANAGER" in
        apt)
            install_apt_packages build-essential python3 python3-pip make g++ gcc
            ;;
        dnf)
            run_sudo dnf groupinstall -y -q "Development Tools"
            run_sudo dnf install -y -q python3 python3-pip make gcc gcc-c++
            ;;
        yum)
            run_sudo yum groupinstall -y -q "Development Tools"
            run_sudo yum install -y -q python3 python3-pip make gcc gcc-c++
            ;;
        pacman)
            run_sudo pacman -S --noconfirm --needed base-devel python python-pip make gcc
            ;;
    esac
    
    print_success "Build tools installed"
}

install_cli_tools() {
    print_step "Installing useful CLI tools..."
    
    case "$PACKAGE_MANAGER" in
        apt)
            # ripgrep might be named differently
            local rg_pkg="ripgrep"
            install_apt_packages jq tmux unzip "$rg_pkg" || install_apt_packages jq tmux unzip
            ;;
        dnf|yum)
            run_sudo "$PACKAGE_MANAGER" install -y -q jq ripgrep tmux unzip || true
            ;;
        pacman)
            run_sudo pacman -S --noconfirm --needed jq ripgrep tmux unzip
            ;;
    esac
    
    print_success "CLI tools installed"
}

install_node_nvm() {
    print_step "Installing Node.js via nvm..."
    
    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
    
    # Check if nvm is already installed
    if [[ -d "$nvm_dir" ]] && [[ -s "$nvm_dir/nvm.sh" ]]; then
        print_info "nvm already installed at $nvm_dir"
    else
        print_substep "Downloading nvm installer..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would download and run nvm install script"
        else
            # Download and install nvm
            curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
            print_success "nvm installed"
        fi
    fi
    
    # Source nvm for this session
    if [[ "$DRY_RUN" != "true" ]]; then
        export NVM_DIR="$nvm_dir"
        # shellcheck source=/dev/null
        [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
    fi
    
    # Install Node.js LTS
    print_substep "Installing Node.js LTS..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: nvm install --lts"
    else
        if has_command nvm || type nvm &>/dev/null; then
            nvm install --lts
            nvm use --lts
            nvm alias default 'lts/*'
            INSTALLED_NODE=$(node --version 2>/dev/null || echo "installed")
            print_success "Node.js LTS installed ($INSTALLED_NODE)"
        else
            print_error "nvm not available in current shell"
            print_info "Run: source ~/.bashrc && nvm install --lts"
            return 1
        fi
    fi
}

install_node_nodesource() {
    print_step "Installing Node.js via NodeSource..."
    
    if [[ "$PACKAGE_MANAGER" != "apt" ]]; then
        print_warning "NodeSource setup is optimized for Debian/Ubuntu"
        print_info "Falling back to nvm..."
        install_node_nvm
        return
    fi
    
    print_substep "Adding NodeSource repository..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would add NodeSource repository and install Node.js 22.x"
    else
        # NodeSource setup for Node.js 22.x (current LTS)
        curl -fsSL https://deb.nodesource.com/setup_22.x | run_sudo bash -
        
        print_substep "Installing Node.js..."
        run_sudo apt-get install -y -qq nodejs
        
        INSTALLED_NODE=$(node --version 2>/dev/null || echo "installed")
        print_success "Node.js installed ($INSTALLED_NODE)"
    fi
}

install_pnpm_corepack() {
    print_step "Installing pnpm via corepack..."
    
    if ! has_command node; then
        print_error "Node.js is required for corepack"
        print_info "Install Node.js first, then re-run this script"
        return 1
    fi
    
    print_substep "Enabling corepack..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: corepack enable"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: corepack prepare pnpm@latest --activate"
    else
        # Enable corepack (might need sudo if Node.js is system-installed)
        if [[ -w "$(dirname "$(command -v node)")" ]]; then
            corepack enable
        else
            run_sudo corepack enable
        fi
        
        # Prepare pnpm
        corepack prepare pnpm@latest --activate 2>/dev/null || true
        
        # Verify
        if has_command pnpm; then
            INSTALLED_PNPM=$(pnpm --version 2>/dev/null || echo "installed")
            print_success "pnpm installed ($INSTALLED_PNPM)"
        else
            print_warning "pnpm not immediately available"
            print_info "You may need to restart your shell"
        fi
    fi
}

install_pnpm_standalone() {
    print_step "Installing pnpm via standalone installer..."
    
    print_substep "Downloading pnpm installer..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would download and run pnpm install script"
    else
        curl -fsSL https://get.pnpm.io/install.sh | sh -
        
        # Add to PATH for this session
        export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
        export PATH="$PNPM_HOME:$PATH"
        
        if has_command pnpm; then
            INSTALLED_PNPM=$(pnpm --version 2>/dev/null || echo "installed")
            print_success "pnpm installed ($INSTALLED_PNPM)"
        else
            print_warning "pnpm installed but not in PATH"
            print_info "Add to your shell config: export PATH=\"\$PNPM_HOME:\$PATH\""
        fi
    fi
}

install_homebrew() {
    print_step "Installing Linuxbrew/Homebrew..."
    
    if has_command brew; then
        print_skip "Homebrew already installed"
        return 0
    fi
    
    print_substep "Downloading Homebrew installer..."
    print_warning "This may take several minutes..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would download and run Homebrew install script"
    else
        # Homebrew install script handles its own prompts
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for this session
        if [[ -d /home/linuxbrew/.linuxbrew ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        elif [[ -d "$HOME/.linuxbrew" ]]; then
            eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
        fi
        
        if has_command brew; then
            print_success "Homebrew installed"
        else
            print_warning "Homebrew installed but not in PATH"
            print_info "Run: eval \"\$($(brew --prefix)/bin/brew shellenv)\""
        fi
    fi
}

setup_local_bin() {
    print_step "Setting up ~/.local/bin..."
    
    local local_bin="$HOME/.local/bin"
    
    # Create directory if needed
    if [[ ! -d "$local_bin" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would create: $local_bin"
        else
            mkdir -p "$local_bin"
            print_success "Created $local_bin"
        fi
    else
        print_skip "~/.local/bin already exists"
    fi
    
    # Check if it's in PATH
    if [[ ":$PATH:" == *":$local_bin:"* ]]; then
        print_skip "~/.local/bin already in PATH"
        return 0
    fi
    
    # Add to shell config
    local shell_rc=""
    if [[ -n "${BASH_VERSION:-}" ]] && [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -n "${ZSH_VERSION:-}" ]] && [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -f "$HOME/.profile" ]]; then
        shell_rc="$HOME/.profile"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [[ -n "$shell_rc" ]]; then
        local marker="# Added by openclaw-prep"
        
        if grep -q "$marker" "$shell_rc" 2>/dev/null; then
            print_skip "PATH already configured in $(basename "$shell_rc")"
            return 0
        fi
        
        local path_addition="
$marker
export PATH=\"\$HOME/.local/bin:\$PATH\""
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would add PATH to $(basename "$shell_rc")"
        else
            echo "$path_addition" >> "$shell_rc"
            print_success "Added ~/.local/bin to PATH in $(basename "$shell_rc")"
        fi
    else
        print_warning "Could not find shell config to update PATH"
        print_info "Add manually: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    # Add to current session
    export PATH="$local_bin:$PATH"
}

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------

verify_installation() {
    print_step "Verifying installation..."
    
    local all_good=true
    
    # Node.js
    if has_command node; then
        local node_ver=$(node --version 2>/dev/null)
        print_success "Node.js: ${CYAN}$node_ver${NC}"
    else
        print_error "Node.js: not found"
        all_good=false
    fi
    
    # pnpm
    if has_command pnpm; then
        local pnpm_ver=$(pnpm --version 2>/dev/null)
        print_success "pnpm: ${CYAN}$pnpm_ver${NC}"
    else
        print_error "pnpm: not found"
        all_good=false
    fi
    
    # git
    if has_command git; then
        local git_ver=$(git --version 2>/dev/null | awk '{print $3}')
        print_success "git: ${CYAN}$git_ver${NC}"
    else
        print_error "git: not found"
        all_good=false
    fi
    
    # Build tools
    if has_command gcc; then
        print_success "gcc: ${CYAN}$(gcc --version | head -1)${NC}"
    fi
    if has_command make; then
        print_success "make: ${CYAN}$(make --version | head -1)${NC}"
    fi
    if has_command python3; then
        print_success "python3: ${CYAN}$(python3 --version)${NC}"
    fi
    
    # CLI tools
    local tools=("curl" "wget" "jq" "rg" "tmux" "unzip")
    local found_tools=()
    for tool in "${tools[@]}"; do
        if has_command "$tool"; then
            found_tools+=("$tool")
        fi
    done
    print_success "CLI tools: ${CYAN}${found_tools[*]}${NC}"
    
    # Homebrew
    if has_command brew; then
        print_success "Homebrew: ${CYAN}installed${NC}"
    fi
    
    echo ""
    
    if [[ "$all_good" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

print_next_steps() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Next Steps${NC}                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check if we need to source shell config
    local needs_source=false
    if [[ -n "${NVM_DIR:-}" ]] && ! has_command node; then
        needs_source=true
    fi
    if ! has_command pnpm; then
        needs_source=true
    fi
    
    echo -e "${BOLD}1. Reload your shell configuration:${NC}"
    echo ""
    echo -e "   ${CYAN}source ~/.bashrc${NC}   ${DIM}# or restart your terminal${NC}"
    echo ""
    
    echo -e "${BOLD}2. Install OpenClaw:${NC}"
    echo ""
    echo -e "   ${CYAN}pnpm add -g openclaw${NC}"
    echo ""
    
    echo -e "${BOLD}3. Run the onboarding wizard:${NC}"
    echo ""
    echo -e "   ${CYAN}openclaw onboard${NC}"
    echo ""
    
    echo -e "${DIM}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${CYAN}📚${NC} Documentation: ${BLUE}https://docs.openclaw.ai${NC}"
    echo -e "  ${CYAN}💬${NC} Community:     ${BLUE}https://discord.com/invite/clawd${NC}"
    echo -e "  ${CYAN}🐙${NC} GitHub:        ${BLUE}https://github.com/openclaw/openclaw${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    parse_args "$@"
    print_header
    
    echo -e "${BOLD}This script prepares your system for OpenClaw installation.${NC}"
    echo ""
    echo "It will install/configure:"
    echo "  • Node.js (LTS version)"
    echo "  • pnpm package manager"
    echo "  • git"
    echo "  • Build tools for native modules"
    echo "  • Useful CLI tools (jq, ripgrep, tmux, etc.)"
    echo ""
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        if ! confirm "Continue?" "y"; then
            echo "Aborted."
            exit 0
        fi
    fi
    
    # Detect system
    detect_distro
    
    # Check what's already installed
    check_existing_tools
    
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    
    # Determine Node.js installation method
    local node_method="$OPT_NODE_METHOD"
    if [[ -z "$node_method" ]]; then
        if has_command node; then
            local node_ver=$(node --version 2>/dev/null)
            local major_ver=$(echo "$node_ver" | sed 's/v\([0-9]*\).*/\1/')
            if [[ "$major_ver" =~ ^[0-9]+$ ]] && ((major_ver >= 18)); then
                echo ""
                print_info "Node.js $node_ver is already installed and meets requirements"
                if ! confirm "Skip Node.js installation?" "y"; then
                    node_method=$(prompt_choice "How would you like to install Node.js?" "nvm" "nvm" "nodesource")
                else
                    node_method="skip"
                fi
            else
                echo ""
                print_warning "Node.js $node_ver is older than recommended (v18+)"
                node_method=$(prompt_choice "How would you like to install Node.js?" "nvm" "nvm" "nodesource" "skip")
            fi
        else
            node_method=$(prompt_choice "How would you like to install Node.js?" "nvm" "nvm" "nodesource")
        fi
    fi
    
    # Determine pnpm installation method
    local pnpm_method="$OPT_PNPM_METHOD"
    if [[ -z "$pnpm_method" ]]; then
        if has_command pnpm; then
            echo ""
            print_info "pnpm is already installed"
            if confirm "Skip pnpm installation?" "y"; then
                pnpm_method="skip"
            else
                pnpm_method=$(prompt_choice "How would you like to install pnpm?" "corepack" "corepack" "standalone")
            fi
        else
            pnpm_method=$(prompt_choice "How would you like to install pnpm?" "corepack" "corepack" "standalone")
        fi
    fi
    
    # Determine build tools
    local install_build_tools="$OPT_INSTALL_BUILD_TOOLS"
    if [[ -z "$install_build_tools" ]]; then
        if has_command gcc && has_command make && has_command python3; then
            install_build_tools="no"
        else
            echo ""
            if confirm "Install build tools (needed for some native Node.js modules)?" "y"; then
                install_build_tools="yes"
            else
                install_build_tools="no"
            fi
        fi
    fi
    
    # Determine Homebrew
    local install_homebrew="$OPT_INSTALL_HOMEBREW"
    if [[ -z "$install_homebrew" ]]; then
        if has_command brew; then
            install_homebrew="no"
        else
            echo ""
            echo -e "${DIM}Homebrew provides many useful tools but is optional.${NC}"
            if confirm "Install Linuxbrew/Homebrew?" "n"; then
                install_homebrew="yes"
            else
                install_homebrew="no"
            fi
        fi
    fi
    
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${BOLD}Installation Plan:${NC}"
    echo ""
    [[ "$node_method" != "skip" ]] && echo "  • Node.js via $node_method" || echo "  • Node.js: ${DIM}skip (already installed)${NC}"
    [[ "$pnpm_method" != "skip" ]] && echo "  • pnpm via $pnpm_method" || echo "  • pnpm: ${DIM}skip (already installed)${NC}"
    echo "  • git"
    [[ "$install_build_tools" == "yes" ]] && echo "  • Build tools (gcc, make, python3)" || echo "  • Build tools: ${DIM}skip${NC}"
    echo "  • CLI tools (jq, ripgrep, tmux, curl, wget, unzip)"
    [[ "$install_homebrew" == "yes" ]] && echo "  • Linuxbrew/Homebrew" || echo "  • Homebrew: ${DIM}skip${NC}"
    echo "  • ~/.local/bin PATH setup"
    echo ""
    
    if [[ "$NON_INTERACTIVE" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        if ! confirm "Proceed with installation?" "y"; then
            echo "Aborted."
            exit 0
        fi
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Update package lists
    update_package_lists
    
    # Install essential packages first
    install_essential_packages
    
    # Install git
    install_git
    
    # Install build tools
    if [[ "$install_build_tools" == "yes" ]]; then
        install_build_tools
    else
        print_step "Skipping build tools..."
        print_skip "Build tools installation skipped"
    fi
    
    # Install CLI tools
    install_cli_tools
    
    # Install Node.js
    case "$node_method" in
        nvm)
            install_node_nvm
            ;;
        nodesource)
            install_node_nodesource
            ;;
        skip)
            print_step "Skipping Node.js installation..."
            print_skip "Node.js already installed"
            ;;
    esac
    
    # Install pnpm
    case "$pnpm_method" in
        corepack)
            install_pnpm_corepack
            ;;
        standalone)
            install_pnpm_standalone
            ;;
        skip)
            print_step "Skipping pnpm installation..."
            print_skip "pnpm already installed"
            ;;
    esac
    
    # Install Homebrew
    if [[ "$install_homebrew" == "yes" ]]; then
        install_homebrew
    else
        print_step "Skipping Homebrew..."
        print_skip "Homebrew installation skipped"
    fi
    
    # Setup ~/.local/bin
    setup_local_bin
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    # Verify
    if [[ "$DRY_RUN" != "true" ]]; then
        verify_installation
    fi
    
    # Print next steps
    print_next_steps
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
        echo -e "Run without --dry-run to execute the installation."
        echo ""
    fi
    
    echo -e "${GREEN}✓${NC} ${BOLD}System preparation complete!${NC}"
    echo ""
}

main "$@"
