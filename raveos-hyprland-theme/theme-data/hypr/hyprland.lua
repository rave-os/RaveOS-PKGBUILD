------------------
---- SOURCES -----
------------------

require("config/keybinds")
require("config/windowrules")

--###############
--## MONITORS ###
--###############

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("dms run")
    hl.exec_cmd("HYPRSHELL_NO_USE_PLUGIN=1 hyprshell run")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("bash -c 'wl-paste --watch cliphist store &'")
end)

--##################
--## MY PROGRAMS ###
--##################

local terminal   = "kitty"
local fileManager = "Thunar"
local menu       = "dms ipc call spotlight toggle"

--############################
--## ENVIRONMENT VARIABLES ###
--############################

local _home        = os.getenv("HOME") or ("/home/" .. (os.getenv("USER") or "user"))
local _xdg_runtime = os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000"

hl.env("XCURSOR_SIZE",   24)
hl.env("HYPRCURSOR_SIZE", 24)
hl.env("XCURSOR_THEME",  "Adwaita")

hl.env("HOME",                        _home)
hl.env("XDG_CONFIG_HOME",             _home .. "/.config")
hl.env("XDG_CURRENT_DESKTOP",         "Hyprland")
hl.env("XDG_SESSION_TYPE",            "wayland")
hl.env("XDG_SESSION_DESKTOP",         "Hyprland")
hl.env("XDG_MENU_PREFIX",             "arch-")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("GDK_BACKEND",                  "wayland")
hl.env("QT_QPA_PLATFORM",             "wayland")
hl.env("QT_QPA_PLATFORMTHEME",        "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", 1)
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", 1)
hl.env("QT_STYLE_OVERRIDE",           "kvantum")
hl.env("SSH_AUTH_SOCK",               _xdg_runtime .. "/ssh-agent.socket")

--#####################
--## LOOK AND FEEL ###
--#####################

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(4ef527cc)", "rgba(005dcacc)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "dwindle",
        snap = {
            enabled     = true,
            monitor_gap = 22,
        },
    },
})

hl.config({
    decoration = {
        rounding       = 10,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.66,
        shadow = {
            enabled      = true,
            range        = 44,
            render_power = 5,
            color        = "rgba(00000070)",
        },
        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },
})

hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 }    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 }    } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 }       } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 }    } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 }     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",        style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",      style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

--###########
--## INPUT ##
--###########

hl.config({
    input = {
        kb_layout          = "",
        kb_variant         = "",
        follow_mouse       = 1,
        sensitivity        = 0,
        numlock_by_default = true,
        accel_profile      = "flat",
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

--#######################
--## HYPRSHELL LAYERS ###
--#######################

hl.layer_rule({ match = { namespace = "hyprshell_overview" }, blur = true })
hl.layer_rule({ match = { namespace = "hyprshell_overview" }, ignore_alpha = true })
hl.layer_rule({ match = { namespace = "hyprshell_switch" },   blur = true })
hl.layer_rule({ match = { namespace = "hyprshell_switch" },   ignore_alpha = true })
hl.layer_rule({ match = { namespace = "hyprshell_launcher" }, blur = true })
hl.layer_rule({ match = { namespace = "hyprshell_launcher" }, ignore_alpha = true })
