#!/bin/bash
set -e

echo ">>> [fix-bootentry] Running INSIDE target system"

ENTRYDIR="/boot/loader/entries"
[ -d "${ENTRYDIR}" ] || { echo ">>> [fix-bootentry] No ${ENTRYDIR}, skipping."; exit 0; }

# 95-raveos.install (kernel-install hook, fired during pacstrap/mkinitcpio)
# detects the root device via findmnt at hook-time. Depending on the
# chroot/mount-namespace context that detection can silently come back
# empty, producing a loader entry with no "root=" in its options line
# (system then drops to an emergency shell on boot: "Failed to mount ''
# on real root"). By this point in the install sequence /etc/fstab is
# already correctly generated, so use it as the authoritative source and
# patch any entry that is missing root=.

ROOT_UUID="$(findmnt -no UUID / || true)"
if [ -z "${ROOT_UUID}" ]; then
  ROOT_UUID="$(awk '$2 == "/" && $1 ~ /^UUID=/ {print $1; exit}' /etc/fstab | sed 's/^UUID=//')"
fi

if [ -z "${ROOT_UUID}" ]; then
  echo ">>> [fix-bootentry] Could not determine root UUID from findmnt or fstab, leaving entries untouched."
  exit 0
fi

echo ">>> [fix-bootentry] Root UUID: ${ROOT_UUID}"

for f in "${ENTRYDIR}"/*.conf; do
  [ -f "$f" ] || continue

  if grep -qE '^options[[:space:]].*\broot=' "$f"; then
    echo ">>> [fix-bootentry] Already has root=, skipping: $f"
    continue
  fi

  echo ">>> [fix-bootentry] Patching missing root= in: $f"
  sed -i -E "s#^options[[:space:]]+#options root=UUID=${ROOT_UUID} #" "$f"
done

echo ">>> [fix-bootentry] Done."
