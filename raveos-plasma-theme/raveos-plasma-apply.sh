#!/usr/bin/env bash
# raveos-plasma-apply.sh
# ----------------------
# Telepíti a KDE Plasma téma payloadját:
#   - /etc/skel alá (új usereknek)
#   - minden meglévő, bejelentkező user home-jába
#
# Root jogosultság szükséges. A raveos-plasma-theme.install post_install
# hook-ja hívja közvetlenül.

set -euo pipefail

PAYLOAD="/usr/share/raveos/plasma-theme/theme-data"
wallpaper_dst="/usr/share/backgrounds/raveos/raveos-main-bg.jpeg"

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

disable_kmix_autostart() {
    local target_home="$1"
    mkdir -p "${target_home}/.config/autostart"
    cat > "${target_home}/.config/autostart/kmix_autostart.desktop" <<'EOF'
[Desktop Entry]
Hidden=true
EOF
}

write_konsolerc() {
    local target_home="$1"
    cat > "${target_home}/.config/konsolerc" <<'EOF'
[Desktop Entry]
DefaultProfile=RaveOS.profile

[General]
ConfigVersion=1

[UiSettings]
ColorScheme=RaveOS
EOF
}

write_plasma_wallpaper_config() {
    local target_home="$1"
    local applet_config="${target_home}/.config/plasma-org.kde.plasma.desktop-appletsrc"

    mkdir -p "${target_home}/.config"
    if [[ ! -f "${applet_config}" ]]; then
        if command -v kwriteconfig6 &>/dev/null; then
            kwriteconfig6 --file "${applet_config}" \
                --group Containments --group 1 --group Wallpaper \
                --group org.kde.image --group General \
                --key Image "file://${wallpaper_dst}"
            kwriteconfig6 --file "${applet_config}" \
                --group Containments --group 1 --group Wallpaper \
                --group org.kde.image --group General \
                --key FillMode 2
        else
            cat >> "${applet_config}" <<EOF

[Containments][1][Wallpaper][org.kde.image][General]
FillMode=2
Image=file://${wallpaper_dst}
EOF
        fi
    else
        local containments
        containments=$(grep -oP '(?<=^\[Containments\]\[)\d+(?=\])' "${applet_config}" | sort -un)
        [[ -z "${containments}" ]] && containments="1"
        for c in ${containments}; do
            if command -v kwriteconfig6 &>/dev/null; then
                kwriteconfig6 --file "${applet_config}" \
                    --group Containments --group "${c}" --group Wallpaper \
                    --group org.kde.image --group General \
                    --key Image "file://${wallpaper_dst}"
                kwriteconfig6 --file "${applet_config}" \
                    --group Containments --group "${c}" --group Wallpaper \
                    --group org.kde.image --group General \
                    --key FillMode 2
            fi
        done
    fi
}

write_kickoff_config() {
    local target_home="$1"
    local kickoff_image="${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg"
    [[ -f "$kickoff_image" ]] || kickoff_image="/usr/share/pixmaps/raveos-logo.svg"
    [[ -f "$kickoff_image" ]] || kickoff_image="/usr/share/icons/breeze/applets/256/org.kde.plasma.kickoff.svg"
    [[ -f "${target_home}/.config/plasma-org.kde.plasma.desktop-appletsrc" ]] || return 0

    while IFS=: read -r containment applet; do
        [[ -n "${containment}" && -n "${applet}" ]] || continue
        if command -v kwriteconfig6 &>/dev/null; then
            kwriteconfig6 --file "${target_home}/.config/plasma-org.kde.plasma.desktop-appletsrc" \
                --group Containments --group "${containment}" --group Applets \
                --group "${applet}" --group Configuration --group General \
                --key useCustomButtonImage true
            kwriteconfig6 --file "${target_home}/.config/plasma-org.kde.plasma.desktop-appletsrc" \
                --group Containments --group "${containment}" --group Applets \
                --group "${applet}" --group Configuration --group General \
                --key customButtonImage "file://${kickoff_image}"
            kwriteconfig6 --file "${target_home}/.config/plasma-org.kde.plasma.desktop-appletsrc" \
                --group Containments --group "${containment}" --group Applets \
                --group "${applet}" --group Configuration --group General \
                --key icon "${kickoff_image}"
        else
            cat >> "${target_home}/.config/plasma-org.kde.plasma.desktop-appletsrc" <<EOF

[Containments][${containment}][Applets][${applet}][Configuration][General]
customButtonImage=file://${kickoff_image}
icon=${kickoff_image}
useCustomButtonImage=true
EOF
        fi
    done < <(
        awk '
            match($0, /^\[Containments\]\[([0-9]+)\]\[Applets\]\[([0-9]+)\]$/, m) { c=m[1]; a=m[2]; next }
            /^plugin=org\.kde\.plasma\.(kickoff|kicker|simplemenu|kickoffdashboard)$/ && c != "" && a != "" { print c ":" a }
        ' "${target_home}/.config/plasma-org.kde.plasma.desktop-appletsrc" | sort -u
    )
}

write_kscreenlockerrc() {
    local target_home="$1"
    mkdir -p "${target_home}/.config"
    cat > "${target_home}/.config/kscreenlockerrc" <<EOF
[Greeter][Wallpaper][org.kde.image][General]
FillMode=2
Image=file://${wallpaper_dst}
EOF
}

write_ksplashrc() {
    local target_home="$1"
    mkdir -p "${target_home}/.config"
    cat > "${target_home}/.config/ksplashrc" <<'EOF'
[KSplash]
Engine=KSplashQML
Theme=org.kde.raveos.desktop
EOF
}

# ---------------------------------------------------------------------------
# RENDSZERSZINTŰ TELEPÍTÉS
# ---------------------------------------------------------------------------

# Háttérkép rendszerkönyvtárba
[[ -f "${PAYLOAD}/background" ]] && \
    install -Dm644 "${PAYLOAD}/background" "$wallpaper_dst"

# Fastfetch profile.d script (terminál nyitáskor fut)
[[ -f "${PAYLOAD}/profile.d/raveos-fastfetch.sh" ]] && \
    install -Dm755 "${PAYLOAD}/profile.d/raveos-fastfetch.sh" /etc/profile.d/raveos-fastfetch.sh

# Kickoff/rendszer ikon globálisan
if [[ -f "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" ]]; then
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" /usr/share/pixmaps/raveos-logo.svg
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
        /usr/share/icons/hicolor/scalable/apps/raveos-logo.svg
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
        /usr/share/icons/hicolor/scalable/apps/distributor-logo-raveos.svg

    for theme in breeze breeze-dark hicolor; do
        [[ -d "/usr/share/icons/${theme}" ]] || continue
        find "/usr/share/icons/${theme}" -name "start-here*" -delete 2>/dev/null || true
        find "/usr/share/icons/${theme}" -name "distributor-logo*" -delete 2>/dev/null || true
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "/usr/share/icons/${theme}/scalable/places/start-here-kde.svg"
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "/usr/share/icons/${theme}/scalable/places/start-here.svg"
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "/usr/share/icons/${theme}/scalable/places/distributor-logo.svg"
    done

    for dir in \
        /usr/local/share/icons/breeze/applets/256 \
        /usr/local/share/icons/breeze-dark/applets/256 \
        /usr/share/icons/breeze/applets/256 \
        /usr/share/icons/breeze-dark/applets/256; do
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "${dir}/org.kde.plasma.kickoff.svg"
    done
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
        /usr/local/share/icons/Adwaita/symbolic/places/start-here-symbolic.svg
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
        /usr/share/icons/Adwaita/symbolic/places/start-here-symbolic.svg
    for size in 22 32 64 96; do
        for dir in \
            /usr/local/share/icons/breeze/places/${size} \
            /usr/local/share/icons/breeze-dark/places/${size} \
            /usr/share/icons/breeze/places/${size} \
            /usr/share/icons/breeze-dark/places/${size}; do
            install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
                "${dir}/start-here-kde.svg"
            install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
                "${dir}/start-here.svg"
        done
    done
fi

# Plasma splash téma
if [[ -d "${PAYLOAD}/plasma-splash" ]]; then
    mkdir -p /usr/share/plasma/look-and-feel
    rm -rf /usr/share/plasma/look-and-feel/org.kde.raveos.desktop
    cp -r --no-preserve=ownership "${PAYLOAD}/plasma-splash" \
        /usr/share/plasma/look-and-feel/org.kde.raveos.desktop
fi

# SDDM: a téma és konfig a PKGBUILD + .install hook által van telepítve, itt nincs teendő

# ---------------------------------------------------------------------------
# MEGLÉVŐ USEREK FRISSÍTÉSE
# /etc/passwd alapján minden UID >= 1000 bejelentkező user home-ja
# ---------------------------------------------------------------------------

apply_user_payload() {
    local target_user="$1"
    local passwd_line target_uid target_gid target_home

    passwd_line="$(getent passwd "$target_user" || true)"
    [[ -n "$passwd_line" ]] || return 0
    IFS=: read -r _ _ target_uid target_gid _ target_home _ <<<"$passwd_line"
    [[ -d "$target_home" ]] || return 0

    mkdir -p \
        "${target_home}/.config/kitty" \
        "${target_home}/.config/fastfetch" \
        "${target_home}/.config/autostart" \
        "${target_home}/.local/share/konsole" \
        "${target_home}/.local/share/icons/breeze/applets/256" \
        "${target_home}/.local/share/icons/breeze-dark/applets/256" \
        "${target_home}/.local/share/icons/breeze/places/22" \
        "${target_home}/.local/share/icons/breeze/places/32" \
        "${target_home}/.local/share/icons/breeze/places/64" \
        "${target_home}/.local/share/icons/breeze/places/96" \
        "${target_home}/.local/share/icons/breeze-dark/places/22" \
        "${target_home}/.local/share/icons/breeze-dark/places/32" \
        "${target_home}/.local/share/icons/breeze-dark/places/64" \
        "${target_home}/.local/share/icons/breeze-dark/places/96" \
        "${target_home}/.local/share/icons/Adwaita/symbolic/places"

    install -Dm644 "$wallpaper_dst" "${target_home}/.config/background"

    [[ -f "${PAYLOAD}/kitty/kitty.conf" ]] && \
        install -Dm644 "${PAYLOAD}/kitty/kitty.conf" "${target_home}/.config/kitty/kitty.conf"
    for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
        [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
            install -Dm644 "${PAYLOAD}/fastfetch/${f}" "${target_home}/.config/fastfetch/${f}"
    done
    [[ -f "${PAYLOAD}/konsole/RaveOS.colorscheme" ]] && \
        install -Dm644 "${PAYLOAD}/konsole/RaveOS.colorscheme" \
            "${target_home}/.local/share/konsole/RaveOS.colorscheme"
    [[ -f "${PAYLOAD}/konsole/RaveOS.profile" ]] && \
        install -Dm644 "${PAYLOAD}/konsole/RaveOS.profile" \
            "${target_home}/.local/share/konsole/RaveOS.profile"

    if [[ -f "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" ]]; then
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "${target_home}/.local/share/icons/breeze/applets/256/org.kde.plasma.kickoff.svg"
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "${target_home}/.local/share/icons/breeze-dark/applets/256/org.kde.plasma.kickoff.svg"
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "${target_home}/.local/share/icons/Adwaita/symbolic/places/start-here-symbolic.svg"
        for size in 22 32 64 96; do
            install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
                "${target_home}/.local/share/icons/breeze/places/${size}/start-here-kde.svg"
            install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
                "${target_home}/.local/share/icons/breeze-dark/places/${size}/start-here-kde.svg"
            install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
                "${target_home}/.local/share/icons/breeze/places/${size}/start-here.svg"
            install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
                "${target_home}/.local/share/icons/breeze-dark/places/${size}/start-here.svg"
        done
    fi

    write_konsolerc "$target_home"
    write_plasma_wallpaper_config "$target_home"
    write_kickoff_config "$target_home"
    write_kscreenlockerrc "$target_home"
    write_ksplashrc "$target_home"
    disable_kmix_autostart "$target_home"
    ensure_bashrc_hook "${target_home}/.bashrc"

    chown -R "${target_uid}:${target_gid}" \
        "${target_home}/.config" "${target_home}/.local" "${target_home}/.bashrc"
}

while IFS=: read -r user _ uid _ _ home shell; do
    [[ "$uid" -ge 1000 ]] || continue
    [[ -d "$home" ]] || continue
    [[ "$shell" != "/usr/bin/nologin" && "$shell" != "/bin/false" ]] || continue
    apply_user_payload "$user"
done < /etc/passwd

# ---------------------------------------------------------------------------
# SKEL TELEPÍTÉS
# Új usereknek (useradd által másolt /etc/skel tartalom)
# ---------------------------------------------------------------------------

mkdir -p \
    /etc/skel/.config/kitty \
    /etc/skel/.config/fastfetch \
    /etc/skel/.config/autostart \
    /etc/skel/.local/share/konsole \
    /etc/skel/.local/share/icons/breeze/applets/256 \
    /etc/skel/.local/share/icons/breeze-dark/applets/256 \
    /etc/skel/.local/share/icons/breeze/places/22 \
    /etc/skel/.local/share/icons/breeze/places/32 \
    /etc/skel/.local/share/icons/breeze/places/64 \
    /etc/skel/.local/share/icons/breeze/places/96 \
    /etc/skel/.local/share/icons/breeze-dark/places/22 \
    /etc/skel/.local/share/icons/breeze-dark/places/32 \
    /etc/skel/.local/share/icons/breeze-dark/places/64 \
    /etc/skel/.local/share/icons/breeze-dark/places/96 \
    /etc/skel/.local/share/icons/Adwaita/symbolic/places

[[ -f "${PAYLOAD}/background" ]] && \
    install -Dm644 "${PAYLOAD}/background" /etc/skel/.config/background
[[ -f "${PAYLOAD}/kitty/kitty.conf" ]] && \
    install -Dm644 "${PAYLOAD}/kitty/kitty.conf" /etc/skel/.config/kitty/kitty.conf
for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
    [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
        install -Dm644 "${PAYLOAD}/fastfetch/${f}" "/etc/skel/.config/fastfetch/${f}"
done
[[ -f "${PAYLOAD}/konsole/RaveOS.colorscheme" ]] && \
    install -Dm644 "${PAYLOAD}/konsole/RaveOS.colorscheme" /etc/skel/.local/share/konsole/RaveOS.colorscheme
[[ -f "${PAYLOAD}/konsole/RaveOS.profile" ]] && \
    install -Dm644 "${PAYLOAD}/konsole/RaveOS.profile" /etc/skel/.local/share/konsole/RaveOS.profile

if [[ -f "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" ]]; then
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
        /etc/skel/.local/share/icons/breeze/applets/256/org.kde.plasma.kickoff.svg
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
        /etc/skel/.local/share/icons/breeze-dark/applets/256/org.kde.plasma.kickoff.svg
    install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
        /etc/skel/.local/share/icons/Adwaita/symbolic/places/start-here-symbolic.svg
    for size in 22 32 64 96; do
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "/etc/skel/.local/share/icons/breeze/places/${size}/start-here-kde.svg"
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "/etc/skel/.local/share/icons/breeze-dark/places/${size}/start-here-kde.svg"
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "/etc/skel/.local/share/icons/breeze/places/${size}/start-here.svg"
        install -Dm644 "${PAYLOAD}/plasma/org.kde.plasma.kickoff.svg" \
            "/etc/skel/.local/share/icons/breeze-dark/places/${size}/start-here.svg"
    done
fi

write_konsolerc /etc/skel
write_plasma_wallpaper_config /etc/skel
write_kickoff_config /etc/skel
write_kscreenlockerrc /etc/skel
write_ksplashrc /etc/skel
disable_kmix_autostart /etc/skel
ensure_bashrc_hook /etc/skel/.bashrc

command -v gtk-update-icon-cache &>/dev/null && \
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true

echo "Telepítés kész."
