#!/bin/bash
# Nyomtató támogatás telepítő script
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
    echo "Removing printer support..."
    systemctl disable --now cups 2>/dev/null || true
    remove_installed_packages \
        cups \
        hplip \
        system-config-printer \
        epson-inkjet-printer-escpr \
        epson-inkjet-printer-escpr2
    echo "Printer support removal complete!"
    exit 0
fi

echo "Installing printer support..."

# Alap nyomtató csomagok
pacman -S --noconfirm --needed \
    cups \
    hplip \
    system-config-printer

# Epson nyomtatók
# Ezek a RaveOS környezetben repo-ból is elérhetők, ezért ne használjunk
# interaktív `yay` futtatást egy rootból indított installer scriptben.
pacman -S --noconfirm --needed \
    epson-inkjet-printer-escpr \
    epson-inkjet-printer-escpr2 \
    || true

# CUPS szolgáltatás engedélyezése
systemctl enable cups
systemctl start cups

echo "Printer support installation complete!"
