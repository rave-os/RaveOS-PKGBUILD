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

mkdir -p /etc/skel/.config/hypr
if [[ -d "${payload_dir}/hypr" ]]; then
  cp -rf "${payload_dir}/hypr/." /etc/skel/.config/hypr/
fi
mkdir -p /etc/skel/.config/dms
mkdir -p /etc/skel/.config/matugen
mkdir -p /etc/skel/.config/kitty
mkdir -p /etc/skel/.config/fastfetch
mkdir -p /etc/skel/.config/quickshell/pockets/DMS

if [[ -d "${payload_dir}/DankMaterialShell/quickshell" ]]; then
  cp -r "${payload_dir}/DankMaterialShell/quickshell/." /etc/skel/.config/quickshell/pockets/DMS/
  cp -r "${payload_dir}/DankMaterialShell/quickshell/." /etc/skel/.config/dms/
  if [[ -d "${payload_dir}/DankMaterialShell/quickshell/matugen/configs" ]]; then
    cp -r "${payload_dir}/DankMaterialShell/quickshell/matugen/configs/." /etc/skel/.config/matugen/
  fi
fi

if [[ -f "${payload_dir}/fastfetch/config.jsonc" ]]; then
  install -Dm644 "${payload_dir}/fastfetch/config.jsonc" /etc/skel/.config/fastfetch/config.jsonc
fi

if [[ -f "${payload_dir}/fastfetch/config-kitty.jsonc" ]]; then
  install -Dm644 "${payload_dir}/fastfetch/config-kitty.jsonc" /etc/skel/.config/fastfetch/config-kitty.jsonc
fi

if [[ -f "${payload_dir}/fastfetch/raveos-logo.png" ]]; then
  install -Dm644 "${payload_dir}/fastfetch/raveos-logo.png" /etc/skel/.config/fastfetch/raveos-logo.png
fi

if [[ -f "${payload_dir}/fastfetch/raveos-logo.txt" ]]; then
  install -Dm644 "${payload_dir}/fastfetch/raveos-logo.txt" /etc/skel/.config/fastfetch/raveos-logo.txt
fi

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
fi

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

while IFS=: read -r user _ uid gid _ home shell; do
  [[ "$uid" -ge 1000 ]] || continue
  [[ -d "$home" ]] || continue
  [[ "$shell" != "/usr/bin/nologin" && "$shell" != "/bin/false" ]] || continue
  mkdir -p "${home}/.config/hypr" "${home}/.config/quickshell/pockets/DMS" "${home}/.config/dms" "${home}/.config/matugen" "${home}/.config/kitty" "${home}/.config/fastfetch"
  if [[ -d "${payload_dir}/hypr" ]]; then
    cp -rf "${payload_dir}/hypr/." "${home}/.config/hypr/"
  fi
  if [[ -d "${payload_dir}/DankMaterialShell/quickshell" ]]; then
    cp -r "${payload_dir}/DankMaterialShell/quickshell/." "${home}/.config/quickshell/pockets/DMS/"
    cp -r "${payload_dir}/DankMaterialShell/quickshell/." "${home}/.config/dms/"
    if [[ -d "${payload_dir}/DankMaterialShell/quickshell/matugen/configs" ]]; then
      cp -r "${payload_dir}/DankMaterialShell/quickshell/matugen/configs/." "${home}/.config/matugen/"
    fi
  fi

  if [[ -d "${payload_dir}/skel" ]]; then
    cp -r --no-preserve=ownership "${payload_dir}/skel/." "$home/"
  fi
  if [[ -f "${payload_dir}/background" ]]; then
    install -Dm644 "${payload_dir}/background" "${home}/.config/background"
  fi
  if [[ -f "${payload_dir}/kitty/kitty.conf" ]]; then
    install -Dm644 "${payload_dir}/kitty/kitty.conf" "${home}/.config/kitty/kitty.conf"
  fi
  if [[ -f "${payload_dir}/fastfetch/config.jsonc" ]]; then
    install -Dm644 "${payload_dir}/fastfetch/config.jsonc" "${home}/.config/fastfetch/config.jsonc"
  fi
  if [[ -f "${payload_dir}/fastfetch/config-kitty.jsonc" ]]; then
    install -Dm644 "${payload_dir}/fastfetch/config-kitty.jsonc" "${home}/.config/fastfetch/config-kitty.jsonc"
  fi
  if [[ -f "${payload_dir}/fastfetch/raveos-logo.png" ]]; then
    install -Dm644 "${payload_dir}/fastfetch/raveos-logo.png" "${home}/.config/fastfetch/raveos-logo.png"
  fi
  if [[ -f "${payload_dir}/fastfetch/raveos-logo.txt" ]]; then
    install -Dm644 "${payload_dir}/fastfetch/raveos-logo.txt" "${home}/.config/fastfetch/raveos-logo.txt"
  fi
  if [[ -f "${payload_dir}/hypr/scripts/raveos-monitor-setup.sh" ]]; then
    bash "${payload_dir}/hypr/scripts/raveos-monitor-setup.sh" --hypr-dir "${home}/.config/hypr"
  fi
  chown -R "${uid}:${gid}" "$home"
done < /etc/passwd

echo "Automatic apply finished."
