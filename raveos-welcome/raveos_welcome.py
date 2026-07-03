#!/usr/bin/env python3
"""
RaveOS Welcome App — First-run onboarding wizard
Requires: PyQt6, nmcli (NetworkManager)
"""

import os
import re
import sys
import subprocess
import shutil
from pathlib import Path

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QStackedWidget, QLineEdit, QListWidget,
    QListWidgetItem, QFrame, QGraphicsOpacityEffect, QProgressBar,
    QSizePolicy, QDialog, QCheckBox, QScrollArea, QFileDialog
)
from PyQt6.QtCore import (
    Qt, QThread, pyqtSignal, QTimer, QPropertyAnimation,
    QEasingCurve, QPoint, QSize, pyqtProperty, QObject, QProcess
)
from PyQt6.QtGui import (
    QFont, QFontDatabase, QColor, QPalette, QLinearGradient,
    QGradient, QPainter, QBrush, QPen, QPixmap, QIcon,
    QFontMetrics, QPainterPath
)
from PyQt6.QtWidgets import QProxyStyle, QStyle
from PyQt6.QtSvgWidgets import QSvgWidget

# ─── Constants ────────────────────────────────────────────────────────────────

FLAG_FILE = Path.home() / ".config" / "raveos" / ".welcome_done"
APP_INSTALLER = "/usr/bin/raveos-app-installer"
SVG_LOGO = "/usr/share/raveos-welcome/raveos-welcome.svg"
_SCRIPT_DIR = Path(__file__).resolve().parent

COLORS = {
    "bg":           "#2B2B2B",
    "bg2":          "#1e1e1e",
    "surface":      "#363636",
    "surface2":     "#404040",
    "border":       "#555555",
    "accent":       "#3d7839",
    "accent_hover": "#285226",
    "accent_light": "#5aa856",
    "text":         "#ecf0f1",
    "text_dim":     "#95a5a6",
    "success":      "#3d7839",
    "warning":      "#f39c12",
    "error":        "#e74c3c",
}

# ─── Translations ─────────────────────────────────────────────────────────────

_current_lang = "hu"

T = {
    # Nav
    "nav_back":     {"hu": "← Vissza",            "en": "← Back"},
    "nav_next":     {"hu": "Tovább →",            "en": "Next →"},
    # Step bar
    "step_welcome":  {"hu": "ÜDVÖZLÉS",           "en": "WELCOME"},
    "step_network":  {"hu": "HÁLÓZAT",            "en": "NETWORK"},
    "step_optimize": {"hu": "OPTIMALIZÁCIÓ",      "en": "OPTIMIZE"},
    "step_hyprland": {"hu": "HYPRLAND",           "en": "HYPRLAND"},
    "step_credits":  {"hu": "KÖZREMŰKÖDŐK",       "en": "CREDITS"},
    "step_finish":   {"hu": "BEFEJEZÉS",          "en": "FINISH"},
    # Welcome page
    "welcome_tag":      {"hu": "LINUX DISTRIBUTION", "en": "LINUX DISTRIBUTION"},
    "welcome_about":    {"hu": "RaveOS finomhangolás, kulcsra kész állapot!",
                         "en": "RaveOS tuned, ready to go!"},
    "btn_support":      {"hu": "€  Támogatás", "en": "€  Support"},
    "feat_perf":        {"hu": "CachyOS kernel\noptimalizált teljesítmény",
                         "en": "CachyOS kernel\noptimized performance"},
    "feat_gaming":      {"hu": "Gaming-ready\nProton, MangoHud, GameMode",
                         "en": "Gaming-ready\nProton, MangoHud, GameMode"},
    "feat_apps":        {"hu": "App Installer\negy kattintás, minden szoftver",
                         "en": "App Installer\none click, all software"},
    # WiFi page
    "wifi_title":       {"hu": "HÁLÓZAT",            "en": "NETWORK"},
    "wifi_subtitle":    {"hu": "WiFi kapcsolat",     "en": "WiFi connection"},
    "wifi_scan":        {"hu": "Frissítés",          "en": "Refresh"},
    "wifi_password":    {"hu": "Jelszó:",            "en": "Password:"},
    "wifi_connect":     {"hu": "CSATLAKOZÁS",        "en": "CONNECT"},
    "wifi_scanning":    {"hu": "Hálózatok keresése...","en": "Scanning networks..."},
    "wifi_none":        {"hu": "Nem találtam hálózatot.","en": "No networks found."},
    "wifi_found":       {"hu": "{n} hálózat található","en": "{n} networks found"},
    "wifi_open":        {"hu": "  [nyílt]",           "en": "  [open]"},
    "wifi_encrypted":   {"hu": "  [titkosított]",     "en": "  [encrypted]"},
    "wifi_selected":    {"hu": "Kiválasztva: {ssid}", "en": "Selected: {ssid}"},
    "wifi_connecting":  {"hu": "Csatlakozás folyamatban...","en": "Connecting..."},
    "wifi_connected":   {"hu": "Csatlakozva: {ssid}", "en": "Connected: {ssid}"},
    "wifi_error":       {"hu": "Hiba: {err}",         "en": "Error: {err}"},
    "wifi_timeout":     {"hu": "Időtúllépés — próbáld újra","en": "Timeout — try again"},
    "wifi_unknown_err": {"hu": "Ismeretlen hiba",      "en": "Unknown error"},
    # Optimize page
    "opt_title":        {"hu": "ALKALMAZÁSOK & OPTIMALIZÁCIÓ", "en": "APPS & OPTIMIZATION"},
    "opt_browser":      {"hu": "BÖNGÉSZŐ",           "en": "BROWSER"},
    "opt_brave":        {"hu": "Brave Origin",       "en": "Brave Origin"},
    "opt_brave_desc":   {"hu": "Brave Origin — a Brave letisztított, reklám/rewards/kripto-mentes verziója",
                         "en": "Brave Origin — Brave's stripped-down version, without ads/rewards/crypto"},
    "opt_firefox":      {"hu": "Firefox",            "en": "Firefox"},
    "opt_firefox_desc": {"hu": "Mozilla Firefox — nyílt forrású, privacy-fókuszú",
                         "en": "Mozilla Firefox — open source, privacy-focused"},
    "opt_brave_profile":      {"hu": "Brave profil visszaállítása", "en": "Restore Brave profile"},
    "opt_brave_profile_desc": {"hu": "Előre konfigurált RaveOS Brave profil másolása (könyvjelzők, beállítások)",
                               "en": "Copy pre-configured RaveOS Brave profile (bookmarks, settings)"},
    "opt_gaming":       {"hu": "GAMING OPTIMALIZÁCIÓ  —  GPU: {gpu}", "en": "GAMING OPTIMIZATION  —  GPU: {gpu}"},
    "opt_sysctl":       {"hu": "Kernel/sysctl tweaks",
                         "en": "Kernel/sysctl tweaks"},
    "opt_sysctl_desc":  {"hu": "Kernel paraméterek optimalizálása gaming-hoz:\n"
                               "• vm.swappiness=10 — RAM preferálása swap helyett\n"
                               "• THP=madvise — Transparent Huge Pages, kevesebb micro-stutter\n"
                               "• NMI watchdog kikapcsolva — kevesebb CPU interrupt overhead\n"
                               "• split_lock_mitigate=0 — egyes játékok gyorsabban futnak\n"
                               "• TCP FastOpen — gyorsabb hálózati kapcsolatok online játékhoz\n"
                               "Permanensen mentve: /etc/sysctl.d/99-gaming.conf",
                         "en": "Kernel parameter optimization for gaming:\n"
                               "• vm.swappiness=10 — prefer RAM over swap\n"
                               "• THP=madvise — Transparent Huge Pages, less micro-stutter\n"
                               "• NMI watchdog off — less CPU interrupt overhead\n"
                               "• split_lock_mitigate=0 — some games run faster\n"
                               "• TCP FastOpen — faster network for online gaming\n"
                               "Saved permanently: /etc/sysctl.d/99-gaming.conf"},
    "opt_io_sched":     {"hu": "I/O Scheduler",
                         "en": "I/O Scheduler"},
    "opt_io_sched_desc":{"hu": "Lemez olvasás/írás ütemező optimalizálása:\n"
                               "• SSD → mq-deadline: alacsonyabb latency mint BFQ\n"
                               "• NVMe → none: NVMe saját belső ütemezőt használ, külső felesleges\n"
                               "• HDD → bfq: legjobb forgódobos meghajtóhoz\n"
                               "Permanensen mentve: /etc/udev/rules.d/60-ssd-scheduler.rules",
                         "en": "Disk I/O scheduler optimization:\n"
                               "• SSD → mq-deadline: lower latency than BFQ\n"
                               "• NVMe → none: NVMe uses its own internal scheduler\n"
                               "• HDD → bfq: best for rotational drives\n"
                               "Saved permanently: /etc/udev/rules.d/60-ssd-scheduler.rules"},
    "opt_ananicy":      {"hu": "ananicy-cpp",
                         "en": "ananicy-cpp"},
    "opt_ananicy_desc": {"hu": "Automatikus process prioritás kezelő:\n"
                               "• Játékok indításkor magasabb CPU prioritást kapnak\n"
                               "• Háttérfolyamatok (frissítők, indexelők) alacsonyabb prioritást kapnak\n"
                               "• Eredmény: stabilabb FPS, kevesebb frame drop\n"
                               "Telepíti: ananicy-cpp + cachyos-ananicy-rules, majd engedélyezi",
                         "en": "Automatic process priority handler:\n"
                               "• Games get higher CPU priority on launch\n"
                               "• Background processes (updaters, indexers) get lower priority\n"
                               "• Result: more stable FPS, fewer frame drops\n"
                               "Installs: ananicy-cpp + cachyos-ananicy-rules, then enables"},
    "opt_gamemode":     {"hu": "GameMode + MangoHud",
                         "en": "GameMode + MangoHud"},
    "opt_gamemode_desc":{"hu": "GameMode: automatikus teljesítmény-boost játék közben:\n"
                               "• CPU governor powersave → performance játék indításkor\n"
                               "• Játék bezárásakor visszavált powersave-re\n"
                               "• I/O és process prioritás is optimalizálódik\n\n"
                               "MangoHud: in-game overlay:\n"
                               "• FPS, frametime, GPU/CPU hőmérséklet, VRAM kijelzés\n"
                               "• GOverlay: grafikus felület a MangoHud beállításához\n"
                               "• Steam launch options: MANGOHUD=1 gamemoderun %command%",
                         "en": "GameMode: automatic performance boost while gaming:\n"
                               "• CPU governor powersave → performance on game launch\n"
                               "• Reverts to powersave when game closes\n"
                               "• I/O and process priority also optimized\n\n"
                               "MangoHud: in-game overlay:\n"
                               "• FPS, frametime, GPU/CPU temp, VRAM display\n"
                               "• GOverlay: GUI to configure MangoHud\n"
                               "• Steam launch options: MANGOHUD=1 gamemoderun %command%"},
    "opt_gpu_profile":      {"hu": "GPU Power Profile — 3D Full Screen",
                             "en": "GPU Power Profile — 3D Full Screen"},
    "opt_gpu_profile_desc": {"hu": "AMDGPU teljesítmény profil átváltása 3D_FULL_SCREEN-re:\n"
                                   "• Agresszívebb GPU órajel játék közben\n"
                                   "• Alapértelmezett profil visszafogottabb teljesítményre törekszik\n"
                                   "• Eredmény: magasabb és stabilabb FPS\n"
                                   "Permanensen mentve: /etc/tmpfiles.d/gpu-power-profile.conf",
                             "en": "AMDGPU power profile switch to 3D_FULL_SCREEN:\n"
                                   "• More aggressive GPU clocks while gaming\n"
                                   "• Default profile is more conservative\n"
                                   "• Result: higher and more stable FPS\n"
                                   "Saved permanently: /etc/tmpfiles.d/gpu-power-profile.conf"},
    "opt_amd_overdrive":      {"hu": "AMD Overdrive (ppfeaturemask)",
                               "en": "AMD Overdrive (ppfeaturemask)"},
    "opt_amd_overdrive_desc": {"hu": "AMD GPU Overdrive funkciók feloldása:\n"
                                     "• Lehetővé teszi a manuális órajel és feszültség állítást (LACT-ban)\n"
                                     "• Alapértelmezetten az AMD zárolja ezeket a funkciókat\n"
                                     "• Beállítás: /etc/modprobe.d/99-amdgpu-overdrive.conf\n"
                                     "FIGYELEM: initramfs újraépítést igényel, újraindítás szükséges utána!",
                               "en": "Unlock AMD GPU Overdrive features:\n"
                                     "• Enables manual clock and voltage tuning (in LACT)\n"
                                     "• AMD locks these features by default\n"
                                     "• Config: /etc/modprobe.d/99-amdgpu-overdrive.conf\n"
                                     "WARNING: requires initramfs rebuild, reboot needed after!"},
    "opt_amd_powercap":      {"hu": "AMD GPU Power Cap — Maximum",
                              "en": "AMD GPU Power Cap — Maximum"},
    "opt_amd_powercap_desc": {"hu": "AMD GPU teljesítmény korlát feloldása maximumra:\n"
                                    "• A GPU alapból korlátozott TDP-re van beállítva\n"
                                    "• Ez beállítja a power1_cap értékét a maximálisan engedélyezett értékre\n"
                                    "• Eredmény: GPU teljes teljesítményen futhat, magasabb FPS csúcsok\n"
                                    "• Permanensen mentve: /etc/tmpfiles.d/amd-powercap.conf",
                              "en": "Unlock AMD GPU power cap to maximum:\n"
                                    "• GPU is limited to restricted TDP by default\n"
                                    "• Sets power1_cap to the maximum allowed value\n"
                                    "• Result: GPU can run at full power, higher FPS peaks\n"
                                    "• Saved permanently: /etc/tmpfiles.d/amd-powercap.conf"},
    "opt_nvidia_perf":      {"hu": "Nvidia Maximum Performance",
                             "en": "Nvidia Maximum Performance"},
    "opt_nvidia_perf_desc": {"hu": "Nvidia GPU teljesítmény maximalizálása:\n"
                                   "• nvidia-smi persistence mode bekapcsolva (gyorsabb driver válasz)\n"
                                   "• Auto-boost letiltva régi kártyákon (stabilabb órajel)\n"
                                   "• GPU firmware offload letiltva (NVreg_EnableGpuFirmware=0)\n"
                                   "Permanensen mentve: /etc/modprobe.d/99-nvidia-gaming.conf\n"
                                   "FIGYELEM: initramfs újraépítést igényel, újraindítás szükséges utána!",
                             "en": "Maximize Nvidia GPU performance:\n"
                                   "• nvidia-smi persistence mode on (faster driver response)\n"
                                   "• Auto-boost disabled on older cards (more stable clocks)\n"
                                   "• GPU firmware offload disabled (NVreg_EnableGpuFirmware=0)\n"
                                   "Saved permanently: /etc/modprobe.d/99-nvidia-gaming.conf\n"
                                   "WARNING: requires initramfs rebuild, reboot needed after!"},
    "opt_apply":        {"hu": "TELEPÍTÉS / ALKALMAZÁS", "en": "INSTALL / APPLY"},
    "opt_apply_empty":  {"hu": "Nincs kijelölve semmi.", "en": "Nothing selected."},
    "opt_apply_missing":{"hu": "Hiányzó script: ", "en": "Missing script: "},
    "opt_apply_ok":     {"hu": "Sikeresen alkalmazva!", "en": "Successfully applied!"},
    "opt_apply_err":    {"hu": "Hiba (kód: {code}) — napló: {log}",
                         "en": "Error (code: {code}) — log: {log}"},
    # Hyprland page
    "hypr_title":       {"hu": "HYPRLAND — KEYBINDS", "en": "HYPRLAND — KEYBINDS"},
    "hypr_source":      {"hu": "Forrás: ", "en": "Source: "},
    "hypr_none":        {"hu": "Nem található Hyprland konfiguráció.", "en": "No Hyprland configuration found."},
    # Hyprland descriptions
    "hypr_spotlight":   {"hu": "Spotlight (DMS) megnyitása", "en": "Open Spotlight (DMS)"},
    "hypr_terminal":    {"hu": "Terminál megnyitása (Kitty)", "en": "Open terminal (Kitty)"},
    "hypr_filemanager": {"hu": "Fájlkezelő megnyitása (Thunar)", "en": "Open file manager (Thunar)"},
    "hypr_launcher":    {"hu": "App launcher megnyitása", "en": "Open app launcher"},
    "hypr_logout":      {"hu": "Kijelentkezés / leállítás", "en": "Logout / shutdown"},
    "hypr_exit":        {"hu": "Hyprland kilépés", "en": "Exit Hyprland"},
    "hypr_volume":      {"hu": "Hangerő állítás", "en": "Adjust volume"},
    "hypr_mute":        {"hu": "Némítás ki/be", "en": "Toggle mute"},
    "hypr_brightness":  {"hu": "Fényerő állítás", "en": "Adjust brightness"},
    "hypr_next_track":  {"hu": "Következő szám", "en": "Next track"},
    "hypr_prev_track":  {"hu": "Előző szám", "en": "Previous track"},
    "hypr_play_pause":  {"hu": "Lejátszás / szünet", "en": "Play / pause"},
    "hypr_clipboard":   {"hu": "Vágólap megjelenítése", "en": "Show clipboard"},
    "hypr_screenshot":  {"hu": "Képernyőkép készítése", "en": "Take screenshot"},
    "hypr_lock":        {"hu": "Képernyőzár", "en": "Lock screen"},
    "hypr_kill":        {"hu": "Aktív ablak bezárása", "en": "Close active window"},
    "hypr_float":       {"hu": "Lebegő mód ki/be", "en": "Toggle floating mode"},
    "hypr_pseudo":      {"hu": "Pseudo-tiling ki/be", "en": "Toggle pseudo-tiling"},
    "hypr_fullscreen":  {"hu": "Teljes képernyős mód", "en": "Fullscreen mode"},
    "hypr_exit2":       {"hu": "Kilépés", "en": "Exit"},
    "hypr_scratchpad":  {"hu": "Scratchpad megjelenítése", "en": "Toggle scratchpad"},
    "hypr_focus_l":     {"hu": "Fókusz mozgatása balra", "en": "Focus left"},
    "hypr_focus_r":     {"hu": "Fókusz mozgatása jobbra", "en": "Focus right"},
    "hypr_focus_u":     {"hu": "Fókusz mozgatása fel", "en": "Focus up"},
    "hypr_focus_d":     {"hu": "Fókusz mozgatása le", "en": "Focus down"},
    "hypr_ws_goto":     {"hu": "Váltás {p}. munkaterületre", "en": "Switch to workspace {p}"},
    "hypr_ws_move":     {"hu": "Ablak áthelyezése {p}. munkaterületre", "en": "Move window to workspace {p}"},
    "hypr_ws_generic":  {"hu": "Munkaterület: {p}", "en": "Workspace: {p}"},
    "hypr_ws_scratch":  {"hu": "Ablak → scratchpad", "en": "Window → scratchpad"},
    "hypr_ws_scratch_t":{"hu": "Scratchpad ki/be", "en": "Toggle scratchpad"},
    "hypr_ws_next":     {"hu": "Következő munkaterület", "en": "Next workspace"},
    "hypr_ws_prev":     {"hu": "Előző munkaterület", "en": "Previous workspace"},
    "hypr_ws_goto_n":   {"hu": "Váltás {n}. munkaterületre", "en": "Switch to workspace {n}"},
    "hypr_ws_move_n":   {"hu": "Ablak áthelyezése {n}. munkaterületre", "en": "Move window to workspace {n}"},
    "hypr_layout":      {"hu": "Layout: {p}", "en": "Layout: {p}"},
    "hypr_run":         {"hu": "Futtatás: {prog}", "en": "Run: {prog}"},
    "hypr_run_generic": {"hu": "Program futtatása", "en": "Run program"},
    # Credits page
    "credits_title":    {"hu": "KÖZREMŰKÖDŐK", "en": "CONTRIBUTORS"},
    "credits_rp1_name": {"hu": "RavePriest1", "en": "RavePriest1"},
    "credits_rp1_role": {"hu": "Névadó, hivatalos naplopó", "en": "Namesake, official slacker"},
    "credits_rp1_desc": {"hu": "Nem tudja mit akar — magyar streamer.", "en": "Doesn't know what he wants — Hungarian streamer."},
    "credits_alexc_name": {"hu": "AlexC", "en": "AlexC"},
    "credits_alexc_role": {"hu": "Arch alapkő", "en": "Arch cornerstone"},
    "credits_alexc_desc": {"hu": "Hallóóó mester.", "en": "Hellooo master."},
    "credits_nippy_name": {"hu": "Nippy", "en": "Nippy"},
    "credits_nippy_role": {"hu": "Fejlesztő", "en": "Developer"},
    "credits_nippy_desc": {"hu": "Agyérgörcsöt kap PR1-től, mert nem tudja mit akar.", "en": "Gets an aneurysm from PR1 because he doesn't know what he wants."},
    "credits_gabesz_name": {"hu": "GabeszM", "en": "GabeszM"},
    "credits_gabesz_role": {"hu": "Fejlesztő", "en": "Developer"},
    "credits_gabesz_desc": {"hu": "Weboldal, GNOME kiegészítő és alt-tab dizájn — mert valakinek kellett.", "en": "Website, GNOME extension and alt-tab design — because someone had to."},
    "credits_stefi_name": {"hu": "Stefi", "en": "Stefi"},
    "credits_stefi_role": {"hu": "Design", "en": "Design"},
    "credits_stefi_desc": {"hu": "5000 lesz!", "en": "That'll be 5000!"},
    # Finish page
    "finish_ok":        {"hu": "OK", "en": "OK"},
    "finish_title":     {"hu": "KÉSZ!", "en": "DONE!"},
    "finish_sub":       {"hu": "A RaveOS be van állítva.", "en": "RaveOS is set up."},
    "finish_next_step": {"hu": "KÖVETKEZŐ LÉPÉS", "en": "NEXT STEP"},
    "finish_inst_desc": {"hu": "Az App Installer segítségével telepíthetsz minden fontos "
                               "szoftvert egy helyen — böngészőtől kezdve a fejlesztőeszközökig.",
                         "en": "With the App Installer you can install all important "
                               "software in one place — from browsers to developer tools."},
    "finish_install":   {"hu": "APP INSTALLER INDÍTÁSA", "en": "LAUNCH APP INSTALLER"},
    "finish_close":     {"hu": "Bezárás", "en": "Close"},
    "finish_install_missing": {"hu": "Nem található az App Installer.", "en": "App Installer not found."},
    "finish_install_err":     {"hu": "Nem sikerült elindítani. Napló: {log}", "en": "Failed to launch. Log: {log}"},
    # Tooltip keys (for optimize page descriptions that use _ACTION_DESCS)
    "action_killactive":    {"hu": "Aktív ablak bezárása", "en": "Close active window"},
    "action_togglefloat":   {"hu": "Lebegő mód ki/be", "en": "Toggle floating mode"},
    "action_pseudo":        {"hu": "Pseudo-tiling ki/be", "en": "Toggle pseudo-tiling"},
    "action_fullscreen":    {"hu": "Teljes képernyős mód", "en": "Fullscreen mode"},
    "action_exit":          {"hu": "Kilépés", "en": "Exit"},
    "action_scratchpad":    {"hu": "Scratchpad megjelenítése", "en": "Toggle scratchpad"},
    "action_focus_l":       {"hu": "Fókusz mozgatása balra", "en": "Focus left"},
    "action_focus_r":       {"hu": "Fókusz mozgatása jobbra", "en": "Focus right"},
    "action_focus_u":       {"hu": "Fókusz mozgatása fel", "en": "Focus up"},
    "action_focus_d":       {"hu": "Fókusz mozgatása le", "en": "Focus down"},
}


def _t(key, **kwargs):
    """Get translation for key, with optional format kwargs."""
    lang = _current_lang
    text = T.get(key, {}).get(lang, T.get(key, {}).get("hu", key))
    if kwargs:
        try:
            return text.format(**kwargs)
        except (KeyError, IndexError):
            return text
    return text


STYLESHEET = f"""
QMainWindow, QWidget#central {{
    background: {COLORS['bg']};
}}

QWidget {{
    color: {COLORS['text']};
    font-family: 'Ubuntu', sans-serif;
}}

QLabel#title {{
    font-size: 38px;
    font-weight: 700;
    color: {COLORS['text']};
}}

QLabel#subtitle {{
    font-size: 14px;
    color: {COLORS['text_dim']};
    letter-spacing: 1px;
}}

QLabel#section_title {{
    font-size: 12px;
    font-weight: 600;
    letter-spacing: 2px;
    color: {COLORS['accent_light']};
    text-transform: uppercase;
}}

QLabel#body {{
    font-size: 14px;
    color: {COLORS['text_dim']};
    line-height: 1.6;
}}

QPushButton#primary {{
    background: {COLORS['accent']};
    color: white;
    border: none;
    border-radius: 6px;
    padding: 12px 32px;
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 1px;
    min-width: 140px;
}}
QPushButton#primary:hover {{
    background: {COLORS['accent_hover']};
}}
QPushButton#primary:pressed {{
    background: {COLORS['accent_hover']};
    padding: 13px 31px 11px 33px;
}}
QPushButton#primary:disabled {{
    background: {COLORS['surface2']};
    color: {COLORS['text_dim']};
}}

QPushButton#secondary {{
    background: transparent;
    color: {COLORS['text_dim']};
    border: 1px solid {COLORS['border']};
    border-radius: 6px;
    padding: 12px 32px;
    font-size: 13px;
    font-weight: 500;
    min-width: 100px;
}}
QPushButton#secondary:hover {{
    border-color: {COLORS['accent']};
    color: {COLORS['accent_light']};
}}

QPushButton#icon_btn {{
    background: {COLORS['surface']};
    border: 1px solid {COLORS['border']};
    border-radius: 6px;
    padding: 8px 14px;
    font-size: 13px;
    color: {COLORS['text_dim']};
}}
QPushButton#icon_btn:hover {{
    border-color: {COLORS['accent']};
    color: {COLORS['accent_light']};
    background: {COLORS['surface2']};
}}

QListWidget {{
    background: {COLORS['surface']};
    border: 1px solid {COLORS['border']};
    border-radius: 8px;
    padding: 4px;
    outline: none;
}}
QListWidget::item {{
    padding: 10px 14px;
    border-radius: 4px;
    font-size: 14px;
    color: {COLORS['text']};
    border: none;
}}
QListWidget::item:hover {{
    background: {COLORS['surface2']};
}}
QListWidget::item:selected {{
    background: rgba(61, 120, 57, 0.20);
    color: {COLORS['accent_light']};
    border: 1px solid rgba(61, 120, 57, 0.40);
}}

QLineEdit {{
    background: {COLORS['surface']};
    border: 1px solid {COLORS['border']};
    border-radius: 6px;
    padding: 10px 14px;
    font-size: 14px;
    color: {COLORS['text']};
}}
QLineEdit:focus {{
    border-color: {COLORS['accent']};
}}
QLineEdit::placeholder {{
    color: {COLORS['text_dim']};
}}

QProgressBar {{
    background: {COLORS['surface']};
    border: none;
    border-radius: 2px;
    height: 4px;
    text-align: center;
    font-size: 0px;
}}
QProgressBar::chunk {{
    background: {COLORS['accent']};
    border-radius: 2px;
}}

QFrame#separator {{
    background: {COLORS['accent']};
    max-height: 1px;
    min-height: 1px;
    opacity: 0.4;
}}

QFrame#card {{
    background: {COLORS['surface']};
    border: 1px solid {COLORS['border']};
    border-radius: 8px;
}}

QToolTip {{
    background: {COLORS['bg2']};
    color: {COLORS['text']};
    border: 1px solid {COLORS['border']};
    border-radius: 4px;
    padding: 6px 10px;
    font-size: 12px;
}}
"""

# ─── WiFi Worker ───────────────────────────────────────────────────────────────

class WiFiScanner(QThread):
    result = pyqtSignal(list)
    error  = pyqtSignal(str)

    def run(self):
        try:
            out = subprocess.check_output(
                ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"],
                stderr=subprocess.DEVNULL, timeout=10
            ).decode().strip()
            networks = []
            seen = set()
            for line in out.splitlines():
                parts = line.split(":")
                if len(parts) >= 2:
                    ssid = parts[0].strip()
                    if not ssid or ssid in seen:
                        continue
                    seen.add(ssid)
                    try:
                        signal = int(parts[1])
                    except ValueError:
                        signal = 0
                    security = parts[2].strip() if len(parts) > 2 else ""
                    networks.append({"ssid": ssid, "signal": signal, "security": security})
            networks.sort(key=lambda x: x["signal"], reverse=True)
            self.result.emit(networks)
        except Exception as e:
            self.error.emit(str(e))


class WiFiConnector(QThread):
    success = pyqtSignal()
    failure = pyqtSignal(str)

    def __init__(self, ssid, password=""):
        super().__init__()
        self.ssid = ssid
        self.password = password

    def run(self):
        try:
            if self.password:
                cmd = ["nmcli", "dev", "wifi", "connect", self.ssid,
                       "password", self.password]
            else:
                cmd = ["nmcli", "dev", "wifi", "connect", self.ssid]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            if result.returncode == 0:
                self.success.emit()
            else:
                self.failure.emit(result.stderr.strip() or _t("wifi_unknown_err"))
        except subprocess.TimeoutExpired:
            self.failure.emit(_t("wifi_timeout"))
        except Exception as e:
            self.failure.emit(str(e))


# ─── Logo Widget ───────────────────────────────────────────────────────────────

def _find_svg() -> str:
    if Path(SVG_LOGO).exists():
        return SVG_LOGO
    candidate = _SCRIPT_DIR / "raveos-welcome.svg"
    if candidate.exists():
        return str(candidate)
    return ""


class RaveLogo(QWidget):
    """RaveOS SVG logo, nagy meretben."""

    SIZE = 180

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedSize(self.SIZE, self.SIZE)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        svg_path = _find_svg()
        if svg_path:
            self._svg = QSvgWidget(svg_path, self)
            self._svg.setFixedSize(self.SIZE, self.SIZE)
            layout.addWidget(self._svg)
        else:
            fallback = QLabel("RAVE OS", self)
            fallback.setAlignment(Qt.AlignmentFlag.AlignCenter)
            fallback.setStyleSheet(
                f"font-size: 32px; font-weight: 700; color: {COLORS['text']};"
                f"font-family: Ubuntu;"
            )
            layout.addWidget(fallback)


# ─── WiFi page visibility check ───────────────────────────────────────────────

def _should_show_wifi() -> bool:
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "TYPE,STATE", "dev"],
            stderr=subprocess.DEVNULL, timeout=1
        ).decode()
    except Exception:
        return False

    has_wifi = False
    for line in out.splitlines():
        parts = line.split(":")
        if len(parts) < 2:
            continue
        dev_type, state = parts[0], parts[1]
        if dev_type == "wifi":
            has_wifi = True
        if dev_type == "ethernet" and state == "connected":
            return False  # aktív vezetékes kapcsolat van, wifi oldal nem kell

    return has_wifi


# ─── Signal bar helper ─────────────────────────────────────────────────────────

def signal_icon(signal: int) -> str:
    if signal >= 80: return "▂▄▆█"
    if signal >= 60: return "▂▄▆·"
    if signal >= 40: return "▂▄··"
    return "▂···"


def security_tag(sec: str) -> str:
    if not sec or sec == "--":
        return _t("wifi_open")
    return _t("wifi_encrypted")


# ─── Page 1: Welcome ───────────────────────────────────────────────────────────

class WelcomePage(QWidget):
    def __init__(self):
        super().__init__()
        self._build()

    def _build(self):
        lay = QVBoxLayout(self)
        lay.setContentsMargins(60, 40, 60, 40)
        lay.setSpacing(0)

        # Logo
        logo = RaveLogo()
        lay.addWidget(logo, alignment=Qt.AlignmentFlag.AlignHCenter)
        lay.addSpacing(10)

        title_lbl = QLabel()
        title_lbl.setTextFormat(Qt.TextFormat.RichText)
        title_lbl.setText(
            f'<span style="font-size:38px;font-weight:700;color:{COLORS["text"]};">RAVE</span>'
            f'<span style="font-size:48px;font-weight:700;color:{COLORS["accent_light"]};">OS</span>'
        )
        title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(title_lbl)
        lay.addSpacing(2)

        self.tag = QLabel(_t("welcome_tag"))
        self.tag.setObjectName("subtitle")
        self.tag.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(self.tag)

        sep = QFrame()
        sep.setObjectName("separator")
        sep.setFixedHeight(1)
        lay.addSpacing(28)
        lay.addWidget(sep)
        lay.addSpacing(24)

        # About card
        card = QFrame()
        card.setObjectName("card")
        card_lay = QVBoxLayout(card)
        card_lay.setContentsMargins(28, 20, 28, 20)
        card_lay.setSpacing(14)

        self.about = QLabel(_t("welcome_about"))
        self.about.setObjectName("body")
        self.about.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.about.setWordWrap(True)
        card_lay.addWidget(self.about)

        sep2 = QFrame()
        sep2.setObjectName("separator")
        sep2.setFixedHeight(1)
        card_lay.addWidget(sep2)

        features_lay = QHBoxLayout()
        features_lay.setSpacing(24)
        self._feature_icons = []
        self._feature_labels = []
        for icon, key in [
            ("⚡︎", "feat_perf"),
            ("🎮︎", "feat_gaming"),
            ("🛠︎", "feat_apps"),
        ]:
            col = QVBoxLayout()
            col.setSpacing(4)
            ico = QLabel(icon)
            ico.setAlignment(Qt.AlignmentFlag.AlignCenter)
            ico.setStyleSheet(f"font-size: 22px; color: {COLORS['text']};")
            lbl = QLabel(_t(key))
            lbl.setObjectName("body")
            lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl.setStyleSheet(f"font-size: 11px; color: {COLORS['text_dim']};")
            col.addWidget(ico)
            col.addWidget(lbl)
            features_lay.addLayout(col)
            self._feature_icons.append(icon)
            self._feature_labels.append((key, lbl))
        card_lay.addLayout(features_lay)

        lay.addWidget(card)
        lay.addSpacing(18)

        # Community links
        links_row1 = QHBoxLayout()
        links_row1.setSpacing(8)
        links_row2 = QHBoxLayout()
        links_row2.setSpacing(8)

        all_links = [
            ("support",  "https://ko-fi.com/ravepriest1/tiers"),
            ("RP Forgejo", "https://git.rp1.hu/explore/repos"),
            ("RP YouTube", "https://www.youtube.com/@RPslair"),
            ("RP Twitch",  "https://www.twitch.tv/ravepriest1"),
            ("RP Kick",    "https://kick.com/rpslair"),
            ("RP Discord", "https://discord.gg/gSdVMXRFQc"),
        ]
        self._link_btns = []
        self._support_btn = None
        for i, (label, url) in enumerate(all_links):
            if label == "support":
                btn = QPushButton(_t("btn_support"))
                self._support_btn = btn
            else:
                btn = QPushButton(label)
            btn.setObjectName("icon_btn")
            btn.clicked.connect(lambda _, u=url: self._open_url(u))
            if label == "support":
                btn.setStyleSheet(
                    f"QPushButton {{ background: {COLORS['surface']}; border: 1px solid {COLORS['accent']};"
                    f" border-radius: 6px; padding: 8px 14px; font-size: 13px;"
                    f" color: #ffffff; font-weight: 700; }}"
                    f"QPushButton:hover {{ border-color: {COLORS['accent_light']};"
                    f" color: {COLORS['accent_light']}; background: {COLORS['surface2']}; }}"
                )
            if i < 3:
                links_row1.addWidget(btn)
            else:
                links_row2.addWidget(btn)
            self._link_btns.append((label, btn))

        lay.addLayout(links_row1)
        lay.addSpacing(6)
        lay.addLayout(links_row2)
        lay.addStretch()

    def retranslate(self):
        self.tag.setText(_t("welcome_tag"))
        self.about.setText(_t("welcome_about"))
        for key, lbl in self._feature_labels:
            lbl.setText(_t(key))
        if self._support_btn:
            self._support_btn.setText(_t("btn_support"))

    def _open_url(self, url):
        subprocess.Popen(["xdg-open", url])


# ─── Page 2: WiFi ──────────────────────────────────────────────────────────────

class WiFiPage(QWidget):
    def __init__(self):
        super().__init__()
        self._networks = []
        self._selected_ssid = None
        self._scanner = None
        self._connector = None
        self._build()

    def _build(self):
        lay = QVBoxLayout(self)
        lay.setContentsMargins(60, 40, 60, 40)
        lay.setSpacing(16)

        self.title = QLabel(_t("wifi_title"))
        self.title.setObjectName("section_title")
        lay.addWidget(self.title)

        h = QHBoxLayout()
        h.setSpacing(10)
        self.net_title = QLabel(_t("wifi_subtitle"))
        self.net_title.setObjectName("subtitle")
        h.addWidget(self.net_title)
        h.addStretch()

        self.scan_btn = QPushButton(_t("wifi_scan"))
        self.scan_btn.setObjectName("icon_btn")
        self.scan_btn.clicked.connect(self.scan)
        h.addWidget(self.scan_btn)
        lay.addLayout(h)

        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.setFixedHeight(4)
        self.progress.setVisible(False)
        lay.addWidget(self.progress)

        self.list = QListWidget()
        self.list.setMinimumHeight(180)
        self.list.itemClicked.connect(self._on_select)
        lay.addWidget(self.list)

        # Password field
        self.pw_frame = QFrame()
        pw_lay = QVBoxLayout(self.pw_frame)
        pw_lay.setContentsMargins(0, 0, 0, 0)
        pw_lay.setSpacing(6)

        self.pw_label = QLabel(_t("wifi_password"))
        self.pw_label.setObjectName("body")
        pw_lay.addWidget(self.pw_label)

        self.pw_input = QLineEdit()
        self.pw_input.setPlaceholderText(_t("wifi_password"))
        self.pw_input.setEchoMode(QLineEdit.EchoMode.Password)
        pw_lay.addWidget(self.pw_input)

        self.pw_frame.setVisible(False)
        lay.addWidget(self.pw_frame)

        # Status
        self.status_label = QLabel("")
        self.status_label.setObjectName("body")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(self.status_label)

        # Connect button
        self.connect_btn = QPushButton(_t("wifi_connect"))
        self.connect_btn.setObjectName("primary")
        self.connect_btn.setEnabled(False)
        self.connect_btn.clicked.connect(self._connect)
        lay.addWidget(self.connect_btn, alignment=Qt.AlignmentFlag.AlignRight)

        lay.addStretch()

    def retranslate(self):
        self.title.setText(_t("wifi_title"))
        self.net_title.setText(_t("wifi_subtitle"))
        self.scan_btn.setText(_t("wifi_scan"))
        self.connect_btn.setText(_t("wifi_connect"))
        if self._selected_ssid:
            self.status_label.setText(_t("wifi_selected", ssid=self._selected_ssid))

    def showEvent(self, event):
        super().showEvent(event)
        if not self._networks:
            self.scan()

    def scan(self):
        self.scan_btn.setEnabled(False)
        self.list.clear()
        self.status_label.setText(_t("wifi_scanning"))
        self.progress.setVisible(True)
        self._scanner = WiFiScanner()
        self._scanner.result.connect(self._on_scan_result)
        self._scanner.error.connect(self._on_scan_error)
        self._scanner.start()

    def _on_scan_result(self, networks):
        self.progress.setVisible(False)
        self.scan_btn.setEnabled(True)
        self._networks = networks
        self.list.clear()
        if not networks:
            self.status_label.setText(_t("wifi_none"))
            return
        self.status_label.setText(_t("wifi_found", n=len(networks)))
        for n in networks:
            text = f"{signal_icon(n['signal'])}  {n['ssid']}{security_tag(n['security'])}"
            item = QListWidgetItem(text)
            item.setData(Qt.ItemDataRole.UserRole, n)
            self.list.addItem(item)

    def _on_scan_error(self, err):
        self.progress.setVisible(False)
        self.scan_btn.setEnabled(True)
        self.status_label.setStyleSheet(f"color: {COLORS['error']};")
        self.status_label.setText(_t("wifi_error", err=err))

    def _on_select(self, item):
        n = item.data(Qt.ItemDataRole.UserRole)
        self._selected_ssid = n["ssid"]
        needs_pw = bool(n["security"] and n["security"] != "--")
        self.pw_frame.setVisible(needs_pw)
        if needs_pw:
            self.pw_label.setText(f"{_t('wifi_password')} ({n['ssid']}):")
        self.connect_btn.setEnabled(True)
        self.status_label.setStyleSheet("")
        self.status_label.setText(_t("wifi_selected", ssid=n['ssid']))

    def _connect(self):
        if not self._selected_ssid:
            return
        pw = self.pw_input.text() if self.pw_frame.isVisible() else ""
        self.connect_btn.setEnabled(False)
        self.progress.setVisible(True)
        self.status_label.setStyleSheet(f"color: {COLORS['text_dim']};")
        self.status_label.setText(_t("wifi_connecting"))
        self._connector = WiFiConnector(self._selected_ssid, pw)
        self._connector.success.connect(self._on_connected)
        self._connector.failure.connect(self._on_connect_fail)
        self._connector.start()

    def _on_connected(self):
        self.progress.setVisible(False)
        self.status_label.setStyleSheet(f"color: {COLORS['success']};")
        self.status_label.setText(_t("wifi_connected", ssid=self._selected_ssid))
        self.connect_btn.setEnabled(True)

    def _on_connect_fail(self, err):
        self.progress.setVisible(False)
        self.status_label.setStyleSheet(f"color: {COLORS['error']};")
        self.status_label.setText(_t("wifi_error", err=err))
        self.connect_btn.setEnabled(True)


# ─── Hyprland Detection ───────────────────────────────────────────────────────

HYPR_CONFIG = Path.home() / ".config" / "hypr" / "hyprland.conf"
_HYPR_FALLBACK = Path("/usr/share/raveos/hyprland-theme/theme-data/hypr/hyprland.conf")

# Hyprland 0.55+ Lua config mod (RaveOS ezt hasznalja alapertelmezetten,
# nincs is hagyomanyos hyprland.conf a rendszeren)
HYPR_KEYBINDS_LUA = Path.home() / ".config" / "hypr" / "config" / "keybinds.lua"
_HYPR_KEYBINDS_LUA_FALLBACK = Path(
    "/usr/share/raveos/hyprland-theme/theme-data/hypr/config/keybinds.lua"
)

def _detect_hyprland() -> bool:
    if os.environ.get("XDG_CURRENT_DESKTOP", "").lower() == "hyprland":
        return True
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return True
    return False


def _fmt_key(raw: str) -> str:
    mapping = {
        "super": "Win", "ctrl": "Ctrl", "alt": "Alt", "shift": "Shift",
        "return": "Enter", "space": "Space", "tab": "Tab",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse_down": "Görgő le", "mouse_up": "Görgő fel",
        "mouse:272": "Bal egér", "mouse:273": "Jobb egér",
        "super_l": "Win",
    }
    parts = [p.strip() for p in raw.replace("+", " ").split() if p.strip()]
    result = []
    for p in parts:
        result.append(mapping.get(p.lower(), p.upper()))
    return " + ".join(result)


_EXEC_SNIPPETS = {
    "dms ipc call spotlight toggle": "Spotlight (DMS) megnyitása",
    "dms ipc call clipboard toggle": "Vágólap megjelenítése",
    "dms ipc call processlist toggle": "Folyamatlista megjelenítése",
    "dms ipc call notifications toggle": "Értesítések megjelenítése",
    "dms ipc call settings toggle": "Beállítások megnyitása",
    "dms ipc call dankdash wallpaper": "Háttérkép váltó megnyitása",
    "hyprshell socat": "Ablakváltó (Alt+Tab) megnyitása",
    "reboot": "Újraindítás",
    "poweroff": "Leállítás",
    "freetube": "FreeTube megnyitása",
    "discord": "Discord megnyitása",
    "gedit": "Szövegszerkesztő megnyitása",
    "pavucontrol": "Hangkezelő megnyitása",
    "kitty": "Terminál megnyitása (Kitty)",
    "thunar": "Fájlkezelő megnyitása (Thunar)",
    "hyperlauncher": "App launcher megnyitása",
    "hyprlauncher": "App launcher megnyitása",
    "hyprshutdown": "Kijelentkezés / leállítás",
    "hyprctl dispatch exit": "Hyprland kilépés",
    "wpctl set-volume": "Hangerő állítás",
    "wpctl set-mute": "Némítás ki/be",
    "brightnessctl": "Fényerő állítás",
    "playerctl next": "Következő szám",
    "playerctl previous": "Előző szám",
    "playerctl play-pause": "Lejátszás / szünet",
    "rofi": "App launcher (Rofi)",
    "wofi": "App launcher (Wofi)",
    "wl-paste": "Vágólap kezelő",
    "cliphist": "Vágólap megjelenítése",
    "grim": "Képernyőkép készítése",
    "grimblast": "Képernyőkép készítése",
    "hyprlock": "Képernyőzár",
    "swaylock": "Képernyőzár",
}

_ACTION_DESCS = {
    "killactive":             "Aktív ablak bezárása",
    "togglefloating":         "Lebegő mód ki/be",
    "pseudo":                 "Pseudo-tiling ki/be",
    "fullscreen":             "Teljes képernyős mód",
    "exit":                   "Kilépés",
    "movefocus":              {
        "l": "Fókusz mozgatása balra",
        "r": "Fókusz mozgatása jobbra",
        "u": "Fókusz mozgatása fel",
        "d": "Fókusz mozgatása le",
    },
    "togglespecialworkspace": "Scratchpad megjelenítése",
    "workspace":              lambda p: (
        f"Váltás {p}. munkaterületre" if p.isdigit() else
        f"Munkaterület: {p}"
    ),
    "movetoworkspace":        lambda p: (
        f"Ablak áthelyezése {p}. munkaterületre" if p.isdigit() else
        f"Ablak áthelyezése: {p}"
    ),
    "layoutmsg":              lambda p: f"Layout: {p}",
}


def _exec_desc(cmd: str) -> str:
    cmd_lower = cmd.lower()
    for snippet, label in _EXEC_SNIPPETS.items():
        if snippet.lower() in cmd_lower:
            return label
    prog = cmd.strip().split()[0].split("/")[-1] if cmd.strip() else ""
    return f"Futtatás: {prog}" if prog else "Program futtatása"


def _workspace_desc(prefix: str, params: str) -> str:
    p = params.strip()
    if p.startswith("special:"):
        return "Ablak → scratchpad" if prefix == "move" else "Scratchpad ki/be"
    if p in ("e+1",):
        return "Következő munkaterület"
    if p in ("e-1",):
        return "Előző munkaterület"
    if p.isdigit():
        n = p if p != "0" else "10"
        return f"Ablak → {n}. munkaterületre" if prefix == "move" else f"Váltás {n}. munkaterületre"
    return f"Munkaterület: {p}"


def _action_desc(action: str, params: str) -> str:
    if action in ("workspace",):
        return _workspace_desc("", params)
    if action in ("movetoworkspace",):
        return _workspace_desc("move", params)
    entry = _ACTION_DESCS.get(action)
    if entry is None:
        if action == "exec":
            return _exec_desc(params)
        return f"{action} {params}".strip()
    if callable(entry):
        return entry(params)
    if isinstance(entry, dict):
        return entry.get(params.strip(), f"Fókusz mozgatása ({params})")
    return entry


def _parse_hypr_binds(config_path: Path) -> list:
    if not config_path.exists():
        return []
    try:
        text = config_path.read_text(errors="replace")
    except Exception:
        return []

    vars_ = {}
    binds = []

    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("$") and "=" in line:
            k, _, v = line.partition("=")
            vars_[k.strip()] = v.split("#")[0].strip()
            continue

        if not line.startswith("bind"):
            continue
        if line.startswith("bindm"):
            continue

        eq = line.find("=")
        if eq < 0:
            continue
        rest = line[eq + 1:].strip()

        for vn, vv in vars_.items():
            rest = rest.replace(vn, vv)

        parts = [p.strip() for p in rest.split(",")]
        if len(parts) < 3:
            continue

        mods_raw = parts[0]
        key_raw  = parts[1]
        action   = parts[2].lower().strip()
        if action == "exec" and len(parts) > 3:
            params = ",".join(parts[3:]).split("#")[0].strip()
        elif len(parts) > 3:
            params = parts[3].split("#")[0].strip()
        else:
            params = ""

        if "XF86" in key_raw:
            continue

        combo = _fmt_key(f"{mods_raw} {key_raw}" if mods_raw else key_raw)
        desc  = _action_desc(action, params)
        if combo and desc:
            binds.append((combo, desc))

    return binds


# ─── Hyprland Lua config parser (keybinds.lua, hl.bind(...) hivasok) ─────────
# Best-effort parser: nem valodi Lua interpreter, csak a RaveOS keybinds.lua
# tipikus mintait (hl.bind("KEY", hl.dsp.xxx(...)), local string valtozok,
# egyszeru "for i = a, b do ... end" munkaterulet-ciklusok) ismeri fel.

def _lua_extract_call(line: str, funcname: str):
    marker = funcname + "("
    idx = line.find(marker)
    if idx < 0:
        return None
    start = idx + len(marker)
    depth = 1
    i = start
    in_str = False
    str_char = ""
    while i < len(line) and depth > 0:
        c = line[i]
        if in_str:
            if c == str_char:
                in_str = False
        elif c in "\"'":
            in_str = True
            str_char = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return line[start:i - 1]


def _lua_split_args(s: str) -> list:
    parts = []
    depth = 0
    current = []
    in_str = False
    str_char = ""
    for c in s:
        if in_str:
            current.append(c)
            if c == str_char:
                in_str = False
            continue
        if c in "\"'":
            in_str = True
            str_char = c
            current.append(c)
            continue
        if c in "([{":
            depth += 1
            current.append(c)
            continue
        if c in ")]}":
            depth -= 1
            current.append(c)
            continue
        if c == "," and depth == 0:
            parts.append("".join(current))
            current = []
            continue
        current.append(c)
    if current:
        parts.append("".join(current))
    return [p.strip() for p in parts]


def _lua_resolve_key_expr(expr: str, env: dict):
    parts = expr.split("..")
    resolved = []
    for part in parts:
        part = part.strip()
        if len(part) >= 2 and part[0] == part[-1] and part[0] in "\"'":
            resolved.append(part[1:-1])
        elif part in env:
            resolved.append(str(env[part]))
        else:
            return None
    return "".join(resolved)


def _lua_unquote(s: str) -> str:
    s = s.strip()
    if s.startswith("[[") and s.endswith("]]"):
        return s[2:-2]
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        return s[1:-1]
    return s


def _lua_dispatch_desc(call_expr: str):
    m = re.match(r'^hl\.dsp\.([\w.]+)\((.*)\)$', call_expr.strip(), re.DOTALL)
    if not m:
        return None
    dispatcher, arg_str = m.group(1), m.group(2)
    if dispatcher == "exec_cmd":
        return _exec_desc(_lua_unquote(arg_str))
    if dispatcher == "window.kill":
        return "Aktív ablak bezárása"
    if dispatcher == "window.float":
        return "Lebegő mód ki/be"
    if dispatcher == "window.drag":
        return "Ablak húzása egérrel"
    if dispatcher == "window.resize":
        return "Ablak átméretezése egérrel"
    if dispatcher == "focus":
        dm = re.search(r'direction\s*=\s*"(\w+)"', arg_str)
        if dm:
            names = {"left": "balra", "right": "jobbra", "up": "fel", "down": "le"}
            return f"Fókusz mozgatása {names.get(dm.group(1), dm.group(1))}"
        wm = re.search(r'workspace\s*=\s*(-?\d+)', arg_str)
        if wm:
            return f"Váltás {wm.group(1)}. munkaterületre"
        return "Fókusz mozgatása"
    if dispatcher == "window.move":
        wm = re.search(r'workspace\s*=\s*(-?\d+)', arg_str)
        if wm:
            return f"Ablak áthelyezése {wm.group(1)}. munkaterületre"
        return "Ablak áthelyezése"
    return None


def _lua_simple_arith(expr: str, env: dict):
    expr = expr.strip()
    m = re.match(r'^(\w+)\s*%\s*(\d+)$', expr)
    if m and m.group(1) in env:
        try:
            return int(env[m.group(1)]) % int(m.group(2))
        except (TypeError, ValueError):
            return None
    m = re.match(r'^(\w+)\s*([+-])\s*(\d+)$', expr)
    if m and m.group(1) in env:
        try:
            base = int(env[m.group(1)])
            return base + int(m.group(3)) if m.group(2) == "+" else base - int(m.group(3))
        except (TypeError, ValueError):
            return None
    if expr.lstrip("-").isdigit():
        return int(expr)
    return env.get(expr)


def _lua_try_add_bind(line: str, env: dict, binds: list):
    inner = _lua_extract_call(line, "hl.bind")
    if inner is None:
        return
    args = _lua_split_args(inner)
    if len(args) < 2:
        return
    if "XF86" in args[0]:
        return
    combo_raw = _lua_resolve_key_expr(args[0], env)
    if combo_raw is None:
        return
    combo = _fmt_key(combo_raw)

    # ciklus-valtozok (pl. workspace = i) behelyettesitese a dispatcher
    # kifejezesbe is, hogy a leiras a tenyleges munkaterulet-szamot mutassa
    dispatch_expr = args[1]
    for name, value in env.items():
        if isinstance(value, int):
            dispatch_expr = re.sub(rf'\b{re.escape(name)}\b', str(value), dispatch_expr)

    desc = _lua_dispatch_desc(dispatch_expr)
    if combo and desc:
        binds.append((combo, desc))


def _parse_hypr_binds_lua(path: Path) -> list:
    if not path.exists():
        return []
    try:
        lines = path.read_text(errors="replace").splitlines()
    except Exception:
        return []

    env = {}
    binds = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i].strip()
        if not line or line.startswith("--"):
            i += 1
            continue

        m = re.match(r'^local\s+(\w+)\s*=\s*"([^"]*)"\s*$', line)
        if m:
            env[m.group(1)] = m.group(2)
            i += 1
            continue

        m = re.match(r'^for\s+(\w+)\s*=\s*(-?\d+)\s*,\s*(-?\d+)\s+do\s*$', line)
        if m:
            var, start, end = m.group(1), int(m.group(2)), int(m.group(3))
            body = []
            depth = 1
            j = i + 1
            while j < n and depth > 0:
                bline = lines[j].strip()
                if bline == "end":
                    depth -= 1
                    if depth == 0:
                        break
                elif re.match(r'^(for|if|function)\b', bline) and \
                        (bline.endswith("do") or bline.endswith("then")):
                    depth += 1
                if depth > 0:
                    body.append(bline)
                j += 1
            for val in range(start, end + 1):
                loop_env = dict(env)
                loop_env[var] = val
                for bline in body:
                    lm = re.match(r'^local\s+(\w+)\s*=\s*(.+)$', bline)
                    if lm:
                        result = _lua_simple_arith(lm.group(2), loop_env)
                        if result is not None:
                            loop_env[lm.group(1)] = result
                        continue
                    _lua_try_add_bind(bline, loop_env, binds)
            i = j + 1
            continue

        _lua_try_add_bind(line, env, binds)
        i += 1

    return binds


# ─── Page: Hyprland Keybinds ─────────────────────────────────────────────────

class HyprlandPage(QWidget):
    def __init__(self):
        super().__init__()
        cfg = HYPR_CONFIG if HYPR_CONFIG.exists() else _HYPR_FALLBACK
        self._binds = _parse_hypr_binds(cfg)
        self._cfg_path = cfg
        if not self._binds:
            # nincs hagyomanyos hyprland.conf (vagy nincs benne bind sor) -
            # a RaveOS Hyprland 0.55+ Lua config modot hasznalja
            lua_cfg = HYPR_KEYBINDS_LUA if HYPR_KEYBINDS_LUA.exists() else _HYPR_KEYBINDS_LUA_FALLBACK
            lua_binds = _parse_hypr_binds_lua(lua_cfg)
            if lua_binds:
                self._binds = lua_binds
                self._cfg_path = lua_cfg
        self._build()

    def _build(self):
        lay = QVBoxLayout(self)
        lay.setContentsMargins(60, 28, 60, 20)
        lay.setSpacing(10)

        header = QHBoxLayout()
        self.title = QLabel(_t("hypr_title"))
        self.title.setObjectName("section_title")
        header.addWidget(self.title)
        header.addStretch()
        self.src = QLabel(_t("hypr_source") + str(self._cfg_path))
        self.src.setStyleSheet(f"font-size: 10px; color: {COLORS['text_dim']};")
        header.addWidget(self.src)
        lay.addLayout(header)

        if not self._binds:
            self.msg = QLabel(_t("hypr_none"))
            self.msg.setObjectName("body")
            self.msg.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lay.addWidget(self.msg, alignment=Qt.AlignmentFlag.AlignCenter)
            lay.addStretch()
            return

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("background: transparent;")

        inner = QWidget()
        inner.setStyleSheet("background: transparent;")
        vlay = QVBoxLayout(inner)
        vlay.setContentsMargins(0, 4, 8, 0)
        vlay.setSpacing(0)

        card = QFrame()
        card.setObjectName("card")
        card_lay = QVBoxLayout(card)
        card_lay.setContentsMargins(16, 10, 16, 10)
        card_lay.setSpacing(0)

        for i, (key, desc) in enumerate(self._binds):
            row = QHBoxLayout()
            row.setContentsMargins(0, 6, 0, 6)
            row.setSpacing(12)

            key_lbl = QLabel(key)
            key_lbl.setFixedWidth(230)
            key_lbl.setStyleSheet(
                f"font-family: monospace; font-size: 12px; font-weight: 600;"
                f" color: {COLORS['accent_light']}; background: {COLORS['surface2']};"
                f" border-radius: 4px; padding: 3px 8px;"
            )

            desc_lbl = QLabel(desc)
            desc_lbl.setStyleSheet(f"font-size: 13px; color: {COLORS['text']};")

            row.addWidget(key_lbl)
            row.addWidget(desc_lbl)
            row.addStretch()
            card_lay.addLayout(row)

            if i < len(self._binds) - 1:
                div = QFrame()
                div.setFixedHeight(1)
                div.setStyleSheet(f"background: {COLORS['border']}; border: none;")
                card_lay.addWidget(div)

        vlay.addWidget(card)
        vlay.addStretch()
        scroll.setWidget(inner)
        lay.addWidget(scroll, 1)

    def retranslate(self):
        self.title.setText(_t("hypr_title"))
        self.src.setText(_t("hypr_source") + str(self._cfg_path))
        if not self._binds:
            self.msg.setText(_t("hypr_none"))


# ─── GPU Detection ────────────────────────────────────────────────────────────

def _detect_gpu() -> str:
    try:
        out = subprocess.check_output(
            ["lspci"], stderr=subprocess.DEVNULL
        ).decode().lower()
        if "amd" in out or "radeon" in out:
            return "amd"
        if "nvidia" in out:
            return "nvidia"
    except Exception:
        pass
    return "other"


# ─── Page 3: Optimize ──────────────────────────────────────────────────────────

OPTIMIZE_SCRIPT = "/usr/share/raveos-welcome/gaming-optimize.sh"
OPTIMIZE_LOG = "/var/log/raveos-welcome/gaming-optimize.log"

CHECKBOX_STYLE = f"""
QCheckBox {{
    color: {COLORS['text']};
    font-size: 13px;
    spacing: 8px;
}}
QCheckBox::indicator {{
    width: 16px;
    height: 16px;
    border-radius: 3px;
    border: 1px solid {COLORS['border']};
    background: {COLORS['surface2']};
}}
QCheckBox::indicator:checked {{
    background: {COLORS['accent']};
    border-color: {COLORS['accent']};
}}
"""


class OptimizePage(QWidget):
    def __init__(self):
        super().__init__()
        self._gpu = _detect_gpu()
        self._checks = {}
        self._hints = {}
        self._proc = None
        self._build()

    def _build(self):
        lay = QVBoxLayout(self)
        lay.setContentsMargins(60, 28, 60, 20)
        lay.setSpacing(10)

        self.title = QLabel(_t("opt_title"))
        self.title.setObjectName("section_title")
        lay.addWidget(self.title)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("background: transparent;")

        inner = QWidget()
        inner.setStyleSheet("background: transparent;")
        vlay = QVBoxLayout(inner)
        vlay.setContentsMargins(0, 0, 8, 0)
        vlay.setSpacing(4)

        # --- Browsers ---
        self.sec1 = QLabel(_t("opt_browser"))
        self.sec1.setObjectName("section_title")
        vlay.addWidget(self.sec1)
        vlay.addSpacing(4)

        browsers = [
            ("brave",   "opt_brave",   "opt_brave_desc"),
            ("firefox", "opt_firefox", "opt_firefox_desc"),
        ]
        self._browser_checks = {}
        for key, label_key, desc_key in browsers:
            cb = self._add_check(vlay, key, _t(label_key), _t(desc_key), default=False)
            self._browser_checks[key] = (label_key, desc_key, cb)

        cb_bp = self._add_check(vlay, "brave_profile",
            _t("opt_brave_profile"),
            _t("opt_brave_profile_desc"),
            default=False)
        self._brave_profile_check = ("opt_brave_profile", "opt_brave_profile_desc", cb_bp)

        vlay.addSpacing(14)

        # --- Gaming optimization ---
        gpu_name = {"amd": "AMD", "nvidia": "Nvidia"}.get(self._gpu, "Ismeretlen")
        self.sec2 = QLabel(_t("opt_gaming", gpu=gpu_name))
        self.sec2.setObjectName("section_title")
        vlay.addWidget(self.sec2)
        vlay.addSpacing(4)

        common = [
            ("sysctl", "opt_sysctl", "opt_sysctl_desc"),
            ("io_sched", "opt_io_sched", "opt_io_sched_desc"),
            ("ananicy", "opt_ananicy", "opt_ananicy_desc"),
            ("gamemode", "opt_gamemode", "opt_gamemode_desc"),
        ]
        self._common_checks = {}
        for key, label_key, desc_key in common:
            cb = self._add_check(vlay, key, _t(label_key), _t(desc_key), default=True)
            self._common_checks[key] = (label_key, desc_key, cb)

        self._amd_checks = {}
        self._nvidia_checks = {}
        if self._gpu == "amd":
            amd_opts = [
                ("gpu_profile", "opt_gpu_profile", "opt_gpu_profile_desc"),
                ("amd_overdrive", "opt_amd_overdrive", "opt_amd_overdrive_desc"),
                ("amd_powercap", "opt_amd_powercap", "opt_amd_powercap_desc"),
            ]
            for key, label_key, desc_key in amd_opts:
                cb = self._add_check(vlay, key, _t(label_key), _t(desc_key), default=(key in ("gpu_profile", "amd_powercap")))
                self._amd_checks[key] = (label_key, desc_key, cb)

        elif self._gpu == "nvidia":
            cb = self._add_check(vlay,
                "nvidia_perf", _t("opt_nvidia_perf"),
                _t("opt_nvidia_perf_desc"),
                default=True)
            self._nvidia_checks["nvidia_perf"] = ("opt_nvidia_perf", "opt_nvidia_perf_desc", cb)

        vlay.addStretch()
        scroll.setWidget(inner)
        lay.addWidget(scroll, 1)

        # Status + gomb
        self.status_lbl = QLabel("")
        self.status_lbl.setObjectName("body")
        self.status_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(self.status_lbl)

        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.setFixedHeight(4)
        self.progress.setVisible(False)
        lay.addWidget(self.progress)

        self.apply_btn = QPushButton(_t("opt_apply"))
        self.apply_btn.setObjectName("primary")
        self.apply_btn.clicked.connect(self._apply)
        lay.addWidget(self.apply_btn, alignment=Qt.AlignmentFlag.AlignRight)

    def retranslate(self):
        self.title.setText(_t("opt_title"))
        self.sec1.setText(_t("opt_browser"))
        gpu_name = {"amd": "AMD", "nvidia": "Nvidia"}.get(self._gpu, "Ismeretlen")
        self.sec2.setText(_t("opt_gaming", gpu=gpu_name))
        self.apply_btn.setText(_t("opt_apply"))
        for key, (lk, dk, cb) in self._browser_checks.items():
            cb.setText(_t(lk))
            if key in self._hints:
                self._hints[key].setToolTip(_t(dk))
        bp_lk, bp_dk, bp_cb = self._brave_profile_check
        bp_cb.setText(_t(bp_lk))
        if "brave_profile" in self._hints:
            self._hints["brave_profile"].setToolTip(_t(bp_dk))
        for key, (lk, dk, cb) in self._common_checks.items():
            cb.setText(_t(lk))
            if key in self._hints:
                self._hints[key].setToolTip(_t(dk))
        for key, (lk, dk, cb) in self._amd_checks.items():
            cb.setText(_t(lk))
            if key in self._hints:
                self._hints[key].setToolTip(_t(dk))
        for key, (lk, dk, cb) in self._nvidia_checks.items():
            cb.setText(_t(lk))
            if key in self._hints:
                self._hints[key].setToolTip(_t(dk))

    def _add_check(self, layout, key, label, desc, default):
        row = QHBoxLayout()
        row.setContentsMargins(0, 0, 0, 0)
        row.setSpacing(6)

        cb = QCheckBox(label)
        cb.setChecked(default)
        cb.setStyleSheet(CHECKBOX_STYLE)
        row.addWidget(cb)

        hint = QLabel("?")
        hint.setToolTip(desc)
        hint.setCursor(Qt.CursorShape.WhatsThisCursor)
        hint.setFixedSize(16, 16)
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        hint.setStyleSheet(
            f"color: {COLORS['text_dim']}; font-size: 11px; font-weight: 600;"
            f" background: {COLORS['surface2']}; border-radius: 8px;"
            f" border: 1px solid {COLORS['border']};"
        )
        row.addWidget(hint)
        row.addStretch()

        layout.addLayout(row)
        layout.addSpacing(3)
        self._checks[key] = cb
        self._hints[key] = hint
        return cb

    def _apply(self):
        selected = [k for k, cb in self._checks.items() if cb.isChecked()]
        if not selected:
            self.status_lbl.setStyleSheet(f"color: {COLORS['warning']};")
            self.status_lbl.setText(_t("opt_apply_empty"))
            return

        script = OPTIMIZE_SCRIPT
        if not Path(script).exists():
            self.status_lbl.setStyleSheet(f"color: {COLORS['error']};")
            self.status_lbl.setText(_t("opt_apply_missing") + script)
            return

        self.apply_btn.setEnabled(False)
        self.status_lbl.setText("")
        self.progress.setVisible(True)

        self._proc = QProcess(self)
        self._proc.finished.connect(self._on_done)
        self._proc.start("pkexec", [script] + selected)

    def _on_done(self, exit_code, _):
        self.apply_btn.setEnabled(True)
        self.progress.setVisible(False)
        if exit_code == 0:
            self.status_lbl.setStyleSheet(f"color: {COLORS['success']};")
            self.status_lbl.setText(_t("opt_apply_ok"))
        else:
            self.status_lbl.setStyleSheet(f"color: {COLORS['error']};")
            self.status_lbl.setText(_t("opt_apply_err", code=exit_code, log=OPTIMIZE_LOG))


# ─── Page 4: Credits ──────────────────────────────────────────────────────────

class CreditsPage(QWidget):
    def __init__(self):
        super().__init__()
        self._build()

    def _build(self):
        lay = QVBoxLayout(self)
        lay.setContentsMargins(60, 40, 60, 40)
        lay.setSpacing(0)

        self.title = QLabel(_t("credits_title"))
        self.title.setObjectName("section_title")
        self.title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(self.title)

        sep = QFrame()
        sep.setObjectName("separator")
        sep.setFixedHeight(1)
        lay.addSpacing(16)
        lay.addWidget(sep)
        lay.addSpacing(24)

        people = [
            ("credits_rp1",   "credits_rp1_name",   "credits_rp1_role",   "credits_rp1_desc"),
            ("credits_alexc", "credits_alexc_name", "credits_alexc_role", "credits_alexc_desc"),
            ("credits_nippy", "credits_nippy_name", "credits_nippy_role", "credits_nippy_desc"),
            ("credits_gabesz","credits_gabesz_name","credits_gabesz_role","credits_gabesz_desc"),
            ("credits_stefi", "credits_stefi_name", "credits_stefi_role", "credits_stefi_desc"),
        ]

        self._people_cards = []
        for prefix, name_key, role_key, desc_key in people:
            card = QFrame()
            card.setObjectName("card")
            card_lay = QHBoxLayout(card)
            card_lay.setContentsMargins(20, 14, 20, 14)
            card_lay.setSpacing(16)

            left = QVBoxLayout()
            left.setSpacing(2)
            name_lbl = QLabel(_t(name_key))
            name_lbl.setStyleSheet(
                f"font-size: 15px; font-weight: 700; color: {COLORS['text']};"
            )
            role_lbl = QLabel(_t(role_key))
            role_lbl.setStyleSheet(
                f"font-size: 11px; font-weight: 600; letter-spacing: 1px;"
                f" color: {COLORS['accent_light']};"
            )
            left.addWidget(name_lbl)
            left.addWidget(role_lbl)

            desc_lbl = QLabel(_t(desc_key))
            desc_lbl.setStyleSheet(
                f"font-size: 12px; color: {COLORS['text_dim']}; font-style: italic;"
            )
            desc_lbl.setWordWrap(True)
            desc_lbl.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)

            card_lay.addLayout(left)
            card_lay.addStretch()
            card_lay.addWidget(desc_lbl)

            lay.addWidget(card)
            lay.addSpacing(10)

            self._people_cards.append((name_key, role_key, desc_key, name_lbl, role_lbl, desc_lbl))

        lay.addStretch()

    def retranslate(self):
        self.title.setText(_t("credits_title"))
        for name_key, role_key, desc_key, name_lbl, role_lbl, desc_lbl in self._people_cards:
            name_lbl.setText(_t(name_key))
            role_lbl.setText(_t(role_key))
            desc_lbl.setText(_t(desc_key))


# ─── Page 5: Finish ────────────────────────────────────────────────────────────

class FinishPage(QWidget):
    launch_installer = pyqtSignal()

    def __init__(self):
        super().__init__()
        self._build()

    def _build(self):
        lay = QVBoxLayout(self)
        lay.setContentsMargins(60, 40, 60, 40)
        lay.setSpacing(0)

        self.done_label = QLabel(_t("finish_ok"))
        self.done_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.done_label.setStyleSheet(
            f"font-size: 52px; font-weight: 700; color: {COLORS['success']};"
            f"font-family: Ubuntu; padding: 10px;"
        )
        lay.addWidget(self.done_label)
        lay.addSpacing(12)

        self.title = QLabel(_t("finish_title"))
        self.title.setObjectName("title")
        self.title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(self.title)
        lay.addSpacing(6)

        self.sub = QLabel(_t("finish_sub"))
        self.sub.setObjectName("subtitle")
        self.sub.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(self.sub)

        sep = QFrame()
        sep.setObjectName("separator")
        sep.setFixedHeight(1)
        lay.addSpacing(28)
        lay.addWidget(sep)
        lay.addSpacing(24)

        # App installer CTA card
        card = QFrame()
        card.setObjectName("card")
        card_lay = QVBoxLayout(card)
        card_lay.setContentsMargins(24, 18, 24, 18)
        card_lay.setSpacing(10)

        self.card_title = QLabel(_t("finish_next_step"))
        self.card_title.setObjectName("section_title")
        card_lay.addWidget(self.card_title)

        self.card_body = QLabel(_t("finish_inst_desc"))
        self.card_body.setObjectName("body")
        self.card_body.setWordWrap(True)
        card_lay.addWidget(self.card_body)

        self.install_btn = QPushButton(_t("finish_install"))
        self.install_btn.setObjectName("primary")
        self.install_btn.clicked.connect(self.launch_installer.emit)
        card_lay.addWidget(self.install_btn, alignment=Qt.AlignmentFlag.AlignRight)

        self.install_status = QLabel("")
        self.install_status.setObjectName("body")
        self.install_status.setWordWrap(True)
        self.install_status.setVisible(False)
        card_lay.addWidget(self.install_status)

        lay.addWidget(card)
        lay.addStretch()

    def retranslate(self):
        self.done_label.setText(_t("finish_ok"))
        self.title.setText(_t("finish_title"))
        self.sub.setText(_t("finish_sub"))
        self.card_title.setText(_t("finish_next_step"))
        self.card_body.setText(_t("finish_inst_desc"))
        self.install_btn.setText(_t("finish_install"))

    def show_error(self, msg):
        self.install_btn.setEnabled(True)
        self.install_status.setStyleSheet(f"color: {COLORS['error']};")
        self.install_status.setText(msg)
        self.install_status.setVisible(True)


# ─── Main Window ───────────────────────────────────────────────────────────────

class RaveOSWelcome(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("RaveOS — Üdvözlünk")
        self.setMinimumSize(720, 640)
        self.resize(800, 720)
        self.setStyleSheet(STYLESHEET)
        self._show_wifi    = _should_show_wifi()
        self._show_hyprland = _detect_hyprland()

        central = QWidget()
        central.setObjectName("central")
        self.setCentralWidget(central)

        root = QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Step indicator bar
        self.step_bar = self._make_step_bar()
        root.addWidget(self.step_bar)

        # Page container
        self.stack = QStackedWidget()
        root.addWidget(self.stack, stretch=1)

        # Pages
        self.p_welcome  = WelcomePage()
        self.p_optimize = OptimizePage()
        self.p_credits  = CreditsPage()
        self.p_finish   = FinishPage()

        self.stack.addWidget(self.p_welcome)
        if self._show_wifi:
            self.p_wifi = WiFiPage()
            self.stack.addWidget(self.p_wifi)
        self.stack.addWidget(self.p_optimize)
        if self._show_hyprland:
            self.p_hyprland = HyprlandPage()
            self.stack.addWidget(self.p_hyprland)
        self.stack.addWidget(self.p_credits)
        self.stack.addWidget(self.p_finish)

        # Nav buttons
        nav = QHBoxLayout()
        nav.setContentsMargins(24, 10, 24, 18)
        nav.setSpacing(12)

        # Language selector (bottom-left)
        self.lang_hu_btn = QPushButton("Magyar")
        self.lang_hu_btn.setObjectName("lang_btn")
        self.lang_hu_btn.setFixedHeight(30)
        self.lang_hu_btn.setCheckable(True)
        self.lang_hu_btn.setChecked(True)
        self.lang_hu_btn.setStyleSheet(
            f"QPushButton {{ background: {COLORS['accent']}; color: #ffffff;"
            f" border: none; border-radius: 4px; padding: 4px 12px;"
            f" font-size: 11px; font-weight: 600; }}"
            f"QPushButton:hover {{ background: {COLORS['accent_hover']}; }}"
            f"QPushButton:checked {{ background: {COLORS['accent']}; color: #ffffff; }}"
        )
        self.lang_hu_btn.clicked.connect(lambda: self._set_lang("hu"))
        nav.addWidget(self.lang_hu_btn)

        self.lang_en_btn = QPushButton("English")
        self.lang_en_btn.setObjectName("lang_btn")
        self.lang_en_btn.setFixedHeight(30)
        self.lang_en_btn.setCheckable(True)
        self.lang_en_btn.setChecked(False)
        self.lang_en_btn.setStyleSheet(
            f"QPushButton {{ background: {COLORS['surface']}; color: {COLORS['text_dim']};"
            f" border: 1px solid {COLORS['border']}; border-radius: 4px; padding: 4px 12px;"
            f" font-size: 11px; font-weight: 600; }}"
            f"QPushButton:hover {{ border-color: {COLORS['accent']}; color: {COLORS['accent_light']}; }}"
            f"QPushButton:checked {{ background: {COLORS['accent']}; color: #ffffff; border: none; }}"
        )
        self.lang_en_btn.clicked.connect(lambda: self._set_lang("en"))
        nav.addWidget(self.lang_en_btn)

        self.back_btn = QPushButton(_t("nav_back"))
        self.back_btn.setObjectName("secondary")
        self.back_btn.clicked.connect(self._prev_page)
        self.back_btn.setVisible(False)
        nav.addWidget(self.back_btn)

        nav.addStretch()

        self.next_btn = QPushButton(_t("nav_next"))
        self.next_btn.setObjectName("primary")
        self.next_btn.clicked.connect(self._next_or_close)
        nav.addWidget(self.next_btn)

        root.addLayout(nav)

        self.p_finish.launch_installer.connect(self._launch_installer)
        self._update_nav()

    def _set_lang(self, lang):
        global _current_lang
        if _current_lang == lang:
            return
        _current_lang = lang
        self.lang_hu_btn.setChecked(lang == "hu")
        self.lang_en_btn.setChecked(lang == "en")
        if lang == "hu":
            self.lang_hu_btn.setStyleSheet(
                f"QPushButton {{ background: {COLORS['accent']}; color: #ffffff;"
                f" border: none; border-radius: 4px; padding: 4px 12px;"
                f" font-size: 11px; font-weight: 600; }}"
                f"QPushButton:hover {{ background: {COLORS['accent_hover']}; }}"
                f"QPushButton:checked {{ background: {COLORS['accent']}; color: #ffffff; }}"
            )
            self.lang_en_btn.setStyleSheet(
                f"QPushButton {{ background: {COLORS['surface']}; color: {COLORS['text_dim']};"
                f" border: 1px solid {COLORS['border']}; border-radius: 4px; padding: 4px 12px;"
                f" font-size: 11px; font-weight: 600; }}"
                f"QPushButton:hover {{ border-color: {COLORS['accent']}; color: {COLORS['accent_light']}; }}"
                f"QPushButton:checked {{ background: {COLORS['accent']}; color: #ffffff; border: none; }}"
            )
        else:
            self.lang_en_btn.setStyleSheet(
                f"QPushButton {{ background: {COLORS['accent']}; color: #ffffff;"
                f" border: none; border-radius: 4px; padding: 4px 12px;"
                f" font-size: 11px; font-weight: 600; }}"
                f"QPushButton:hover {{ background: {COLORS['accent_hover']}; }}"
                f"QPushButton:checked {{ background: {COLORS['accent']}; color: #ffffff; }}"
            )
            self.lang_hu_btn.setStyleSheet(
                f"QPushButton {{ background: {COLORS['surface']}; color: {COLORS['text_dim']};"
                f" border: 1px solid {COLORS['border']}; border-radius: 4px; padding: 4px 12px;"
                f" font-size: 11px; font-weight: 600; }}"
                f"QPushButton:hover {{ border-color: {COLORS['accent']}; color: {COLORS['accent_light']}; }}"
                f"QPushButton:checked {{ background: {COLORS['accent']}; color: #ffffff; border: none; }}"
            )
        self._retranslate_all()

    def _make_step_bar(self):
        bar = QWidget()
        bar.setFixedHeight(48)
        bar.setStyleSheet(
            f"background: {COLORS['bg2']}; border-bottom: 1px solid {COLORS['border']};"
        )
        lay = QHBoxLayout(bar)
        lay.setContentsMargins(24, 0, 24, 0)

        self.step_labels = []
        self._step_keys = ["step_welcome"]
        if self._show_wifi:
            self._step_keys.append("step_network")
        self._step_keys.append("step_optimize")
        if self._show_hyprland:
            self._step_keys.append("step_hyprland")
        self._step_keys += ["step_credits", "step_finish"]

        for i, key in enumerate(self._step_keys):
            if i > 0:
                dot = QLabel("·····")
                dot.setStyleSheet(f"color: {COLORS['border']}; font-size: 10px; letter-spacing: 2px;")
                lay.addWidget(dot)

            lbl = QLabel(f"{i+1}  {_t(key).upper()}")
            lbl.setStyleSheet(
                f"font-size: 11px; font-weight: 600; letter-spacing: 2px; "
                f"color: {COLORS['text_dim']};"
            )
            lay.addWidget(lbl)
            self.step_labels.append(lbl)

        lay.addStretch()
        return bar

    def _update_nav(self):
        idx = self.stack.currentIndex()
        self.back_btn.setVisible(idx > 0)
        is_last = idx == self.stack.count() - 1
        self.next_btn.setText(_t("finish_close") if is_last else _t("nav_next"))
        self.lang_hu_btn.setVisible(idx == 0)
        self.lang_en_btn.setVisible(idx == 0)
        self._update_steps(idx)

    def _update_steps(self, idx):
        for i, lbl in enumerate(self.step_labels):
            if i < idx:
                lbl.setStyleSheet(
                    f"font-size: 11px; font-weight: 600; letter-spacing: 2px; "
                    f"color: {COLORS['success']};"
                )
            elif i == idx:
                lbl.setStyleSheet(
                    f"font-size: 11px; font-weight: 700; letter-spacing: 2px; "
                    f"color: {COLORS['accent_light']};"
                )
            else:
                lbl.setStyleSheet(
                    f"font-size: 11px; font-weight: 600; letter-spacing: 2px; "
                    f"color: {COLORS['text_dim']};"
                )

    def _retranslate_all(self):
        if _current_lang == "en":
            self.setWindowTitle("RaveOS — Welcome")
        else:
            self.setWindowTitle("RaveOS — Üdvözlünk")
        self.back_btn.setText(_t("nav_back"))
        is_last = self.stack.currentIndex() == self.stack.count() - 1
        self.next_btn.setText(_t("finish_close") if is_last else _t("nav_next"))
        for i, key in enumerate(self._step_keys):
            self.step_labels[i].setText(f"{i+1}  {_t(key).upper()}")
        self.p_welcome.retranslate()
        if self._show_wifi:
            self.p_wifi.retranslate()
        self.p_optimize.retranslate()
        if self._show_hyprland:
            self.p_hyprland.retranslate()
        self.p_credits.retranslate()
        self.p_finish.retranslate()

    def _next_or_close(self):
        idx = self.stack.currentIndex()
        if idx == self.stack.count() - 1:
            QApplication.quit()
        else:
            self._next_page()

    def _next_page(self):
        idx = self.stack.currentIndex()
        if idx < self.stack.count() - 1:
            self.stack.setCurrentIndex(idx + 1)
            self._update_nav()

    def _prev_page(self):
        idx = self.stack.currentIndex()
        if idx > 0:
            self.stack.setCurrentIndex(idx - 1)
            self._update_nav()

    def _launch_installer(self):
        candidates = [
            APP_INSTALLER,
            shutil.which("raveos-app-installer") or "",
        ]
        cmd = None
        for c in candidates:
            if c and Path(c).exists():
                cmd = c
                break

        if not cmd:
            self.p_finish.show_error(_t("finish_install_missing"))
            return

        self.p_finish.install_btn.setEnabled(False)

        log_path = Path.home() / ".config" / "raveos" / "app-installer.log"
        log_path.parent.mkdir(parents=True, exist_ok=True)

        is_hyprland = bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")) or \
            os.environ.get("XDG_CURRENT_DESKTOP", "").lower() == "hyprland"

        if is_hyprland:
            # Hyprland 0.55+ Lua config mod alatt a hagyomanyos
            # "hyprctl dispatch exec <parancs>" szintaxis mar nem mukodik,
            # csak a hl.dsp.exec_cmd("...") Lua hivas - de a regi .conf
            # alapu Hyprland telepiteseken meg a regi szintaxis a jo, ezert
            # eloszor azt probaljuk, es csak hiba eseten valtunk Lua-ra.
            result = subprocess.run(
                ["hyprctl", "dispatch", "exec", cmd],
                capture_output=True, text=True
            )
            if "error" in (result.stdout + result.stderr).lower():
                escaped = cmd.replace('"', '\\"')
                subprocess.run(
                    ["hyprctl", "dispatch", f'hl.dsp.exec_cmd("{escaped}")'],
                    capture_output=True, text=True
                )
            _write_flag()
            self.p_finish.install_btn.setEnabled(True)
            return

        try:
            with open(log_path, "ab") as log:
                proc = subprocess.Popen(
                    [cmd],
                    stdout=log, stderr=log,
                    start_new_session=True
                )
        except OSError as e:
            self.p_finish.show_error(_t("finish_install_err", log=str(e)))
            return

        _write_flag()

        def _check():
            code = proc.poll()
            if code is not None and code != 0:
                self.p_finish.show_error(_t("finish_install_err", log=str(log_path)))
            else:
                self.p_finish.install_btn.setEnabled(True)

        QTimer.singleShot(1200, _check)


# ─── Flag helpers ──────────────────────────────────────────────────────────────

def _flag_exists() -> bool:
    return FLAG_FILE.exists()

def _write_flag():
    FLAG_FILE.parent.mkdir(parents=True, exist_ok=True)
    FLAG_FILE.touch()


# ─── Fast tooltip style ────────────────────────────────────────────────────────

class _FastTooltipStyle(QProxyStyle):
    def styleHint(self, hint, option=None, widget=None, returnData=None):
        if hint == QStyle.StyleHint.SH_ToolTip_WakeUpDelay:
            return 100
        if hint == QStyle.StyleHint.SH_ToolTip_FallAsleepDelay:
            return 5000
        return super().styleHint(hint, option, widget, returnData)


# ─── Entry point ───────────────────────────────────────────────────────────────

def main():
    if _flag_exists() and "--force" not in sys.argv:
        print("RaveOS Welcome: már futott, kihagyva. (--force a felülíráshoz)")
        sys.exit(0)

    app = QApplication(sys.argv)
    app.setStyle(_FastTooltipStyle())
    app.setApplicationName("raveos-welcome-session")
    app.setDesktopFileName("raveos-welcome-session")
    QFontDatabase.addApplicationFont("/usr/share/fonts/ubuntu/Ubuntu-R.ttf")
    QFontDatabase.addApplicationFont("/usr/share/fonts/ubuntu/Ubuntu-B.ttf")

    app_icon = QIcon()
    svg_path = _find_svg()
    if svg_path:
        from PyQt6.QtSvg import QSvgRenderer
        from PyQt6.QtGui import QPixmap, QPainter
        renderer = QSvgRenderer(svg_path)
        for size in (16, 32, 48, 64, 128, 256, 512):
            px = QPixmap(size, size)
            px.fill(Qt.GlobalColor.transparent)
            p = QPainter(px)
            renderer.render(p)
            p.end()
            app_icon.addPixmap(px)
    else:
        app_icon = QIcon.fromTheme("raveos-welcome")
    app.setWindowIcon(app_icon)

    window = RaveOSWelcome()
    window.setWindowIcon(app_icon)
    window.show()

    ret = app.exec()
    _write_flag()
    sys.exit(ret)


if __name__ == "__main__":
    main()
