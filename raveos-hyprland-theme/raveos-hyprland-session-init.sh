#!/usr/bin/env bash
# raveos-hyprland-session-init.sh
# ---------------------------------
# User session init: beállítja a háttérképet és GTK témát Hyprland alatt.
#
# Systemd user service hívja (raveos-hyprland-session-init.service).
# Csak akkor fut, ha HYPRLAND_INSTANCE_SIGNATURE be van állítva.

set -euo pipefail

# ---------------------------------------------------------------------------
# Várakozás Hyprland ready jelzésére
# ---------------------------------------------------------------------------
TIMEOUT=30
ELAPSED=0
while [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; do
    if (( ELAPSED >= TIMEOUT )); then
        echo "Hiba: HYPRLAND_INSTANCE_SIGNATURE nem érkezett ${TIMEOUT}s alatt." >&2
        exit 1
    fi
    sleep 1
    (( ELAPSED++ ))
done

# ---------------------------------------------------------------------------
# Háttérkép beállítása (hyprpaper)
# ---------------------------------------------------------------------------
setup_wallpaper() {
    local wallpaper="${HOME}/.config/background.jpg"
    local hypr_conf="${HOME}/.config/hypr/hyprpaper.conf"

    if [[ ! -f "${wallpaper}" ]]; then
        echo "Nincs háttérkép: ${wallpaper}" >&2
        return 1
    fi

    cat > "${hypr_conf}" <<-EOF
preload = ${wallpaper}
wallpaper = ,${wallpaper}
splash = false
EOF

    if ! pgrep -x hyprpaper >/dev/null 2>&1; then
        hyprpaper &
        disown
        sleep 2
    fi
}

# ---------------------------------------------------------------------------
# GTK téma beállítása
# ---------------------------------------------------------------------------
setup_gtk() {
    gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-olive-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaitaru-olive'
}

# ---------------------------------------------------------------------------
# Futtatás
# ---------------------------------------------------------------------------
setup_wallpaper
setup_gtk
