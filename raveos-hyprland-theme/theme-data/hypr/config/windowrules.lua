--#############################
--## WINDOWS AND WORKSPACES ###
--#############################

hl.window_rule({
    name  = "windowrule-2",
    match = { class = "org.gnome.gedit" },
    size  = { 888, 888 },
})

hl.window_rule({
    name  = "windowrule-3",
    match = { title = "Preferences" },
    size  = { 444, 444 },
})

hl.window_rule({
    name  = "windowrule-4",
    match = { class = "thunar" },
    size  = { 1111, 666 },
})

hl.window_rule({
    name  = "windowrule-5",
    match = { title = "File Operation Progress" },
    size  = { 444, 111 },
})

hl.window_rule({
    name  = "windowrule-6",
    match = { title = "^(.*Properties.*)$" },
    size  = { 444, 444 },
})

hl.window_rule({
    name  = "windowrule-7",
    match = { title = "Confirm to replace files" },
    size  = { 444, 333 },
})

hl.window_rule({
    name  = "windowrule-8",
    match = { class = "org.pulseaudio.pavucontrol" },
    size  = { 888, 888 },
})

hl.window_rule({
    name  = "windowrule-9",
    match = { title = "Create New Folder" },
    size  = { 444, 111 },
})

hl.window_rule({
    name  = "windowrule-10",
    match = { title = "^(.*Rename.*)$" },
    size  = { 444, 111 },
})

hl.window_rule({
    name  = "windowrule-11",
    match = { title = "New Empty File..." },
    size  = { 444, 111 },
})

hl.window_rule({
    name  = "windowrule-12",
    match = { class = "Thunar" },
    size  = { 1111, 666 },
})

hl.window_rule({
    name  = "windowrule-13",
    match = { title = "Set Default Application" },
    size  = { 555, 555 },
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = { 20, "monitor_h-120" },
    float = true,
})
