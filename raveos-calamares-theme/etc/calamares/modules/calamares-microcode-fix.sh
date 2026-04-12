#!/bin/bash
set -e

echo ">>> [microcode-fix] Running INSIDE target system"

VENDOR=$(awk -F: '/vendor_id/ {print $2; exit}' /proc/cpuinfo | xargs)
echo ">>> [microcode-fix] Detected CPU vendor: ${VENDOR}"

if [[ "${VENDOR}" == "GenuineIntel" ]]; then
  PKG="intel-ucode"
  UCODE_IMG="/boot/intel-ucode.img"
  UCODE_LINE="initrd  /intel-ucode.img"
elif [[ "${VENDOR}" == "AuthenticAMD" ]]; then
  PKG="amd-ucode"
  UCODE_IMG="/boot/amd-ucode.img"
  UCODE_LINE="initrd  /amd-ucode.img"
else
  echo ">>> [microcode-fix] Unknown vendor, skipping."
  exit 0
fi

echo ">>> [microcode-fix] Installing microcode package: ${PKG}"
pacman -Sy --noconfirm "${PKG}" || true

if [[ "${VENDOR}" == "AuthenticAMD" ]]; then
  echo ">>> [microcode-fix] Installing zenpower5-dkms-git + deps..."

  pacman -Syy --noconfirm || true

  pacman -S --noconfirm dkms linux-cachyos-headers zenpower5-dkms-git || true

  echo ">>> [microcode-fix] Enabling zenpower module autoload..."
  mkdir -p /etc/modules-load.d
  echo "zenpower" > /etc/modules-load.d/zenpower.conf

  echo ">>> [microcode-fix] DKMS autoinstall..."
  dkms autoinstall || true

  echo ">>> [microcode-fix] Rebuilding initramfs..."
  mkinitcpio -P || true

  echo ">>> [microcode-fix] zenpower package check:"
  pacman -Q zenpower5-dkms-git 2>/dev/null && echo ">>> zenpower OK" || echo ">>> zenpower MISSING"
fi


if [ ! -f "${UCODE_IMG}" ]; then
  echo ">>> [microcode-fix] Missing ${UCODE_IMG}, skipping entry patch."
  exit 0
fi

ENTRYDIR="/boot/loader/entries"
echo ">>> [microcode-fix] Entry dir: ${ENTRYDIR}"

[ -d "${ENTRYDIR}" ] || exit 0

for f in "${ENTRYDIR}"/*.conf; do
  [ -f "$f" ] || continue
  echo ">>> [microcode-fix] Patching: $f"

  if grep -qE '^initrd[[:space:]]+/amd-ucode\.img$' "$f" || grep -qE '^initrd[[:space:]]+/intel-ucode\.img$' "$f"; then
    echo ">>> [microcode-fix] Already has microcode initrd, skipping: $f"
    continue
  fi

  tmp="$(mktemp)"
  {
    echo "${UCODE_LINE}"
    cat "$f"
  } > "$tmp"
  cat "$tmp" > "$f"
  rm -f "$tmp"
done

echo ">>> [microcode-fix] Done."
