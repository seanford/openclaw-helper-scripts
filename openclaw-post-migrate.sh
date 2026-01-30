#!/bin/bash
#
# openclaw-post-migrate.sh
#
# Run after openclaw-migrate.sh completes and you've logged in as the new user.
# This script reinstalls OpenClaw, sets up the gateway service, and verifies everything works.
#
# USAGE:
#   bash openclaw-post-migrate.sh
#
# REQUIREMENTS:
#   - Must run as the NEW user (not root)
#   - Run after reboot (if user was renamed) or immediately (if merge/no-rename)
#
# LICENSE: MIT
#

set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="openclaw-post-migrate"

# Colors for output
# Standard conventions:
#   RED     - Errors, failures
#   GREEN   - Success, confirmation  
#   YELLOW  - Warnings, caution
#   BLUE    - Section headers, steps
#   CYAN    - Highlights, important values
#   MAGENTA - User prompts, questions needing input
#   BOLD    - Emphasis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Options
DRY_RUN=false
SKIP_REINSTALL=false
SKIP_GATEWAY=false
SKIP_VERIFY=false
RUN_CONFIGURE=false
OLD_USER=""

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}OpenClaw Post-Migration Setup${NC} v${VERSION}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Finalize your OpenClaw installation after migration         ${CYAN}║${NC}"
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

Run after migration to finalize OpenClaw setup.

OPTIONS:
  --dry-run              Show what would be done without making changes
  --skip-reinstall       Skip pnpm reinstall of openclaw
  --skip-gateway         Skip gateway daemon reinstall
  --skip-verify          Skip verification step
  --configure            Run 'openclaw configure' for channel re-auth
  --remove-old-user <name>  Remove the old user account after verification
  --help, -h             Show this help message
  --version              Show version

EXAMPLES:
  # Standard post-migration
  $0

  # Preview what would happen
  $0 --dry-run

  # Full cleanup including old user removal
  $0 --remove-old-user moltbot

  # Re-authenticate messaging channels
  $0 --configure

EOF
}

print_step() {
    echo -e "${BLUE}▶${NC} ${BOLD}$1${NC}"
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

run_cmd() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: $*"
        return 0
    else
        "$@"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-reinstall)
                SKIP_REINSTALL=true
                shift
                ;;
            --skip-gateway)
                SKIP_GATEWAY=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --configure)
                RUN_CONFIGURE=true
                shift
                ;;
            --remove-old-user)
                OLD_USER="$2"
                shift 2
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

check_not_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        print_error "This script should NOT be run as root."
        echo ""
        echo "You need to run this as the NEW user account after migration."
        echo ""
        echo "Options:"
        echo "  1. SSH in as the new user:"
        echo "     ssh <newuser>@$(hostname)"
        echo ""
        echo "  2. Switch to the new user:"
        echo "     su - <newuser>"
        echo ""
        echo "Then run this script again."
        exit 1
    fi
}

check_correct_account() {
    print_step "Verifying you're logged into the correct account..."
    
    local current_user=$(whoami)
    local errors=0
    local warnings=0
    
    # Check 1: Home directory exists and is accessible
    if [[ ! -d "$HOME" ]]; then
        print_error "Home directory does not exist: $HOME"
        ((errors++))
    else
        print_success "Home directory exists: $HOME"
    fi
    
    # Check 2: Look for OpenClaw installation markers
    local has_openclaw_dir=false
    local has_config=false
    local has_workspace=false
    local has_systemd_service=false
    
    if [[ -d "$HOME/.openclaw" ]]; then
        has_openclaw_dir=true
        print_success "Found ~/.openclaw directory"
        
        # Check for config file
        if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
            has_config=true
            print_success "Found openclaw.json config"
        fi
        
        # Check for workspace
        if [[ -d "$HOME/.openclaw/workspace" ]]; then
            has_workspace=true
            print_success "Found workspace directory"
        fi
    fi
    
    # Check for legacy directories that might indicate this is the OLD user
    for legacy_dir in ".moltbot" ".clawdbot"; do
        if [[ -d "$HOME/$legacy_dir" ]] && [[ ! -L "$HOME/$legacy_dir" ]]; then
            # It's a real directory, not a symlink - might be old user
            print_warning "Found legacy directory: ~/$legacy_dir (not a symlink)"
            print_info "This might be the OLD user account. Make sure you're logged into the NEW user."
            ((warnings++))
        fi
    done
    
    # Check for systemd user service
    if [[ -f "$HOME/.config/systemd/user/openclaw-gateway.service" ]]; then
        has_systemd_service=true
        print_success "Found gateway service file"
    fi
    
    # Evaluate results
    if [[ "$has_openclaw_dir" == "false" ]]; then
        echo ""
        print_error "No OpenClaw installation found in this account!"
        echo ""
        echo "  Expected to find: ~/.openclaw/"
        echo "  Current user: $current_user"
        echo "  Home directory: $HOME"
        echo ""
        echo "  Are you logged into the correct account?"
        echo "  The migration should have created ~/.openclaw/ in the NEW user's home."
        echo ""
        
        # Check if maybe running from wrong account
        for other_home in /home/*; do
            [[ -d "$other_home" ]] || continue
            [[ "$other_home" == "$HOME" ]] && continue
            if [[ -d "$other_home/.openclaw" ]]; then
                local other_user=$(basename "$other_home")
                print_info "Found OpenClaw installation at: $other_home"
                print_info "Try logging in as: $other_user"
            fi
        done
        
        ((errors++))
    fi
    
    echo ""
    
    if ((errors > 0)); then
        print_error "Account verification failed"
        echo ""
        echo "Make sure you're logged in as the NEW user that was created/targeted"
        echo "during migration, not the old user or root."
        return 1
    fi
    
    if ((warnings > 0)); then
        print_warning "Account verification completed with warnings"
        echo ""
        echo -en "${MAGENTA}▸ ${BOLD}Continue anyway?${NC} ${CYAN}[y/N]${NC}: "
        read confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    else
        print_success "Account verification passed"
    fi
    
    return 0
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local errors=0
    
    # Check for pnpm
    if command -v pnpm &>/dev/null; then
        print_success "pnpm found: $(pnpm --version)"
    else
        print_error "pnpm not found"
        print_info "Install with: curl -fsSL https://get.pnpm.io/install.sh | sh -"
        ((errors++))
    fi
    
    # Check for node
    if command -v node &>/dev/null; then
        print_success "Node.js found: $(node --version)"
    else
        print_error "Node.js not found"
        ((errors++))
    fi
    
    # Check for systemctl
    if command -v systemctl &>/dev/null; then
        print_success "systemctl available"
    else
        print_warning "systemctl not found (non-systemd system?)"
    fi
    
    echo ""
    
    if ((errors > 0)); then
        print_error "Prerequisites check failed with $errors error(s)"
        return 1
    fi
    
    return 0
}

reinstall_openclaw() {
    if [[ "$SKIP_REINSTALL" == "true" ]]; then
        print_step "Skipping OpenClaw reinstall (--skip-reinstall)"
        return 0
    fi
    
    print_step "Reinstalling OpenClaw (fixes hardcoded paths)..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: pnpm add -g openclaw@latest"
    else
        # Remove existing first to ensure clean install
        pnpm remove -g openclaw 2>/dev/null || true
        
        if pnpm add -g openclaw@latest; then
            print_success "OpenClaw reinstalled successfully"
            
            # Verify openclaw command works
            if command -v openclaw &>/dev/null; then
                local version=$(openclaw --version 2>/dev/null || echo "unknown")
                print_success "openclaw command available: $version"
            else
                print_warning "openclaw command not in PATH"
                print_info "You may need to restart your shell or add ~/.local/share/pnpm to PATH"
            fi
        else
            print_error "Failed to reinstall OpenClaw"
            return 1
        fi
    fi
}

reinstall_gateway() {
    if [[ "$SKIP_GATEWAY" == "true" ]]; then
        print_step "Skipping gateway reinstall (--skip-gateway)"
        return 0
    fi
    
    print_step "Reinstalling gateway daemon..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: openclaw gateway install --force"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: systemctl --user daemon-reload"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: systemctl --user enable openclaw-gateway.service"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: systemctl --user start openclaw-gateway.service"
    else
        # Install gateway service
        if openclaw gateway install --force; then
            print_success "Gateway daemon installed"
        else
            print_error "Failed to install gateway daemon"
            return 1
        fi
        
        # Reload systemd
        systemctl --user daemon-reload
        print_success "Systemd reloaded"
        
        # Enable service
        if systemctl --user enable openclaw-gateway.service; then
            print_success "Gateway service enabled"
        else
            print_warning "Could not enable gateway service"
        fi
        
        # Enable lingering (allows user services to run without login)
        if command -v loginctl &>/dev/null; then
            loginctl enable-linger "$(whoami)" 2>/dev/null || true
            print_success "User lingering enabled"
        fi
        
        # Start service
        if systemctl --user start openclaw-gateway.service; then
            print_success "Gateway service started"
        else
            print_error "Failed to start gateway service"
            print_info "Check logs with: journalctl --user -u openclaw-gateway.service"
            return 1
        fi
    fi
}

verify_installation() {
    if [[ "$SKIP_VERIFY" == "true" ]]; then
        print_step "Skipping verification (--skip-verify)"
        return 0
    fi
    
    print_step "Verifying installation..."
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: openclaw status"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would check gateway service status"
        return 0
    fi
    
    local errors=0
    
    # Check service status
    if systemctl --user is-active openclaw-gateway.service &>/dev/null; then
        print_success "Gateway service is running"
    else
        print_error "Gateway service is not running"
        ((errors++))
    fi
    
    # Run openclaw status
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    echo -e "${BOLD}OpenClaw Status:${NC}"
    echo ""
    
    if command -v openclaw &>/dev/null; then
        openclaw status || ((errors++))
    else
        print_error "openclaw command not found"
        ((errors++))
    fi
    
    echo ""
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    
    if ((errors > 0)); then
        print_warning "Verification completed with $errors issue(s)"
        return 1
    else
        print_success "All checks passed!"
    fi
    
    return 0
}

run_configure() {
    if [[ "$RUN_CONFIGURE" != "true" ]]; then
        return 0
    fi
    
    print_step "Running OpenClaw configure for channel re-authentication..."
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: openclaw configure"
    else
        openclaw configure
    fi
}

remove_old_user() {
    if [[ -z "$OLD_USER" ]]; then
        return 0
    fi
    
    print_step "Removing old user account: $OLD_USER"
    
    # Safety check - don't remove self
    if [[ "$OLD_USER" == "$(whoami)" ]]; then
        print_error "Cannot remove current user!"
        return 1
    fi
    
    # Check if user exists
    if ! id "$OLD_USER" &>/dev/null; then
        print_info "User '$OLD_USER' does not exist (may have been renamed)"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}⚠  WARNING: This will permanently delete:${NC}"
    echo "   • User account: $OLD_USER"
    echo "   • Home directory: /home/$OLD_USER"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would run: sudo userdel -r $OLD_USER"
    else
        echo -en "${MAGENTA}▸ ${BOLD}Are you sure you want to remove user '$OLD_USER'?${NC} ${CYAN}[y/N]${NC}: "
        read confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if sudo userdel -r "$OLD_USER" 2>/dev/null; then
                print_success "User '$OLD_USER' removed"
            else
                print_error "Failed to remove user '$OLD_USER'"
                print_info "Try manually: sudo userdel -r $OLD_USER"
                return 1
            fi
        else
            print_info "Skipped user removal"
        fi
    fi
}

main() {
    print_header
    
    check_not_root
    
    echo -e "${BOLD}Running as:${NC} $(whoami)"
    echo -e "${BOLD}Home:${NC} $HOME"
    echo ""
    
    if ! check_correct_account; then
        exit 1
    fi
    
    if ! check_prerequisites; then
        echo ""
        print_error "Please fix the issues above and try again."
        exit 1
    fi
    
    reinstall_openclaw
    echo ""
    
    reinstall_gateway
    echo ""
    
    verify_installation
    echo ""
    
    run_configure
    
    remove_old_user
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}Post-migration setup complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [[ "$RUN_CONFIGURE" != "true" ]]; then
        echo "If messaging channels need re-authentication, run:"
        echo -e "  ${CYAN}openclaw configure${NC}"
        echo ""
    fi
    
    echo "To check status anytime:"
    echo -e "  ${CYAN}openclaw status${NC}"
    echo ""
    echo "To view gateway logs:"
    echo -e "  ${CYAN}journalctl --user -u openclaw-gateway.service -f${NC}"
    echo ""
}

parse_args "$@"
main
