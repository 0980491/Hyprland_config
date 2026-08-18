-- ───────────────────────────── LOOK AND FEEL ────────────────────────────────
local C = require("conf.colors") -- palette matugen generates from the wallpaper

hl.config({
    general = {
        gaps_in    = 5,
        gaps_out   = 10,
        float_gaps = 8, -- separate gaps for floating windows (new)

        border_size = 2,

        col = {
            -- Animated gradient from two colours of the wallpaper palette
            active_border   = { colors = { C.primary, C.tertiary }, angle = 45 },
            inactive_border = C.rgba("outline_variant", 0.55),
        },

        resize_on_border      = true, -- resize by dragging the border
        extend_border_grab_area = 10,
        hover_icon_on_border  = true,

        allow_tearing = true, -- needed for tearing in games; enabled per rule
        layout        = "dwindle",

        -- Snapping for floating windows (they stick to each other and to edges)
        snap = {
            enabled       = true,
            window_gap    = 10,
            monitor_gap   = 10,
            respect_gaps  = true,
        },
    },

    decoration = {
        rounding       = 8,   -- like you had it before
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 0.96,

        dim_inactive = false,
        dim_strength = 0.15,
        dim_special  = 0.35,

        shadow = {
            enabled      = true,
            range        = 4,     -- like you had it before
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        -- Glow (the coloured halo around the focused window) is off: you didn't
        -- like it. Flip enabled to true if you ever want it back.
        glow = {
            enabled = false,
        },

        blur = {
            enabled           = true,
            size              = 4,
            passes            = 2,
            new_optimizations = true, -- much cheaper
            xray              = false,
            ignore_opacity    = true,
            noise             = 0.015,
            contrast          = 1.05,
            brightness        = 0.9,
            vibrancy          = 0.17,
            vibrancy_darkness = 0.2,
            popups            = true,
            popups_ignorealpha = 0.4,
            special           = true,
        },
    },

    -- Tabbed groups (SUPER+G): group bar themed with the wallpaper palette
    group = {
        auto_group      = false,
        drag_into_group = 1,
        col = {
            border_active          = { colors = { C.primary, C.tertiary }, angle = 45 },
            border_inactive        = C.rgba("outline_variant", 0.55),
            border_locked_active   = { colors = { C.error, C.primary }, angle = 45 },
            border_locked_inactive = C.rgba("outline", 0.4),
        },
        groupbar = {
            enabled            = true,
            font_family        = "JetBrainsMono Nerd Font",
            font_size          = 11,
            font_weight_active = "bold",
            height             = 20,
            indicator_height   = 3,
            gradients          = true,
            gradient_rounding  = 6,
            round_only_edges   = true,
            rounding           = 6,
            render_titles      = true,
            text_color         = C.on_surface,
            text_color_inactive = C.on_surface_variant,
            middle_click_close = true,
            scrolling          = true,
            col = {
                active   = C.rgba("primary_container", 0.95),
                inactive = C.rgba("surface_container", 0.75),
            },
        },
    },

    misc = {
        force_default_wallpaper = 0,     -- no default wallpaper
        disable_hyprland_logo   = true,  -- no logo / anime splash
        disable_splash_rendering = true,
        background_color        = C.surface,
        font_family             = "JetBrainsMono Nerd Font",
        focus_on_activate       = true,
        mouse_move_focuses_monitor = true,
        enable_anr_dialog       = true,  -- warn when an app stops responding
        anr_missed_pings        = 8,
        allow_session_lock_restore = true, -- recoverable if hyprlock dies
        session_lock_blur       = true,
        render_unfocused_fps    = 15,
        middle_click_paste      = false,

        -- Swallow: launching a GUI app from the terminal hides the terminal
        -- until the app closes.
        enable_swallow = true,
        swallow_regex  = "^(kitty)$",
    },

    render = {
        direct_scanout = 2, -- 2 = for fullscreen games (lower latency)
        cm_auto_hdr    = 0, -- OFF: these panels are sRGB, auto HDR washed them out
    },

    cursor = {
        inactive_timeout  = 5,    -- hide the cursor after 5 s idle
        hide_on_key_press = false,
        enable_hyprcursor = true,
        no_warps          = false,
        warp_on_change_workspace = 2, -- only when the cursor isn't over a window
        zoom_factor       = 1.0,  -- driven by the SUPER+CTRL+scroll bind
        zoom_rigid        = false,
    },

    binds = {
        workspace_back_and_forth = true,  -- pressing the same number goes back
        allow_workspace_cycles   = true,
        movefocus_cycles_fullscreen = false,
        hide_special_on_workspace_change = true,
        drag_threshold           = 10,
    },

    dwindle = {
        preserve_split  = true,
        smart_split     = false,
        smart_resizing  = true,
        force_split     = 2, -- new windows always to the right / below
        default_split_ratio = 1.0,
    },

    master = {
        new_status = "master",
        mfact      = 0.55,
    },

    scrolling = {
        fullscreen_on_one_column = true,
    },

    xwayland = {
        force_zero_scaling = true, -- crisp X11 apps on scaled monitors
    },

    animations = { enabled = true },
})

-- ───────────────────────────────── CURVES ───────────────────────────────────
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

-- Springs (new): natural bounce, nicer than bezier curves for windows
hl.curve("snappy", { type = "spring", mass = 1, stiffness = 320, dampening = 26 })
hl.curve("bouncy", { type = "spring", mass = 1, stiffness = 240, dampening = 22 })

-- ──────────────────────────────── ANIMATIONS ────────────────────────────────
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "snappy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "bouncy", style = "popin 90%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.0,  bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.6,  bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })
