# raveswitch hibajelentés — SUPER+TAB nem működik friss telepítésen

## Környezet
- raveswitch verzió: 0.3.1 (`hyprland_raveswitch` git HEAD, commit körül: `c14bc28` "bugfix")
- Hyprland: 0.56.1
- Teszt: friss RaveOS telepítés (Calamares), Hyprland desktop flavour, teljesen új felhasználó (`asd`), semmilyen korábbi raveswitch-konfiguráció nincs a rendszeren
- RaveOS oldali keybind: `SUPER + TAB` → `raveswitch socat '{"OpenSwitch":{"reverse":false}}'`

## Tünet
Friss telepítés után a `SUPER+TAB` billentyűkombináció nem csinál semmit — nem jelenik meg semmilyen ablakváltó felület.

## 1. hiba: `get_default_config_file()` rossz útvonalra esik vissza friss rendszeren

**Fájl:** `crates/core-lib/src/path.rs`, `get_default_config_file()` függvény

Ha SEHOL nem található meglévő config fájl (sem a felhasználói `$XDG_CONFIG_HOME/raveswitch/config.{ron,toml,json,json5}`, sem a rendszerszintű `/etc/raveswitch/config.{toml,ron}` útvonalakon — ami egy teljesen friss telepítésen mindig igaz), a függvény a **legutoljára ellenőrzött rendszerszintű útvonalat** (`/etc/raveswitch/config.toml`) adja vissza "alapértelmezett" gyanánt, ahelyett hogy a felhasználói útvonalra (`~/.config/raveswitch/config.ron`) esne vissza egy ÚJ fájl létrehozásához.

**Következmény:**
- `raveswitch config generate` (paraméter nélkül) megpróbálja létrehozni a configot `/etc/raveswitch/`-ban → `Permission denied` (a normál felhasználónak nincs írási joga oda), a parancs lefagy/hibázik.
- Maga a `raveswitch run` daemon is ugyanezt az útvonal-feloldást használja induláskor. Mivel nem talál configot, és a fájlt nem tudja figyelni ("watch for file changes"), **egy végtelen, mikroszekundumonkénti hibaciklusba kerül**:
  ```
  ERROR Failed to block config: unable to watch for file changes as the file doesnt exist, exiting
  WARN Failed wait for config change: unable to watch for file changes as the file doesnt exist, exiting
  INFO Trying to reload config after config change
  WARN Failed to load config: Config file does not exist, create it using `raveswitch config generate`, retrying on change
  ```
  Ez a ciklus percenként több tízezerszer fut le, és leköti a daemon fő event loop-ját — a socket IPC handler ugyan külön szálon/taskon fut és nyugtázza a beérkező parancsokat ("OK"), de a switcher-ablakot megjelenítő logika sosem kap esélyt lefutni.

**Workaround, amivel reprodukáltam és igazoltam:** kézzel, explicit `-c` kapcsolóval generálva a configot (`raveswitch -c ~/.config/raveswitch/config.ron config generate`) a busy-loop megszűnik.

## 2. hiba: a generált alapértelmezett config `switch: None`-t ad

**Fájl:** a `config generate` (GUI-alapú) által írt alapértelmezett `config.ron`

Az így legenerált config tartalma:
```ron
windows: (
    scale: 8.5,
    items_per_row: 5,
    overview: None,
    switch: None,
    switch_2: None,
),
```

Vagyis **az ablakváltó (switch) funkció alapból nincs bekapcsolva/konfigurálva** — a felhasználónak kézzel, a GUI-s beállításokon keresztül kellene bekapcsolnia, mielőtt bármilyen `OpenSwitch` IPC parancs ténylegesen csinálna bármit. Egy friss RaveOS telepítésen, ahol a `SUPER+TAB` keybind eleve be van drótozva és "csak működnie kellene", ez azt jelenti hogy a funkció **sosincs bekapcsolva**, amíg a felhasználó nem nyitja meg kézzel a raveswitch beállításait.

**Workaround, amivel reprodukáltam és igazoltam:** kézzel kitöltve egy érvényes `switch: Some(modifier: "Alt", key: "Tab", filter_by: [current_monitor], switch_workspaces: false, exclude_workspaces: "", kill_key: 'q')` blokkot, a daemon újraindítása után a switcher-ablak ténylegesen létrejön a compositorban (helyes `raveswitch_switch` namespace, helyes pozíció/méret a `hyprctl layers` szerint).

## 3. (bizonytalan, esetleg csak a teszt-VM-re jellemző): a létrejött ablak `a: 0` (láthatatlan)

A fenti két workaround után a switcher réteg TÉNYLEGESEN létrejön a Hyprlandben (`hyprctl layers` mutatja, helyes namespace/geometria), **de nulla átlátszósággal (`a: 0`)**, tehát vizuálisan semmi nem látszik belőle — screenshottal is megerősítve.

A raveswitch daemon logjában ezzel egyidőben GPU-inicializálási hibák látszanak:
```
MESA: error: vdrm_device_connect failed
radv/amdgpu: failed to initialize device.
Gdk-WARNING: Vulkan: ...failed to initialize winsys (VK_ERROR_INITIALIZATION_FAILED)
libEGL warning: egl: failed to create dri2 screen
```

Ez a tesztkörnyezet (libvirt/QEMU VM, GPU-passthrough nélkül) hiánya lehet, NEM feltétlenül raveswitch-hiba — valódi hardveren vagy GPU-passthrough-os VM-en érdemes külön leellenőrizni, hogy ugyanez jelentkezik-e.

## Javasolt javítás(ok)

1. `get_default_config_file()`: ha SEHOL nem található meglévő config, essen vissza a **felhasználói** útvonalra (`~/.config/raveswitch/config.ron`) egy új fájl generálásához, ne a rendszerszintű `/etc/raveswitch/`-ra.
2. A daemon kezelje le kecsesen (ne végtelen hibaciklussal) azt az esetet, amikor a config fájl nem létezik és nem hozható létre — pl. hozza létre automatikusan alapértékekkel, vagy fusson tovább in-memory defaultokkal ahelyett hogy a fő loopot leköti.
3. Fontolja meg, hogy a `config generate` / friss telepítés alapból bekapcsolt `switch` (és esetleg `switch_2`) profillal induljon, mivel a raveswitch fő funkciója pont ez — jelenleg "silently disabled by default" az élmény.

*(RaveOS oldalról alternatív/kiegészítő megoldás: a `raveos-hyprland-theme` csomag telepíthetne egy kész, működő alapértelmezett `config.ron`-t az első bejelentkezéskor, hogy ne kelljen megvárni az upstream javítást.)*



build fájl. 



pkgname=raveswitch
pkgver=0.3.1
pkgrel=1
pkgdesc="A modern GTK4-based window switcher and application launcher for Hyprland"
arch=('x86_64' 'aarch64')
conflicts=('hyprshell')
provides=('hyprshell')
url="https://git.rp1.hu/gabeszm/hyprland_raveswitch"
license=("MIT")
makedepends=('cargo' 'git')
optdepends=('org.freedesktop.secrets: Store clipboard encryption in the keyring')
depends=('hyprland' 'gtk4-layer-shell' 'gtk4' 'libadwaita' 'zstd')
source=("hyprland_raveswitch::git+ssh://git@git.rp1.hu/gabeszm/hyprland_raveswitch.git")
sha256sums=('SKIP')

prepare() {
    export RUSTUP_TOOLCHAIN=stable
    cd hyprland_raveswitch
    # dep-crates/hyprland-rs is vendored without a README.md, but its own
    # src/lib.rs does include_str!("../README.md") -- create a stub so the
    # build doesn't fail on a missing doc-comment source file.
    [ -f dep-crates/hyprland-rs/README.md ] || echo "# hyprland-rs (vendored)" > dep-crates/hyprland-rs/README.md
    # crates/config-edit-lib embeds assets/logo.png via include_bytes!, but
    # the repo only ships assets/raveicon.png -- reuse it as the logo.
    [ -f assets/logo.png ] || cp assets/raveicon.png assets/logo.png
    cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
}
build() {
    export RUSTUP_TOOLCHAIN=stable
    export CARGO_TARGET_DIR=target
    cd hyprland_raveswitch
    cargo build --frozen --release
}
package() {
    install -Dm755 "hyprland_raveswitch/target/release/raveswitch"             "$pkgdir/usr/bin/raveswitch"
    install -Dm644 "hyprland_raveswitch/README.md"                            "$pkgdir/usr/share/doc/raveswitch/README.md"
    install -Dm644 "hyprland_raveswitch/packaging/raveswitch.service"          "$pkgdir/usr/lib/systemd/user/raveswitch.service"
    install -Dm644 "hyprland_raveswitch/assets/raveswitch-settings.png"     "$pkgdir/usr/share/pixmaps/raveswitch-settings.png"
    for size in 16 24 32 48 64 128 256; do
        install -Dm644 "hyprland_raveswitch/assets/raveswitch-settings.png" "$pkgdir/usr/share/icons/hicolor/${size}x${size}/apps/raveswitch-settings.png"
    done
    install -Dm644 "hyprland_raveswitch/packaging/hu.rp1.raveswitch.settings.desktop" "$pkgdir/usr/share/applications/hu.rp1.raveswitch.settings.desktop"
    mkdir "$pkgdir/usr/share/raveswitch"
    tar -xf "hyprland_raveswitch/packaging/usr-share.tar" -C "$pkgdir/usr/share/raveswitch"
    install -Dm644 "hyprland_raveswitch/assets/raveicon.png"   "$pkgdir/usr/share/raveswitch/assets/raveicon.png"
    "$pkgdir/usr/bin/raveswitch" completions bash -p  "$pkgdir/usr/share/bash-completion/completions"
    "$pkgdir/usr/bin/raveswitch" completions fish -p  "$pkgdir/usr/share/fish/vendor_completions.d"
    "$pkgdir/usr/bin/raveswitch" completions zsh -p   "$pkgdir/usr/share/zsh/site-functions"
}

