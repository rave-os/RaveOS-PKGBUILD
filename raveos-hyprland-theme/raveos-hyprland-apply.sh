#!/usr/bin/env bash
set -euo pipefail

payload_dir="/usr/share/raveos/hyprland-theme/theme-data"

if [[ ! -d "$payload_dir" ]]; then
  echo "Missing payload: $payload_dir" >&2
  exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

# --- /etc/skel ---

mkdir -p /etc/skel/.config/hypr
if [[ -d "${payload_dir}/hypr" ]]; then
  cp -rf "${payload_dir}/hypr/." /etc/skel/.config/hypr/
fi

mkdir -p /etc/skel/.config/dms
mkdir -p /etc/skel/.config/quickshell/pockets/DMS
mkdir -p /etc/skel/.config/DankMaterialShell
dms_src="${payload_dir}/dms"
[[ -f "${dms_src}/shell.qml" ]] || dms_src="${payload_dir}/DankMaterialShell/quickshell"
if [[ -d "$dms_src" ]]; then
  cp -r "${dms_src}/." /etc/skel/.config/quickshell/pockets/DMS/
  cp -r "${dms_src}/." /etc/skel/.config/dms/
  if [[ -d "${dms_src}/matugen/configs" ]]; then
    mkdir -p /etc/skel/.config/matugen
    cp -r "${dms_src}/matugen/configs/." /etc/skel/.config/matugen/
  fi
fi
if [[ -f "${payload_dir}/DankMaterialShell/settings.json" ]]; then
  install -Dm644 "${payload_dir}/DankMaterialShell/settings.json" /etc/skel/.config/DankMaterialShell/settings.json
fi
if [[ -f "${payload_dir}/DankMaterialShell/.firstlaunch" ]]; then
  install -Dm644 "${payload_dir}/DankMaterialShell/.firstlaunch" /etc/skel/.config/DankMaterialShell/.firstlaunch
fi

mkdir -p /etc/skel/.config/kitty
if [[ -d "${payload_dir}/kitty" ]]; then
  cp -r "${payload_dir}/kitty/." /etc/skel/.config/kitty/
fi

if [[ -f "${payload_dir}/hyprland-pp.png" ]]; then
  install -Dm644 "${payload_dir}/hyprland-pp.png" /etc/skel/.face
fi

mkdir -p /etc/skel/.config/fastfetch
for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
  if [[ -f "${payload_dir}/fastfetch/${f}" ]]; then
    install -Dm644 "${payload_dir}/fastfetch/${f}" "/etc/skel/.config/fastfetch/${f}"
  fi
done

if [[ -f "${payload_dir}/profile.d/raveos-fastfetch.sh" ]]; then
  install -Dm755 "${payload_dir}/profile.d/raveos-fastfetch.sh" /etc/profile.d/raveos-fastfetch.sh
fi

if [[ -d "${payload_dir}/skel" ]]; then
  cp -r --no-preserve=ownership "${payload_dir}/skel/." /etc/skel/
fi

if [[ -f "${payload_dir}/background" ]]; then
  mkdir -p /usr/share/backgrounds/raveos
  install -m644 "${payload_dir}/background" /usr/share/backgrounds/raveos/raveos-main-bg.jpeg
  install -Dm644 "${payload_dir}/background" /etc/skel/.config/background
  install -Dm644 "${payload_dir}/background" /etc/skel/.config/background.jpg
fi

for d in gtk-3.0 gtk-4.0 nwg-look Thunar xfce4 xsettingsd; do
  if [[ -d "${payload_dir}/${d}" ]]; then
    mkdir -p "/etc/skel/.config/${d}"
    cp -rf "${payload_dir}/${d}/." "/etc/skel/.config/${d}/"
  fi
done

if [[ -f "${payload_dir}/sddm/sddm.conf" ]]; then
  install -Dm644 "${payload_dir}/sddm/sddm.conf" /etc/sddm.conf.d/raveos-theme.conf
fi

for candidate in \
  "/usr/share/sddm/themes/sddm-astronaut-theme" \
  "/usr/share/sddm/themes/astronaut" \
  "/usr/share/sddm/themes/sddm-astronaut"; do
  if [[ -d "$candidate" ]]; then
    if [[ -f "${payload_dir}/sddm/new-raveos-main-bg.jpeg" ]]; then
      install -Dm644 "${payload_dir}/sddm/new-raveos-main-bg.jpeg" \
        "${candidate}/Backgrounds/new-raveos-main-bg.jpeg"
    fi
    if [[ -f "${payload_dir}/sddm/astronaut.conf" ]]; then
      install -Dm644 "${payload_dir}/sddm/astronaut.conf" \
        "${candidate}/Themes/astronaut.conf"
    fi
    break
  fi
done

# --- meglévő userek ---

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

  if [[ -d "${payload_dir}/hypr" ]]; then
    cp -rf "${payload_dir}/hypr/." "${home}/.config/hypr/"
  fi
  printf 'preload = %s/.config/background.jpg\nwallpaper = ,%s/.config/background.jpg\nsplash = false\n' \
    "$home" "$home" > "${home}/.config/hypr/hyprpaper.conf"

  dms_src="${payload_dir}/dms"
  [[ -f "${dms_src}/shell.qml" ]] || dms_src="${payload_dir}/DankMaterialShell/quickshell"
  if [[ -d "$dms_src" ]]; then
    cp -r "${dms_src}/." "${home}/.config/quickshell/pockets/DMS/"
    cp -r "${dms_src}/." "${home}/.config/dms/"
    if [[ -d "${dms_src}/matugen/configs" ]]; then
      cp -r "${dms_src}/matugen/configs/." "${home}/.config/matugen/"
    fi
  fi
  if [[ -f "${payload_dir}/DankMaterialShell/settings.json" ]]; then
    install -Dm644 "${payload_dir}/DankMaterialShell/settings.json" "${home}/.config/DankMaterialShell/settings.json"
  fi
  if [[ -f "${payload_dir}/DankMaterialShell/.firstlaunch" ]]; then
    install -Dm644 "${payload_dir}/DankMaterialShell/.firstlaunch" "${home}/.config/DankMaterialShell/.firstlaunch"
  fi

  if [[ -d "${payload_dir}/skel" ]]; then
    cp -r --no-preserve=ownership "${payload_dir}/skel/." "$home/"
  fi

  if [[ -f "${payload_dir}/background" ]]; then
    install -Dm644 "${payload_dir}/background" "${home}/.config/background"
    install -Dm644 "${payload_dir}/background" "${home}/.config/background.jpg"
  fi

  if [[ -d "${payload_dir}/kitty" ]]; then
    cp -r "${payload_dir}/kitty/." "${home}/.config/kitty/"
  fi

  if [[ -f "${payload_dir}/hyprland-pp.png" ]]; then
    install -Dm644 "${payload_dir}/hyprland-pp.png" "${home}/.face"
  fi

  for f in config.jsonc config-kitty.jsonc raveos-logo.png raveos-logo.txt; do
    if [[ -f "${payload_dir}/fastfetch/${f}" ]]; then
      install -Dm644 "${payload_dir}/fastfetch/${f}" "${home}/.config/fastfetch/${f}"
    fi
  done

  if [[ -f "${payload_dir}/hypr/scripts/raveos-monitor-setup.sh" ]]; then
    bash "${payload_dir}/hypr/scripts/raveos-monitor-setup.sh" --hypr-dir "${home}/.config/hypr"
  fi

  for d in gtk-3.0 gtk-4.0 nwg-look Thunar xfce4 xsettingsd; do
    if [[ -d "${payload_dir}/${d}" ]]; then
      mkdir -p "${home}/.config/${d}"
      cp -rf "${payload_dir}/${d}/." "${home}/.config/${d}/"
    fi
  done

  chown -R "${uid}:${gid}" "$home"

  if command -v matugen &>/dev/null && [[ -f "${home}/.config/background" ]]; then
    runuser -u "$user" -- matugen image "${home}/.config/background" 2>/dev/null || true
  fi
done < /etc/passwd

echo "Automatic apply finished."
