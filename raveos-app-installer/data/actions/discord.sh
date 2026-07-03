#!/bin/bash
# Discord + Vencord telepítő script
# Környezeti változók: INSTALL_USER, INSTALL_HOME, REPO_CONFIGS_URL

set -e

USER="$INSTALL_USER"
HOME="$INSTALL_HOME"
REPO_URL="${REPO_CONFIGS_URL:-https://git.rp1.hu/Nippy/Raveos-App-beta/raw/branch/main/raveos-app-installer-beta/configs/}"
ACTION="${1:-install}"
TARGET_UID="${TARGET_UID:-$(id -u "$USER" 2>/dev/null || true)}"
TARGET_XDG_RUNTIME_DIR="${TARGET_XDG_RUNTIME_DIR:-/run/user/$TARGET_UID}"
CONFIG_OVERRIDE_DIR="${RAVEOS_CONFIG_OVERRIDE_DIR:-/etc/raveos-beta/configs}"
CONFIG_PACKAGE_DIR="${RAVEOS_CONFIG_PACKAGE_DIR:-/usr/share/raveos-app-installer-beta/configs}"

run_as_user() {
    runuser -u "$USER" -- env \
        HOME="$HOME" \
        XDG_RUNTIME_DIR="$TARGET_XDG_RUNTIME_DIR" \
        "$@"
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
    echo "Removing Discord + Vencord for $USER..."
    remove_installed_packages discord
    rm -f /etc/pacman.d/hooks/vencord-reinstall.hook
    rm -f /usr/local/bin/vencord-reinstall.sh
    rm -f /usr/local/bin/VencordInstallerCli-linux
    rm -rf "$HOME/.config/Vencord"
    echo "Discord + Vencord removal complete!"
    exit 0
fi

echo "Installing Discord + Vencord for $USER..."

# Discord telepítése
pacman -S --noconfirm --needed discord

# Secure temp directory
TMPDIR=$(mktemp -d)
chmod 755 "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# Vencord Installer letöltése
echo "Downloading Vencord Installer..."
VENCORD_URL="https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli-linux"
wget -q -O "$TMPDIR/VencordInstallerCli-linux" "$VENCORD_URL"

# Verify it's an ELF binary (not a malicious script)
FILE_TYPE=$(file -b "$TMPDIR/VencordInstallerCli-linux")
if [[ "$FILE_TYPE" != ELF* ]]; then
    echo "ERROR: Downloaded file is not a valid ELF binary: $FILE_TYPE"
    exit 1
fi

chmod +x "$TMPDIR/VencordInstallerCli-linux"

# Vencord installer másolása a rendszerbe
cp "$TMPDIR/VencordInstallerCli-linux" /usr/local/bin/VencordInstallerCli-linux
chmod +x /usr/local/bin/VencordInstallerCli-linux

# Vencord telepítése user módban, auto-detect (Discord a user ~/.config/discord/-ban van)
# Az Arch discord csomag bootstrap: első futtatáskor tölti le Discordot a user home-ba.
# Ha még nem futott a Discord, a telepítés csendesen megbukik - a pacman hook elvégzi
# a következő Discord frissítés után automatikusan.
echo "Installing Vencord (user mode)..."
run_as_user /usr/local/bin/VencordInstallerCli-linux -install 2>/dev/null || true
run_as_user /usr/local/bin/VencordInstallerCli-linux -install-openasar 2>/dev/null || true

# Pacman hook: Discord update után Vencord újratelepítés
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/vencord-reinstall.hook << 'HOOK'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = discord

[Action]
Description = Reinstalling Vencord after Discord update...
When = PostTransaction
Exec = /usr/local/bin/vencord-reinstall.sh
HOOK

# Reinstall script - user neve bele van égetve telepítéskor
cat > /usr/local/bin/vencord-reinstall.sh << SCRIPT
#!/bin/bash
runuser -u "$USER" -- env HOME="$HOME" /usr/local/bin/VencordInstallerCli-linux -install || true
runuser -u "$USER" -- env HOME="$HOME" /usr/local/bin/VencordInstallerCli-linux -install-openasar || true
SCRIPT
chmod +x /usr/local/bin/vencord-reinstall.sh

# Vencord config könyvtár létrehozása és RaveOS téma letöltése
run_as_user mkdir -p "$HOME/.config/Vencord/themes"
echo "Downloading RaveOS Vencord theme..."
if local_cfg="$(resolve_local_config RaveOS-Vencord.theme.css)"; then
    cp "$local_cfg" "$HOME/.config/Vencord/themes/RaveOS-Vencord.theme.css"
else
    wget -q -O "$HOME/.config/Vencord/themes/RaveOS-Vencord.theme.css" \
        "${REPO_URL}RaveOS-Vencord.theme.css" || true
fi
if local_cfg="$(resolve_local_config raveos-discord-bg.jpeg)"; then
    cp "$local_cfg" "$HOME/.config/Vencord/themes/raveos-discord-bg.jpeg"
else
    wget -q -O "$HOME/.config/Vencord/themes/raveos-discord-bg.jpeg" \
        "${REPO_URL}raveos-discord-bg.jpeg" || true
fi

# Vencord settings: téma engedélyezés + quickCss bekapcsolás
run_as_user mkdir -p "$HOME/.config/Vencord/settings"
VENCORD_SETTINGS="$HOME/.config/Vencord/settings/settings.json"
if [ ! -f "$VENCORD_SETTINGS" ]; then
    cat > "$VENCORD_SETTINGS" << 'SETTINGS'
{
    "autoUpdate": true,
    "autoUpdateNotification": true,
    "useQuickCss": true,
    "enabledThemes": [
        "RaveOS-Vencord.theme.css"
    ]
}
SETTINGS
else
    python3 -c "
import json
with open('$VENCORD_SETTINGS', 'r') as f:
    s = json.load(f)
themes = s.get('enabledThemes', [])
if 'RaveOS-Vencord.theme.css' not in themes:
    themes.append('RaveOS-Vencord.theme.css')
    s['enabledThemes'] = themes
    with open('$VENCORD_SETTINGS', 'w') as f:
        json.dump(s, f, indent=4)
" || true
fi
chown -R "$USER:$USER" "$HOME/.config/Vencord"

echo "Discord + Vencord installation complete!"
echo "Note: Ha a Vencord nem lett azonnal alkalmazva, indítsd el a Discordot egyszer,"
echo "majd a kovetkezo Discord frissitesnel automatikusan feltelepul."
