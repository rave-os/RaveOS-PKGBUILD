#!/bin/bash
# CoreCTRL (AMD GPU vezérlő) telepítő script
# Környezeti változók: INSTALL_USER, INSTALL_HOME, REPO_CONFIGS_URL

set -e

USER="$INSTALL_USER"
HOME="$INSTALL_HOME"
REPO_URL="${REPO_CONFIGS_URL:-https://git.rp1.hu/Nippy/Raveos-App-beta/raw/branch/main/raveos-app-installer-beta/configs/}"
ACTION="${1:-install}"
CONFIG_OVERRIDE_DIR="${RAVEOS_CONFIG_OVERRIDE_DIR:-/etc/raveos-beta/configs}"
CONFIG_PACKAGE_DIR="${RAVEOS_CONFIG_PACKAGE_DIR:-/usr/share/raveos-app-installer-beta/configs}"

run_as_user() {
    runuser -u "$USER" -- env HOME="$HOME" "$@"
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
        pacman -Rcns --noconfirm "${installed[@]}"
    fi
}

if [[ "$ACTION" == "remove" ]]; then
    echo "Removing CoreCTRL for $USER..."
    remove_installed_packages corectrl
    rm -f /etc/polkit-1/rules.d/90-corectrl.rules
    rm -f "$HOME/.config/autostart/org.corectrl.CoreCtrl.desktop"
    rm -rf "$HOME/.config/corectrl"
    echo "CoreCTRL removal complete!"
    exit 0
fi

echo "Installing CoreCTRL for $USER..."

# CoreCTRL telepítése
pacman -S --noconfirm --needed corectrl

# CoreCTRL config letöltése
echo "Downloading CoreCTRL config..."
run_as_user mkdir -p "$HOME/.config/corectrl"
if local_cfg="$(resolve_local_config corectrl.ini)"; then
    cp "$local_cfg" "$HOME/.config/corectrl/corectrl.ini"
else
    wget -q -O "$HOME/.config/corectrl/corectrl.ini" "${REPO_URL}corectrl.ini" || true
fi
chown "$USER:$USER" "$HOME/.config/corectrl/corectrl.ini" 2>/dev/null || true

# Autostart beállítása
run_as_user mkdir -p "$HOME/.config/autostart"
cp /usr/share/applications/org.corectrl.CoreCtrl.desktop "$HOME/.config/autostart/"
chown "$USER:$USER" "$HOME/.config/autostart/org.corectrl.CoreCtrl.desktop"

# Polkit szabály létrehozása (jelszó nélküli indítás)
cat > /etc/polkit-1/rules.d/90-corectrl.rules << EOF
polkit.addRule(function(action, subject) {
    if ((action.id == "org.corectrl.helper.init" ||
         action.id == "org.corectrl.helperkiller.init") &&
        subject.local == true &&
        subject.active == true &&
        subject.isInGroup("$USER")) {
        return polkit.Result.YES;
    }
});
EOF

# AMD GPU kernel paraméterek hozzáadása (ha systemd-boot)
if [[ -d /boot/loader/entries ]]; then
    for conf in /boot/loader/entries/*.conf; do
        if [[ -f "$conf" ]]; then
            if ! grep -q "amdgpu.ppfeaturemask" "$conf"; then
                sed -i '/^options/s/$/ amdgpu.ppfeaturemask=0xffffffff/' "$conf"
            fi
        fi
    done
fi

# GRUB esetén
if [[ -f /etc/default/grub ]]; then
    if ! grep -q "amdgpu.ppfeaturemask" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="amdgpu.ppfeaturemask=0xffffffff \1"/' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
    fi
fi

echo "CoreCTRL installation complete!"
echo "Please reboot for kernel parameters to take effect."
