#!/usr/bin/env bash
set -euo pipefail

marker_dir="${HOME}/.config/raveos-kde-theme"
marker_file="${marker_dir}/.first-login-done"
wallpaper="/usr/share/backgrounds/raveos/raveos-main-bg.jpeg"
kickoff_image="/usr/share/raveos/plasma-theme/theme-data/plasma/org.kde.plasma.kickoff.svg"
applet_config="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"

mkdir -p "${marker_dir}"
[[ -e "${marker_file}" ]] && exit 0
[[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* || "${DESKTOP_SESSION:-}" == *plasma* ]] || exit 0

until qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 || qdbus org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; do
    sleep 2
done

sleep 10

QDBUS=""
if command -v qdbus6 >/dev/null 2>&1; then
  QDBUS="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
  QDBUS="qdbus"
fi

if command -v plasma-apply-lookandfeel >/dev/null 2>&1; then
  plasma-apply-lookandfeel -a org.kde.breezedark.desktop >/dev/null 2>&1 || true
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file "${HOME}/.config/ksplashrc" --group KSplash --key Engine KSplashQML
  kwriteconfig6 --file "${HOME}/.config/ksplashrc" --group KSplash --key Theme org.kde.raveos.desktop
  kwriteconfig6 --file "${HOME}/.config/kdeglobals" --group KDE --key widgetStyle Breeze
  kwriteconfig6 --file "${HOME}/.config/kdeglobals" --group General --key ColorScheme BreezeDark
  kwriteconfig6 --file "${HOME}/.config/kdeglobals" --group Icons --key Theme breeze-dark
fi

if [[ -f "${wallpaper}" ]] && command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "${wallpaper}" >/dev/null 2>&1 || true
fi

if [[ -n "$QDBUS" ]]; then
  $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
    if ('${wallpaper}' !== '') {
      var desktops = desktops();
      for (var i = 0; i < desktops.length; i++) {
        desktops[i].wallpaperPlugin = 'org.kde.image';
        desktops[i].currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
        desktops[i].writeConfig('Image', 'file://${wallpaper}');
        desktops[i].writeConfig('FillMode', 2);
      }
    }

    if ('${kickoff_image}' !== '') {
      function setKickoffIcon(applet, iconPath) {
        var groups = [['Configuration', 'General'], ['General']];
        for (var i = 0; i < groups.length; i++) {
          applet.currentConfigGroup = groups[i];
          applet.writeConfig('useCustomButtonImage', 'true');
          applet.writeConfig('customButtonImage', 'file://' + iconPath);
          applet.writeConfig('icon', iconPath);
        }
      }
      var panels = panels();
      for (var i = 0; i < panels.length; i++) {
        var applets = panels[i].applets;
        for (var j = 0; j < applets.length; j++) {
          var plugin = applets[j].pluginName;
          if (plugin === 'org.kde.plasma.kickoff' || plugin === 'org.kde.plasma.kicker' || plugin === 'org.kde.plasma.simplemenu' || plugin === 'org.kde.plasma.kickoffdashboard') {
            setKickoffIcon(applets[j], '${kickoff_image}');
          }
        }
      }
    }
  " >/dev/null 2>&1 || true
fi

touch "${marker_file}"
