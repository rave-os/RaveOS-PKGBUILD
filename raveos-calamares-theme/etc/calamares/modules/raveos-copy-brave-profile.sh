#!/usr/bin/env bash
# RaveOS: Brave Origin profil másolása a céluser HOME-jába
# A Calamares shellprocess (dontChroot: true) hívja, $1 = ${ROOT}.
set -euo pipefail

ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "raveos-copy-brave-profile: ROOT hiányzik"; exit 1; }

SRC="/etc/calamares/brave-profile"
[ -d "$SRC" ] || { echo "raveos-copy-brave-profile: forrás hiányzik ($SRC)"; exit 0; }

# Céluser + UID:GID a target /etc/passwd-ből (nem a live rendszerből)
USERLINE=$(awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)/ {print; exit}' "$ROOT/etc/passwd")
[ -n "$USERLINE" ] || { echo "raveos-copy-brave-profile: nincs céluser"; exit 0; }

USERNAME=$(echo "$USERLINE" | cut -d: -f1)
UID_GID=$(echo "$USERLINE" | cut -d: -f3,4)

DEST="/home/$USERNAME/.config/BraveSoftware"
mkdir -p "$ROOT$DEST"
cp -a "$SRC" "$ROOT$DEST/Brave-Origin"
chown -R "$UID_GID" "$ROOT$DEST/Brave-Origin"

echo "raveos-copy-brave-profile: $DEST/Brave-Origin kész"
