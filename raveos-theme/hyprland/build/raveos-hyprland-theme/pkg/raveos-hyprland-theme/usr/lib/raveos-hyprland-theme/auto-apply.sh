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

mkdir -p /etc/skel

if [[ -f "${payload_dir}/kitty/kitty.conf" ]]; then
  install -Dm644 "${payload_dir}/kitty/kitty.conf" /etc/skel/.config/kitty/kitty.conf
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
  install -Dm644 "${payload_dir}/background" /usr/share/backgrounds/raveos/raveos-main-bg.jpeg
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
  if [[ -d "${payload_dir}/skel" ]]; then
    cp -r --no-preserve=ownership "${payload_dir}/skel/." "$home/"
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
  chown -R "${uid}:${gid}" "$home"
done < /etc/passwd

echo "Automatic apply finished."
