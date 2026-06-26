#!/usr/bin/env bash
# raveos-session-init.sh
# ----------------------
# Első login-kor beállítja a GTK témát és a DMS session.json-ban a háttérképet.
# Csak egyszer fut (ha az ~/.raveos-init-done nem létezik).

_raveos_init="${HOME}/.raveos-init-done"

if [[ -f "${_raveos_init}" ]]; then
    unset _raveos_init
    return 0 2>/dev/null || exit 0
fi

# GTK téma
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-olive-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaitaru-olive'

# DMS session.json: háttérkép beállítása
_session_file="${HOME}/.local/state/DankMaterialShell/session.json"
_bg_file="${HOME}/.config/background.jpg"

if [[ -f "${_bg_file}" ]]; then
    if [[ ! -f "${_session_file}" ]]; then
        mkdir -p "$(dirname "${_session_file}")"
        printf '{\n  "wallpaperPath": "%s"\n}\n' "${_bg_file}" > "${_session_file}"
    elif ! grep -q '"wallpaperPath": "[^"]\+' "${_session_file}" 2>/dev/null; then
        sed -i "s|\"wallpaperPath\": \"\"|\"wallpaperPath\": \"${_bg_file}\"|g" "${_session_file}" 2>/dev/null || true
    fi
fi

unset _session_file _bg_file

# Jelzés hogy lefutott
touch "${_raveos_init}"
unset _raveos_init
