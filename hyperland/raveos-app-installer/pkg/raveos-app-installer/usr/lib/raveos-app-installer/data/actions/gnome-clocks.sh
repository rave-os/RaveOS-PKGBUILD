#!/bin/bash
# GNOME Clocks (módosított hangokkal) telepítő script
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
        pacman -Rns --noconfirm "${installed[@]}"
    fi
}

if [[ "$ACTION" == "remove" ]]; then
    echo "Removing GNOME Clocks..."
    remove_installed_packages gnome-clocks
    echo "GNOME Clocks removal complete!"
    exit 0
fi

echo "Installing GNOME Clocks..."

# Függőségek
pacman -S --noconfirm --needed \
    itstool \
    vala \
    meson \
    gst-plugins-base \
    gst-plugins-good \
    gnome-clocks

echo "GNOME Clocks installation complete!"
