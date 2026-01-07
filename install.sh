#!/usr/bin/env bash
# Hamr installation script
# Usage: ./install.sh [--uninstall]
# Or: curl -fsSL https://raw.githubusercontent.com/stewart86/hamr/main/install.sh | bash

set -e

HAMR_REPO="https://github.com/stewart86/hamr.git"
HAMR_INSTALL_DIR="$HOME/.local/share/hamr"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect if running via curl | bash (piped input, no valid SCRIPT_DIR)
detect_and_clone() {
    # BASH_SOURCE is empty when script is piped
    if [[ -z "${BASH_SOURCE[0]}" ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
        info "Running via curl | bash, cloning repository..."
        
        if [[ -d "$HAMR_INSTALL_DIR" ]]; then
            if [[ -d "$HAMR_INSTALL_DIR/.git" ]]; then
                info "Existing installation found, updating..."
                cd "$HAMR_INSTALL_DIR"
                git pull --rebase
                exec "$HAMR_INSTALL_DIR/install.sh" "$@"
            else
                warn "Directory exists but is not a git repo: $HAMR_INSTALL_DIR"
                error "Please remove it manually and retry"
            fi
        fi
        
        git clone "$HAMR_REPO" "$HAMR_INSTALL_DIR"
        exec "$HAMR_INSTALL_DIR/install.sh" "$@"
    fi
}

detect_and_clone "$@"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
QUICKSHELL_DIR="$CONFIG_DIR/quickshell"
HAMR_LINK="$QUICKSHELL_DIR/hamr"

check_command() {
    command -v "$1" >/dev/null 2>&1
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "$ID" in
            arch|manjaro|endeavouros|artix|parabola)
                echo "arch"
                ;;
            debian|ubuntu|pop|linuxmint|elementary)
                echo "debian"
                ;;
            fedora|rhel|centos|rocky|alma)
                echo "fedora"
                ;;
            opensuse*|suse)
                echo "suse"
                ;;
            nixos)
                echo "nixos"
                ;;
            void)
                echo "void"
                ;;
            gentoo)
                echo "gentoo"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Package mappings: command -> arch:debian:fedora:suse:void:gentoo
# Verified against repology.org
declare -A PKG_MAP=(
    ["qs"]="quickshell:BUILD_FROM_SOURCE:quickshell:quickshell:quickshell:gui-apps/quickshell"
    ["python3"]="python:python3:python3:python3:python3:dev-lang/python"
    ["jq"]="jq:jq:jq:jq:jq:app-misc/jq"
    ["wl-copy"]="wl-clipboard:wl-clipboard:wl-clipboard:wl-clipboard:wl-clipboard:gui-apps/wl-clipboard"
    ["cliphist"]="cliphist:cliphist:cliphist:cliphist:cliphist:app-misc/cliphist"
    ["slurp"]="slurp:slurp:slurp:slurp:slurp:gui-apps/slurp"
    ["grim"]="grim:grim:grim:grim:grim:gui-apps/grim"
    ["hyprpicker"]="hyprpicker:hyprpicker:hyprpicker:hyprpicker:hyprpicker:gui-apps/hyprpicker"
    ["matugen"]="matugen:BUILD_FROM_SOURCE:BUILD_FROM_SOURCE:BUILD_FROM_SOURCE:BUILD_FROM_SOURCE:x11-misc/matugen"
)

get_pkg_name() {
    local cmd="$1"
    local distro="$2"
    local mapping="${PKG_MAP[$cmd]}"
    
    if [[ -z "$mapping" ]]; then
        echo "$cmd"
        return
    fi
    
    local idx
    case "$distro" in
        arch) idx=1 ;;
        debian) idx=2 ;;
        fedora) idx=3 ;;
        suse) idx=4 ;;
        void) idx=5 ;;
        gentoo) idx=6 ;;
        *) idx=1 ;;
    esac
    
    echo "$mapping" | cut -d: -f"$idx"
}

install_packages() {
    local distro="$1"
    shift
    local packages=("$@")
    
    case "$distro" in
        arch)
            # Try paru, yay, or pacman
            if check_command paru; then
                paru -S --needed --noconfirm "${packages[@]}"
            elif check_command yay; then
                yay -S --needed --noconfirm "${packages[@]}"
            else
                sudo pacman -S --needed --noconfirm "${packages[@]}"
            fi
            ;;
        debian)
            sudo apt-get update
            sudo apt-get install -y "${packages[@]}"
            ;;
        fedora)
            sudo dnf install -y "${packages[@]}"
            ;;
        suse)
            sudo zypper install -y "${packages[@]}"
            ;;
        void)
            sudo xbps-install -y "${packages[@]}"
            ;;
        gentoo)
            sudo emerge --ask=n "${packages[@]}"
            ;;
        *)
            error "Cannot auto-install on $distro"
            ;;
    esac
}

setup_fedora_copr() {
    if ! check_command dnf; then
        error "dnf not found"
    fi
    
    # Check if COPR is already enabled
    if dnf repolist | grep -q "avengemedia-dms"; then
        info "COPR avengemedia/dms already enabled"
        return
    fi
    
    info "Enabling COPR repository: avengemedia/dms"
    sudo dnf copr enable -y avengemedia/dms
}

check_dependencies() {
    local distro
    distro=$(detect_distro)
    
    info "Detected distribution: $distro"
    echo ""
    
    # Required dependencies
    local required=("qs:Quickshell" "python3:Python 3.9+")
    local missing_required=()
    
    info "Checking required dependencies..."
    for dep in "${required[@]}"; do
        local cmd="${dep%%:*}"
        local desc="${dep#*:}"
        if check_command "$cmd"; then
            echo "  [ok] $cmd"
        else
            echo "  [missing] $cmd - $desc"
            missing_required+=("$cmd")
        fi
    done
    
    if [[ ${#missing_required[@]} -gt 0 ]]; then
        echo ""
        
        # Check if we can auto-install
        local can_auto_install=true
        local packages_to_install=()
        
        for cmd in "${missing_required[@]}"; do
            local pkg
            pkg=$(get_pkg_name "$cmd" "$distro")
            if [[ "$pkg" == "BUILD_FROM_SOURCE" ]]; then
                can_auto_install=false
            else
                packages_to_install+=("$pkg")
            fi
        done
        
        if [[ "$can_auto_install" == "true" && ${#packages_to_install[@]} -gt 0 ]]; then
            info "Installing required dependencies: ${packages_to_install[*]}"
            
            # Fedora needs COPR enabled first for quickshell
            if [[ "$distro" == "fedora" ]] && [[ " ${missing_required[*]} " == *" qs "* ]]; then
                setup_fedora_copr
            fi
            
            install_packages "$distro" "${packages_to_install[@]}"
            
            # Verify installation
            for cmd in "${missing_required[@]}"; do
                if ! check_command "$cmd"; then
                    error "Failed to install $cmd"
                fi
            done
            info "Dependencies installed successfully"
        else
            # Can't auto-install
            warn "Cannot auto-install some dependencies on $distro"
            echo ""
            for cmd in "${missing_required[@]}"; do
                local pkg
                pkg=$(get_pkg_name "$cmd" "$distro")
                if [[ "$pkg" == "BUILD_FROM_SOURCE" ]]; then
                    echo "  $cmd: Build from source required"
                    if [[ "$cmd" == "qs" ]]; then
                        echo "         See: https://quickshell.outfoxxed.me/docs/v0.2.1/guide/install-setup/"
                    fi
                fi
            done
            echo ""
            error "Please install required dependencies and retry."
        fi
    fi
    
    # Optional dependencies (just show info, don't install)
    local optional=("jq:JSON processor" "wl-copy:Clipboard" "cliphist:Clipboard history" "slurp:Region selector" "grim:Screenshot" "hyprpicker:Color picker" "matugen:Material colors")
    local missing_optional=()
    
    echo ""
    info "Checking optional dependencies..."
    for dep in "${optional[@]}"; do
        local cmd="${dep%%:*}"
        local desc="${dep#*:}"
        if check_command "$cmd"; then
            echo "  [ok] $cmd - $desc"
        else
            echo "  [missing] $cmd - $desc"
            missing_optional+=("$cmd")
        fi
    done
    echo ""
}

create_default_config() {
    local config_file="$CONFIG_DIR/hamr/config.json"
    
    # Default config template
    local default_config='{
  "apps": {
    "terminal": "ghostty",
    "terminalArgs": "--class=floating.terminal",
    "shell": "zsh"
  },
  "search": {
    "nonAppResultDelay": 30,
    "debounceMs": 50,
    "pluginDebounceMs": 150,
    "maxHistoryItems": 500,
    "maxDisplayedResults": 16,
    "maxRecentItems": 20,
    "shellHistoryLimit": 50,
    "engineBaseUrl": "https://www.google.com/search?q=",
    "excludedSites": ["quora.com", "facebook.com"],
    "prefix": {
      "action": "/",
      "app": ">",
      "clipboard": ";",
      "emojis": ":",
      "file": "~",
      "math": "=",
      "shellCommand": "$",
      "shellHistory": "!",
      "webSearch": "?"
    },
    "shellHistory": {
      "enable": true,
      "shell": "auto",
      "customHistoryPath": "",
      "maxEntries": 500
    },
    "actionKeys": ["u", "i", "o", "p"]
  },
  "imageBrowser": {
    "useSystemFileDialog": false,
    "columns": 4,
    "cellAspectRatio": 1.333,
    "sidebarWidth": 140
  },
  "appearance": {
    "backgroundTransparency": 0.2,
    "contentTransparency": 0.2,
    "launcherXRatio": 0.5,
    "launcherYRatio": 0.1
  },
  "sizes": {
    "searchWidth": 580,
    "searchInputHeight": 40,
    "maxResultsHeight": 600,
    "resultIconSize": 40,
    "imageBrowserWidth": 1200,
    "imageBrowserHeight": 690,
    "windowPickerMaxWidth": 350,
    "windowPickerMaxHeight": 220
  },
  "fonts": {
    "main": "Google Sans Flex",
    "monospace": "JetBrains Mono NF",
    "reading": "Readex Pro",
    "icon": "Material Symbols Rounded"
  },
  "paths": {
    "wallpaperDir": "",
    "colorsJson": ""
  }
}'

    mkdir -p "$CONFIG_DIR/hamr"
    
    if [[ -f "$config_file" ]]; then
        # Config exists - merge new keys without overwriting existing values
        if check_command jq; then
            info "Updating config with new default keys (preserving existing values)..."
            local tmp_file
            tmp_file=$(mktemp)
            # Use jq to merge: existing values take priority over defaults
            echo "$default_config" | jq -s '.[0] * .[1]' - "$config_file" > "$tmp_file"
            mv "$tmp_file" "$config_file"
        else
            info "Config exists. Install jq to auto-merge new config options."
        fi
    else
        # Create new config
        info "Creating default config: $config_file"
        echo "$default_config" > "$config_file"
    fi
}

install_hamr() {
    info "Installing hamr..."

    # Create quickshell config directory
    mkdir -p "$QUICKSHELL_DIR"

    # Remove existing symlink or directory
    if [[ -L "$HAMR_LINK" ]]; then
        rm "$HAMR_LINK"
    elif [[ -d "$HAMR_LINK" ]]; then
        warn "Existing hamr directory found at $HAMR_LINK"
        read -p "Replace with symlink? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
        rm -rf "$HAMR_LINK"
    fi

    # Create symlink
    ln -s "$SCRIPT_DIR" "$HAMR_LINK"
    info "Created symlink: $HAMR_LINK -> $SCRIPT_DIR"

    # Create user plugins directory
    mkdir -p "$CONFIG_DIR/hamr/plugins"
    info "Created user plugins directory: $CONFIG_DIR/hamr/plugins"

    # Create or update default config
    create_default_config

    # Copy switchwall.sh to user config if it doesn't exist
    mkdir -p "$CONFIG_DIR/hamr/scripts"
    if [[ ! -f "$CONFIG_DIR/hamr/scripts/switchwall.sh" ]]; then
        cp "$SCRIPT_DIR/scripts/colors/switchwall.sh" "$CONFIG_DIR/hamr/scripts/switchwall.sh"
        chmod +x "$CONFIG_DIR/hamr/scripts/switchwall.sh"
        info "Copied switchwall.sh to $CONFIG_DIR/hamr/scripts/"
    fi

    # Make scripts executable
    chmod +x "$SCRIPT_DIR/scripts/thumbnails/thumbgen.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/scripts/thumbnails/thumbgen.py" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/scripts/ocr/ocr-index.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/scripts/ocr/ocr-index.py" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/scripts/colors/switchwall.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/hamr" 2>/dev/null || true

    # Install hamr command to ~/.local/bin
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    ln -sf "$SCRIPT_DIR/hamr" "$bin_dir/hamr"
    info "Installed hamr command: $bin_dir/hamr"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        warn "$bin_dir is not in your PATH"
        echo "Add to your shell rc file:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    info "Installation complete!"
    echo ""
    echo "Start hamr with:"
    echo "  hamr"
    echo ""
    echo "Commands:"
    echo "  hamr              Start daemon"
    echo "  hamr toggle       Toggle open/close"
    echo "  hamr plugin NAME  Open plugin directly"
    echo ""
    
    # Detect compositor and show appropriate instructions
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        show_hyprland_instructions
    elif [[ -n "${NIRI_SOCKET:-}" ]]; then
        show_niri_instructions
    else
        echo "Add to your compositor config for autostart."
        echo ""
        echo "For Hyprland: $0 --hyprland-config"
        echo "For Niri: $0 --niri-config"
    fi
}

show_hyprland_instructions() {
    echo "Hyprland detected! Add to ~/.config/hypr/hyprland.conf:"
    echo ""
    echo "  # Autostart hamr"
    echo "  exec-once = hamr"
    echo ""
    echo "  # Toggle hamr with Super key"
    echo "  bind = SUPER, SUPER_L, global, quickshell:hamrToggle"
    echo "  bindr = SUPER, SUPER_L, global, quickshell:hamrToggleRelease"
    echo ""
    echo "  # Or with Ctrl+Space"
    echo "  bind = CTRL, Space, exec, hamr toggle"
    echo ""
}

show_niri_instructions() {
    echo "Niri detected!"
    echo ""
    echo "1. Enable systemd service (recommended):"
    echo "   $0 --enable-service"
    echo ""
    echo "2. Add keybinding to ~/.config/niri/config.kdl:"
    echo ""
    echo "   binds {"
    echo "       // Toggle hamr with Ctrl+Space"
    echo "       Ctrl+Space { spawn \"hamr\" \"toggle\"; }"
    echo ""
    echo "       // Or with Super key (Mod key)"
    echo "       Mod+Space { spawn \"hamr\" \"toggle\"; }"
    echo "   }"
    echo ""
}

install_systemd_service() {
    local service_src="$SCRIPT_DIR/hamr.service"
    local service_dest="$HOME/.config/systemd/user/hamr.service"
    
    if [[ ! -f "$service_src" ]]; then
        error "hamr.service not found in $SCRIPT_DIR"
    fi
    
    mkdir -p "$HOME/.config/systemd/user"
    cp "$service_src" "$service_dest"
    info "Installed systemd service: $service_dest"
    
    systemctl --user daemon-reload
    systemctl --user enable hamr.service
    
    # Try to add wants for niri if it exists
    if systemctl --user list-unit-files niri.service &>/dev/null; then
        systemctl --user add-wants niri.service hamr.service
        info "Enabled hamr.service (will start with niri.service)"
    else
        info "Enabled hamr.service"
    fi
    
    echo ""
    echo "To start now: systemctl --user start hamr.service"
    echo "To check status: systemctl --user status hamr.service"
    echo "To view logs: journalctl --user -u hamr.service -f"
}

disable_systemd_service() {
    systemctl --user stop hamr.service 2>/dev/null || true
    systemctl --user disable hamr.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/niri.service.wants/hamr.service" 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/hamr.service"
    systemctl --user daemon-reload
    info "Disabled and removed hamr.service"
}

update_hamr() {
    info "Updating hamr..."

    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        error "Not a git repository. Cannot update."
    fi

    cd "$SCRIPT_DIR"
    
    # Check for local changes
    if [[ -n $(git status --porcelain) ]]; then
        warn "Local changes detected:"
        git status --short
        echo ""
        echo "Options:"
        echo "  1. Stash changes:  git stash && $0 -U && git stash pop"
        echo "  2. Commit changes: git add -A && git commit -m 'local changes'"
        echo "  3. Discard changes: git checkout -- ."
        echo ""
        error "Please resolve local changes before updating."
    fi

    git pull --rebase

    info "Update complete!"
    echo ""
    echo "Restart hamr to apply changes:"
    echo "  systemctl --user restart hamr"
    echo "  # or kill and restart manually"
}

uninstall_hamr() {
    info "Uninstalling hamr..."

    # Disable service if running
    if systemctl --user is-active hamr.service &>/dev/null; then
        systemctl --user stop hamr.service
    fi
    if systemctl --user is-enabled hamr.service &>/dev/null; then
        disable_systemd_service
    fi

    if [[ -L "$HAMR_LINK" ]]; then
        rm "$HAMR_LINK"
        info "Removed symlink: $HAMR_LINK"
    elif [[ -d "$HAMR_LINK" ]]; then
        warn "Found directory instead of symlink at $HAMR_LINK"
        read -p "Remove it? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && rm -rf "$HAMR_LINK"
    else
        warn "No hamr installation found at $HAMR_LINK"
    fi

    # Remove hamr command from ~/.local/bin
    local bin_link="$HOME/.local/bin/hamr"
    if [[ -L "$bin_link" ]]; then
        rm "$bin_link"
        info "Removed command: $bin_link"
    fi

    info "Uninstall complete. User data in $CONFIG_DIR/hamr/ was preserved."
}

# Main
case "${1:-}" in
    --update|-U)
        update_hamr
        ;;
    --uninstall|-u)
        uninstall_hamr
        ;;
    --check|-c)
        check_dependencies
        ;;
    --hyprland-config)
        show_hyprland_instructions
        ;;
    --niri-config)
        show_niri_instructions
        ;;
    --enable-service)
        install_systemd_service
        ;;
    --disable-service)
        disable_systemd_service
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Install:"
        echo "  curl -fsSL https://raw.githubusercontent.com/stewart86/hamr/main/install.sh | bash"
        echo ""
        echo "Options:"
        echo "  (none)             Install hamr"
        echo "  --check, -c        Check dependencies only"
        echo "  --update, -U       Update hamr via git pull"
        echo "  --uninstall, -u    Remove hamr installation"
        echo "  --hyprland-config  Show Hyprland configuration"
        echo "  --niri-config      Show Niri configuration"
        echo "  --enable-service   Enable systemd user service"
        echo "  --disable-service  Disable systemd user service"
        echo "  --help, -h         Show this help"
        echo ""
        echo "Supported compositors: Hyprland, Niri"
        ;;
    *)
        check_dependencies
        install_hamr
        ;;
esac
