#!/usr/bin/env bash

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

xdg_lang=""
[[ -f /etc/locale.conf ]] && xdg_lang="$(awk -F'=' '/^LANG=/{print $2}' /etc/locale.conf | tr -d '"')"
xdg_lang="${xdg_lang%%.*}"; xdg_lang="${xdg_lang%%_*}"
case "$xdg_lang" in
    hu)
        XDG_DESKTOP="Asztal";        XDG_DOWNLOAD="Letöltések";  XDG_TEMPLATES="Sablonok"
        XDG_PUBLIC="Nyilvános";      XDG_DOCUMENTS="Dokumentumok"; XDG_MUSIC="Zenék"
        XDG_PICTURES="Képek";        XDG_VIDEOS="Videók";        XDG_PROJECTS="Projektek"
        BM_DOCUMENTS="Dokumentumok"; BM_MUSIC="Zen%C3%A9k";      BM_PICTURES="K%C3%A9pek"
        BM_VIDEOS="Vide%C3%B3k";     BM_DOWNLOAD="Let%C3%B6lt%C3%A9sek"
        ;;
    de)
        XDG_DESKTOP="Schreibtisch";  XDG_DOWNLOAD="Download";    XDG_TEMPLATES="Vorlagen"
        XDG_PUBLIC="Öffentlich";     XDG_DOCUMENTS="Dokumente";  XDG_MUSIC="Musik"
        XDG_PICTURES="Bilder";       XDG_VIDEOS="Videos";        XDG_PROJECTS="Projekte"
        BM_DOCUMENTS="Dokumente";    BM_MUSIC="Musik";           BM_PICTURES="Bilder"
        BM_VIDEOS="Videos";          BM_DOWNLOAD="Download"
        ;;
    *)
        XDG_DESKTOP="Desktop";       XDG_DOWNLOAD="Downloads";   XDG_TEMPLATES="Templates"
        XDG_PUBLIC="Public";         XDG_DOCUMENTS="Documents";  XDG_MUSIC="Music"
        XDG_PICTURES="Pictures";     XDG_VIDEOS="Videos";        XDG_PROJECTS="Projects"
        BM_DOCUMENTS="Documents";    BM_MUSIC="Music";           BM_PICTURES="Pictures"
        BM_VIDEOS="Videos";          BM_DOWNLOAD="Downloads"
        ;;
esac

setup_xdg_dirs() {
    local home="$1"
    local dirs="${home}/.config/user-dirs.dirs"

    mkdir -p "$(dirname "$dirs")" \
        "${home}/${XDG_DESKTOP}" \
        "${home}/${XDG_DOWNLOAD}" \
        "${home}/${XDG_TEMPLATES}" \
        "${home}/${XDG_PUBLIC}" \
        "${home}/${XDG_DOCUMENTS}" \
        "${home}/${XDG_MUSIC}" \
        "${home}/${XDG_PICTURES}" \
        "${home}/${XDG_VIDEOS}" \
        "${home}/${XDG_PROJECTS}"

    cat > "${dirs}" <<EOF
XDG_DESKTOP_DIR="\$HOME/${XDG_DESKTOP}"
XDG_DOWNLOAD_DIR="\$HOME/${XDG_DOWNLOAD}"
XDG_TEMPLATES_DIR="\$HOME/${XDG_TEMPLATES}"
XDG_PUBLICSHARE_DIR="\$HOME/${XDG_PUBLIC}"
XDG_DOCUMENTS_DIR="\$HOME/${XDG_DOCUMENTS}"
XDG_MUSIC_DIR="\$HOME/${XDG_MUSIC}"
XDG_PICTURES_DIR="\$HOME/${XDG_PICTURES}"
XDG_VIDEOS_DIR="\$HOME/${XDG_VIDEOS}"
XDG_PROJECTS_DIR="\$HOME/${XDG_PROJECTS}"
EOF
}

install_gtk_bookmarks() {
    local home="$1"
    local bookmarks="${home}/.config/gtk-3.0/bookmarks"
    local tmp

    mkdir -p "$(dirname "$bookmarks")"
    tmp=$(mktemp)
    [[ -f "$bookmarks" ]] && cat "$bookmarks" > "$tmp"

    for entry in \
        "file://${home}/${BM_DOCUMENTS}" \
        "file://${home}/${BM_MUSIC}" \
        "file://${home}/${BM_PICTURES}" \
        "file://${home}/${BM_VIDEOS}" \
        "file://${home}/${BM_DOWNLOAD}"; do
        grep -qxF "$entry" "$tmp" || printf '%s\n' "$entry" >> "$tmp"
    done

    install -m644 "$tmp" "$bookmarks"
    rm -f "$tmp"
}

set_hypr_keyboard() {
    local hypr_lua="$1"
    local kb_layout="hu"
    local kb_variant=""
    local xorg_kb="/etc/X11/xorg.conf.d/00-keyboard.conf"
    local kb_tmp
    [[ -f "$hypr_lua" ]] || return 0
    if [[ -f "${xorg_kb}" ]]; then
        kb_tmp="$(awk '/XkbLayout/ {print $3}' "${xorg_kb}" 2>/dev/null | tr -d '"' | head -1)"
        [[ -n "$kb_tmp" ]] && kb_layout="${kb_tmp%%,*}"
        kb_tmp="$(awk '/XkbVariant/ {print $3}' "${xorg_kb}" 2>/dev/null | tr -d '"' | head -1)"
        [[ -n "$kb_tmp" ]] && kb_variant="${kb_tmp%%,*}"
    elif [[ -f /etc/default/keyboard ]]; then
        kb_tmp="$(awk -F'"' '/^XKBLAYOUT=/{print $2; exit}' /etc/default/keyboard 2>/dev/null)"
        [[ -n "$kb_tmp" ]] && kb_layout="${kb_tmp%%,*}"
        kb_tmp="$(awk -F'"' '/^XKBVARIANT=/{print $2; exit}' /etc/default/keyboard 2>/dev/null)"
        [[ -n "$kb_tmp" ]] && kb_variant="${kb_tmp%%,*}"
    fi
    sed -i "s/kb_layout[[:space:]]*=[[:space:]]*\"\"/kb_layout = \"${kb_layout}\"/" "$hypr_lua"
    sed -i "s/kb_variant[[:space:]]*=[[:space:]]*\"\"/kb_variant = \"${kb_variant}\"/" "$hypr_lua"
}

mkdir -p /etc/skel/.config/hypr
if [[ -d "${PAYLOAD}/hypr" ]]; then
    cp -rf "${PAYLOAD}/hypr/." /etc/skel/.config/hypr/
    # Ha Lua konfig létezik, a legacy .conf-ot töröljük
    [[ -f /etc/skel/.config/hypr/hyprland.lua ]] && rm -f /etc/skel/.config/hypr/hyprland.conf
    set_hypr_keyboard /etc/skel/.config/hypr/hyprland.lua
fi

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

mkdir -p /etc/skel/.config/kitty
[[ -d "${PAYLOAD}/kitty" ]] && cp -r "${PAYLOAD}/kitty/." /etc/skel/.config/kitty/

mkdir -p /etc/skel/.config/fastfetch
for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
    [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
        install -Dm644 "${PAYLOAD}/fastfetch/${f}" "/etc/skel/.config/fastfetch/${f}"
done

[[ -f "${PAYLOAD}/profile.d/raveos-fastfetch.sh" ]] && \
    install -Dm755 "${PAYLOAD}/profile.d/raveos-fastfetch.sh" /etc/profile.d/raveos-fastfetch.sh

[[ -d "${PAYLOAD}/skel" ]] && \
    cp -r --no-preserve=ownership "${PAYLOAD}/skel/." /etc/skel/

setup_xdg_dirs /etc/skel
install_gtk_bookmarks /etc/skel

[[ -f "${PAYLOAD}/background.jpg" ]] && \
    install -Dm644 "${PAYLOAD}/background.jpg" /etc/skel/.config/background.jpg

[[ -f "${PAYLOAD}/hyprland-pp.png" ]] && \
    install -Dm644 "${PAYLOAD}/hyprland-pp.png" /etc/skel/.face

for d in gtk-3.0 gtk-4.0 nwg-look Thunar xfce4 xsettingsd Kvantum; do
    if [[ -d "${PAYLOAD}/${d}" ]]; then
        mkdir -p "/etc/skel/.config/${d}"
        cp -rf "${PAYLOAD}/${d}/." "/etc/skel/.config/${d}/"
    fi
done

[[ -f "${PAYLOAD}/raveswitch/config.ron" ]] && \
    install -Dm644 "${PAYLOAD}/raveswitch/config.ron" /etc/skel/.config/raveswitch/config.ron


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
        set_hypr_keyboard "${home}/.config/hypr/hyprland.lua"
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

    setup_xdg_dirs "$home"
    install_gtk_bookmarks "$home"

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

    # GTK, Thunar, nwg-look, xsettingsd, Kvantum konfigok
    for d in gtk-3.0 gtk-4.0 nwg-look Thunar xfce4 xsettingsd Kvantum; do
        if [[ -d "${PAYLOAD}/${d}" ]]; then
            mkdir -p "${home}/.config/${d}"
            cp -rf "${PAYLOAD}/${d}/." "${home}/.config/${d}/"
        fi
    done

    # RaveSwitch alap config (modifier: Super, lasd fentebb a skel-agnal)
    if [[ -f "${PAYLOAD}/raveswitch/config.ron" && ! -f "${home}/.config/raveswitch/config.ron" ]]; then
        install -Dm644 "${PAYLOAD}/raveswitch/config.ron" "${home}/.config/raveswitch/config.ron"
    fi

    # Icon és GTK téma beállítása (dconf/gsettings)
    # A settings.ini nem elég — a GTK daemonok a dconf-ot olvassák
    # Chroot-ban (Calamares) dbus-launch lehet hogy nincs — ezért set +e
    (
        runuser -u "$user" -- dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-olive-dark' 2>/dev/null
        runuser -u "$user" -- dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Adwaitaru-olive' 2>/dev/null
    ) || true

    # Tulajdonos visszaállítása
    chown -R "${uid}:${gid}" "$home"

    # matugen: wallpaper-alapú színséma generálás
    if command -v matugen &>/dev/null && [[ -f "${home}/.config/background.jpg" ]]; then
        runuser -u "$user" -- matugen image "${home}/.config/background.jpg" 2>/dev/null || true
    fi

done < /etc/passwd

echo "Telepítés kész."
