#!/bin/bash
set -e

echo ">>> [snapshots-subvol] Running INSIDE target system"

# Calamares' partition module ignores our btrfsSubvolumes config here and
# always creates its own hardcoded set (/home /root /srv /var/cache
# /var/log /var/tmp as separate subvolumes) -- there's no ".snapshots"
# subvolume among them, which grub-btrfs/Snapper need. Create it by hand
# as a proper top-level (subvolid=5) sibling of the other subvolumes,
# so snapshots of "/" don't recursively include the snapshot store itself.

ROOT_DEV="$(findmnt -no SOURCE / | sed 's/\[.*\]//')"
ROOT_FS="$(findmnt -no FSTYPE /)"

if [ "$ROOT_FS" != "btrfs" ]; then
  echo ">>> [snapshots-subvol] Root is not btrfs (${ROOT_FS}), skipping."
  exit 0
fi

if [ -d /.snapshots ] && findmnt -no SOURCE /.snapshots >/dev/null 2>&1; then
  echo ">>> [snapshots-subvol] /.snapshots already mounted, skipping."
  exit 0
fi

mkdir -p /mnt/topvol
mount -o subvolid=5 "${ROOT_DEV}" /mnt/topvol

if [ ! -d /mnt/topvol/@snapshots ]; then
  btrfs subvolume create /mnt/topvol/@snapshots
  echo ">>> [snapshots-subvol] Created @snapshots subvolume"
else
  echo ">>> [snapshots-subvol] @snapshots subvolume already exists"
fi

umount /mnt/topvol
rmdir /mnt/topvol

mkdir -p /.snapshots

ROOT_UUID="$(blkid -s UUID -o value "${ROOT_DEV}")"
if ! grep -q '/.snapshots' /etc/fstab; then
  echo "UUID=${ROOT_UUID} /.snapshots btrfs rw,noatime,compress=zstd:3,discard=async,space_cache=v2,subvol=/@snapshots 0 0" >> /etc/fstab
  echo ">>> [snapshots-subvol] Added /.snapshots to fstab"
fi

mount /.snapshots

echo ">>> [snapshots-subvol] Done."
