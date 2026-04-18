#!/usr/bin/env bash
set -euo pipefail

payload_dir="/usr/share/raveos/cosmic-theme/theme-data"
fastfetch_hook='[[ -f /etc/profile.d/raveos-fastfetch.sh ]] && source /etc/profile.d/raveos-fastfetch.sh'

if [[ ! -d "$payload_dir" ]]; then
  echo "Missing payload: $payload_dir" >&2
  exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

ensure_bashrc_hook() {
  local bashrc_path="$1"
  touch "$bashrc_path"
  if ! grep -Fqx "$fastfetch_hook" "$bashrc_path" 2>/dev/null; then
    printf '\n%s\n' "$fastfetch_hook" >> "$bashrc_path"
  fi
}

mkdir -p /etc/skel/.config/kitty
mkdir -p /etc/skel/.config/fastfetch
mkdir -p /etc/skel/.config/cosmic/com.system76.CosmicTerm/v1

if [[ -f "${payload_dir}/kitty/kitty.conf" ]]; then
  install -Dm644 "${payload_dir}/kitty/kitty.conf" /etc/skel/.config/kitty/kitty.conf
fi

if [[ -d "${payload_dir}/cosmic-term/v1" ]]; then
  cp -r "${payload_dir}/cosmic-term/v1/"* /etc/skel/.config/cosmic/com.system76.CosmicTerm/v1/
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

ensure_bashrc_hook /etc/skel/.bashrc

if [[ -f "${payload_dir}/background" ]]; then
  install -Dm644 "${payload_dir}/background" /usr/share/backgrounds/raveos/raveos-main-bg.jpeg
fi

if [[ -d /usr/share/cosmic ]]; then
  find /usr/share/cosmic -type f -exec sed -i 's/0.3882353/0.29411766/g' {} + || true
  find /usr/share/cosmic -type f -exec sed -i 's/0.8156863/0.52156866/g' {} + || true
  find /usr/share/cosmic -type f -exec sed -i 's/0.8745098/0.003921569/g' {} + || true
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
  mkdir -p "${home}/.config/kitty" "${home}/.config/fastfetch" "${home}/.config/cosmic/com.system76.CosmicTerm/v1"
  if [[ -f "${payload_dir}/kitty/kitty.conf" ]]; then
    install -Dm644 "${payload_dir}/kitty/kitty.conf" "${home}/.config/kitty/kitty.conf"
  fi
  if [[ -d "${payload_dir}/cosmic-term/v1" ]]; then
    cp -r "${payload_dir}/cosmic-term/v1/"* "${home}/.config/cosmic/com.system76.CosmicTerm/v1/"
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
  ensure_bashrc_hook "${home}/.bashrc"
  chown -R "${uid}:${gid}" "$home"
done < /etc/passwd

echo "Automatic apply finished."
