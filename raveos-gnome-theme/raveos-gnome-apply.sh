#!/usr/bin/env bash
# raveos-gnome-apply.sh
# ---------------------
# Telepíti a GNOME téma payloadját:
#   - /etc/skel alá (új usereknek)
#   - minden meglévő, bejelentkező user home-jába
#
# Root jogosultság szükséges. A raveos-gnome-theme.install post_install
# hook-ja hívja közvetlenül.

set -euo pipefail

PAYLOAD="/usr/share/raveos/gnome-theme/theme-data"
wallpaper_dst="/usr/share/backgrounds/raveos/raveos-main-bg.jpeg"
dconf_profile_dir="/etc/dconf/profile"
dconf_db_dir="/etc/dconf/db/local.d"
dconf_default_file="${dconf_db_dir}/00-raveos"

if [[ ! -d "$PAYLOAD" ]]; then
    echo "Hiba: hiányzó payload: $PAYLOAD" >&2
    exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
    echo "Root jogosultság szükséges." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# SEGÉDFÜGGVÉNYEK
# ---------------------------------------------------------------------------

ensure_bashrc_hook() {
    local bashrc_path="$1"
    local hook_line='[[ -f /etc/profile.d/raveos-fastfetch.sh ]] && source /etc/profile.d/raveos-fastfetch.sh'
    touch "$bashrc_path"
    if ! grep -Fqx "$hook_line" "$bashrc_path" 2>/dev/null; then
        printf '\n%s\n' "$hook_line" >> "$bashrc_path"
    fi
}

write_mimeapps_defaults() {
    local mimeapps_path="$1"
    mkdir -p "$(dirname "$mimeapps_path")"
    cat > "$mimeapps_path" <<'EOF'
[Default Applications]
image/jpeg=org.gnome.eog.desktop
image/png=org.gnome.eog.desktop
image/webp=org.gnome.eog.desktop
image/gif=org.gnome.eog.desktop
image/bmp=org.gnome.eog.desktop
image/tiff=org.gnome.eog.desktop
image/avif=org.gnome.eog.desktop
image/heif=org.gnome.eog.desktop
image/heic=org.gnome.eog.desktop
EOF
}

build_system_dconf_defaults() {
    sed -e "s|file:///home/{HOME}/.config/background|file://${wallpaper_dst}|g" \
        "${PAYLOAD}/dconf/full-system-dump.ini" > "$dconf_default_file"
}

build_user_dconf_dump() {
    local target_home="$1"
    local output_path="$2"
    sed \
        -e "s|file:///home/{HOME}/.config/background|file://${target_home}/.config/background|g" \
        -e "s|{HOME}|${target_home}|g" \
        "${PAYLOAD}/dconf/full-system-dump.ini" > "$output_path"
}

# ---------------------------------------------------------------------------
# RENDSZERSZINTŰ TELEPÍTÉS
# ---------------------------------------------------------------------------

# Háttérkép rendszerkönyvtárba
install -Dm644 "${PAYLOAD}/background" "$wallpaper_dst"

# App grid ikon és rendszer logo
[[ -f "${PAYLOAD}/icons/view-app-grid-symbolic.svg" ]] && \
    install -Dm644 "${PAYLOAD}/icons/view-app-grid-symbolic.svg" \
        /usr/share/icons/Adwaita/symbolic/actions/view-app-grid-symbolic.svg
[[ -f "${PAYLOAD}/system/raveos-logo.svg" ]] && \
    install -Dm644 "${PAYLOAD}/system/raveos-logo.svg" /usr/share/pixmaps/raveos-logo.svg && \
    install -Dm644 "${PAYLOAD}/system/raveos-logo.svg" /usr/share/icons/hicolor/scalable/apps/raveos-logo.svg

# Elrejtett alkalmazások (NoDisplay=true .desktop felülírással)
mkdir -p /usr/local/share/applications
for desktop_id in avahi-discover.desktop bssh.desktop bvnc.desktop qv4l2.desktop qvidcap.desktop vim.desktop; do
    cat > "/usr/local/share/applications/${desktop_id}" <<'EOF'
[Desktop Entry]
NoDisplay=true
EOF
done

# dconf rendszerprofil és alapértelmezések
mkdir -p "$dconf_profile_dir" "$dconf_db_dir"
cat > "${dconf_profile_dir}/user" <<'EOF'
user-db:user
system-db:local
EOF
build_system_dconf_defaults
command -v dconf &>/dev/null && dconf update || true

# SDDM: a téma és konfig a PKGBUILD + .install hook által van telepítve, itt nincs teendő

# ---------------------------------------------------------------------------
# MEGLÉVŐ USEREK FRISSÍTÉSE
# /etc/passwd alapján minden UID >= 1000 bejelentkező user home-ja
# ---------------------------------------------------------------------------

install_user() {
    local target_user="$1"
    local passwd_line target_uid target_gid target_home tmpdir

    passwd_line="$(getent passwd "$target_user" || true)"
    [[ -n "$passwd_line" ]] || return 0
    IFS=: read -r _ _ target_uid target_gid _ target_home _ <<<"$passwd_line"
    [[ -d "$target_home" ]] || return 0

    mkdir -p \
        "${target_home}/.config/kitty" \
        "${target_home}/.config/fastfetch" \
        "${target_home}/.config/burn-my-windows/profiles" \
        "${target_home}/.config" \
        "${target_home}/.themes" \
        "${target_home}/.icons" \
        "${target_home}/.local/share/gnome-shell/extensions"

    install -Dm644 "$wallpaper_dst" "${target_home}/.config/background"
    cp -r --no-preserve=ownership "${PAYLOAD}/user-themes/." "${target_home}/.themes/"
    cp -r --no-preserve=ownership "${PAYLOAD}/user-icons/." "${target_home}/.icons/"
    cp -r --no-preserve=ownership "${PAYLOAD}/extensions/installed/." \
        "${target_home}/.local/share/gnome-shell/extensions/"

    [[ -f "${PAYLOAD}/kitty/kitty.conf" ]] && \
        install -Dm644 "${PAYLOAD}/kitty/kitty.conf" "${target_home}/.config/kitty/kitty.conf"
    for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
        [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
            install -Dm644 "${PAYLOAD}/fastfetch/${f}" "${target_home}/.config/fastfetch/${f}"
    done
    [[ -f "${PAYLOAD}/burn-my-windows/burn-my-windows.conf" ]] && \
        install -Dm644 "${PAYLOAD}/burn-my-windows/burn-my-windows.conf" \
            "${target_home}/.config/burn-my-windows/profiles/burn-my-windows.conf"
    write_mimeapps_defaults "${target_home}/.config/mimeapps.list"
    ensure_bashrc_hook "${target_home}/.bashrc"

    if command -v glib-compile-schemas &>/dev/null; then
        find "${target_home}/.local/share/gnome-shell/extensions" -type d -name schemas -print0 | \
            while IFS= read -r -d '' schema_dir; do
                glib-compile-schemas "$schema_dir"
            done
    fi

    tmpdir="$(mktemp -d)"
    chmod 755 "$tmpdir"
    build_user_dconf_dump "${target_home}" "${tmpdir}/full-system-dump.ini"
    chmod 644 "${tmpdir}/full-system-dump.ini"

    if command -v dconf &>/dev/null && command -v dbus-run-session &>/dev/null; then
        runuser -u "$target_user" -- env \
            HOME="${target_home}" USER="${target_user}" LOGNAME="${target_user}" \
            XDG_CONFIG_HOME="${target_home}/.config" XDG_DATA_HOME="${target_home}/.local/share" \
            dbus-run-session /bin/bash -lc "
                dconf load / < '${tmpdir}/full-system-dump.ini' || true
                gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-olive-dark' || true
                gsettings set org.gnome.desktop.interface icon-theme 'Adwaitaru-olive' || true
                gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
                gsettings set org.gnome.desktop.background picture-uri 'file://${target_home}/.config/background' || true
                gsettings set org.gnome.desktop.background picture-uri-dark 'file://${target_home}/.config/background' || true
                gsettings set org.gnome.shell.extensions.user-theme name 'Yaru-olive-dark' || true
            " || true
    fi

    rm -rf "$tmpdir"

    chown -R "${target_uid}:${target_gid}" \
        "${target_home}/.config" "${target_home}/.local" \
        "${target_home}/.themes" "${target_home}/.icons" "${target_home}/.bashrc"
}

while IFS=: read -r user _ uid _ _ home shell; do
    [[ "$uid" -ge 1000 ]] || continue
    [[ -d "$home" ]] || continue
    [[ "$shell" != "/usr/bin/nologin" && "$shell" != "/bin/false" ]] || continue
    install_user "$user"
done < /etc/passwd

# ---------------------------------------------------------------------------
# SKEL TELEPÍTÉS
# Új usereknek (useradd által másolt /etc/skel tartalom)
# ---------------------------------------------------------------------------

mkdir -p \
    /etc/skel/.config/kitty \
    /etc/skel/.config/fastfetch \
    /etc/skel/.config/burn-my-windows/profiles \
    /etc/skel/.themes \
    /etc/skel/.icons \
    /etc/skel/.local/share/gnome-shell/extensions

cp -r --no-preserve=ownership "${PAYLOAD}/user-themes/." /etc/skel/.themes/
cp -r --no-preserve=ownership "${PAYLOAD}/user-icons/." /etc/skel/.icons/
cp -r --no-preserve=ownership "${PAYLOAD}/extensions/installed/." /etc/skel/.local/share/gnome-shell/extensions/
install -Dm644 "$wallpaper_dst" /etc/skel/.config/background
[[ -f "${PAYLOAD}/kitty/kitty.conf" ]] && \
    install -Dm644 "${PAYLOAD}/kitty/kitty.conf" /etc/skel/.config/kitty/kitty.conf
for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
    [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
        install -Dm644 "${PAYLOAD}/fastfetch/${f}" "/etc/skel/.config/fastfetch/${f}"
done
[[ -f "${PAYLOAD}/profile.d/raveos-fastfetch.sh" ]] && \
    install -Dm755 "${PAYLOAD}/profile.d/raveos-fastfetch.sh" /etc/profile.d/raveos-fastfetch.sh
[[ -f "${PAYLOAD}/burn-my-windows/burn-my-windows.conf" ]] && \
    install -Dm644 "${PAYLOAD}/burn-my-windows/burn-my-windows.conf" \
        /etc/skel/.config/burn-my-windows/profiles/burn-my-windows.conf
write_mimeapps_defaults /etc/skel/.config/mimeapps.list
ensure_bashrc_hook /etc/skel/.bashrc

echo "Telepítés kész."
