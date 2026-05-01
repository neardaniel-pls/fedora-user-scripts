#!/bin/bash
#
# setup.sh — Installer for Fedora Scripts Manager GUI and Nautilus extension
#
# USAGE:
#   ./setup.sh install     # Install everything
#   ./setup.sh uninstall   # Remove all installed components
#   ./setup.sh update      # Re-install (use after git pull)
#
# DEPENDENCIES:
#   - nautilus-python
#   - python3-gobject
#   - gtk4
#   - libadwaita
#   - zenity
#   - vte291 (optional, for interactive script support)
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/fedora-user-scripts"
CONFIG_FILE="${CONFIG_DIR}/config.sh"

NAUTILUS_EXT_DIR="${HOME}/.local/share/nautilus-python/extensions"
APP_INSTALL_DIR="${HOME}/.local/share/fedora-scripts-manager"
DESKTOP_DIR="${HOME}/.local/share/applications"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${BOLD}${GREEN}[INFO]${RESET} $*"; }
warn()  { echo -e "${BOLD}${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${BOLD}${RED}[ERROR]${RESET} $*" >&2; }

detect_sandbox() {
    if [ -f /.flatpak-info ] || [ -n "${container:-}" ] || [ -n "${FLATPAK_ID:-}" ]; then
        return 0
    fi
    if [ -n "${SNAP:-}" ] || [ -d /snap ]; then
        return 0
    fi
    return 1
}

is_flatpak() {
    [ -f /.flatpak-info ] || [ -n "${FLATPAK_ID:-}" ]
}

check_sudo() {
    if ! command -v sudo &>/dev/null; then
        return 1
    fi
    sudo -vn &>/dev/null 2>&1 || sudo -v &>/dev/null 2>&1
}

check_dependencies() {
    local missing=()
    local optional_missing=()

    for pkg in nautilus-python python3-gobject gtk4 libadwaita zenity; do
        if ! rpm -q "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if ! rpm -q vte291 &>/dev/null; then
        optional_missing+=("vte291")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required packages: ${missing[*]}"
        echo

        if detect_sandbox; then
            echo -e "${BOLD}${CYAN}─────────────────────────────────────────────────────────${RESET}"
            echo -e "${BOLD}${YELLOW}  Running inside a container/sandbox (Flatpak or Snap).${RESET}"
            echo -e "${BOLD}${YELLOW}  sudo is not available here.${RESET}"
            echo
            echo -e "  ${BOLD}Open a regular terminal (not inside VSCodium) and run:${RESET}"
            echo
            echo -e "  ${GREEN}sudo dnf install -y ${missing[*]}${RESET}"
            echo
            echo -e "  ${BOLD}Then re-run this installer from that terminal:${RESET}"
            echo
            echo -e "  ${GREEN}cd \"${REPO_DIR}\" && ./setup.sh install${RESET}"
            echo -e "${BOLD}${CYAN}─────────────────────────────────────────────────────────${RESET}"
            if [ ${#optional_missing[@]} -gt 0 ]; then
                echo
                warn "Optional packages also available: ${optional_missing[*]}"
            fi
            exit 1
        fi

        read -rp "Install them now? [y/N] " answer
        if [[ "${answer,,}" == "y" ]]; then
            if ! check_sudo; then
                error "sudo is not available or not configured."
                echo
                echo -e "  Run manually: ${GREEN}sudo dnf install -y ${missing[*]}${RESET}"
                echo -e "  Then re-run:  ${GREEN}./setup.sh install${RESET}"
                exit 1
            fi
            sudo dnf install -y "${missing[@]}" || {
                error "Failed to install packages."
                exit 1
            }
            info "Required packages installed."
        else
            error "Cannot continue without required packages."
            echo
            echo -e "  Install manually: ${GREEN}sudo dnf install -y ${missing[*]}${RESET}"
            exit 1
        fi
    fi

    if [ ${#optional_missing[@]} -gt 0 ]; then
        warn "Optional packages not installed: ${optional_missing[*]}"
        warn "Install vte291 for interactive script support in the GUI."
    fi

    if ! command -v python3 &>/dev/null; then
        error "python3 not found."
        exit 1
    fi

    if ! python3 -c "import gi; gi.require_version('Gtk', '4.0'); gi.require_version('Adw', '1')" 2>/dev/null; then
        error "GTK4/Libadwaita Python bindings not available."
        echo -e "  Install: ${GREEN}sudo dnf install python3-gobject gtk4 libadwaita${RESET}"
        exit 1
    fi
}

ensure_config() {
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
        info "Created config file: $CONFIG_FILE"
    fi

    if ! grep -q "^FEDORA_SCRIPTS_DIR=" "$CONFIG_FILE" 2>/dev/null; then
        echo "FEDORA_SCRIPTS_DIR=\"${REPO_DIR}\"" >> "$CONFIG_FILE"
        info "Set FEDORA_SCRIPTS_DIR=${REPO_DIR} in config."
    else
        sed -i "s|^FEDORA_SCRIPTS_DIR=.*|FEDORA_SCRIPTS_DIR=\"${REPO_DIR}\"|" "$CONFIG_FILE"
        info "Updated FEDORA_SCRIPTS_DIR in config."
    fi
}

check_path_safety() {
    for dir in "$NAUTILUS_EXT_DIR" "$APP_INSTALL_DIR" "$DESKTOP_DIR" "$CONFIG_DIR"; do
        if [ -L "$dir" ]; then
            error "Refusing to follow symlink: $dir"
            exit 1
        fi
    done
}

install_nautilus_extension() {
    check_path_safety
    mkdir -p "$NAUTILUS_EXT_DIR"
    cp "${REPO_DIR}/nautilus/fedora-scripts-extension.py" "${NAUTILUS_EXT_DIR}/"
    info "Installed Nautilus extension to ${NAUTILUS_EXT_DIR}/"
}

install_gui_app() {
    rm -rf "$APP_INSTALL_DIR"
    mkdir -p "$APP_INSTALL_DIR"
    cp -r "${REPO_DIR}/gui/fedora_scripts_manager" "${APP_INSTALL_DIR}/"
    cp "${REPO_DIR}/gui/run.py" "${APP_INSTALL_DIR}/"
    chmod +x "${APP_INSTALL_DIR}/run.py"
    info "Installed GUI app to ${APP_INSTALL_DIR}/"

    mkdir -p "$DESKTOP_DIR"
    desktop_src="${REPO_DIR}/gui/data/org.fedoraproscripts.Manager.desktop"
    desktop_dst="${DESKTOP_DIR}/org.fedoraproscripts.Manager.desktop"
    sed "s|Exec=python3 /usr/share/fedora-scripts-manager/run.py|Exec=python3 ${APP_INSTALL_DIR}/run.py|" \
        "$desktop_src" > "$desktop_dst"
    chmod +x "$desktop_dst"
    info "Installed .desktop file to ${DESKTOP_DIR}/"

    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
}

restart_nautilus() {
    if pgrep -x nautilus &>/dev/null; then
        nautilus -q 2>/dev/null || true
        info "Restarted Nautilus."
    fi
}

do_install() {
    info "Starting installation..."
    echo

    if detect_sandbox; then
        warn "Detected sandbox/container environment."
        warn "File installation will target the host filesystem via ~/ paths."
        warn "If files don't appear, run this from a regular terminal instead."
        echo
    fi

    check_dependencies
    ensure_config
    install_nautilus_extension
    install_gui_app
    restart_nautilus

    echo
    info "Installation complete!"
    echo
    echo -e "  ${BOLD}GUI App:${RESET}   Launch from Activities → 'Fedora Scripts Manager'"
    echo -e "  ${BOLD}Context Menu:${RESET} Right-click PDF/PNG/JPEG files → 'Clean Metadata'"
    echo -e "  ${BOLD}Terminal:${RESET}    python3 ${APP_INSTALL_DIR}/run.py"
    echo
}

do_uninstall() {
    info "Uninstalling..."

    rm -f "${NAUTILUS_EXT_DIR}/fedora-scripts-extension.py"
    info "Removed Nautilus extension."

    rm -rf "$APP_INSTALL_DIR"
    info "Removed GUI app."

    rm -f "${DESKTOP_DIR}/org.fedoraproscripts.Manager.desktop"
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    info "Removed .desktop file."

    restart_nautilus

    echo
    info "Uninstallation complete."
    info "Config file preserved: $CONFIG_FILE"
}

do_update() {
    info "Updating installation..."
    echo
    install_nautilus_extension
    install_gui_app
    restart_nautilus
    echo
    info "Update complete."
}

case "${1:-}" in
    install)
        do_install
        ;;
    uninstall)
        do_uninstall
        ;;
    update)
        do_update
        ;;
    *)
        echo "Usage: $(basename "$0") {install|uninstall|update}"
        exit 1
        ;;
esac
