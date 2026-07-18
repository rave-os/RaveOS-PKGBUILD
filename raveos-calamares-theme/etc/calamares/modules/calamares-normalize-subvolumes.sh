#!/bin/bash
set -e

echo ">>> [subvol-normalize] Running INSIDE target system"

ROOT_DEV="$(findmnt -no SOURCE / | sed 's/\[.*\]//')"
ROOT_FS="$(findmnt -no FSTYPE /)"

if [ "$ROOT_FS" != "btrfs" ]; then
  echo ">>> [subvol-normalize] Root is not btrfs (${ROOT_FS}), skipping."
  exit 0
fi

# Calamares' partition module ignores our btrfsSubvolumes config entirely
# and always creates its own hardcoded set: @, @home, @root, @srv, @cache,
# @log, @tmp. We only want @, @home, @log, @pkg (just /var/cache/pacman/pkg,
# not all of /var/cache) and @snapshots (created separately). Drop the rest
# here, after everything else has already run, merging any content back
# into the parent (@) subvolume first.

mkdir -p /mnt/topvol
mount -o subvolid=5 "${ROOT_DEV}" /mnt/topvol

unmount_retry() {
  local path="$1"
  local i
  for i in 1 2 3 4 5; do
    if umount "$path" 2>/dev/null; then
      return 0
    fi
    fuser -km "$path" >/dev/null 2>&1 || true
    sleep 1
  done
  umount -l "$path" 2>/dev/null || true
}

for entry in "root:@root" "srv:@srv" "var/tmp:@tmp"; do
  path="/${entry%%:*}"
  subvol="${entry##*:}"
  if findmnt -no SOURCE "$path" >/dev/null 2>&1; then
    echo ">>> [subvol-normalize] Removing separate subvolume ${subvol} (${path})"
    unmount_retry "$path"
    # $path is now a plain empty dir in @ again -- copy the old
    # subvolume's content back into it before deleting the subvolume.
    if [ -d "/mnt/topvol/${subvol}" ] && ! findmnt -no SOURCE "$path" >/dev/null 2>&1; then
      cp -a "/mnt/topvol/${subvol}/." "$path/" 2>/dev/null || true
      btrfs subvolume delete "/mnt/topvol/${subvol}" || true
    fi
  fi
  sed -i "\#[[:space:]]${path}[[:space:]]#d" /etc/fstab
done

# Narrow /var/cache: drop the whole-@cache subvolume (keep it as a plain
# directory), and create a dedicated @pkg subvolume just for pacman's
# package cache -- that's the only part of /var/cache archinstall separates.
if findmnt -no SOURCE /var/cache >/dev/null 2>&1; then
  echo ">>> [subvol-normalize] Narrowing /var/cache -> only pacman/pkg as @pkg"
  unmount_retry /var/cache
  if [ -d /mnt/topvol/@cache ] && ! findmnt -no SOURCE /var/cache >/dev/null 2>&1; then
    cp -a /mnt/topvol/@cache/. /var/cache/ 2>/dev/null || true
    btrfs subvolume delete /mnt/topvol/@cache || true
  fi
fi
sed -i "\#[[:space:]]/var/cache[[:space:]]#d" /etc/fstab

if [ ! -d /mnt/topvol/@pkg ]; then
  btrfs subvolume create /mnt/topvol/@pkg
  echo ">>> [subvol-normalize] Created @pkg subvolume"
fi

unmount_retry /mnt/topvol
rmdir /mnt/topvol 2>/dev/null || true

mkdir -p /var/cache/pacman
rm -rf /var/cache/pacman/pkg
mkdir -p /var/cache/pacman/pkg

ROOT_UUID="$(blkid -s UUID -o value "${ROOT_DEV}")"
MOUNT_OPTS="rw,noatime,compress=zstd:3,discard=async,space_cache=v2"
if ! grep -q '/var/cache/pacman/pkg' /etc/fstab; then
  echo "UUID=${ROOT_UUID} /var/cache/pacman/pkg btrfs ${MOUNT_OPTS},subvol=/@pkg 0 0" >> /etc/fstab
  echo ">>> [subvol-normalize] Added /var/cache/pacman/pkg to fstab"
fi

mount /var/cache/pacman/pkg

echo ">>> [subvol-normalize] Done. Final subvolume list:"
btrfs subvolume list /
