#!/bin/bash
# Steam + ProtonGE telepítő script
# Környezeti változók: INSTALL_USER, INSTALL_HOME, REPO_CONFIGS_URL

set -e

USER="$INSTALL_USER"
HOME="$INSTALL_HOME"
REPO_URL="${REPO_CONFIGS_URL:-https://git.rp1.hu/Nippy/Raveos-App-beta/raw/branch/main/raveos-app-installer-beta/configs/}"
ACTION="${1:-install}"
CONFIG_OVERRIDE_DIR="${RAVEOS_CONFIG_OVERRIDE_DIR:-/etc/raveos-beta/configs}"
CONFIG_PACKAGE_DIR="${RAVEOS_CONFIG_PACKAGE_DIR:-/usr/share/raveos-app-installer-beta/configs}"

run_as_user() {
    sudo -u "$USER" env HOME="$HOME" "$@"
}

resolve_local_config() {
    local name="$1"
    local candidate
    for candidate in \
        "$CONFIG_OVERRIDE_DIR/$name" \
        "$CONFIG_PACKAGE_DIR/$name"
    do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

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
    echo "Removing Steam for $USER..."
    remove_installed_packages steam proton-cachyos
    rm -f "$HOME/.local/bin/update-proton-ge"
    rm -f "$HOME/.local/share/Steam/steam_dev.cfg"
    rm -f "$HOME/.steam/steam/steam_dev.cfg"
    echo "Steam removal complete!"
    exit 0
fi

echo "Installing Steam for $USER..."

# GPU detektálás - AMD-hez vulkan-radeon kell
nVidia=$(lspci | grep -i "NVIDIA" -c || true)
if [[ $nVidia -eq 0 ]]; then
    echo "AMD GPU detected, installing vulkan-radeon..."
    pacman -S --noconfirm --needed vulkan-radeon lib32-vulkan-radeon
fi

# Steam telepítés
pacman -S --noconfirm --needed steam

# Steam data dir meghatározása (symlink-kompatibilis)
STEAM_DATA="$HOME/.local/share/Steam"
if [ -L "$HOME/.steam/steam" ]; then
    # Symlink már létezik (Steam volt már indítva)
    STEAM_DATA=$(readlink -f "$HOME/.steam/steam")
elif [ -d "$HOME/.steam/steam" ]; then
    # Valódi mappa
    STEAM_DATA="$HOME/.steam/steam"
fi

# Steam config letöltése
echo "Downloading Steam config..."
run_as_user mkdir -p "$STEAM_DATA"
if local_cfg="$(resolve_local_config steam_dev.cfg)"; then
    cp "$local_cfg" "$STEAM_DATA/steam_dev.cfg"
else
    wget -q -O "$STEAM_DATA/steam_dev.cfg" "${REPO_URL}steam_dev.cfg" || true
fi
chown "$USER:$USER" "$STEAM_DATA/steam_dev.cfg" 2>/dev/null || true

# ProtonGE updater script letöltése
echo "Downloading ProtonGE updater..."
run_as_user mkdir -p "$HOME/.local/bin"
if local_cfg="$(resolve_local_config update-proton-ge)"; then
    cp "$local_cfg" "$HOME/.local/bin/update-proton-ge"
else
    wget -q -O "$HOME/.local/bin/update-proton-ge" "${REPO_URL}update-proton-ge"
fi
chmod +x "$HOME/.local/bin/update-proton-ge"
chown "$USER:$USER" "$HOME/.local/bin/update-proton-ge"

# ProtonGE telepítése az updater scripttel (mindig legfrissebb)
echo "Installing ProtonGE..."
run_as_user "$HOME/.local/bin/update-proton-ge" || true

# proton-cachyos telepítése (mindig legfrissebb, CachyOS repo)
echo "Installing proton-cachyos..."
pacman -S --noconfirm --needed proton-cachyos || true

# GSK_RENDERER beállítás
if ! grep -q "GSK_RENDERER" /etc/environment 2>/dev/null; then
    echo "GSK_RENDERER=gl" >> /etc/environment
fi

# Felesleges desktop fájl törlése
rm -f /usr/share/applications/steam-native.desktop 2>/dev/null || true

echo "Steam installation complete!"
