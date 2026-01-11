#!/bin/sh

echo "[calamares] systemd-boot post-install fix starting"

BOOT=/boot
ENTRIES=$BOOT/loader/entries

# --------------------------------------------------
# Disable kernel-install safely
# --------------------------------------------------
rm -rf /usr/lib/kernel/install.d 2>/dev/null

[ -x /usr/bin/kernel-install ] && ln -sf /dev/null /usr/bin/kernel-install
[ -x /bin/kernel-install ] && ln -sf /dev/null /bin/kernel-install

# --------------------------------------------------
# Remove machine-id entries (do NOT fail if missing)
# --------------------------------------------------
if [ -f /etc/machine-id ]; then
    MID=$(cat /etc/machine-id)
    rm -f "$ENTRIES/$MID"-*.conf 2>/dev/null
    rm -rf "$BOOT/$MID" 2>/dev/null
fi

# --------------------------------------------------
# Kernel detection (safe)
# --------------------------------------------------
KERNEL=linux
for k in linux linux-lts linux-zen linux-hardened; do
    [ -e "$BOOT/vmlinuz-$k" ] && KERNEL=$k
done

VMLINUX="/vmlinuz-$KERNEL"
INITRD="/initramfs-$KERNEL.img"

# --------------------------------------------------
# Microcode detection
# --------------------------------------------------
MICROCODE=""
[ -e "$BOOT/intel-ucode.img" ] && MICROCODE="initrd  /intel-ucode.img"
[ -e "$BOOT/amd-ucode.img" ] && MICROCODE="initrd  /amd-ucode.img"

# --------------------------------------------------
# Root + filesystem detection (NO findmnt)
# --------------------------------------------------
ROOT_SRC=$(awk '$2=="/"{print $1}' /proc/self/mounts)
ROOT_OPTS=$(awk '$2=="/"{print $4}' /proc/self/mounts)
ROOT_FS=$(awk '$2=="/"{print $3}' /proc/self/mounts)

OPTS="rw quiet"

# --------------------------------------------------
# LUKS detection (mapper path only)
# --------------------------------------------------
case "$ROOT_SRC" in
    /dev/mapper/*)
        NAME=$(basename "$ROOT_SRC")
        UUID=$(blkid -s UUID -o value "/dev/disk/by-id/*" 2>/dev/null | head -n1)
        OPTS="$OPTS root=/dev/mapper/$NAME"
        ;;
    *)
        PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_SRC" 2>/dev/null)
        [ -n "$PARTUUID" ] && OPTS="$OPTS root=PARTUUID=$PARTUUID"
        ;;
esac

# --------------------------------------------------
# Btrfs subvolume detection
# --------------------------------------------------
if [ "$ROOT_FS" = "btrfs" ]; then
    SUBVOL=$(echo "$ROOT_OPTS" | tr ',' '\n' | grep '^subvol=' | cut -d= -f2)
    [ -n "$SUBVOL" ] && OPTS="$OPTS rootflags=subvol=$SUBVOL"
fi

# --------------------------------------------------
# Write static systemd-boot entry
# --------------------------------------------------
ENTRY="$ENTRIES/$KERNEL.conf"

{
    echo "title   Linux ($KERNEL)"
    echo "linux   $VMLINUX"
    [ -n "$MICROCODE" ] && echo "$MICROCODE"
    echo "initrd  $INITRD"
    echo "options $OPTS"
} > "$ENTRY"

# --------------------------------------------------
# loader.conf sanity
# --------------------------------------------------
if [ ! -f "$BOOT/loader/loader.conf" ]; then
    cat > "$BOOT/loader/loader.conf" <<EOF
default $KERNEL.conf
timeout 3
editor  no
EOF
fi

echo "[calamares] systemd-boot fix completed"
exit 0
