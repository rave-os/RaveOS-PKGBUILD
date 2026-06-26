#!/usr/bin/env python3
"""
RaveOS App Installer
====================
Egyetlen fájlos, letisztult PyQt6 alkalmazástelepítő a RaveOS-hez.

Tervezési elvek:
  * A welcome app vizuális témája: dark charcoal, muted natural green accent,
    Bebas Neue display font, minimal lekerekítés, semmi neon / cyberpunk.
  * USER-ként fut (NEM root). A rendszerszintű parancsok (pacman) per-művelet
    `pkexec`-en mennek -> Wayland/Hyprland-helyes (a root GUI Waylanden gáz).
  * Háttér QThread a telepítéshez -> a GUI nem fagy be / nem zár be magától.
  * GUI + CLI ugyanabból a fájlból (argparse).
  * Az alkalmazás-katalógus külön `app-list.json`-ban (te frissíted GitHubról).

Backendek (app "type" mezője):
  pacman   -> pkexec pacman -S ...        (id = csomagnév)
  aur      -> yay -S ...      user-ként   (id = AUR csomagnév)
  flatpak  -> flatpak install --user ...  (id = flatpak app id, flathubról)
  script   -> bash -c <id>                (id = a futtatandó parancs)

Függőségek: python-pyqt6, polkit (pkexec), flatpak, opcionálisan yay.
Hyprlandon kell egy polkit agent is (pl. hyprpolkit-agent vagy polkit-gnome).
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
#  Konstansok / útvonalak
# ─────────────────────────────────────────────────────────────────────────────

APP_NAME = "RaveOS App Installer"
APP_ID = "raveos-app-installer"  # Wayland app_id (Hyprland window rule-okhoz)
APP_VERSION = "2.0"

# app-list.json keresési sorrend: a script mellett -> /usr/share -> ~/.config
_SCRIPT_DIR = Path(__file__).resolve().parent
APP_LIST_CANDIDATES = [
    _SCRIPT_DIR / "app-list.json",
    Path("/usr/share/raveos/app-list.json"),
    Path.home() / ".config" / "raveos" / "app-list.json",
]

CATEGORY_ALL = "All"


# ─────────────────────────────────────────────────────────────────────────────
#  Téma (a welcome app stílusa)
# ─────────────────────────────────────────────────────────────────────────────

C = {
    "bg":         "#232427",
    "header":     "#1b1c1e",
    "surface":    "#2b2c30",
    "surface_hi": "#34353a",
    "border":     "#3a3b40",
    "border_hi":  "#4a4b52",
    "accent":     "#62a052",   # muted natural green
    "accent_hi":  "#72b062",
    "accent_dim": "#4d8043",
    "text":       "#eaeaea",
    "text_dim":   "#9298a0",
    "text_mut":   "#6c727a",
    "danger":     "#b5544a",
    "danger_hi":  "#c56458",
}

# Per-type kis badge színek (visszafogottak)
TYPE_LABEL = {
    "pacman":  "pacman",
    "aur":     "AUR",
    "flatpak": "flatpak",
    "script":  "script",
}


def build_qss() -> str:
    return f"""
    QWidget {{
        background: {C['bg']};
        color: {C['text']};
        font-size: 13px;
    }}
    QToolTip {{
        background: {C['surface']};
        color: {C['text']};
        border: 1px solid {C['border']};
        padding: 4px;
    }}

    /* Fejléc sáv */
    QFrame#Header {{
        background: {C['header']};
        border: none;
        border-bottom: 1px solid {C['border']};
    }}

    /* Kártya-szerű felületek */
    QFrame#Card, QScrollArea, QFrame#ListHost {{
        background: {C['bg']};
        border: none;
    }}

    /* Label-ek átlátszó háttere (ne nyomja rá a QWidget bg-t) */
    QLabel {{ background: transparent; }}

    /* App sorok */
    QFrame#Row {{
        background: {C['surface']};
        border: 1px solid {C['border']};
        border-radius: 4px;
    }}
    QFrame#Row:hover {{
        background: {C['surface_hi']};
        border: 1px solid {C['border_hi']};
    }}

    /* Kereső / combo */
    QLineEdit, QComboBox {{
        background: {C['surface']};
        border: 1px solid {C['border']};
        border-radius: 4px;
        padding: 7px 10px;
        color: {C['text']};
        selection-background-color: {C['accent_dim']};
    }}
    QLineEdit:focus, QComboBox:focus {{
        border: 1px solid {C['accent']};
    }}
    QComboBox::drop-down {{ border: none; width: 22px; }}
    QComboBox QAbstractItemView {{
        background: {C['surface']};
        border: 1px solid {C['border']};
        selection-background-color: {C['accent_dim']};
        outline: none;
    }}

    /* Szegmentált fülek (All / Installed) */
    QPushButton#Tab {{
        background: transparent;
        border: 1px solid {C['border']};
        border-radius: 4px;
        padding: 6px 18px;
        color: {C['text_dim']};
    }}
    QPushButton#Tab:hover {{ color: {C['text']}; border-color: {C['border_hi']}; }}
    QPushButton#Tab:checked {{
        background: {C['surface_hi']};
        color: {C['text']};
        border-color: {C['border_hi']};
    }}

    /* Gombok */
    QPushButton {{
        background: {C['surface']};
        border: 1px solid {C['border']};
        border-radius: 4px;
        padding: 9px 18px;
        color: {C['text']};
    }}
    QPushButton:hover {{ background: {C['surface_hi']}; border-color: {C['border_hi']}; }}
    QPushButton:disabled {{ color: {C['text_mut']}; border-color: {C['border']}; }}

    QPushButton#Primary {{
        background: {C['accent']};
        border: 1px solid {C['accent']};
        color: #15240f;
        font-weight: 600;
    }}
    QPushButton#Primary:hover {{ background: {C['accent_hi']}; border-color: {C['accent_hi']}; }}
    QPushButton#Primary:disabled {{ background: {C['accent_dim']}; border-color: {C['accent_dim']}; color: #2a3a22; }}

    QPushButton#Danger {{ border-color: {C['danger']}; color: {C['danger_hi']}; }}
    QPushButton#Danger:hover {{ background: {C['danger']}; color: {C['text']}; }}
    QPushButton#Danger:disabled {{ color: {C['text_mut']}; border-color: {C['border']}; }}

    /* Checkbox: zöld kitöltés bekapcsoláskor (asset nélkül) */
    QCheckBox {{ spacing: 0; }}
    QCheckBox::indicator {{
        width: 17px; height: 17px;
        border: 1px solid {C['border_hi']};
        border-radius: 3px;
        background: transparent;
    }}
    QCheckBox::indicator:hover {{ border-color: {C['accent']}; }}
    QCheckBox::indicator:checked {{
        background: {C['accent']};
        border: 1px solid {C['accent']};
    }}

    /* Log */
    QPlainTextEdit#Log {{
        background: {C['header']};
        border: 1px solid {C['border']};
        border-radius: 4px;
        color: {C['text_dim']};
        font-family: "JetBrains Mono", "DejaVu Sans Mono", monospace;
        font-size: 12px;
        padding: 6px;
    }}

    /* Progress */
    QProgressBar {{
        background: {C['surface']};
        border: 1px solid {C['border']};
        border-radius: 4px;
        text-align: center;
        color: {C['text']};
        height: 22px;
    }}
    QProgressBar::chunk {{ background: {C['accent']}; border-radius: 3px; }}

    /* Scrollbar */
    QScrollBar:vertical {{ background: transparent; width: 10px; margin: 0; }}
    QScrollBar::handle:vertical {{
        background: {C['border_hi']}; border-radius: 5px; min-height: 28px;
    }}
    QScrollBar::handle:vertical:hover {{ background: {C['text_mut']}; }}
    QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; }}
    QScrollBar::add-page, QScrollBar::sub-page {{ background: transparent; }}
    """


# ─────────────────────────────────────────────────────────────────────────────
#  Adat: katalógus betöltés + telepítettség detektálás
# ─────────────────────────────────────────────────────────────────────────────

def load_catalog() -> list:
    """app-list.json beolvasása az első létező útvonalról."""
    for path in APP_LIST_CANDIDATES:
        if path.is_file():
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, OSError) as exc:
                raise RuntimeError(f"Hibás app-list.json ({path}): {exc}")
            apps = data.get("apps", data) if isinstance(data, dict) else data
            cleaned = []
            for a in apps:
                if not isinstance(a, dict) or "name" not in a or "id" not in a:
                    continue
                if a.get("type") == "message":
                    continue
                a.setdefault("type", "pacman")
                a.setdefault("category", "Other")
                a.setdefault("description", a.get("desc", ""))
                cleaned.append(a)
            cleaned.sort(key=lambda x: x["name"].lower())
            return cleaned
    raise RuntimeError(
        "Nem található app-list.json. Keresett helyek:\n  "
        + "\n  ".join(str(p) for p in APP_LIST_CANDIDATES)
    )


def _query_set(cmd) -> set:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
        return {l.strip() for l in out.stdout.splitlines() if l.strip()}
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        return set()


def installed_index() -> dict:
    """Egyetlen lekérdezés backendenként -> gyors membership check."""
    pac = _query_set(["pacman", "-Qq"])
    flat = _query_set(["flatpak", "list", "--app", "--columns=application"])
    return {"pacman": pac, "flatpak": flat}


def is_installed(app: dict, idx: dict) -> bool:
    t = app.get("type", "pacman")

    if t in ("pacman", "aur"):
        packages = app.get("packages") or [app["id"]]
        return all(p in idx["pacman"] for p in packages)

    if t == "flatpak-user":
        fid = app.get("flatpak_id", "")
        return bool(fid) and fid in idx["flatpak"]

    if t == "script":
        check_pkgs = app.get("check_packages")
        if check_pkgs:
            return all(p in idx["pacman"] for p in check_pkgs)
        chk = app.get("check")
        if not chk:
            return False
        if chk.startswith("/") and Path(chk).exists():
            return True
        try:
            return subprocess.run(["bash", "-c", chk],
                                  capture_output=True, timeout=15).returncode == 0
        except (subprocess.SubprocessError, OSError):
            return False

    return False


# ─────────────────────────────────────────────────────────────────────────────
#  Parancs-építés (telepítés / eltávolítás), batch-elve backendenként
# ─────────────────────────────────────────────────────────────────────────────

def _root_prefix(gui: bool) -> list:
    """GUI -> sudo -S (jelszó stdin-ről), terminál -> sudo, ha már root -> semmi."""
    if os.geteuid() == 0:
        return []
    return ["sudo", "-S"]


def plan_commands(apps: list, install: bool, gui: bool) -> list:
    """
    Visszaad egy listát: [(címke, parancs_lista), ...].
    Backendenként batch-eli a csomagokat -> kevesebb pkexec prompt.
    """
    import shlex
    pac, aur, flat, scripts, post = [], [], [], [], []

    for a in apps:
        t = a.get("type", "pacman")
        if t == "pacman":
            pkgs = a.get("packages") or [a["id"]]
            pac.extend(pkgs)
            if install:
                for cmd_str in a.get("post_install", []):
                    post.append((f"post: {a['name']}", shlex.split(cmd_str)))
        elif t == "aur":
            pkgs = a.get("packages") or [a["id"]]
            aur.extend(pkgs)
        elif t == "flatpak-user":
            fid = a.get("flatpak_id")
            if fid:
                flat.append((fid, a.get("post_install", []), a["name"]))
        elif t == "script":
            if install or a.get("removable", True):
                scripts.append(a)

    rp = _root_prefix(gui)
    steps = []

    if pac:
        if install:
            steps.append((f"pacman: {', '.join(pac)}",
                          rp + ["pacman", "-S", "--needed", "--noconfirm", *pac]))
        else:
            steps.append((f"pacman -R: {', '.join(pac)}",
                          rp + ["pacman", "-Rns", "--noconfirm", *pac]))

    if aur:
        if install:
            steps.append((f"AUR: {', '.join(aur)}",
                          ["yay", "-S", "--needed", "--noconfirm", *aur]))
        else:
            steps.append((f"AUR -R: {', '.join(aur)}",
                          ["yay", "-Rns", "--noconfirm", *aur]))

    if flat and install:
        steps.append(("flathub remote", [
            "flatpak", "remote-add", "--if-not-exists", "--user",
            "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo"
        ]))

    for fid, post_cmds, name in flat:
        if install:
            steps.append((f"flatpak: {fid}",
                          ["flatpak", "install", "--user", "--noninteractive",
                           "--or-update", "flathub", fid]))
            for cmd_str in post_cmds:
                steps.append((f"post: {name}", shlex.split(cmd_str)))
        else:
            steps.append((f"flatpak uninstall: {fid}",
                          ["flatpak", "uninstall", "--user", "-y", fid]))

    # Script env: a szkript tudja ki a tényleges user (sudo után root fut)
    _caller = os.environ.get("USER") or os.environ.get("LOGNAME") or ""
    _caller_home = os.path.expanduser("~")
    _caller_uid = str(os.getuid())
    _xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{_caller_uid}")
    _config_dir = str(_SCRIPT_DIR / "data" / "configs")
    _script_env = [
        "env",
        f"INSTALL_USER={_caller}",
        f"INSTALL_HOME={_caller_home}",
        f"TARGET_UID={_caller_uid}",
        f"TARGET_XDG_RUNTIME_DIR={_xdg_runtime}",
        f"RAVEOS_CONFIG_PACKAGE_DIR={_config_dir}",
    ]

    for a in scripts:
        script_name = a.get("script", "")
        script_path = _SCRIPT_DIR / "data" / "actions" / script_name
        if script_name and script_path.exists():
            action = "install" if install else "remove"
            steps.append((f"script: {a['name']}",
                          rp + _script_env + ["bash", str(script_path), action]))

    steps.extend(post)
    return steps


def stream_command(label: str, cmd: list, emit, password: str = "") -> bool:
    """Parancs futtatása élő kimenettel. emit(str) -> log sor. True ha sikeres."""
    emit(f"$ {' '.join(cmd)}")
    try:
        needs_pw = len(cmd) >= 2 and cmd[0] == "sudo" and cmd[1] == "-S"
        stdin_pipe = subprocess.PIPE if needs_pw else None
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, stdin=stdin_pipe,
                                text=True, bufsize=1)
        if needs_pw and password:
            proc.stdin.write(password + "\n")
            proc.stdin.flush()
            proc.stdin.close()
    except (FileNotFoundError, OSError) as exc:
        emit(f"[HIBA] nem indítható: {exc}")
        return False
    for line in proc.stdout:
        emit(line.rstrip("\n"))
    proc.wait()
    ok = proc.returncode == 0
    emit(f"[{'OK' if ok else 'HIBA(' + str(proc.returncode) + ')'}] {label}")
    return ok


# ─────────────────────────────────────────────────────────────────────────────
#  GUI rész (csak ha van PyQt6 / display)
# ─────────────────────────────────────────────────────────────────────────────

BACKUP_LIST_CANDIDATES = [
    _SCRIPT_DIR / "data/backup/backup-paths.json",
    Path("/usr/share/raveos/backup-paths.json"),
]


def load_backup_catalog() -> list:
    for path in BACKUP_LIST_CANDIDATES:
        if path.is_file():
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                return data.get("groups", [])
            except (json.JSONDecodeError, OSError):
                return []
    return []


def run_gui() -> int:
    from PyQt6.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
        QLabel, QPushButton, QLineEdit, QComboBox, QScrollArea, QFrame,
        QCheckBox, QPlainTextEdit, QProgressBar, QButtonGroup, QSizePolicy,
        QMessageBox, QFileDialog, QDialog,
    )
    from PyQt6.QtCore import Qt, QThread, pyqtSignal
    from PyQt6.QtGui import QFont, QFontDatabase

    # ── display font helper (Bebas Neue, fallbackkel) ────────────────────────
    def display_font(size: int, weight=QFont.Weight.Normal) -> QFont:
        for fam in ("Bebas Neue", "Oswald", "Anton"):
            if fam in QFontDatabase.families():
                f = QFont(fam, size)
                f.setLetterSpacing(QFont.SpacingType.PercentageSpacing, 104)
                return f
        f = QFont()  # fallback: rendszer sans, bold + tracking
        f.setPointSize(size)
        f.setBold(True)
        f.setLetterSpacing(QFont.SpacingType.PercentageSpacing, 102)
        return f

    # ── háttér worker ────────────────────────────────────────────────────────
    class Worker(QThread):
        log = pyqtSignal(str)
        progress = pyqtSignal(int)          # 0..100
        done = pyqtSignal(int, int)         # ok_steps, total_steps

        def __init__(self, steps, password: str = ""):
            super().__init__()
            self.steps = steps
            self.password = password

        def run(self):
            total = len(self.steps)
            ok = 0
            for i, (label, cmd) in enumerate(self.steps):
                self.log.emit("")
                self.log.emit(f"── {label} ──")
                if stream_command(label, cmd, self.log.emit, self.password):
                    ok += 1
                self.progress.emit(int((i + 1) / total * 100))
            self.done.emit(ok, total)

    # ── egy app sor widget ───────────────────────────────────────────────────
    class Row(QFrame):
        def __init__(self, app, installed):
            super().__init__()
            self.app = app
            self.installed = installed
            self.setObjectName("Row")
            lay = QHBoxLayout(self)
            lay.setContentsMargins(12, 9, 12, 9)
            lay.setSpacing(10)

            self.cb = QCheckBox()
            lay.addWidget(self.cb)

            mid = QVBoxLayout()
            mid.setSpacing(2)
            top = QLabel(app["name"])
            top.setStyleSheet(f"font-weight:600; font-size:14px; color:{C['text']};")
            sub = QLabel(f"{app['category']}  ·  {TYPE_LABEL.get(app['type'], app['type'])}"
                         + (f"  ·  {app['description']}" if app["description"] else ""))
            sub.setStyleSheet(f"color:{C['text_dim']}; font-size:12px;")
            mid.addWidget(top)
            mid.addWidget(sub)
            lay.addLayout(mid, 1)

            status = QLabel("telepítve" if installed else "nincs telepítve")
            status.setStyleSheet(
                f"color:{C['accent_hi'] if installed else C['text_mut']}; font-size:12px;")
            lay.addWidget(status)

            # sorra kattintás is váltja a checkboxot
            self.setCursor(Qt.CursorShape.PointingHandCursor)

        def mousePressEvent(self, e):
            if e.button() == Qt.MouseButton.LeftButton:
                self.cb.toggle()
            super().mousePressEvent(e)

    # ── backup worker ────────────────────────────────────────────────────────
    class BackupWorker(QThread):
        log = pyqtSignal(str)
        progress = pyqtSignal(int)
        done = pyqtSignal(bool, str)

        def __init__(self, paths, dest, restore=False):
            super().__init__()
            self.paths = paths      # [(label, abs_path), ...]
            self.dest = dest        # str: .tar.gz útvonal
            self.restore = restore

        def run(self):
            import tarfile
            total = len(self.paths)
            if not self.restore:
                try:
                    with tarfile.open(self.dest, "w:gz") as tf:
                        for i, (label, p) in enumerate(self.paths):
                            self.log.emit(f"+ {label}  ({p})")
                            if Path(p).exists():
                                tf.add(p, arcname=Path(p).name)
                            else:
                                self.log.emit(f"  [kihagyva, nem létezik]")
                            self.progress.emit(int((i + 1) / total * 100))
                    self.done.emit(True, "Mentés kész.")
                except Exception as exc:
                    self.done.emit(False, str(exc))
            else:
                try:
                    import tarfile
                    with tarfile.open(self.dest, "r:gz") as tf:
                        total_members = len(tf.getmembers())
                        for i, member in enumerate(tf.getmembers()):
                            self.log.emit(f"< {member.name}")
                            tf.extract(member, path=str(Path(self.paths[0][1]).parent),
                                       filter="data")
                            self.progress.emit(int((i + 1) / total_members * 100))
                    self.done.emit(True, "Visszaállítás kész.")
                except Exception as exc:
                    self.done.emit(False, str(exc))

    # ── fő ablak ─────────────────────────────────────────────────────────────
    class Main(QMainWindow):
        def __init__(self, catalog):
            super().__init__()
            from PyQt6.QtWidgets import QStackedWidget
            self.catalog = catalog
            self.idx = installed_index()
            self.rows = []
            self.worker = None
            self.backup_worker = None
            self.backup_checkboxes = {}   # item_id -> (QCheckBox, abs_path, label)
            self._sudo_pw = ""
            self._sudo_pw_ts = 0.0        # timestamp: mikor lett megjegyezve

            self.setWindowTitle(APP_NAME)
            self.resize(1060, 820)

            root = QWidget()
            self.setCentralWidget(root)
            outer = QVBoxLayout(root)
            outer.setContentsMargins(0, 0, 0, 0)
            outer.setSpacing(0)

            # ── Header ───────────────────────────────────────────────────────
            header = QFrame()
            header.setObjectName("Header")
            hl = QHBoxLayout(header)
            hl.setContentsMargins(20, 14, 20, 14)
            wm = QHBoxLayout()
            wm.setSpacing(0)
            rave = QLabel("RAVE")
            rave.setFont(display_font(26))
            rave.setStyleSheet(f"color:{C['text']};")
            os_ = QLabel("OS")
            os_.setFont(display_font(26))
            os_.setStyleSheet(f"color:{C['accent']};")
            wm.addWidget(rave)
            wm.addWidget(os_)
            self.header_sep = QLabel("  ·  APP INSTALLER")
            self.header_sep.setFont(display_font(15))
            self.header_sep.setStyleSheet(f"color:{C['text_dim']};")
            wm.addWidget(self.header_sep)
            hl.addLayout(wm)
            hl.addStretch(1)
            self.btn_nav = QPushButton("Backup / Restore")
            self.btn_nav.clicked.connect(self._go_backup)
            hl.addWidget(self.btn_nav)
            hl.addSpacing(12)
            ver = QLabel(f"v{APP_VERSION}")
            ver.setStyleSheet(f"color:{C['text_mut']};")
            hl.addWidget(ver)
            outer.addWidget(header)

            # ── Stack ─────────────────────────────────────────────────────────
            self.stack = QStackedWidget()
            outer.addWidget(self.stack, 1)

            # ── Oldal 0: Apps ─────────────────────────────────────────────────
            apps_page = QWidget()
            bl = QVBoxLayout(apps_page)
            bl.setContentsMargins(20, 16, 20, 16)
            bl.setSpacing(12)

            frow = QHBoxLayout()
            frow.setSpacing(8)
            self.tab_all = QPushButton("All")
            self.tab_inst = QPushButton("Installed")
            for t in (self.tab_all, self.tab_inst):
                t.setObjectName("Tab")
                t.setCheckable(True)
            self.tab_all.setChecked(True)
            grp = QButtonGroup(self)
            grp.setExclusive(True)
            grp.addButton(self.tab_all)
            grp.addButton(self.tab_inst)
            self.tab_all.clicked.connect(self._refresh_and_filter)
            self.tab_inst.clicked.connect(self._refresh_and_filter)
            frow.addWidget(self.tab_all)
            frow.addWidget(self.tab_inst)
            frow.addSpacing(8)
            self.search = QLineEdit()
            self.search.setPlaceholderText("Keresés…")
            self.search.textChanged.connect(self.apply_filter)
            frow.addWidget(self.search, 1)
            self.cat = QComboBox()
            cats = [CATEGORY_ALL] + sorted({a["category"] for a in catalog})
            self.cat.addItems(cats)
            self.cat.currentTextChanged.connect(self.apply_filter)
            frow.addWidget(self.cat)
            bl.addLayout(frow)

            self.scroll = QScrollArea()
            self.scroll.setWidgetResizable(True)
            self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            host = QFrame()
            host.setObjectName("ListHost")
            self.list_lay = QVBoxLayout(host)
            self.list_lay.setContentsMargins(0, 0, 6, 0)
            self.list_lay.setSpacing(7)
            self.list_lay.addStretch(1)
            self.scroll.setWidget(host)
            bl.addWidget(self.scroll, 1)

            self.log = QPlainTextEdit()
            self.log.setObjectName("Log")
            self.log.setReadOnly(True)
            self.log.setFixedHeight(120)
            self.log.hide()
            bl.addWidget(self.log)

            arow = QHBoxLayout()
            arow.setSpacing(8)
            self.btn_install = QPushButton("Telepítés")
            self.btn_install.setObjectName("Primary")
            self.btn_install.clicked.connect(lambda: self.run_action(True))
            self.btn_remove = QPushButton("Eltávolítás")
            self.btn_remove.setObjectName("Danger")
            self.btn_remove.clicked.connect(lambda: self.run_action(False))
            self.btn_remove.hide()
            self.bar = QProgressBar()
            self.bar.setValue(0)
            arow.addWidget(self.btn_install)
            arow.addWidget(self.btn_remove)
            arow.addWidget(self.bar, 1)
            bl.addLayout(arow)

            self.stack.addWidget(apps_page)

            # ── Oldal 1: Backup / Restore ─────────────────────────────────────
            bk_page = QWidget()
            bbl = QVBoxLayout(bk_page)
            bbl.setContentsMargins(20, 16, 20, 16)
            bbl.setSpacing(12)

            bk_scroll = QScrollArea()
            bk_scroll.setWidgetResizable(True)
            bk_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            bk_host = QWidget()
            bk_vl = QVBoxLayout(bk_host)
            bk_vl.setContentsMargins(0, 0, 6, 0)
            bk_vl.setSpacing(14)

            home = str(Path.home())
            for bgrp in load_backup_catalog():
                gl = QLabel(bgrp.get("label", bgrp["id"]))
                gl.setStyleSheet(f"font-weight:600; font-size:13px; color:{C['accent']}; background:transparent;")
                bk_vl.addWidget(gl)
                desc = bgrp.get("description", "")
                if desc:
                    dl = QLabel(desc)
                    dl.setStyleSheet(f"color:{C['text_dim']}; font-size:11px; background:transparent;")
                    dl.setWordWrap(True)
                    bk_vl.addWidget(dl)
                for item in bgrp.get("items", []):
                    brow = QFrame()
                    brow.setObjectName("Row")
                    rl = QHBoxLayout(brow)
                    rl.setContentsMargins(12, 7, 12, 7)
                    rl.setSpacing(10)
                    cb = QCheckBox()
                    cb.setChecked(item.get("default_selected", False))
                    abs_path = str(Path(home) / item["path"]) if item.get("scope","home") == "home" else item["path"]
                    self.backup_checkboxes[item["id"]] = (cb, abs_path, item.get("label", item["id"]))
                    rl.addWidget(cb)
                    mid = QVBoxLayout()
                    mid.setSpacing(1)
                    tl = QLabel(item.get("label", item["id"]))
                    tl.setStyleSheet(f"font-weight:600; font-size:13px; color:{C['text']}; background:transparent;")
                    sl = QLabel(abs_path)
                    sl.setStyleSheet(f"color:{C['text_dim']}; font-size:11px; background:transparent;")
                    mid.addWidget(tl)
                    mid.addWidget(sl)
                    if item.get("note"):
                        nl = QLabel(item["note"])
                        nl.setStyleSheet(f"color:{C['danger_hi']}; font-size:11px; background:transparent;")
                        mid.addWidget(nl)
                    rl.addLayout(mid, 1)
                    if item.get("size_hint"):
                        hl2 = QLabel(item["size_hint"])
                        hl2.setStyleSheet(f"color:{C['text_mut']}; font-size:11px; background:transparent;")
                        rl.addWidget(hl2)
                    bk_vl.addWidget(brow)

            bk_vl.addStretch(1)
            bk_scroll.setWidget(bk_host)
            bbl.addWidget(bk_scroll, 1)

            dest_row = QHBoxLayout()
            dest_row.setSpacing(8)
            self.dest_edit = QLineEdit()
            self.dest_edit.setPlaceholderText("Backup fájl útvonala (.tar.gz)…")
            self.dest_edit.setText(str(Path.home() / "raveos-backup.tar.gz"))
            browse_btn = QPushButton("Tallóz")
            browse_btn.clicked.connect(self._bk_browse)
            dest_row.addWidget(self.dest_edit, 1)
            dest_row.addWidget(browse_btn)
            bbl.addLayout(dest_row)

            self.bk_log = QPlainTextEdit()
            self.bk_log.setObjectName("Log")
            self.bk_log.setReadOnly(True)
            self.bk_log.setFixedHeight(120)
            self.bk_log.hide()
            bbl.addWidget(self.bk_log)

            bk_arow = QHBoxLayout()
            bk_arow.setSpacing(8)
            self.btn_bk_save = QPushButton("Mentés")
            self.btn_bk_save.setObjectName("Primary")
            self.btn_bk_save.clicked.connect(self._do_backup)
            self.btn_bk_restore = QPushButton("Visszaállítás")
            self.btn_bk_restore.setObjectName("Danger")
            self.btn_bk_restore.clicked.connect(self._do_restore)
            self.bk_bar = QProgressBar()
            self.bk_bar.setValue(0)
            bk_arow.addWidget(self.btn_bk_save)
            bk_arow.addWidget(self.btn_bk_restore)
            bk_arow.addWidget(self.bk_bar, 1)
            bbl.addLayout(bk_arow)

            self.stack.addWidget(bk_page)

            self.build_rows()
            self.apply_filter()

        # ── frissítés ─────────────────────────────────────────────────────────
        def _refresh_and_filter(self):
            self.idx = installed_index()
            self.build_rows()
            self.apply_filter()

        # ── navigáció ─────────────────────────────────────────────────────────
        def _go_backup(self):
            self.stack.setCurrentIndex(1)
            self.header_sep.setText("  ·  BACKUP / RESTORE")
            self.btn_nav.setText("← Vissza")
            self.btn_nav.clicked.disconnect()
            self.btn_nav.clicked.connect(self._go_apps)

        def _go_apps(self):
            self.stack.setCurrentIndex(0)
            self.header_sep.setText("  ·  APP INSTALLER")
            self.btn_nav.setText("Backup / Restore")
            self.btn_nav.clicked.disconnect()
            self.btn_nav.clicked.connect(self._go_backup)

        # ── lista építés ──────────────────────────────────────────────────────
        def build_rows(self):
            for r in self.rows:
                r.setParent(None)
            self.rows.clear()
            for app in self.catalog:
                inst = is_installed(app, self.idx)
                row = Row(app, inst)
                self.list_lay.insertWidget(self.list_lay.count() - 1, row)
                self.rows.append(row)

        def apply_filter(self):
            q = self.search.text().strip().lower()
            cat = self.cat.currentText()
            only_inst = self.tab_inst.isChecked()
            self.btn_remove.setVisible(only_inst)
            self.btn_install.setVisible(not only_inst)
            for r in self.rows:
                show = True
                if only_inst and not r.installed:
                    show = False
                if not only_inst and r.installed:
                    show = False
                if cat != CATEGORY_ALL and r.app["category"] != cat:
                    show = False
                if q and q not in r.app["name"].lower() \
                        and q not in r.app["description"].lower():
                    show = False
                r.setVisible(show)

        def selected(self):
            return [r.app for r in self.rows if r.cb.isChecked() and r.isVisible()]

        # ── app akció ─────────────────────────────────────────────────────────
        def _ask_password(self) -> str:
            """Jelszó dialog — egyszer fut az akció elején. Üres string = megszakítva."""
            err_msg = ""
            while True:
                dlg = QDialog(self)
                dlg.setWindowTitle("Hitelesítés szükséges")
                dlg.setFixedWidth(360)
                lay = QVBoxLayout(dlg)
                lay.setSpacing(10)
                lay.setContentsMargins(20, 16, 20, 16)

                lbl = QLabel(err_msg if err_msg else "Sudo jelszó:")
                lbl.setStyleSheet(
                    f"color: {'#e06c6c' if err_msg else C['text_dim']}; font-size: 13px;")
                lbl.setWordWrap(True)
                lay.addWidget(lbl)

                pw_edit = QLineEdit()
                pw_edit.setEchoMode(QLineEdit.EchoMode.Password)
                pw_edit.setPlaceholderText("Jelszó…")
                pw_edit.setStyleSheet(
                    f"background: {C['surface']}; color: {C['text']};"
                    "border: 1px solid #444; border-radius: 4px;"
                    "padding: 6px 10px; font-size: 13px;")
                lay.addWidget(pw_edit)

                btn_row = QHBoxLayout()
                btn_ok = QPushButton("OK")
                btn_ok.setDefault(True)
                btn_cancel = QPushButton("Mégse")
                btn_ok.setFixedHeight(32)
                btn_cancel.setFixedHeight(32)
                btn_ok.setStyleSheet(
                    f"background: {C['accent']}; color: {C['text']};"
                    "border-radius: 4px; font-size: 13px;")
                btn_cancel.setStyleSheet(
                    f"background: {C['surface']}; color: {C['text_dim']};"
                    "border-radius: 4px; font-size: 13px;")
                btn_ok.clicked.connect(dlg.accept)
                btn_cancel.clicked.connect(dlg.reject)
                pw_edit.returnPressed.connect(dlg.accept)
                btn_row.addStretch()
                btn_row.addWidget(btn_cancel)
                btn_row.addWidget(btn_ok)
                lay.addLayout(btn_row)

                if not dlg.exec():
                    return ""

                pw = pw_edit.text()
                if not pw:
                    err_msg = "A jelszó nem lehet üres."
                    continue

                try:
                    chk = subprocess.run(
                        ["sudo", "-S", "true"],
                        input=pw + "\n",
                        capture_output=True,
                        text=True,
                        timeout=8,
                    )
                    if chk.returncode == 0:
                        return pw
                    err_msg = "Hibás jelszó, próbáld újra."
                except Exception:
                    # Ha az ellenőrzés nem sikerül, elfogadjuk és hagyjuk a parancsot hibázni
                    return pw

        def run_action(self, install: bool):
            apps = self.selected()
            if not apps:
                self.log.appendPlainText("Nincs kijelölve semmi.")
                return
            if self.worker and self.worker.isRunning():
                return
            steps = plan_commands(apps, install, gui=True)
            if not steps:
                self.log.appendPlainText("Nincs végrehajtható művelet.")
                return

            # Jelszó — 5 percen belül megjegyzett jelszót újra felhasználjuk
            import time
            if os.geteuid() != 0:
                if self._sudo_pw and (time.time() - self._sudo_pw_ts) < 300:
                    password = self._sudo_pw
                else:
                    password = self._ask_password()
                    if not password:
                        return
                    self._sudo_pw = password
                    self._sudo_pw_ts = time.time()
            else:
                password = ""

            self.set_busy(True)
            self.bar.setValue(0)
            self.log.clear()
            self.log.show()
            self.log.appendPlainText(("Telepítés" if install else "Eltávolítás")
                                     + f" indul ({len(apps)} app)…")
            self.worker = Worker(steps, password)
            self.worker.log.connect(self.log.appendPlainText)
            self.worker.progress.connect(self.bar.setValue)
            self.worker.done.connect(self.on_done)
            self.worker.start()

        def on_done(self, ok, total):
            self.bar.setValue(100)
            self.log.appendPlainText(f"\nKész: {ok}/{total} lépés sikeres.")
            self.idx = installed_index()
            keep_scroll = self.scroll.verticalScrollBar().value()
            self.build_rows()
            self.apply_filter()
            self.scroll.verticalScrollBar().setValue(keep_scroll)
            self.set_busy(False)

        def set_busy(self, busy: bool):
            self.btn_install.setEnabled(not busy)
            self.btn_remove.setEnabled(not busy)
            self.search.setEnabled(not busy)
            self.cat.setEnabled(not busy)

        # ── backup akciók ─────────────────────────────────────────────────────
        def _bk_browse(self):
            path, _ = QFileDialog.getSaveFileName(
                self, "Backup fájl", str(Path.home()), "Tar archive (*.tar.gz)")
            if path:
                if not path.endswith(".tar.gz"):
                    path += ".tar.gz"
                self.dest_edit.setText(path)

        def _bk_selected(self):
            return [(label, abs_path)
                    for cb, abs_path, label in self.backup_checkboxes.values()
                    if cb.isChecked()]

        def _bk_set_busy(self, busy):
            self.btn_bk_save.setEnabled(not busy)
            self.btn_bk_restore.setEnabled(not busy)
            self.dest_edit.setEnabled(not busy)

        def _do_backup(self):
            paths = self._bk_selected()
            if not paths:
                self.bk_log.appendPlainText("Nincs kijelölve semmi.")
                return
            dest = self.dest_edit.text().strip()
            if not dest:
                self.bk_log.appendPlainText("Add meg a célfájlt.")
                return
            self.bk_log.clear()
            self.bk_log.show()
            self.bk_log.appendPlainText(f"Mentés indul -> {dest}")
            self.bk_bar.setValue(0)
            self._bk_set_busy(True)
            self.backup_worker = BackupWorker(paths, dest, restore=False)
            self.backup_worker.log.connect(self.bk_log.appendPlainText)
            self.backup_worker.progress.connect(self.bk_bar.setValue)
            self.backup_worker.done.connect(self._bk_done)
            self.backup_worker.start()

        def _do_restore(self):
            dest = self.dest_edit.text().strip()
            if not dest or not Path(dest).is_file():
                self.bk_log.appendPlainText("Nem létező vagy érvénytelen backup fájl.")
                return
            paths = self._bk_selected()
            if not paths:
                self.bk_log.appendPlainText("Jelölj ki legalább egy elemet.")
                return
            self.bk_log.clear()
            self.bk_log.show()
            self.bk_log.appendPlainText(f"Visszaállítás indul <- {dest}")
            self.bk_bar.setValue(0)
            self._bk_set_busy(True)
            self.backup_worker = BackupWorker(paths, dest, restore=True)
            self.backup_worker.log.connect(self.bk_log.appendPlainText)
            self.backup_worker.progress.connect(self.bk_bar.setValue)
            self.backup_worker.done.connect(self._bk_done)
            self.backup_worker.start()

        def _bk_done(self, ok, msg):
            self.bk_bar.setValue(100 if ok else 0)
            self.bk_log.appendPlainText(f"\n{'OK' if ok else 'HIBA'}: {msg}")
            self._bk_set_busy(False)

    # ── alkalmazás bootstrap ─────────────────────────────────────────────────
    if shutil.which("hyprctl"):
        subprocess.run(
            ["hyprctl", "keyword", "windowrulev2",
             f"opacity 1.0 1.0, class:^({APP_ID})$"],
            capture_output=True,
        )

    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setApplicationDisplayName(APP_NAME)
    app.setDesktopFileName(APP_ID)  # Wayland app_id -> Hyprland window rule

    try:
        catalog = load_catalog()
    except RuntimeError as exc:
        QMessageBox.critical(None, APP_NAME, str(exc))
        return 1

    win = Main(catalog)
    win.setStyleSheet(build_qss())
    win.show()
    return app.exec()


# ─────────────────────────────────────────────────────────────────────────────
#  CLI rész
# ─────────────────────────────────────────────────────────────────────────────

def _resolve(names, catalog):
    by = {a["name"].lower(): a for a in catalog}
    found, missing = [], []
    for n in names:
        a = by.get(n.lower())
        (found if a else missing).append(a if a else n)
    return found, missing


def cli_list(catalog, only_installed=False):
    idx = installed_index()
    for a in catalog:
        inst = is_installed(a, idx)
        if only_installed and not inst:
            continue
        mark = "[x]" if inst else "[ ]"
        print(f"{mark} {a['name']:<22} {a['category']:<10} "
              f"{TYPE_LABEL.get(a['type'], a['type'])}")


def cli_action(names, catalog, install: bool):
    found, missing = _resolve(names, catalog)
    for m in missing:
        print(f"Nem található: {m}")
    if not found:
        return 1
    steps = plan_commands(found, install, gui=False)
    if not steps:
        print("Nincs végrehajtható lépés.")
        return 1
    ok = 0
    for label, cmd in steps:
        print(f"\n── {label} ──")
        if stream_command(label, cmd, print):
            ok += 1
    print(f"\nKész: {ok}/{len(steps)} lépés sikeres.")
    return 0 if ok == len(steps) else 1


def main():
    parser = argparse.ArgumentParser(
        prog=APP_ID, description="RaveOS App Installer (GUI + CLI)")
    parser.add_argument("--list", action="store_true", help="elérhető appok listája")
    parser.add_argument("--installed", action="store_true", help="csak telepítettek")
    parser.add_argument("--install", nargs="+", metavar="APP", help="app(ok) telepítése")
    parser.add_argument("--remove", nargs="+", metavar="APP", help="app(ok) eltávolítása")
    parser.add_argument("--gui", action="store_true", help="GUI indítása (alapértelmezett)")
    parser.add_argument("--version", action="version", version=f"%(prog)s {APP_VERSION}")
    args = parser.parse_args()

    cli_mode = args.list or args.installed or args.install or args.remove
    if not cli_mode:
        # GUI-t user-ként indítsd (Wayland) — root GUI ne!
        if os.geteuid() == 0:
            print("Figyelem: a GUI-t NE rootként indítsd. "
                  "Futtasd sima userként, a jogot pkexec kéri majd.")
        try:
            sys.exit(run_gui())
        except ModuleNotFoundError:
            print("PyQt6 nincs telepítve. Telepítsd: sudo pacman -S python-pyqt6")
            sys.exit(1)

    try:
        catalog = load_catalog()
    except RuntimeError as exc:
        print(exc)
        sys.exit(1)

    if args.list or args.installed:
        cli_list(catalog, only_installed=args.installed)
        sys.exit(0)
    if args.install:
        sys.exit(cli_action(args.install, catalog, install=True))
    if args.remove:
        sys.exit(cli_action(args.remove, catalog, install=False))


if __name__ == "__main__":
    main()
