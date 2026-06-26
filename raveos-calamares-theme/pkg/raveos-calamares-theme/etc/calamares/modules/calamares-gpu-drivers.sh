#!/bin/bash
set -e

echo ">>> [gpu] Running INSIDE target system"

GPU_INFO="$(lspci -nn | grep -E 'VGA|3D|Display' || true)"
echo ">>> [gpu] Detected devices:"
echo "$GPU_INFO"

install_pkgs() {
  pacman -Syy --noconfirm || true
  pacman -S --noconfirm "$@" || true
}

install_pkgs mesa libglvnd vulkan-icd-loader

if echo "$GPU_INFO" | grep -qi "Intel"; then
  echo ">>> [gpu] Installing Intel stack..."
  install_pkgs mesa vulkan-intel intel-media-driver 
fi

# AMD
if echo "$GPU_INFO" | grep -qi "AMD\|ATI"; then
  echo ">>> [gpu] Installing AMD stack..."
  install_pkgs mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools mesa-utils
fi

if echo "$GPU_INFO" | grep -qi "NVIDIA"; then
  echo ">>> [gpu] Installing NVIDIA DKMS stack..."

  install_pkgs dkms linux-cachyos-headers nvidia-dkms nvidia-utils nvidia-settings lib32-nvidia-utils

  if echo "$GPU_INFO" | grep -qi "Intel\|AMD\|ATI"; then
    echo ">>> [gpu] Hybrid laptop detected -> installing nvidia-prime"
    install_pkgs nvidia-prime
  fi

  echo ">>> [gpu] Enabling NVIDIA module autoload..."
  mkdir -p /etc/modules-load.d
  cat > /etc/modules-load.d/nvidia.conf <<EOF
nvidia
nvidia_modeset
nvidia_uvm
nvidia_drm
EOF

  echo ">>> [gpu] Enabling NVIDIA DRM modeset..."
  mkdir -p /etc/modprobe.d
  echo "options nvidia_drm modeset=1" > /etc/modprobe.d/nvidia-drm.conf

  echo ">>> [gpu] Rebuilding initramfs..."
  mkinitcpio -P || true
fi

echo ">>> [gpu] Done."
