#!/usr/bin/env bash
# raveos-cosmic-apply.sh
# ----------------------
# Telepíti a COSMIC téma payloadját:
#   - /etc/skel alá (új usereknek)
#   - minden meglévő, bejelentkező user home-jába
#
# Root jogosultság szükséges. A raveos-cosmic-theme-apply.service hívja
# egyszer, első boot után.

set -euo pipefail

PAYLOAD="/usr/share/raveos/cosmic-theme/theme-data"

if [[ ! -d "$PAYLOAD" ]]; then
    echo "Hiba: hiányzó payload: $PAYLOAD" >&2
    exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
    echo "Root jogosultság szükséges." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# SEGÉDFÜGGVÉNY
# ---------------------------------------------------------------------------

ensure_bashrc_hook() {
    local bashrc_path="$1"
    local hook_line='[[ -f /etc/profile.d/raveos-fastfetch.sh ]] && source /etc/profile.d/raveos-fastfetch.sh'
    touch "$bashrc_path"
    if ! grep -Fqx "$hook_line" "$bashrc_path" 2>/dev/null; then
        printf '\n%s\n' "$hook_line" >> "$bashrc_path"
    fi
}

# ---------------------------------------------------------------------------
# RENDSZERSZINTŰ TELEPÍTÉS
# ---------------------------------------------------------------------------

# Háttérkép rendszerkönyvtárba
[[ -f "${PAYLOAD}/background" ]] && \
    install -Dm644 "${PAYLOAD}/background" /usr/share/backgrounds/raveos/raveos-main-bg.jpeg

# Fastfetch profile.d script (terminál nyitáskor fut)
[[ -f "${PAYLOAD}/profile.d/raveos-fastfetch.sh" ]] && \
    install -Dm755 "${PAYLOAD}/profile.d/raveos-fastfetch.sh" /etc/profile.d/raveos-fastfetch.sh

# COSMIC rendszerfájlok színátírása (RaveOS paletta)
if [[ -d /usr/share/cosmic ]]; then
    find /usr/share/cosmic -type f -exec sed -i \
        -e 's/0.3882353/0.29411766/g' \
        -e 's/0.8156863/0.52156866/g' \
        -e 's/0.8745098/0.003921569/g' \
        {} + || true
fi

# SDDM: a téma és konfig a PKGBUILD + .install hook által van telepítve, itt nincs teendő

# ---------------------------------------------------------------------------
# SKEL TELEPÍTÉS
# Új usereknek (useradd által másolt /etc/skel tartalom)
# ---------------------------------------------------------------------------

mkdir -p \
    /etc/skel/.config/kitty \
    /etc/skel/.config/fastfetch \
    /etc/skel/.config/cosmic/com.system76.CosmicTerm/v1

[[ -f "${PAYLOAD}/kitty/kitty.conf" ]] && \
    install -Dm644 "${PAYLOAD}/kitty/kitty.conf" /etc/skel/.config/kitty/kitty.conf
[[ -d "${PAYLOAD}/cosmic-term/v1" ]] && \
    cp -r "${PAYLOAD}/cosmic-term/v1/." /etc/skel/.config/cosmic/com.system76.CosmicTerm/v1/
for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
    [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
        install -Dm644 "${PAYLOAD}/fastfetch/${f}" "/etc/skel/.config/fastfetch/${f}"
done
ensure_bashrc_hook /etc/skel/.bashrc

# ---------------------------------------------------------------------------
# MEGLÉVŐ USEREK FRISSÍTÉSE
# /etc/passwd alapján minden UID >= 1000 bejelentkező user home-ja
# ---------------------------------------------------------------------------

while IFS=: read -r user _ uid gid _ home shell; do
    [[ "$uid" -ge 1000 ]] || continue
    [[ -d "$home" ]] || continue
    [[ "$shell" != "/usr/bin/nologin" && "$shell" != "/bin/false" ]] || continue

    mkdir -p \
        "${home}/.config/kitty" \
        "${home}/.config/fastfetch" \
        "${home}/.config/cosmic/com.system76.CosmicTerm/v1"

    [[ -f "${PAYLOAD}/kitty/kitty.conf" ]] && \
        install -Dm644 "${PAYLOAD}/kitty/kitty.conf" "${home}/.config/kitty/kitty.conf"
    [[ -d "${PAYLOAD}/cosmic-term/v1" ]] && \
        cp -r "${PAYLOAD}/cosmic-term/v1/." "${home}/.config/cosmic/com.system76.CosmicTerm/v1/"
    for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
        [[ -f "${PAYLOAD}/fastfetch/${f}" ]] && \
            install -Dm644 "${PAYLOAD}/fastfetch/${f}" "${home}/.config/fastfetch/${f}"
    done
    ensure_bashrc_hook "${home}/.bashrc"

    chown -R "${uid}:${gid}" "$home"
done < /etc/passwd

echo "Telepítés kész."
