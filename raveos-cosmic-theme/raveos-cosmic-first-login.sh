#!/usr/bin/env bash
set -euo pipefail

marker_dir="${HOME}/.config/raveos-cosmic-theme"
marker_file="${marker_dir}/.first-login-done"
wallpaper="/usr/share/backgrounds/raveos/raveos-main-bg.jpeg"

mkdir -p "${marker_dir}"
[[ -e "${marker_file}" ]] && exit 0
[[ "${XDG_CURRENT_DESKTOP:-}" == *COSMIC* ]] || exit 0

sleep 5

mkdir -p "${HOME}/.config/cosmic/com.system76.CosmicTheme/v1"
mkdir -p "${HOME}/.config/cosmic/com.system76.CosmicTheme.Appearance/v1"

echo '(accent: (r: 75, g: 133, b: 1, a: 255))' > "${HOME}/.config/cosmic/com.system76.CosmicTheme/v1/active_theme"
echo 'accent_color: Some("#4B8501")' > "${HOME}/.config/cosmic/com.system76.CosmicTheme.Appearance/v1/custom"

cat > "${HOME}/.config/cosmic/com.system76.CosmicTheme.ron" <<EOF
(
    active_theme: (
        accent: (r: 75, g: 133, b: 1, a: 255),
    ),
)
EOF

if [[ -f "${wallpaper}" ]]; then
  mkdir -p "${HOME}/.config/cosmic/com.system76.CosmicBackground/v1"
  cat > "${HOME}/.config/cosmic/com.system76.CosmicBackground/v1/all" <<EOF
(
    output: "all",
    source: Path("${wallpaper}"),
    filter_by_theme: true,
    rotation_frequency: 300,
    filter_method: Lanczos,
    scaling_mode: Zoom,
    sampling_method: Alphanumeric,
)
EOF
  echo "true" > "${HOME}/.config/cosmic/com.system76.CosmicBackground/v1/same-on-all"
fi

# Billentyuzet-kiosztas: a Calamares (systemd-localed) altal beallitott
# layout/variant atvetele az X11 konfigbol; ez az, amit a cosmic-comp is olvas.
kb_layout="hu"
kb_variant=""
xorg_kb="/etc/X11/xorg.conf.d/00-keyboard.conf"
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
mkdir -p "${HOME}/.config/cosmic/com.system76.CosmicComp/v1"
cat > "${HOME}/.config/cosmic/com.system76.CosmicComp/v1/xkb_config" <<EOF
(
    rules: "",
    model: "",
    layout: "${kb_layout}",
    variant: "${kb_variant}",
    options: None,
    repeat_delay: 600,
    repeat_rate: 25,
)
EOF

pkill cosmic-bg || true
pkill cosmic-settings-daemon || true
pkill cosmic-panel || true

touch "${marker_file}"
