#!/usr/bin/env bash
# raveos-session-init.sh
# ----------------------
# Első login-kor beállítja a DMS session.json-ban a háttérképet.
# Csak egyszer fut (ha a wallpaperPath üres).

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
