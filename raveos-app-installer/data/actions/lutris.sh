#!/bin/bash
# Lutris + Wine telepítő script
# Környezeti változók: INSTALL_USER, INSTALL_HOME

set -e

USER="$INSTALL_USER"
HOME="$INSTALL_HOME"
ACTION="${1:-install}"

remove_installed_packages() {
    local installed=()
    local pkg
    for pkg in "$@"; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            installed+=("$pkg")
        fi
    done
    if ((${#installed[@]})); then
        pacman -Rcns --noconfirm "${installed[@]}"
    fi
}

if [[ "$ACTION" == "remove" ]]; then
    echo "Removing Lutris + Wine for $USER..."
    remove_installed_packages lutris wine winetricks wine-mono wine-gecko
    echo "Lutris + Wine removal complete!"
    exit 0
fi

echo "Installing Lutris + Wine for $USER..."

# Lutris és Wine telepítése
pacman -S --noconfirm --needed \
    lutris \
    wine \
    winetricks \
    wine-mono \
    wine-gecko

echo "Lutris + Wine installation complete!"
