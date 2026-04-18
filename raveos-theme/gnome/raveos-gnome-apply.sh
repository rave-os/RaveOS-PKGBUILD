#!/usr/bin/env bash
set -euo pipefail

payload_dir="/usr/share/raveos/gnome-theme/theme-data"

if [[ ! -d "$payload_dir" ]]; then
  echo "Missing payload: $payload_dir" >&2
  exit 1
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

wallpaper_src="${payload_dir}/background"
wallpaper_dst="/usr/share/backgrounds/raveos/raveos-main-bg.jpeg"
themes_src="${payload_dir}/user-themes"
icons_src="${payload_dir}/user-icons"
extensions_src="${payload_dir}/extensions/installed"
kitty_src="${payload_dir}/kitty/kitty.conf"
fastfetch_src="${payload_dir}/fastfetch/config.jsonc"
fastfetch_kitty_src="${payload_dir}/fastfetch/config-kitty.jsonc"
fastfetch_logo_src="${payload_dir}/fastfetch/raveos-logo.png"
fastfetch_logo_txt_src="${payload_dir}/fastfetch/raveos-logo.txt"
fastfetch_profile_src="${payload_dir}/profile.d/raveos-fastfetch.sh"
burn_my_windows_src="${payload_dir}/burn-my-windows/burn-my-windows.conf"
full_dump_src="${payload_dir}/dconf/full-system-dump.ini"
sddm_theme_dir="/usr/share/sddm/themes/sddm-astronaut-theme"
app_grid_icon_src="${payload_dir}/icons/view-app-grid-symbolic.svg"
app_grid_icon_dst="/usr/share/icons/Adwaita/symbolic/actions/view-app-grid-symbolic.svg"
system_logo_src="${payload_dir}/system/raveos-logo.svg"
system_logo_pixmaps_dst="/usr/share/pixmaps/raveos-logo.svg"
system_logo_hicolor_dst="/usr/share/icons/hicolor/scalable/apps/raveos-logo.svg"
dconf_profile_dir="/etc/dconf/profile"
dconf_db_dir="/etc/dconf/db/local.d"
dconf_default_file="${dconf_db_dir}/00-raveos"
applications_override_dir="/usr/local/share/applications"
mimeapps_block='[Default Applications]
image/jpeg=org.gnome.eog.desktop
image/png=org.gnome.eog.desktop
image/webp=org.gnome.eog.desktop
image/gif=org.gnome.eog.desktop
image/bmp=org.gnome.eog.desktop
image/tiff=org.gnome.eog.desktop
image/avif=org.gnome.eog.desktop
image/heif=org.gnome.eog.desktop
image/heic=org.gnome.eog.desktop'

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
  cat > "$mimeapps_path" <<EOF
${mimeapps_block}
EOF
}

build_system_dconf_defaults() {
  sed \
    -e "s|file:///home/{HOME}/.config/background|file://${wallpaper_dst}|g" \
    "$full_dump_src" > "$dconf_default_file"
}

build_user_dconf_dump() {
  local target_home="$1"
  local output_path="$2"

  sed \
    -e "s|file:///home/{HOME}/.config/background|file://${target_home}/.config/background|g" \
    -e "s|{HOME}|${target_home}|g" \
    "$full_dump_src" > "$output_path"
}

install -Dm644 "${payload_dir}/sddm/sddm.conf" /etc/sddm.conf.d/raveos-theme.conf
install -Dm644 "$app_grid_icon_src" "$app_grid_icon_dst"
install -Dm644 "$system_logo_src" "$system_logo_pixmaps_dst"
install -Dm644 "$system_logo_src" "$system_logo_hicolor_dst"
install -Dm644 "$wallpaper_src" "$wallpaper_dst"

mkdir -p "$applications_override_dir"
for desktop_id in \
  avahi-discover.desktop \
  bssh.desktop \
  bvnc.desktop \
  qv4l2.desktop \
  qvidcap.desktop \
  vim.desktop; do
  cat > "${applications_override_dir}/${desktop_id}" <<EOF
[Desktop Entry]
NoDisplay=true
EOF
done

mkdir -p "$dconf_profile_dir" "$dconf_db_dir"
cat > "${dconf_profile_dir}/user" <<'EOF'
user-db:user
system-db:local
EOF

build_system_dconf_defaults

if command -v dconf >/dev/null 2>&1; then
  dconf update || true
fi

for candidate in \
  "/usr/share/sddm/themes/sddm-astronaut-theme" \
  "/usr/share/sddm/themes/astronaut" \
  "/usr/share/sddm/themes/sddm-astronaut"; do
  if [[ -d "$candidate" ]]; then
    install -Dm644 "${payload_dir}/sddm/new-raveos-main-bg.jpeg" \
      "${candidate}/Backgrounds/new-raveos-main-bg.jpeg"
    install -Dm644 "${payload_dir}/sddm/astronaut.conf" \
      "${candidate}/Themes/astronaut.conf"
    break
  fi
done

install_user() {
  local target_user="$1"
  local passwd_line target_uid target_gid target_home actual_target_home tmpdir

  passwd_line="$(getent passwd "$target_user" || true)"
  [[ -n "$passwd_line" ]] || return 0

  IFS=: read -r _ _ target_uid target_gid _ target_home _ <<<"$passwd_line"
  actual_target_home="$target_home"
  [[ -d "$actual_target_home" ]] || return 0

  mkdir -p \
    "${actual_target_home}/.config/kitty" \
    "${actual_target_home}/.config/fastfetch" \
    "${actual_target_home}/.config/burn-my-windows/profiles" \
    "${actual_target_home}/.config" \
    "${actual_target_home}/.themes" \
    "${actual_target_home}/.icons" \
    "${actual_target_home}/.local/share/gnome-shell/extensions"

  install -Dm644 "$wallpaper_dst" "${actual_target_home}/.config/background"
  cp -r --no-preserve=ownership "${themes_src}/." "${actual_target_home}/.themes/"
  cp -r --no-preserve=ownership "${icons_src}/." "${actual_target_home}/.icons/"
  cp -r --no-preserve=ownership "${extensions_src}/." "${actual_target_home}/.local/share/gnome-shell/extensions/"
  install -Dm644 "$kitty_src" "${actual_target_home}/.config/kitty/kitty.conf"
  install -Dm644 "$fastfetch_src" "${actual_target_home}/.config/fastfetch/config.jsonc"
  install -Dm644 "$fastfetch_kitty_src" "${actual_target_home}/.config/fastfetch/config-kitty.jsonc"
  install -Dm644 "$fastfetch_logo_src" "${actual_target_home}/.config/fastfetch/raveos-logo.png"
  install -Dm644 "$fastfetch_logo_txt_src" "${actual_target_home}/.config/fastfetch/raveos-logo.txt"
  install -Dm644 "$burn_my_windows_src" "${actual_target_home}/.config/burn-my-windows/profiles/burn-my-windows.conf"
  write_mimeapps_defaults "${actual_target_home}/.config/mimeapps.list"
  ensure_bashrc_hook "${actual_target_home}/.bashrc"

  if command -v glib-compile-schemas >/dev/null 2>&1; then
    find "${actual_target_home}/.local/share/gnome-shell/extensions" -type d -name schemas -print0 | while IFS= read -r -d '' schema_dir; do
      glib-compile-schemas "$schema_dir"
    done
  fi

  tmpdir="$(mktemp -d)"
  chmod 755 "$tmpdir"
  build_user_dconf_dump "${actual_target_home}" "${tmpdir}/full-system-dump.ini"
  chmod 644 "${tmpdir}/full-system-dump.ini"

  if command -v dconf >/dev/null 2>&1 && command -v dbus-run-session >/dev/null 2>&1; then
    runuser -u "$target_user" -- env \
      HOME="${actual_target_home}" \
      USER="${target_user}" \
      LOGNAME="${target_user}" \
      XDG_CONFIG_HOME="${actual_target_home}/.config" \
      XDG_DATA_HOME="${actual_target_home}/.local/share" \
      dbus-run-session /bin/bash -lc "
        dconf load / < '${tmpdir}/full-system-dump.ini' || true
        gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-olive-dark' || true
        gsettings set org.gnome.desktop.interface icon-theme 'Adwaitaru-olive' || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
        gsettings set org.gnome.desktop.background picture-uri 'file://${actual_target_home}/.config/background' || true
        gsettings set org.gnome.desktop.background picture-uri-dark 'file://${actual_target_home}/.config/background' || true
        gsettings set org.gnome.shell.extensions.user-theme name 'Yaru-olive-dark' || true
      " || true
  fi

  rm -rf "$tmpdir"

  chown -R "${target_uid}:${target_gid}" \
    "${actual_target_home}/.config" \
    "${actual_target_home}/.local" \
    "${actual_target_home}/.themes" \
    "${actual_target_home}/.icons" \
    "${actual_target_home}/.bashrc"
}

while IFS=: read -r user _ uid _ _ home shell; do
  [[ "$uid" -ge 1000 ]] || continue
  [[ -d "$home" ]] || continue
  [[ "$shell" != "/usr/bin/nologin" && "$shell" != "/bin/false" ]] || continue
  install_user "$user"
done < /etc/passwd

mkdir -p \
  /etc/skel/.config/kitty \
  /etc/skel/.config/fastfetch \
  /etc/skel/.config/burn-my-windows/profiles \
  /etc/skel/.themes \
  /etc/skel/.icons \
  /etc/skel/.local/share/gnome-shell/extensions

cp -r --no-preserve=ownership "${themes_src}/." /etc/skel/.themes/
cp -r --no-preserve=ownership "${icons_src}/." /etc/skel/.icons/
cp -r --no-preserve=ownership "${extensions_src}/." /etc/skel/.local/share/gnome-shell/extensions/
install -Dm644 "$wallpaper_dst" /etc/skel/.config/background
install -Dm644 "$kitty_src" /etc/skel/.config/kitty/kitty.conf
install -Dm644 "$fastfetch_src" /etc/skel/.config/fastfetch/config.jsonc
install -Dm644 "$fastfetch_kitty_src" /etc/skel/.config/fastfetch/config-kitty.jsonc
install -Dm644 "$fastfetch_logo_src" /etc/skel/.config/fastfetch/raveos-logo.png
install -Dm644 "$fastfetch_logo_txt_src" /etc/skel/.config/fastfetch/raveos-logo.txt
install -Dm755 "$fastfetch_profile_src" /etc/profile.d/raveos-fastfetch.sh
install -Dm644 "$burn_my_windows_src" /etc/skel/.config/burn-my-windows/profiles/burn-my-windows.conf
write_mimeapps_defaults /etc/skel/.config/mimeapps.list
ensure_bashrc_hook /etc/skel/.bashrc

echo "Automatic apply finished."
