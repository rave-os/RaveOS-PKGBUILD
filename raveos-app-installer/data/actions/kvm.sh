#!/bin/bash
# KVM/QEMU virtualizáció telepítő script
# Környezeti változók: INSTALL_USER, INSTALL_HOME

set -e

USER="$INSTALL_USER"
HOME="$INSTALL_HOME"
ACTION="${1:-install}"

remove_installed_packages() {
    local installed=()
    local pkg
    for pkg in "$@"; do
        if pacman -Qq "$pkg" >/dev/null 2>&1; then
            installed+=("$pkg")
        fi
    done
    if ((${#installed[@]})); then
        pacman -Rcns --noconfirm "${installed[@]}"
    fi
}

if [[ "$ACTION" == "remove" ]]; then
    echo "Removing KVM/QEMU for $USER..."
    systemctl disable --now libvirtd.service 2>/dev/null || true
    remove_installed_packages \
        qemu-full \
        qemu-img \
        libvirt \
        virt-install \
        virt-manager \
        virt-viewer \
        edk2-ovmf \
        dnsmasq \
        swtpm \
        guestfs-tools \
        libosinfo \
        dmidecode
    echo "KVM/QEMU removal complete!"
    exit 0
fi

echo "Installing KVM/QEMU for $USER..."

# Csomagok telepítése
pacman -S --noconfirm --needed \
    qemu-full \
    qemu-img \
    libvirt \
    virt-install \
    virt-manager \
    virt-viewer \
    edk2-ovmf \
    dnsmasq \
    swtpm \
    guestfs-tools \
    libosinfo \
    dmidecode

# User hozzáadása a szükséges csoportokhoz
usermod -aG kvm "$USER"
usermod -aG input "$USER"
usermod -aG libvirt "$USER"

# Libvirt konfiguráció - user beállítása
QEMU_CONF="/etc/libvirt/qemu.conf"
if [[ -f "$QEMU_CONF" ]]; then
    # User sor keresése és módosítása
    if grep -q "^#user = " "$QEMU_CONF"; then
        sed -i "s/^#user = .*/user = \"$USER\"/" "$QEMU_CONF"
    elif grep -q "^user = " "$QEMU_CONF"; then
        sed -i "s/^user = .*/user = \"$USER\"/" "$QEMU_CONF"
    else
        echo "user = \"$USER\"" >> "$QEMU_CONF"
    fi
    
    # Group beállítása
    if grep -q '^#group = ' "$QEMU_CONF"; then
        sed -i 's/^#group = .*/group = "kvm"/' "$QEMU_CONF"
    elif grep -q '^group = ' "$QEMU_CONF"; then
        sed -i 's/^group = .*/group = "kvm"/' "$QEMU_CONF"
    else
        echo 'group = "kvm"' >> "$QEMU_CONF"
    fi
fi

# Szolgáltatások engedélyezése és indítása
systemctl enable libvirtd.socket 2>/dev/null || true
systemctl start libvirtd.socket 2>/dev/null || true
systemctl enable libvirtd.service
systemctl start libvirtd.service

# Várjuk meg a socketet mielőtt virsh-t hívunk
timeout 30 bash -c 'until [ -S /run/libvirt/libvirt-sock ]; do sleep 1; done' 2>/dev/null || true

# Default network autostart
virsh net-autostart default 2>/dev/null || true
virsh net-start default 2>/dev/null || true

echo "KVM/QEMU installation complete!"
echo "Please log out and back in for group changes to take effect."
