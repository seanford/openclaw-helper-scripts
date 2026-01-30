#!/bin/bash
#
# openclaw-migrate-user.sh
# 
# Migrate OpenClaw installation to a new Linux username.
# Handles legacy names: moltbot, clawdbot, and any custom username.
#
# Repository: https://github.com/openclaw/openclaw
# Community:  https://discord.com/invite/clawd
#
# REQUIREMENTS:
#   - Must run as root (not as the user being renamed)
#   - SSH in as root or use Proxmox/VM console
#
# USAGE:
#   sudo bash openclaw-migrate-user.sh
#
# LICENSE: MIT
#
set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="openclaw-migrate-user"

# Dry run mode (set via --dry-run flag)
DRY_RUN=false

# Command-line configurable options (empty = prompt interactively)
OPT_OLD_USER=""
OPT_NEW_USER=""
OPT_RENAME_USER=""          # yes/no/prompt
OPT_STANDARDIZE_WORKSPACE="" # yes/no/prompt
OPT_CREATE_SYMLINKS=""       # yes/no/prompt
OPT_MIGRATE_LEGACY_DIRS=""   # yes/no/prompt
OPT_NON_INTERACTIVE=false

# Legacy project names to search for in configs
LEGACY_NAMES=("moltbot" "clawdbot" "clawd")
LEGACY_DIRS=(".moltbot" ".clawdbot" ".clawd")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Dry-run prefix (defined after colors)
DRY_RUN_PREFIX="${YELLOW}[DRY-RUN]${NC}"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}OpenClaw User Migration Tool${NC} v${VERSION}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Migrate your OpenClaw installation to a new username       ${CYAN}║${NC}"
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

Migrate OpenClaw installation - rename user, update paths, standardize layout.

OPTIONS:
  --dry-run                 Show what would be done without making changes
  --non-interactive         Run without prompts (uses auto-detection and defaults)
  
  --old-user <name>         Current username (default: auto-detect)
  --new-user <name>         New username (required if renaming user)
  
  --rename-user             Rename the Linux user account
  --no-rename-user          Don't rename user (just update configs/paths)
  
  --standardize-workspace   Move workspace to ~/.openclaw/workspace
  --no-standardize-workspace Keep workspace in current location
  
  --migrate-legacy-dirs     Rename .moltbot/.clawdbot to .openclaw
  --no-migrate-legacy-dirs  Keep legacy directory names
  
  --create-symlinks         Create backward compatibility symlinks
  --no-create-symlinks      Don't create symlinks
  
  --help, -h                Show this help message
  --version                 Show version

EXAMPLES:
  # Interactive mode (prompts for all choices)
  sudo $0
  
  # Dry-run preview
  sudo $0 --dry-run
  
  # Rename user moltbot to k2so with all migrations
  sudo $0 --old-user moltbot --new-user k2so --rename-user
  
  # Just update configs without renaming user
  sudo $0 --old-user moltbot --no-rename-user --standardize-workspace
  
  # Full non-interactive migration
  sudo $0 --non-interactive --old-user moltbot --new-user k2so \\
      --rename-user --standardize-workspace --create-symlinks

EOF
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

# Execute a command that modifies files
run_modify() {
    local description="$1"
    shift
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} $description"
        return 0
    else
        "$@"
    fi
}

# Print success only when not in dry-run mode
print_success_real() {
    if [[ "$DRY_RUN" != "true" ]]; then
        print_success "$@"
    fi
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
            --old-user)
                OPT_OLD_USER="$2"
                shift 2
                ;;
            --new-user)
                OPT_NEW_USER="$2"
                shift 2
                ;;
            --rename-user)
                OPT_RENAME_USER="yes"
                shift
                ;;
            --no-rename-user)
                OPT_RENAME_USER="no"
                shift
                ;;
            --standardize-workspace)
                OPT_STANDARDIZE_WORKSPACE="yes"
                shift
                ;;
            --no-standardize-workspace)
                OPT_STANDARDIZE_WORKSPACE="no"
                shift
                ;;
            --migrate-legacy-dirs)
                OPT_MIGRATE_LEGACY_DIRS="yes"
                shift
                ;;
            --no-migrate-legacy-dirs)
                OPT_MIGRATE_LEGACY_DIRS="no"
                shift
                ;;
            --create-symlinks)
                OPT_CREATE_SYMLINKS="yes"
                shift
                ;;
            --no-create-symlinks)
                OPT_CREATE_SYMLINKS="no"
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

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi
    
    read -p "$prompt" response < /dev/tty
    response="${response:-$default}"
    
    [[ "$response" =~ ^[Yy]$ ]]
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

check_not_running_as_old_user() {
    local old_user="$1"
    if [[ "$(whoami)" == "$old_user" ]] || [[ "$(logname 2>/dev/null)" == "$old_user" ]]; then
        print_error "Cannot run while logged in as '$old_user'."
        echo ""
        echo "Please SSH as root or use the VM console."
        exit 1
    fi
}

check_user_exists() {
    local user="$1"
    if ! id "$user" &>/dev/null; then
        return 1
    fi
    return 0
}

check_user_not_exists() {
    local user="$1"
    if id "$user" &>/dev/null; then
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Discovery functions
# -----------------------------------------------------------------------------

# Global discovery results (populated by run_discovery)
DISCOVERED_USER=""
DISCOVERED_HOME=""
DISCOVERED_CONFIG=""
DISCOVERED_CONFIG_DIR=""
DISCOVERED_WORKSPACE=""
DISCOVERED_WORKSPACE_SOURCE=""
DISCOVERY_NOTES=()

run_discovery() {
    print_step "Scanning system for OpenClaw installation..."
    echo ""
    
    DISCOVERY_NOTES=()
    
    # Find all potential OpenClaw users
    local candidates=()
    local candidate_scores=()
    
    for user_home in /home/*; do
        [[ -d "$user_home" ]] || continue
        local user=$(basename "$user_home")
        local score=0
        local notes=""
        
        # Check for .openclaw directory (strongest signal)
        if [[ -d "$user_home/.openclaw" ]]; then
            ((score += 100))
            notes+="has .openclaw dir; "
        fi
        
        # Check for legacy directories
        for legacy_dir in "${LEGACY_DIRS[@]}"; do
            if [[ -d "$user_home/$legacy_dir" ]]; then
                ((score += 80))
                notes+="has $legacy_dir (legacy); "
            fi
        done
        
        # Check for config files
        if [[ -f "$user_home/.openclaw/openclaw.json" ]]; then
            ((score += 50))
            notes+="has openclaw.json; "
        fi
        for legacy in moltbot clawdbot; do
            if [[ -f "$user_home/.openclaw/${legacy}.json" ]] || [[ -f "$user_home/.${legacy}/${legacy}.json" ]]; then
                ((score += 40))
                notes+="has ${legacy}.json (legacy); "
            fi
        done
        
        # Check for systemd user services
        if [[ -f "$user_home/.config/systemd/user/openclaw-gateway.service" ]]; then
            ((score += 30))
            notes+="has systemd service; "
        fi
        
        # Check for pnpm global openclaw
        if [[ -d "$user_home/.local/share/pnpm" ]] && ls "$user_home/.local/share/pnpm/global"*/node_modules/openclaw 2>/dev/null | grep -q openclaw; then
            ((score += 20))
            notes+="has pnpm openclaw; "
        fi
        
        # Check for workspace indicators
        for ws in "$user_home/workspace" "$user_home/.openclaw/workspace" "$user_home/$user"; do
            if [[ -f "$ws/AGENTS.md" ]] || [[ -f "$ws/SOUL.md" ]]; then
                ((score += 25))
                notes+="has workspace with AGENTS.md; "
                break
            fi
        done
        
        if ((score > 0)); then
            candidates+=("$user")
            candidate_scores+=("$score:$notes")
        fi
    done
    
    # Select the best candidate
    local best_user=""
    local best_score=0
    local best_notes=""
    
    for i in "${!candidates[@]}"; do
        local score="${candidate_scores[$i]%%:*}"
        local notes="${candidate_scores[$i]#*:}"
        if ((score > best_score)); then
            best_score=$score
            best_user="${candidates[$i]}"
            best_notes="$notes"
        fi
    done
    
    if [[ -z "$best_user" ]]; then
        print_warning "No OpenClaw installation detected"
        return 1
    fi
    
    DISCOVERED_USER="$best_user"
    DISCOVERED_HOME="/home/$best_user"
    
    print_success "Found user: ${CYAN}$best_user${NC} (confidence score: $best_score)"
    print_info "Evidence: $best_notes"
    
    # Find config directory
    if [[ -d "$DISCOVERED_HOME/.openclaw" ]]; then
        DISCOVERED_CONFIG_DIR="$DISCOVERED_HOME/.openclaw"
    else
        for legacy_dir in "${LEGACY_DIRS[@]}"; do
            if [[ -d "$DISCOVERED_HOME/$legacy_dir" ]]; then
                DISCOVERED_CONFIG_DIR="$DISCOVERED_HOME/$legacy_dir"
                DISCOVERY_NOTES+=("Config in legacy location: $legacy_dir")
                break
            fi
        done
    fi
    
    # Find config file
    if [[ -n "$DISCOVERED_CONFIG_DIR" ]]; then
        if [[ -f "$DISCOVERED_CONFIG_DIR/openclaw.json" ]]; then
            DISCOVERED_CONFIG="$DISCOVERED_CONFIG_DIR/openclaw.json"
        else
            for legacy in moltbot clawdbot; do
                if [[ -f "$DISCOVERED_CONFIG_DIR/${legacy}.json" ]]; then
                    DISCOVERED_CONFIG="$DISCOVERED_CONFIG_DIR/${legacy}.json"
                    DISCOVERY_NOTES+=("Config file is legacy: ${legacy}.json")
                    break
                fi
            done
        fi
    fi
    
    print_success "Config dir: ${CYAN}${DISCOVERED_CONFIG_DIR:-not found}${NC}"
    print_success "Config file: ${CYAN}${DISCOVERED_CONFIG:-not found}${NC}"
    
    # Find workspace
    discover_workspace
    
    # Report any conflicts or notes
    if [[ ${#DISCOVERY_NOTES[@]} -gt 0 ]]; then
        echo ""
        print_warning "Notes:"
        for note in "${DISCOVERY_NOTES[@]}"; do
            echo -e "    ${YELLOW}•${NC} $note"
        done
    fi
    
    echo ""
    return 0
}

discover_workspace() {
    local workspace=""
    local source=""
    local conflicts=()
    
    # Method 1: Read from config file
    if [[ -f "$DISCOVERED_CONFIG" ]]; then
        local config_workspace=$(grep -o '"workspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$DISCOVERED_CONFIG" | head -1 | cut -d'"' -f4 || true)
        if [[ -n "$config_workspace" ]]; then
            # Expand ~
            config_workspace="${config_workspace/#\~/$DISCOVERED_HOME}"
            if [[ -d "$config_workspace" ]]; then
                workspace="$config_workspace"
                source="config file"
            else
                conflicts+=("Config points to non-existent workspace: $config_workspace")
            fi
        fi
    fi
    
    # Method 2: Check standard location
    local standard="$DISCOVERED_HOME/.openclaw/workspace"
    if [[ -d "$standard" ]] && [[ -f "$standard/AGENTS.md" || -f "$standard/SOUL.md" ]]; then
        if [[ -z "$workspace" ]]; then
            workspace="$standard"
            source="standard location"
        elif [[ "$workspace" != "$standard" ]]; then
            conflicts+=("Workspace also found at standard location: $standard")
        fi
    fi
    
    # Method 3: Check common custom locations
    for custom in "$DISCOVERED_HOME/workspace" "$DISCOVERED_HOME/.openclaw/workspace" "$DISCOVERED_HOME/openclaw" "$DISCOVERED_HOME/$DISCOVERED_USER"; do
        if [[ -d "$custom" ]] && [[ -f "$custom/AGENTS.md" || -f "$custom/SOUL.md" || -f "$custom/MEMORY.md" ]]; then
            if [[ -z "$workspace" ]]; then
                workspace="$custom"
                source="custom location"
            elif [[ "$workspace" != "$custom" ]]; then
                conflicts+=("Additional workspace found: $custom")
            fi
        fi
    done
    
    # Method 4: Check legacy user-named directories
    for legacy in moltbot clawdbot; do
        local legacy_ws="$DISCOVERED_HOME/$legacy"
        if [[ -d "$legacy_ws" ]] && [[ -f "$legacy_ws/AGENTS.md" || -f "$legacy_ws/SOUL.md" ]]; then
            if [[ -z "$workspace" ]]; then
                workspace="$legacy_ws"
                source="legacy location ($legacy)"
            elif [[ "$workspace" != "$legacy_ws" ]]; then
                conflicts+=("Legacy workspace also found: $legacy_ws")
            fi
        fi
    done
    
    DISCOVERED_WORKSPACE="$workspace"
    DISCOVERED_WORKSPACE_SOURCE="$source"
    
    if [[ -n "$workspace" ]]; then
        print_success "Workspace: ${CYAN}$workspace${NC} (from $source)"
        
        # Check workspace contents
        local contents=""
        [[ -f "$workspace/AGENTS.md" ]] && contents+="AGENTS.md "
        [[ -f "$workspace/SOUL.md" ]] && contents+="SOUL.md "
        [[ -f "$workspace/MEMORY.md" ]] && contents+="MEMORY.md "
        [[ -d "$workspace/memory" ]] && contents+="memory/ "
        [[ -d "$workspace/scripts" ]] && contents+="scripts/ "
        print_info "Contains: $contents"
    else
        print_warning "No workspace found"
        DISCOVERY_NOTES+=("No workspace directory detected - will create standard workspace")
    fi
    
    # Report conflicts
    for conflict in "${conflicts[@]}"; do
        DISCOVERY_NOTES+=("$conflict")
    done
}

detect_openclaw_user() {
    # Simple wrapper for backward compatibility
    run_discovery >/dev/null 2>&1
    echo "$DISCOVERED_USER"
}

find_references() {
    local search_dir="$1"
    local search_term="$2"
    
    if [[ -d "$search_dir" ]]; then
        grep -r -l "$search_term" "$search_dir" 2>/dev/null | grep -v ".jsonl" | head -20 || true
    fi
}

# -----------------------------------------------------------------------------
# Migration functions
# -----------------------------------------------------------------------------

stop_services() {
    local user="$1"
    
    print_step "Stopping services..."
    
    # Stop system services
    for svc in moltbot clawdbot openclaw; do
        if systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
            run_cmd systemctl stop "${svc}.service" 2>/dev/null || true
            print_success "Stopped ${svc}.service"
        fi
    done
    
    # Stop user services (tricky from root context)
    local uid=$(id -u "$user" 2>/dev/null || echo "")
    if [[ -n "$uid" ]]; then
        # Try to stop via loginctl
        run_cmd loginctl terminate-user "$user" 2>/dev/null || true
        [[ "$DRY_RUN" != "true" ]] && sleep 2
    fi
    
    # Kill any remaining processes
    if pgrep -u "$user" > /dev/null 2>&1; then
        print_warning "Killing remaining processes for $user..."
        run_cmd pkill -u "$user" 2>/dev/null || true
        [[ "$DRY_RUN" != "true" ]] && sleep 2
        run_cmd pkill -9 -u "$user" 2>/dev/null || true
    fi
    
    print_success "Services stopped"
}

rename_user() {
    local old_user="$1"
    local new_user="$2"
    local old_home="/home/$old_user"
    local new_home="/home/$new_user"
    
    print_step "Renaming user: $old_user → $new_user"
    
    # Rename login
    run_modify "Rename user login: $old_user → $new_user" \
        usermod -l "$new_user" "$old_user"
    print_success "User login renamed"
    
    # Rename primary group
    if getent group "$old_user" &>/dev/null; then
        run_modify "Rename group: $old_user → $new_user" \
            groupmod -n "$new_user" "$old_user"
        print_success "Primary group renamed"
    fi
    
    # Move home directory
    if [[ "$old_home" != "$new_home" ]]; then
        run_modify "Move home directory: $old_home → $new_home" \
            usermod -d "$new_home" -m "$new_user"
        print_success "Home directory moved to $new_home"
    fi
}

update_sudoers() {
    local old_user="$1"
    local new_user="$2"
    
    print_step "Updating sudoers..."
    
    if [[ -f "/etc/sudoers.d/$old_user" ]]; then
        run_modify "Move sudoers file" \
            mv "/etc/sudoers.d/$old_user" "/etc/sudoers.d/$new_user"
        if [[ "$DRY_RUN" != "true" ]]; then
            sed -i "s/$old_user/$new_user/g" "/etc/sudoers.d/$new_user"
            chmod 440 "/etc/sudoers.d/$new_user"
        else
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update sudoers content and permissions"
        fi
        print_success "Sudoers file migrated"
    else
        print_info "No sudoers file found for $old_user"
    fi
}

cleanup_system_services() {
    local old_user="$1"
    
    print_step "Cleaning up system services..."
    
    for svc in moltbot clawdbot; do
        local svc_file="/etc/systemd/system/${svc}.service"
        if [[ -f "$svc_file" ]]; then
            run_cmd systemctl disable "${svc}.service" 2>/dev/null || true
            run_modify "Remove legacy service file: $svc_file" \
                rm "$svc_file"
            print_success_real "Removed legacy $svc_file"
        fi
    done
    
    run_cmd systemctl daemon-reload
}

update_configs() {
    local new_home="$1"
    local old_user="$2"
    local new_user="$3"
    
    print_step "Updating configuration files..."
    
    local old_home="/home/$old_user"
    
    # OpenClaw config directory
    local openclaw_dir="$new_home/.openclaw"
    
    # Check for legacy directories and migrate
    for legacy_dir in "${LEGACY_DIRS[@]}"; do
        if [[ -d "$new_home/$legacy_dir" ]] && [[ ! -d "$openclaw_dir" ]]; then
            run_modify "Migrate config directory: $legacy_dir → .openclaw" \
                mv "$new_home/$legacy_dir" "$openclaw_dir"
            print_success_real "Migrated $legacy_dir → .openclaw"
        fi
    done
    
    if [[ -d "$openclaw_dir" ]] || [[ "$DRY_RUN" == "true" ]]; then
        # Update main config
        local config_files=(
            "$openclaw_dir/openclaw.json"
            "$openclaw_dir/moltbot.json"
            "$openclaw_dir/clawdbot.json"
            "$openclaw_dir/exec-approvals.json"
        )
        
        for config in "${config_files[@]}"; do
            if [[ -f "$config" ]] || [[ "$DRY_RUN" == "true" && "$config" == *"openclaw.json" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update paths in $(basename "$config")"
                else
                    # Replace all old paths with new
                    sed -i "s|/home/$old_user|/home/$new_user|g" "$config"
                    
                    # Replace legacy names in paths
                    for legacy in "${LEGACY_NAMES[@]}"; do
                        sed -i "s|/home/$legacy|/home/$new_user|g" "$config"
                    done
                    
                    # Replace legacy directory references
                    for legacy_dir in "${LEGACY_DIRS[@]}"; do
                        sed -i "s|$legacy_dir|.openclaw|g" "$config"
                    done
                    
                    print_success "Updated $(basename "$config")"
                fi
            fi
        done
        
        # Rename legacy config files to openclaw.json
        for legacy_config in "$openclaw_dir/moltbot.json" "$openclaw_dir/clawdbot.json"; do
            if [[ -f "$legacy_config" ]] && [[ ! -f "$openclaw_dir/openclaw.json" ]]; then
                run_modify "Rename config: $(basename "$legacy_config") → openclaw.json" \
                    mv "$legacy_config" "$openclaw_dir/openclaw.json"
                print_success_real "Renamed $(basename "$legacy_config") → openclaw.json"
            elif [[ -f "$legacy_config" ]]; then
                run_modify "Remove duplicate config: $(basename "$legacy_config")" \
                    rm "$legacy_config"
                [[ "$DRY_RUN" != "true" ]] && print_info "Removed duplicate $(basename "$legacy_config")"
            fi
        done
        
        # Update backup configs
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update backup config files"
        else
            for f in "$openclaw_dir"/*.bak*; do
                if [[ -f "$f" ]]; then
                    sed -i "s|/home/$old_user|/home/$new_user|g" "$f"
                    for legacy in "${LEGACY_NAMES[@]}"; do
                        sed -i "s|/home/$legacy|/home/$new_user|g" "$f"
                    done
                fi
            done
            print_success "Updated backup configs"
        fi
    fi
}

update_systemd_user_services() {
    local new_home="$1"
    local old_user="$2"
    local new_user="$3"
    
    print_step "Updating systemd user services..."
    
    local user_systemd="$new_home/.config/systemd/user"
    
    if [[ -d "$user_systemd" ]]; then
        for f in "$user_systemd"/*.service "$user_systemd"/*.path "$user_systemd"/*.timer; do
            if [[ -f "$f" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update $(basename "$f")"
                else
                    sed -i "s|/home/$old_user|/home/$new_user|g" "$f"
                    
                    for legacy in "${LEGACY_NAMES[@]}"; do
                        sed -i "s|/home/$legacy|/home/$new_user|g" "$f"
                    done
                    
                    print_success "Updated $(basename "$f")"
                fi
            fi
        done
    else
        print_info "No systemd user services found"
    fi
}

update_shell_configs() {
    local new_home="$1"
    local old_user="$2"
    local new_user="$3"
    
    print_step "Updating shell configurations..."
    
    local shell_files=(
        "$new_home/.profile"
        "$new_home/.bashrc"
        "$new_home/.zshrc"
        "$new_home/.bash_profile"
        "$new_home/.zprofile"
    )
    
    for f in "${shell_files[@]}"; do
        if [[ -f "$f" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update $(basename "$f")"
            else
                sed -i "s|/home/$old_user|/home/$new_user|g" "$f"
                
                for legacy in "${LEGACY_NAMES[@]}"; do
                    sed -i "s|/home/$legacy|/home/$new_user|g" "$f"
                done
                
                print_success "Updated $(basename "$f")"
            fi
        fi
    done
}

migrate_workspace_to_standard() {
    local new_home="$1"
    local old_user="$2"
    local new_user="$3"
    local standardize="$4"  # "yes" or "no"
    
    print_step "Migrating workspace..."
    
    local config="$new_home/.openclaw/openclaw.json"
    local standard_workspace="$new_home/.openclaw/workspace"
    local current_workspace=""
    
    # Find current workspace from config
    if [[ -f "$config" ]]; then
        current_workspace=$(grep -o '"workspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$config" | head -1 | cut -d'"' -f4 || true)
        # Expand ~ and update old paths
        current_workspace="${current_workspace/#\~/$new_home}"
        current_workspace="${current_workspace//\/home\/$old_user/$new_home}"
        for legacy in "${LEGACY_NAMES[@]}"; do
            current_workspace="${current_workspace//\/home\/$legacy/$new_home}"
        done
    fi
    
    # If no workspace in config, try to find it
    if [[ -z "$current_workspace" ]] || [[ ! -d "$current_workspace" ]]; then
        for ws in "$new_home/workspace" "$new_home/.openclaw/workspace" "$new_home/openclaw" "$new_home/$new_user"; do
            if [[ -d "$ws" ]]; then
                current_workspace="$ws"
                break
            fi
        done
        # Also check legacy user-named directories
        # Also check legacy user-named directories
        for legacy in "${LEGACY_NAMES[@]}"; do
            local legacy_ws="$new_home/$legacy"
            if [[ -d "$legacy_ws" ]] && [[ -f "$legacy_ws/AGENTS.md" || -f "$legacy_ws/SOUL.md" ]]; then
                if [[ -z "$current_workspace" ]]; then
                    current_workspace="$legacy_ws"
                fi
                break
            fi
        done
    fi
    
    if [[ -z "$current_workspace" ]]; then
    if [[ -z "$current_workspace" ]]; then
        print_info "No existing workspace found"
        # Create standard workspace
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would create standard workspace: $standard_workspace"
        else
            mkdir -p "$standard_workspace"
            print_success "Created standard workspace: $standard_workspace"
        fi
        return
    fi
    
    print_info "Found workspace: $current_workspace"
    
    # Move to standard location if requested and not already there
    if [[ "$standardize" == "yes" ]] && [[ "$current_workspace" != "$standard_workspace" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would move workspace to: $standard_workspace"
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update config to use standard workspace path"
            current_workspace="$standard_workspace"
        else
            if [[ -d "$standard_workspace" ]] && [[ "$(ls -A "$standard_workspace" 2>/dev/null)" ]]; then
                print_warning "Standard workspace already has content, merging..."
                # Move contents, don't overwrite
                cp -rn "$current_workspace"/* "$standard_workspace"/ 2>/dev/null || true
                cp -rn "$current_workspace"/.* "$standard_workspace"/ 2>/dev/null || true
                # Remove old workspace
                rm -rf "$current_workspace"
            else
                mkdir -p "$(dirname "$standard_workspace")"
                mv "$current_workspace" "$standard_workspace"
            fi
            print_success "Moved workspace to: $standard_workspace"
            
            # Update config to use standard path
            sed -i 's|"workspace"[[:space:]]*:[[:space:]]*"[^"]*"|"workspace": "~/.openclaw/workspace"|g' "$config"
            print_success "Updated config to use standard workspace path"
            
            current_workspace="$standard_workspace"
        fi
    elif [[ "$current_workspace" != "$standard_workspace" ]]; then
        # Just update the path in config to new home
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update workspace path in config"
        else
            sed -i "s|/home/$old_user|/home/$new_user|g" "$config"
            for legacy in "${LEGACY_NAMES[@]}"; do
                sed -i "s|/home/$legacy|/home/$new_user|g" "$config"
            done
            print_success "Updated workspace path in config"
        fi
    fi
    
    # Update markdown files in workspace
    if [[ -d "$current_workspace" ]]; then
        for f in "$current_workspace"/*.md "$current_workspace"/memory/*.md "$current_workspace"/scripts/*.md; do
            if [[ -f "$f" ]]; then
                local needs_update=false
                if grep -q "/home/$old_user" "$f" 2>/dev/null; then
                    needs_update=true
                fi
                for legacy in "${LEGACY_NAMES[@]}"; do
                    if grep -q "/home/$legacy" "$f" 2>/dev/null; then
                        needs_update=true
                    fi
                done
                if $needs_update; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update $(basename "$f")"
                    else
                        sed -i "s|/home/$old_user|/home/$new_user|g" "$f"
                        for legacy in "${LEGACY_NAMES[@]}"; do
                            sed -i "s|/home/$legacy|/home/$new_user|g" "$f"
                        done
                        print_success "Updated $(basename "$f")"
                    fi
                fi
            fi
        done
    fi
}

update_crontab() {
    local old_user="$1"
    local new_user="$2"
    
    print_step "Updating crontab..."
    
    local cron_content
    if cron_content=$(crontab -u "$new_user" -l 2>/dev/null); then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would update crontab paths"
        else
            local new_content
            new_content=$(echo "$cron_content" | sed "s|/home/$old_user|/home/$new_user|g")
            
            for legacy in "${LEGACY_NAMES[@]}"; do
                new_content=$(echo "$new_content" | sed "s|/home/$legacy|/home/$new_user|g")
            done
            
            echo "$new_content" | crontab -u "$new_user" -
            print_success "Crontab updated"
        fi
    else
        print_info "No crontab found"
    fi
}

fix_ownership() {
    local new_home="$1"
    local new_user="$2"
    local old_user="$3"
    
    print_step "Fixing file ownership (running as root, ensuring correct permissions)..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would chown -R $new_user:$new_user $new_home"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would set secure permissions on config files"
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would verify sudoers permissions"
        return
    fi
    
    # Fix ownership of entire home directory
    chown -R "$new_user:$new_user" "$new_home"
    print_success "Ownership updated for $new_home"
    
    # Fix ownership of .openclaw directory specifically (in case of symlinks)
    if [[ -d "$new_home/.openclaw" ]]; then
        chown -R "$new_user:$new_user" "$new_home/.openclaw"
        print_success "Ownership updated for .openclaw/"
    fi
    
    # Fix ownership of workspace if it's outside home (e.g., symlinked location)
    local workspace_path=""
    if [[ -f "$new_home/.openclaw/openclaw.json" ]]; then
        workspace_path=$(grep -o '"workspace"[[:space:]]*:[[:space:]]*"[^"]*"' "$new_home/.openclaw/openclaw.json" | head -1 | cut -d'"' -f4 || true)
        workspace_path="${workspace_path/#\~/$new_home}"
    fi
    if [[ -n "$workspace_path" ]] && [[ -d "$workspace_path" ]] && [[ "$workspace_path" != "$new_home"* ]]; then
        chown -R "$new_user:$new_user" "$workspace_path"
        print_success "Ownership updated for external workspace: $workspace_path"
    fi
    
    # Fix ownership of .config directory (systemd services, etc.)
    if [[ -d "$new_home/.config" ]]; then
        chown -R "$new_user:$new_user" "$new_home/.config"
        print_success "Ownership updated for .config/"
    fi
    
    # Fix ownership of .local directory (pnpm, scripts, etc.)
    if [[ -d "$new_home/.local" ]]; then
        chown -R "$new_user:$new_user" "$new_home/.local"
        print_success "Ownership updated for .local/"
    fi
    
    # Fix the old home symlink if it exists (should be owned by root, pointing to new home)
    local old_home="/home/$old_user"
    if [[ -L "$old_home" ]]; then
        # Symlinks themselves are always owned by root on most systems, that's fine
        print_info "Symlink $old_home → $new_home (owned by root, this is normal)"
    fi
    
    # Ensure correct permissions on sensitive files
    if [[ -f "$new_home/.openclaw/openclaw.json" ]]; then
        chmod 600 "$new_home/.openclaw/openclaw.json"
    fi
    if [[ -f "$new_home/.openclaw/.env" ]]; then
        chmod 600 "$new_home/.openclaw/.env"
    fi
    if [[ -d "$new_home/.openclaw/credentials" ]]; then
        chmod 700 "$new_home/.openclaw/credentials"
        find "$new_home/.openclaw/credentials" -type f -exec chmod 600 {} \;
    fi
    print_success "Secure permissions set on sensitive files"
    
    # Fix sudoers file permissions (must be 440)
    if [[ -f "/etc/sudoers.d/$new_user" ]]; then
        chmod 440 "/etc/sudoers.d/$new_user"
        chown root:root "/etc/sudoers.d/$new_user"
        print_success "Sudoers file permissions verified"
    fi
}

create_compatibility_symlinks() {
    local old_user="$1"
    local new_user="$2"
    local old_home="/home/$old_user"
    local new_home="/home/$new_user"
    local old_workspace="$3"
    local new_workspace="$4"
    
    print_step "Creating backward compatibility symlinks..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would create symlink: $old_home → $new_home"
        for legacy_dir in "${LEGACY_DIRS[@]}"; do
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would create symlink: $legacy_dir → .openclaw"
        done
        if [[ -n "$old_workspace" ]] && [[ "$old_workspace" != "$new_workspace" ]]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} Would create symlink: old workspace → $new_workspace"
        fi
        echo -e "  ${YELLOW}[DRY-RUN]${NC} Would create symlinks: moltbot.json, clawdbot.json → openclaw.json"
        print_info "Old paths would continue to work via symlinks"
        return
    fi
    
    # Symlink old home to new home (if different)
    if [[ "$old_home" != "$new_home" ]] && [[ ! -e "$old_home" ]]; then
        ln -s "$new_home" "$old_home"
        print_success "$old_home → $new_home"
    fi
    
    # Symlink legacy config directories to .openclaw
    for legacy_dir in "${LEGACY_DIRS[@]}"; do
        local legacy_path="$new_home/$legacy_dir"
        local openclaw_path="$new_home/.openclaw"
        
        if [[ ! -e "$legacy_path" ]] && [[ -d "$openclaw_path" ]]; then
            ln -s ".openclaw" "$legacy_path"
            print_success "$legacy_dir → .openclaw"
        fi
    done
    
    # Symlink old workspace to new workspace (if moved and different)
    if [[ -n "$old_workspace" ]] && [[ -n "$new_workspace" ]] && [[ "$old_workspace" != "$new_workspace" ]]; then
        # Calculate the old workspace path in the new home
        local old_ws_in_new_home="${old_workspace//\/home\/$old_user/$new_home}"
        
        if [[ ! -e "$old_ws_in_new_home" ]] && [[ -d "$new_workspace" ]]; then
            # Create parent directory if needed
            mkdir -p "$(dirname "$old_ws_in_new_home")"
            
            # Create relative symlink if possible, absolute otherwise
            local rel_target
            rel_target=$(realpath --relative-to="$(dirname "$old_ws_in_new_home")" "$new_workspace" 2>/dev/null || echo "$new_workspace")
            
            ln -s "$rel_target" "$old_ws_in_new_home"
            print_success "$(basename "$old_ws_in_new_home") → $new_workspace"
        fi
    fi
    
    # Symlink legacy config files to openclaw.json
    local openclaw_config="$new_home/.openclaw/openclaw.json"
    if [[ -f "$openclaw_config" ]]; then
        for legacy in moltbot clawdbot; do
            local legacy_config="$new_home/.openclaw/${legacy}.json"
            if [[ ! -e "$legacy_config" ]]; then
                ln -s "openclaw.json" "$legacy_config"
                print_success "${legacy}.json → openclaw.json"
            fi
        done
    fi
    
    print_info "Old paths will continue to work via symlinks"
}

# -----------------------------------------------------------------------------
# Main interactive flow
# -----------------------------------------------------------------------------

run_preflight_checks() {
    local old_user="$1"
    local old_home="/home/$old_user"
    
    print_step "Running pre-flight checks..."
    echo ""
    
    local warnings=0
    local errors=0
    
    # Check disk space
    local available_kb=$(df "$old_home" 2>/dev/null | awk 'NR==2 {print $4}')
    local home_size_kb=$(du -sk "$old_home" 2>/dev/null | cut -f1)
    if [[ -n "$available_kb" ]] && [[ -n "$home_size_kb" ]]; then
        if ((available_kb < home_size_kb)); then
            print_error "Insufficient disk space for migration"
            print_info "Available: $((available_kb / 1024)) MB, Needed: $((home_size_kb / 1024)) MB"
            ((errors++))
        else
            print_success "Disk space OK ($((available_kb / 1024)) MB available)"
        fi
    fi
    
    # Check for SSH keys
    if [[ -d "$old_home/.ssh" ]]; then
        print_success "SSH keys found - will be migrated"
        if [[ -f "$old_home/.ssh/authorized_keys" ]]; then
            print_info "authorized_keys present - SSH access will continue to work"
        fi
    else
        print_warning "No .ssh directory found"
        ((warnings++))
    fi
    
    # Check for external mounts/symlinks
    local external_links=()
    while IFS= read -r -d '' link; do
        local target=$(readlink "$link")
        if [[ "$target" == /* ]] && [[ "$target" != "$old_home"* ]]; then
            external_links+=("$link → $target")
        fi
    done < <(find "$old_home" -maxdepth 2 -type l -print0 2>/dev/null)
    
    if [[ ${#external_links[@]} -gt 0 ]]; then
        print_success "External symlinks found (will remain valid):"
        for link in "${external_links[@]}"; do
            print_info "  $link"
        done
    fi
    
    # Check for running services
    if systemctl --user -M "${old_user}@" is-active openclaw-gateway.service &>/dev/null; then
        print_warning "OpenClaw gateway is running - will be stopped"
        ((warnings++))
    fi
    
    # Check WhatsApp session
    if [[ -d "$old_home/.openclaw/credentials/whatsapp" ]] || [[ -f "$old_home/.openclaw/whatsapp-session.json" ]]; then
        print_warning "WhatsApp session found - may need re-authentication after migration"
        ((warnings++))
    fi
    
    # Check for open files
    local open_files=$(lsof +D "$old_home" 2>/dev/null | wc -l)
    if ((open_files > 1)); then
        print_warning "$((open_files - 1)) open files in home directory"
        ((warnings++))
    fi
    
    # Check cron jobs
    if crontab -u "$old_user" -l &>/dev/null; then
        local cron_count=$(crontab -u "$old_user" -l 2>/dev/null | grep -v "^#" | grep -c "." || echo 0)
        if ((cron_count > 0)); then
            print_success "Found $cron_count cron jobs - will be migrated"
        fi
    fi
    
    # Summary
    echo ""
    if ((errors > 0)); then
        print_error "Pre-flight failed with $errors error(s)"
        return 1
    elif ((warnings > 0)); then
        print_warning "Pre-flight completed with $warnings warning(s)"
        return 0
    else
        print_success "All pre-flight checks passed"
        return 0
    fi
}

main() {
    print_header
    
    # Check we're root
    check_root
    
    echo -e "${BOLD}This tool helps migrate your OpenClaw installation.${NC}"
    echo ""
    echo -e "${YELLOW}⚠  Depending on your choices, this may:${NC}"
    echo "   • Rename the Linux user account"
    echo "   • Move the home directory"
    echo "   • Kill all processes for the user"
    echo "   • Update OpenClaw configs and services"
    echo ""
    echo -e "You will be prompted for each option."
    echo ""
    
    if [[ "$OPT_NON_INTERACTIVE" != "true" ]]; then
        if ! confirm "Do you want to continue?"; then
            echo "Aborted."
            exit 0
        fi
    fi
    
    echo ""
    
    # Run comprehensive discovery
    if ! run_discovery; then
        echo ""
        print_warning "Could not auto-detect OpenClaw installation."
        echo ""
    fi
    
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Get old username (from CLI, discovery, or prompt)
    local old_user=""
    if [[ -n "$OPT_OLD_USER" ]]; then
        old_user="$OPT_OLD_USER"
        print_info "Using old username from command line: $old_user"
    elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        old_user="$DISCOVERED_USER"
        if [[ -z "$old_user" ]]; then
            print_error "Could not auto-detect user. Use --old-user in non-interactive mode."
            exit 1
        fi
        print_info "Auto-detected username: $old_user"
    elif [[ -n "$DISCOVERED_USER" ]]; then
        read -p "Current username [$DISCOVERED_USER]: " old_user < /dev/tty
        old_user="${old_user:-$DISCOVERED_USER}"
    else
        read -p "Current username: " old_user < /dev/tty
    fi
    
    if [[ -z "$old_user" ]]; then
        print_error "Username cannot be empty"
        exit 1
    fi
    
    if ! check_user_exists "$old_user"; then
        print_error "User '$old_user' does not exist"
        exit 1
    fi
    
    check_not_running_as_old_user "$old_user"
    
    # Determine if we're renaming the user
    local rename_user="yes"
    if [[ -n "$OPT_RENAME_USER" ]]; then
        rename_user="$OPT_RENAME_USER"
    elif [[ "$OPT_NON_INTERACTIVE" != "true" ]]; then
        echo ""
        if ! confirm "Rename the Linux user account?" "y"; then
            rename_user="no"
        fi
    fi
    
    # Get new username (if renaming)
    local new_user="$old_user"
    local new_home="/home/$old_user"
    
    if [[ "$rename_user" == "yes" ]]; then
        # Suggest new username based on hostname
        local suggested_user=""
        local current_hostname=$(hostname)
        if [[ -n "$current_hostname" ]] && [[ "$current_hostname" != "$old_user" ]] && check_user_not_exists "$current_hostname"; then
            suggested_user="$current_hostname"
        fi
        
        if [[ -n "$OPT_NEW_USER" ]]; then
            new_user="$OPT_NEW_USER"
            print_info "Using new username from command line: $new_user"
        elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
            # Use hostname suggestion in non-interactive mode
            if [[ -n "$suggested_user" ]]; then
                new_user="$suggested_user"
                print_info "Using hostname as new username: $new_user"
            else
                print_error "Cannot determine new username. Hostname matches current user or already exists."
                print_error "Use --new-user to specify, or --no-rename-user to skip renaming."
                exit 1
            fi
        else
            if [[ -n "$suggested_user" ]]; then
                echo ""
                print_info "Suggested username based on hostname: ${CYAN}$suggested_user${NC}"
                read -p "New username [$suggested_user]: " new_user < /dev/tty
                new_user="${new_user:-$suggested_user}"
            else
                read -p "New username: " new_user < /dev/tty
            fi
        fi
        new_home="/home/$new_user"
    else
        print_info "Not renaming user - will only update configs and paths"
        new_user="$old_user"
        new_home="/home/$old_user"
    fi
    
    if [[ "$rename_user" == "yes" ]]; then
        if [[ -z "$new_user" ]]; then
            print_error "New username cannot be empty"
            exit 1
        fi
        
        if [[ "$new_user" != "$old_user" ]] && ! check_user_not_exists "$new_user"; then
            print_error "User '$new_user' already exists"
            exit 1
        fi
        
        # Validate username format
        if [[ ! "$new_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            print_error "Invalid username format. Use lowercase letters, numbers, underscore, hyphen."
            exit 1
        fi
    fi
    
    local old_home="/home/$old_user"
    
    echo ""
    echo -e "${BOLD}Migration Summary:${NC}"
    echo "  Old user:  $old_user"
    echo "  New user:  $new_user"
    echo "  Old home:  $old_home"
    echo "  New home:  $new_home"
    echo ""
    
    # Determine workspace standardization
    local current_ws_display="${DISCOVERED_WORKSPACE:-not found}"
    local standard_ws="$new_home/.openclaw/workspace"
    local is_already_standard="no"
    local standardize_workspace="no"
    
    if [[ "$DISCOVERED_WORKSPACE" == */".openclaw/workspace" ]]; then
        is_already_standard="yes"
    fi
    
    if [[ -n "$OPT_STANDARDIZE_WORKSPACE" ]]; then
        standardize_workspace="$OPT_STANDARDIZE_WORKSPACE"
        print_info "Workspace standardization from command line: $standardize_workspace"
    elif [[ "$is_already_standard" == "yes" ]]; then
        echo ""
        echo "  Your workspace is already in the standard location."
        standardize_workspace="yes"
    elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        standardize_workspace="no"
        print_info "Keeping workspace at current location (non-interactive default)"
    else
        echo ""
        echo -e "${BOLD}Workspace Layout:${NC}"
        echo ""
        echo "  Current workspace: ${CYAN}$current_ws_display${NC}"
        if [[ -n "$DISCOVERED_WORKSPACE_SOURCE" ]]; then
            echo "  (detected from: $DISCOVERED_WORKSPACE_SOURCE)"
        fi
        echo ""
        echo "  The standard OpenClaw layout keeps the workspace inside ~/.openclaw/:"
        echo ""
        echo "    ~/.openclaw/"
        echo "    ├── openclaw.json"
        echo "    ├── agents/"
        echo "    └── workspace/        ← Your AGENTS.md, SOUL.md, etc."
        echo ""
        echo "  This is compatible with:"
        echo "    • Fresh 'openclaw onboard' installs"
        echo "    • Docker deployments"  
        echo "    • Switching between stable/beta/dev versions"
        echo ""
        
        standardize_workspace="yes"
        if ! confirm "Move workspace to standard location (~/.openclaw/workspace)?" "y"; then
            standardize_workspace="no"
            print_warning "Keeping workspace at current location"
        fi
    fi
    
    # Determine legacy directory migration
    local migrate_legacy_dirs="yes"
    if [[ -n "$OPT_MIGRATE_LEGACY_DIRS" ]]; then
        migrate_legacy_dirs="$OPT_MIGRATE_LEGACY_DIRS"
    elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        migrate_legacy_dirs="yes"  # Default to yes in non-interactive
    fi
    
    echo ""
    
    # Show what will be checked
    echo -e "${BOLD}Will search and replace:${NC}"
    echo "  • /home/$old_user → /home/$new_user"
    for legacy in "${LEGACY_NAMES[@]}"; do
        if [[ "$legacy" != "$old_user" ]]; then
            echo "  • /home/$legacy → /home/$new_user (legacy)"
        fi
    done
    for legacy_dir in "${LEGACY_DIRS[@]}"; do
        echo "  • $legacy_dir → .openclaw (legacy)"
    done
    if [[ "$standardize_workspace" == "yes" ]]; then
        echo "  • Workspace → ~/.openclaw/workspace (standard)"
    fi
    echo ""
    
    # Determine symlink creation
    local create_symlinks="yes"
    if [[ -n "$OPT_CREATE_SYMLINKS" ]]; then
        create_symlinks="$OPT_CREATE_SYMLINKS"
        print_info "Symlink creation from command line: $create_symlinks"
    elif [[ "$OPT_NON_INTERACTIVE" == "true" ]]; then
        create_symlinks="yes"  # Default to yes in non-interactive
    else
        echo -e "${BOLD}Backward Compatibility:${NC}"
        echo ""
        echo "  Create symlinks so old paths continue to work?"
        echo "  (Useful if you have scripts or configs referencing old locations)"
        echo ""
        echo "  Symlinks created:"
        if [[ "$rename_user" == "yes" ]] && [[ "$old_user" != "$new_user" ]]; then
            echo "    • /home/$old_user → /home/$new_user"
        fi
        echo "    • ~/.moltbot → ~/.openclaw"
        echo "    • ~/.clawdbot → ~/.openclaw"
        if [[ "$standardize_workspace" == "yes" ]] && [[ -n "$DISCOVERED_WORKSPACE" ]]; then
            local old_ws_name=$(basename "$DISCOVERED_WORKSPACE")
            if [[ "$old_ws_name" != "workspace" ]]; then
                echo "    • ~/$old_ws_name → ~/.openclaw/workspace"
            fi
        fi
        echo ""
        
        if ! confirm "Create backward compatibility symlinks?" "y"; then
            create_symlinks="no"
            print_info "Skipping symlinks - old paths will not work"
        fi
    fi
    echo ""
    
    if ! confirm "Proceed with migration?" "n"; then
        echo "Aborted."
        exit 0
    fi
    
    echo ""
    
    # Run pre-flight checks
    if ! run_preflight_checks "$old_user"; then
        echo ""
        if ! confirm "Pre-flight checks failed. Continue anyway?" "n"; then
            echo "Aborted."
            exit 1
        fi
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${BOLD}RECOMMENDED: Create a VM snapshot or backup before proceeding${NC}  ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        if ! confirm "Have you created a backup/snapshot? Continue with migration?" "n"; then
            echo ""
            echo "Please create a backup first. You can run this script again afterward."
            exit 0
        fi
    else
        echo ""
        print_info "Skipping backup prompt (dry-run mode)"
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Starting migration...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Save old workspace path before migration
    local old_workspace_path="$DISCOVERED_WORKSPACE"
    local new_workspace_path="$new_home/.openclaw/workspace"
    if [[ "$standardize_workspace" != "yes" ]]; then
        # Workspace stays in place, just update the path
        new_workspace_path="${old_workspace_path//\/home\/$old_user/$new_home}"
    fi
    
    # Execute migration steps
    stop_services "$old_user"
    
    if [[ "$rename_user" == "yes" ]] && [[ "$old_user" != "$new_user" ]]; then
        rename_user "$old_user" "$new_user"
        update_sudoers "$old_user" "$new_user"
    else
        print_step "Skipping user rename (not requested or same username)"
    fi
    
    cleanup_system_services "$old_user"
    update_configs "$new_home" "$old_user" "$new_user"
    update_systemd_user_services "$new_home" "$old_user" "$new_user"
    update_shell_configs "$new_home" "$old_user" "$new_user"
    migrate_workspace_to_standard "$new_home" "$old_user" "$new_user" "$standardize_workspace"
    update_crontab "$old_user" "$new_user"
    fix_ownership "$new_home" "$new_user" "$old_user"
    
    # Create backward compatibility symlinks
    if [[ "$create_symlinks" == "yes" ]]; then
        create_compatibility_symlinks "$old_user" "$new_user" "$old_workspace_path" "$new_workspace_path"
    else
        print_step "Skipping symlink creation (not requested)"
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}Migration complete!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}Migration summary:${NC}"
    if [[ "$rename_user" == "yes" ]] && [[ "$old_user" != "$new_user" ]]; then
        echo "  User renamed: $old_user → $new_user"
        echo "  Home:         $new_home"
    else
        echo "  User:         $old_user (unchanged)"
        echo "  Home:         $old_home"
    fi
    echo "  Config:       $new_home/.openclaw/openclaw.json"
    if [[ "$standardize_workspace" == "yes" ]]; then
        echo "  Workspace:    $new_home/.openclaw/workspace (standardized)"
    else
        echo "  Workspace:    (current location, see config)"
    fi
    if [[ "$create_symlinks" == "yes" ]]; then
        echo ""
        echo -e "${BOLD}Compatibility symlinks created:${NC}"
        if [[ "$rename_user" == "yes" ]] && [[ "$old_user" != "$new_user" ]]; then
            echo "  /home/$old_user → $new_home"
        fi
        echo "  ~/.moltbot, ~/.clawdbot → ~/.openclaw"
    fi
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo ""
    if [[ "$rename_user" == "yes" ]] && [[ "$old_user" != "$new_user" ]]; then
        echo "  1. Reboot the system:"
        echo -e "     ${CYAN}sudo reboot${NC}"
        echo ""
        echo "  2. SSH as the new user:"
        echo -e "     ${CYAN}ssh $new_user@$(hostname)${NC}"
        echo ""
        echo "  3. Reinstall pnpm global packages (fixes hardcoded paths):"
        echo -e "     ${CYAN}pnpm add -g openclaw@latest${NC}"
        echo ""
        echo "  4. Reinstall the gateway daemon:"
        echo -e "     ${CYAN}openclaw gateway install --force${NC}"
        echo ""
        echo "  5. Start and verify:"
        echo -e "     ${CYAN}systemctl --user enable --now openclaw-gateway.service${NC}"
        echo -e "     ${CYAN}openclaw status${NC}"
    else
        echo "  1. Restart the gateway:"
        echo -e "     ${CYAN}systemctl --user restart openclaw-gateway.service${NC}"
        echo ""
        echo "  2. Verify:"
        echo -e "     ${CYAN}openclaw status${NC}"
    fi
    echo ""
    echo "  If messaging channels need re-auth, run:"
    echo -e "     ${CYAN}openclaw configure${NC}"
    echo ""
}

# Parse command line arguments
parse_args "$@"

# Run main
main
