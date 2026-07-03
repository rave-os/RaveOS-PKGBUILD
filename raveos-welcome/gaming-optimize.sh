#!/bin/bash
# RaveOS Gaming Optimization Helper — fut root-ként pkexec-en keresztül
set -uo pipefail

LOGDIR="/var/log/raveos-welcome"
LOGFILE="$LOGDIR/gaming-optimize.log"
mkdir -p "$LOGDIR" 2>/dev/null || true
exec > >(tee -a "$LOGFILE") 2>&1
echo "=== $(date '+%Y-%m-%d %H:%M:%S') optimize run: $* ==="

apply_sysctl() {
    cat > /etc/sysctl.d/99-gaming.conf << 'EOF'
vm.swappiness=10
vm.compaction_proactiveness=0
vm.watermark_boost_factor=1
vm.page_lock_unfairness=1
vm.dirty_writeback_centisecs=500
kernel.split_lock_mitigate=0
kernel.nmi_watchdog=0
net.ipv4.tcp_fastopen=3
net.core.netdev_max_backlog=4096
vm.max_map_count=2147483642
EOF
    sysctl --load=/etc/sysctl.d/99-gaming.conf >/dev/null 2>&1

    echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    cat > /etc/tmpfiles.d/thp-gaming.conf << 'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
EOF

    if [ "$(sysctl -n vm.swappiness 2>/dev/null)" != "10" ]; then
        echo "[FAIL] sysctl: vm.swappiness nem allt be, a sysctl --load hibazott"
        return 1
    fi
    echo "[OK] sysctl alkalmazva"
}

apply_io_sched() {
    cat > /etc/udev/rules.d/60-ssd-scheduler.rules << 'EOF'
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger --subsystem-match=block --action=change 2>/dev/null || true

    # azonnali alkalmazas is, ne csak legkozelebbi boot/hotplug-kor
    for sched in /sys/block/*/queue/scheduler; do
        [ -f "$sched" ] || continue
        dev="${sched%/queue/scheduler}"
        dev="${dev##*/}"
        case "$dev" in
            nvme*)
                echo none > "$sched" 2>/dev/null || true
                ;;
            sd*)
                rot_file="${sched%scheduler}rotational"
                if [ "$(cat "$rot_file" 2>/dev/null)" = "0" ]; then
                    echo mq-deadline > "$sched" 2>/dev/null || true
                else
                    echo bfq > "$sched" 2>/dev/null || true
                fi
                ;;
        esac
    done
    echo "[OK] io_sched alkalmazva"
}

apply_ananicy() {
    if ! pacman -Q ananicy-cpp &>/dev/null && ! pacman -Q ananicy-cpp-git &>/dev/null; then
        if ! pacman -S --noconfirm --needed ananicy-cpp cachyos-ananicy-rules; then
            echo "[FAIL] ananicy: pacman telepites sikertelen"
            return 1
        fi
    fi
    if ! systemctl enable --now ananicy-cpp; then
        echo "[FAIL] ananicy: systemctl enable --now sikertelen"
        return 1
    fi
    echo "[OK] ananicy alkalmazva"
}

apply_gamemode() {
    if ! pacman -S --noconfirm --needed gamemode lib32-gamemode mangohud lib32-mangohud goverlay; then
        echo "[FAIL] gamemode: pacman telepites sikertelen (multilib repo engedelyezve van?)"
        return 1
    fi
    cat > /etc/gamemode.ini << 'EOF'
[general]
renice=10
softrealtime=auto
inhibit_screensaver=1

[cpu]
park_cores=no
pin_cores=yes

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high
EOF
    echo "[OK] gamemode alkalmazva"
}

apply_gpu_profile() {
    local tmpfile="/etc/tmpfiles.d/gpu-power-profile.conf"
    > "$tmpfile"
    local applied=0
    for card in /sys/class/drm/card*/device/pp_power_profile_mode; do
        [ -f "$card" ] || continue
        local idx
        idx=$(awk '{name=$2; gsub(/[:*]/,"",name); if (name=="3D_FULL_SCREEN") print $1}' "$card" 2>/dev/null | head -1)
        if [ -n "$idx" ] && echo "$idx" > "$card" 2>/dev/null; then
            echo "w $card - - - - $idx" >> "$tmpfile"
            applied=1
        fi
    done
    if [ "$applied" -eq 0 ]; then
        echo "[FAIL] gpu_profile: nincs elerheto 3D_FULL_SCREEN profil (pp_power_profile_mode)"
        return 1
    fi
    echo "[OK] gpu_profile alkalmazva"
}

apply_amd_powercap() {
    local tmpfile="/etc/tmpfiles.d/amd-powercap.conf"
    > "$tmpfile"
    local applied=0
    for cap_max in /sys/class/hwmon/hwmon*/power1_cap_max; do
        [ -f "$cap_max" ] || continue
        local cap_file="${cap_max%_max}"
        local max_val
        max_val=$(cat "$cap_max" 2>/dev/null) || continue
        if [ -n "$max_val" ] && echo "$max_val" > "$cap_file" 2>/dev/null; then
            echo "w $cap_file - - - - $max_val" >> "$tmpfile"
            applied=1
        fi
    done
    if [ "$applied" -eq 0 ]; then
        echo "[FAIL] amd_powercap: nem talalhato irhato power1_cap"
        return 1
    fi
    echo "[OK] amd_powercap alkalmazva"
}

apply_amd_overdrive() {
    echo "options amdgpu ppfeaturemask=0xffffffff" > /etc/modprobe.d/99-amdgpu-overdrive.conf
    if ! mkinitcpio -P; then
        echo "[FAIL] amd_overdrive: mkinitcpio -P sikertelen"
        return 1
    fi
    echo "[OK] amd_overdrive alkalmazva (ujrainditas szukseges)"
}

apply_nvidia_perf() {
    local ok=1

    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi -pm 1 >/dev/null 2>&1 || echo "[WARN] nvidia_perf: persistence mode sikertelen"
        # --auto-boost-default csak regi Kepler karyakon letezik, modern GPU-n
        # normalis hogy hibazik, ezert ez nem szamit kritikus hibanak
        nvidia-smi --auto-boost-default=0 >/dev/null 2>&1 || true
    else
        echo "[FAIL] nvidia_perf: nvidia-smi nem talalhato"
        ok=0
    fi

    # a regi verzio /proc/driver/nvidia/params-ba irt tmpfiles-szel, ami
    # csak-olvashato es sosem mukodott - modul parametert modprobe.d-vel
    # kell beallitani, modul betoltes elott
    rm -f /etc/tmpfiles.d/nvidia-perf.conf
    echo "options nvidia NVreg_EnableGpuFirmware=0" > /etc/modprobe.d/99-nvidia-gaming.conf
    if ! mkinitcpio -P; then
        echo "[FAIL] nvidia_perf: mkinitcpio -P sikertelen"
        ok=0
    fi

    if [ "$ok" -ne 1 ]; then
        return 1
    fi
    echo "[OK] nvidia_perf alkalmazva (firmware tiltas ujrainditas utan lep eletbe)"
}

apply_brave() {
    # brave-origin-bin kesz binariskent elerheto a chaotic-aur repoban,
    # nincs szukseg yay/AUR buildre (ami korabban lefagyott a PKGBUILD-diff
    # promptnal, mert a --noconfirm azt nem nemitja el).
    if pacman -S --noconfirm --needed brave-origin-bin; then
        echo "[OK] brave-origin telepitve"
        return 0
    fi
    echo "[FAIL] brave-origin: pacman telepites sikertelen"
    return 1
}

restore_brave_profile() {
    # Brave Origin a binarisba egetett "BraveSoftware/Brave-Origin" mappat
    # hasznalja (nem "Brave-Browser", mint a rendes Brave) - strings-szel
    # ellenorizve az /opt/brave-origin-bin/brave binariban.
    local src="/usr/share/raveos-welcome/brave-profile/config/BraveSoftware/Brave-Browser"
    if [ ! -d "$src" ]; then
        echo "[FAIL] brave_profile: forras profil nem talalhato ($src)"
        return 1
    fi
    local real_user
    real_user="$(logname 2>/dev/null || echo "${SUDO_USER:-}")"
    if [ -z "$real_user" ]; then
        echo "[FAIL] brave_profile: nem sikerult megallapitani a felhasznalot"
        return 1
    fi
    local home_dir
    home_dir="$(getent passwd "$real_user" | cut -d: -f6)"
    local dest="$home_dir/.config/BraveSoftware/Brave-Origin"
    if ! { mkdir -p "$dest" && cp -a "$src/." "$dest/" && chown -R "$real_user":"$real_user" "$dest"; }; then
        echo "[FAIL] brave_profile: masolas sikertelen"
        return 1
    fi
    echo "[OK] brave_profile visszaallitva"
}

apply_firefox() {
    if ! pacman -S --noconfirm --needed firefox; then
        echo "[FAIL] firefox: pacman telepites sikertelen"
        return 1
    fi
    echo "[OK] firefox telepitve"
}

FAILED=()
for arg in "$@"; do
    case "$arg" in
        sysctl)        apply_sysctl         || FAILED+=("$arg") ;;
        io_sched)      apply_io_sched        || FAILED+=("$arg") ;;
        ananicy)       apply_ananicy         || FAILED+=("$arg") ;;
        gamemode)      apply_gamemode        || FAILED+=("$arg") ;;
        gpu_profile)   apply_gpu_profile     || FAILED+=("$arg") ;;
        amd_powercap)  apply_amd_powercap    || FAILED+=("$arg") ;;
        amd_overdrive) apply_amd_overdrive   || FAILED+=("$arg") ;;
        nvidia_perf)   apply_nvidia_perf     || FAILED+=("$arg") ;;
        brave)         apply_brave           || FAILED+=("$arg") ;;
        brave_profile) restore_brave_profile || FAILED+=("$arg") ;;
        firefox)       apply_firefox         || FAILED+=("$arg") ;;
        *) echo "[WARN] ismeretlen opcio: $arg" ;;
    esac
done

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo "HIBA: a kovetkezok nem alkalmazodtak sikeresen: ${FAILED[*]}" >&2
    echo "Naplo: $LOGFILE" >&2
    exit 1
fi

echo "Minden kivalasztott optimalizacio sikeresen alkalmazva."
exit 0
