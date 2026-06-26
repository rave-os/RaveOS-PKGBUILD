#!/usr/bin/env bash
# raveos-hyprland-apply.sh
# ------------------------
# Telepíti a Hyprland téma payloadját:
#   - /etc/skel alá (új usereknek)
#   - minden meglévő, bejelentkező user home-jába
#
# Root jogosultság szükséges. A raveos-hyprland-theme-apply.service hívja
# egyszer, első boot után. Kézzel is futtatható újratelepítéshez.

set -euo pipefail

PAYLOAD="/usr/share/raveos/hyprland-theme/theme-data"

if [[ ! -d "$PAYLOAD" ]]; then
    echo "Hiba: hiányzó payload: $PAYLOAD" >&2
    exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
    echo "Root jogosultság szükséges." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# SKEL TELEPÍTÉS
# Új usereknek (useradd által másolt /etc/skel tartalom)
# ---------------------------------------------------------------------------

# Hyprland Lua konfig (hyprland.lua + config/ könyvtár)
mkdir -p /etc/skel/.config/hypr
if [[ -d "${PAYLOAD}/hypr" ]]; then
    cp -rf "${PAYLOAD}/hypr/." /etc/skel/.config/hypr/
    # Ha Lua konfig létezik, a legacy .conf-ot töröljük
    [[ -f /etc/skel/.config/hypr/hyprland.lua ]] && rm -f /etc/skel/.config/hypr/hyprland.conf
fi

# DankMaterialShell (DMS) felhasználói konfig
# A dms-shell-hyprland package a binárist és rendszerfájlokat telepíti,
# ez a blokk a per-user config könyvtárakat állítja be.
mkdir -p /etc/skel/.config/dms \
         /etc/skel/.config/quickshell/pockets/DMS \
         /etc/skel/.config/DankMaterialShell

DMS_SRC="${PAYLOAD}/dms"
if [[ -d "$DMS_SRC" ]]; then
    cp -r "${DMS_SRC}/." /etc/skel/.config/quickshell/pockets/DMS/
    cp -r "${DMS_SRC}/." /etc/skel/.config/dms/
    if [[ -d "${DMS_SRC}/matugen/configs" ]]; then
        mkdir -p /etc/skel/.config/matugen
        cp -r "${DMS_SRC}/matugen/configs/." /etc/skel/.config/matugen/
    fi
fi
[[ -f "${PAYLOAD}/DankMaterialShell/settings.json" ]] && \
    install -Dm644 "${PAYLOAD}/DankMaterialShell/settings.json" \
        /etc/skel/.config/DankMaterialShell/settings.json
[[ -f "${PAYLOAD}/DankMaterialShell/.firstlaunch" ]] && \
    install -Dm644 "${PAYLOAD}/DankMaterialShell/.firstlaunch" \
        /etc/skel/.config/DankMaterialShell/.firstlaunch

# Kitty terminál konfig
mkdir -p /etc/skel/.config/kitty
[[ -d "${PAYLOAD}/kitty" ]] && cp -r "${PAYLOAD}/kitty/." /etc/skel/.config/kitty/

# Fastfetch konfig
mkdir -p /etc/skel/.config/fastfetch
for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
    [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
        install -Dm644 "${PAYLOAD}/fastfetch/${f}" "/etc/skel/.config/fastfetch/${f}"
done

# Fastfetch profile.d script (terminál nyitáskor fut)
[[ -f "${PAYLOAD}/profile.d/raveos-fastfetch.sh" ]] && \
    install -Dm755 "${PAYLOAD}/profile.d/raveos-fastfetch.sh" /etc/profile.d/raveos-fastfetch.sh

# Skel root tartalom (pl. .bashrc, .icons, .themes stb.)
[[ -d "${PAYLOAD}/skel" ]] && \
    cp -r --no-preserve=ownership "${PAYLOAD}/skel/." /etc/skel/

# Háttérkép
[[ -f "${PAYLOAD}/background.jpg" ]] && \
    install -Dm644 "${PAYLOAD}/background.jpg" /etc/skel/.config/background.jpg

# Felhasználói avatar
[[ -f "${PAYLOAD}/hyprland-pp.png" ]] && \
    install -Dm644 "${PAYLOAD}/hyprland-pp.png" /etc/skel/.face

# GTK, Thunar, nwg-look, xsettingsd, hyprshell konfigok
for d in gtk-3.0 gtk-4.0 nwg-look Thunar xfce4 xsettingsd hyprshell; do
    if [[ -d "${PAYLOAD}/${d}" ]]; then
        mkdir -p "/etc/skel/.config/${d}"
        cp -rf "${PAYLOAD}/${d}/." "/etc/skel/.config/${d}/"
    fi
done

# SDDM: a téma és konfig a PKGBUILD által van telepítve, itt nincs teendő

# ---------------------------------------------------------------------------
# MEGLÉVŐ USEREK FRISSÍTÉSE
# /etc/passwd alapján minden UID >= 1000 bejelentkező user home-ja
# ---------------------------------------------------------------------------

while IFS=: read -r user _ uid gid _ home shell; do
    [[ "$uid" -ge 1000 ]] || continue
    [[ -d "$home" ]] || continue
    [[ "$shell" != "/usr/bin/nologin" && "$shell" != "/bin/false" ]] || continue

    mkdir -p "${home}/.config/hypr" \
             "${home}/.config/quickshell/pockets/DMS" \
             "${home}/.config/dms" \
             "${home}/.config/DankMaterialShell" \
             "${home}/.config/matugen" \
             "${home}/.config/kitty" \
             "${home}/.config/fastfetch"

    # Hyprland konfig
    pkill -u "$user" hyprpaper 2>/dev/null || true
    if [[ -d "${PAYLOAD}/hypr" ]]; then
        cp -rf "${PAYLOAD}/hypr/." "${home}/.config/hypr/"
        [[ -f "${home}/.config/hypr/hyprland.lua" ]] && \
            rm -f "${home}/.config/hypr/hyprland.conf"
    fi

    # hyprpaper konfig (háttérkép daemon)
    printf 'preload = %s/.config/background.jpg\nwallpaper = ,%s/.config/background.jpg\nsplash = false\n' \
        "$home" "$home" > "${home}/.config/hypr/hyprpaper.conf"

    # DMS per-user konfig
    if [[ -d "$DMS_SRC" ]]; then
        cp -r "${DMS_SRC}/." "${home}/.config/quickshell/pockets/DMS/"
        cp -r "${DMS_SRC}/." "${home}/.config/dms/"
        if [[ -d "${DMS_SRC}/matugen/configs" ]]; then
            cp -r "${DMS_SRC}/matugen/configs/." "${home}/.config/matugen/"
        fi
    fi
    [[ -f "${PAYLOAD}/DankMaterialShell/settings.json" ]] && \
        install -Dm644 "${PAYLOAD}/DankMaterialShell/settings.json" \
            "${home}/.config/DankMaterialShell/settings.json"
    [[ -f "${PAYLOAD}/DankMaterialShell/.firstlaunch" ]] && \
        install -Dm644 "${PAYLOAD}/DankMaterialShell/.firstlaunch" \
            "${home}/.config/DankMaterialShell/.firstlaunch"

    # DMS session.json: háttérkép beállítása
    mkdir -p "${home}/.local/state/DankMaterialShell"
    cat > "${home}/.local/state/DankMaterialShell/session.json" <<-SEOF
{
  "wallpaperPath": "${home}/.config/background.jpg"
}
SEOF

    # Skel tartalom
    [[ -d "${PAYLOAD}/skel" ]] && \
        cp -r --no-preserve=ownership "${PAYLOAD}/skel/." "$home/"

    # Háttérkép
    [[ -f "${PAYLOAD}/background.jpg" ]] && \
        install -Dm644 "${PAYLOAD}/background.jpg" "${home}/.config/background.jpg"

    # Kitty
    [[ -d "${PAYLOAD}/kitty" ]] && \
        cp -r "${PAYLOAD}/kitty/." "${home}/.config/kitty/"

    # Felhasználói avatar
    [[ -f "${PAYLOAD}/hyprland-pp.png" ]] && \
        install -Dm644 "${PAYLOAD}/hyprland-pp.png" "${home}/.face"

    # Fastfetch
    for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
        [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
            install -Dm644 "${PAYLOAD}/fastfetch/${f}" "${home}/.config/fastfetch/${f}"
    done

    # GTK, Thunar, nwg-look, xsettingsd, hyprshell konfigok
    for d in gtk-3.0 gtk-4.0 nwg-look Thunar xfce4 xsettingsd hyprshell; do
        if [[ -d "${PAYLOAD}/${d}" ]]; then
            mkdir -p "${home}/.config/${d}"
            cp -rf "${PAYLOAD}/${d}/." "${home}/.config/${d}/"
        fi
    done

    # Icon és GTK téma beállítása (dconf/gsettings)
    # A settings.ini nem elég — a GTK daemonok a dconf-ot olvassák
    # Chroot-ban (Calamares) dbus-launch lehet hogy nincs — ezért set +e
    (
        runuser -u "$user" -- dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-olive-dark' 2>/dev/null
        runuser -u "$user" -- dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Adwaitaru-olive' 2>/dev/null
    ) || true

    # XDG user könyvtárak (Letöltések, Dokumentumok stb.)
    runuser -u "$user" -- xdg-user-dirs-update 2>/dev/null || true

    # Tulajdonos visszaállítása
    chown -R "${uid}:${gid}" "$home"

    # matugen: wallpaper-alapú színséma generálás
    if command -v matugen &>/dev/null && [[ -f "${home}/.config/background.jpg" ]]; then
        runuser -u "$user" -- matugen image "${home}/.config/background.jpg" 2>/dev/null || true
    fi

done < /etc/passwd

echo "Telepítés kész."
