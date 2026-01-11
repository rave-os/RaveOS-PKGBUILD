#!/usr/bin/env bash
set -euo pipefail

echo "[calamares] Applying systemd-boot post-install fix"

BOOT="/boot"
ENTRIES="$BOOT/loader/entries"
MID="$(cat /etc/machine-id)"

# --------------------------------------------------
# Disable kernel-install permanently
# --------------------------------------------------
echo "[calamares] Disabling kernel-install"

rm -rf /usr/lib/kernel/install.d || true

if [[ -x /usr/bin/kernel-install ]]; then
    ln -sf /dev/null /usr/bin/kernel-install
fi

if [[ -x /bin/kernel-install ]]; then
    ln -sf /dev/null /bin/kernel-install
fi

# --------------------------------------------------
# Remove machine-id based boot artifacts
# --------------------------------------------------
echo "[calamares] Removing machine-id boot entries"

rm -f "$ENTRIES"/"$MID"-*.conf || true
rm -rf "$BOOT/$MID" || true

# --------------------------------------------------
# Detect installed kernel
# --------------------------------------------------
KERNEL="linux-cachyos"

[[ -e "$BOOT/vmlinuz-linux-lts" ]] && KERNEL="linux-lts"
[[ -e "$BOOT/vmlinuz-linux-zen" ]] && KERNEL="linux-zen"
[[ -e "$BOOT/vmlinuz-linux-hardened" ]] && KERNEL="linux-hardened"

VMLINUX="/vmlinuz-$KERNEL"
INITRD="/initramfs-$KERNEL.img"

# --------------------------------------------------
# Detect microcode
# --------------------------------------------------
MICROCODE_LINES=()

[[ -e "$BOOT/intel-ucode.img" ]] && MICROCODE_LINES+=("initrd  /intel-ucode.img")
[[ -e "$BOOT/amd-ucode.img" ]] && MICROCODE_LINES+=("initrd  /amd-ucode.img")

# --------------------------------------------------
# Root device (PARTUUID-safe)
# --------------------------------------------------
ROOT_SRC="$(findmnt -no SOURCE /)"
ROOT_UUID="$(blkid -s PARTUUID -o value "$ROOT_SRC")"

# --------------------------------------------------
# Write static systemd-boot entry
# --------------------------------------------------
ENTRY="$ENTRIES/$KERNEL.conf"

echo "[calamares] Writing static boot entry: $ENTRY"

{
    echo "title   Linux ($KERNEL)"
    echo "linux   $VMLINUX"
    for line in "${MICROCODE_LINES[@]}"; do
        echo "$line"
    done
    echo "initrd  $INITRD"
    echo "options root=PARTUUID=$ROOT_UUID rw quiet"
} > "$ENTRY"

# --------------------------------------------------
# Ensure loader.conf sane defaults
# --------------------------------------------------
LOADER_CONF="$BOOT/loader/loader.conf"

if [[ ! -f "$LOADER_CONF" ]]; then
    cat > "$LOADER_CONF" <<EOF
default $KERNEL.conf
timeout 3
editor  no
EOF
fi

# --------------------------------------------------
# Regenerate initramfs (safety)
# --------------------------------------------------
echo "[calamares] Regenerating initramfs"
mkinitcpio -P || true

echo "[calamares] systemd-boot fix applied successfully"
