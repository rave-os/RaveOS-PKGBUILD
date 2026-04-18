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

pkill cosmic-bg || true
pkill cosmic-settings-daemon || true
pkill cosmic-panel || true

touch "${marker_file}"
