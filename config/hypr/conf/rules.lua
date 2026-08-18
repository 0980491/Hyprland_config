-- ────────────────────────── WINDOW AND LAYER RULES ──────────────────────────
-- New syntax: match = { ...props... } followed by the effects.
-- Props: class, title, initial_class, initial_title, xwayland, float,
--        fullscreen, pin, focus, group, modal, workspace, content, tag...
-- hyprctl clients  → the real class/title of a window.

-- ═══════════════════════════ GENERAL FIXES ══════════════════════════════════

-- Ignore "maximize" requests from apps (they are almost always annoying)
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fixes odd drag behaviour in XWayland apps
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Modal dialogs dim everything behind them
hl.window_rule({
    name  = "modal-dim",
    match = { modal = true },
    dim_around = true,
    float      = true,
    center     = true,
})

-- ═══════════════════════════ FLOATING WINDOWS ═══════════════════════════════

-- RE2 regex, one pattern per line. In Lua "\\." is a literal dot for RE2.
local floatCentered = {
    "^pavucontrol(-qt)?$",
    "^com\\.saivert\\.pwvucontrol$",
    "^blueman-manager$",
    "^nm-connection-editor$",
    "^org\\.kde\\.kcalc$",
    "^qalculate-gtk$",
    "^io\\.github\\.easyeffects\\.Easyeffects$",
    "^xdg-desktop-portal-gtk$",
    "^org\\.kde\\.polkit-kde-authentication-agent-1$",
    "^polkit-gnome-authentication-agent-1$",
    "^file-roller$",
    "^org\\.kde\\.ark$",
}

for _, pattern in ipairs(floatCentered) do
    hl.window_rule({
        match  = { class = pattern },
        float  = true,
        center = true,
        size   = { "monitor_w*0.42", "monitor_h*0.55" },
    })
end

-- File pickers and dialogs matched by title
hl.window_rule({
    name  = "float-dialogs",
    match = { title = "^(Open File|Open Folder|Save File|Save As|Abrir|Guardar como|Elegir archivos|Select a File|Choose Files|Import|Export)" },
    float  = true,
    center = true,
    size   = { "monitor_w*0.5", "monitor_h*0.6" },
})

-- Picture-in-Picture: floating, pinned to every workspace, bottom-right corner
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },
    float  = true,
    pin    = true,
    size   = { 640, 360 },
    move   = { "monitor_w-660", "monitor_h-400" },
    keep_aspect_ratio = true,
    idle_inhibit = "focus",
})

-- Small tool windows
hl.window_rule({
    name  = "float-small-tools",
    match = { class = "^(hyprland-run|qalculate)$" },
    float  = true,
    center = true,
})

-- ═══════════════════════════════ GAMES ══════════════════════════════════════
-- immediate = tearing allowed (lower latency). Needs general.allow_tearing.
-- idle_inhibit = "focus" → the screen won't lock while you play.

hl.window_rule({
    name  = "steam-games",
    match = { class = "^steam_app_" },
    immediate    = true,
    no_anim      = true,
    no_blur      = true,
    no_shadow    = true,
    idle_inhibit = "focus",
    content      = "game",
})

-- If you'd rather Steam games did NOT get forced fullscreen, comment this
-- rule out (you had it enabled before).
hl.window_rule({
    name  = "steam-games-fullscreen",
    match = { class = "^steam_app_" },
    fullscreen = true,
})

-- Anything that declares itself a game (Heroic, Lutris, Proton, native)
hl.window_rule({
    name  = "game-content",
    match = { content = "game" },
    immediate    = true,
    no_anim      = true,
    idle_inhibit = "focus",
    no_vrr       = false,
})

-- Launchers: don't steal focus mid-game
hl.window_rule({
    name  = "launchers-no-steal",
    match = { class = "^(steam|heroic|net\\.lutris\\.Lutris)$" },
    focus_on_activate = false,
})
hl.window_rule({
    name  = "steam-friends-float",
    match = { class = "^steam$", title = "^(Friends List|Lista de amigos)$" },
    float = true,
    size  = { 420, 700 },
})

-- Fullscreen video: never lock the screen
hl.window_rule({
    name  = "video-content",
    match = { content = "video" },
    idle_inhibit = "fullscreen",
})
hl.window_rule({
    name  = "mpv",
    match = { class = "^(mpv|vlc)$" },
    idle_inhibit = "focus",
    no_blur      = true,
})

-- OBS and Sunshine: keep rendering while hidden (avoids frozen captures)
hl.window_rule({
    name  = "keep-rendering",
    match = { class = "^(com\\.obsproject\\.Studio|obs)$" },
    render_unfocused = true,
})

-- DaVinci Resolve / Fusion and friends: no blur or shadows, they're heavy
-- NOTE: "Fusion" here is DaVinci Resolve's Fusion page, NOT Autodesk Fusion 360.
-- Autodesk Fusion runs under Wine and has its own section below.
hl.window_rule({
    name  = "pro-apps",
    match = { class = "^(resolve|Fusion|darktable|Upscayl|blender|prusa-slicer|PrusaSlicer)$" },
    no_blur   = true,
    no_shadow = true,
})

-- ═══════════════════════ AUTODESK FUSION 360 (WINE) ═════════════════════════
-- Fusion is a stacking, multi-window Windows app: it spawns dozens of palettes,
-- tool dialogs and tooltips that a tiling WM has no sane way to place. The fix
-- is Wine's virtual desktop — Wine's own internal WM handles all of that inside
-- ONE X window, and Hyprland only ever sees that single window.
--
-- Fusion now runs inside the `fusion-box` distrobox container (Debian 12), the
-- only setup on this machine where the 3D viewport renders. Launcher:
-- ~/B/autodesk-fusion/bin/fusion-box.sh. Prefix: ~/B/fusion-box-home.
--
-- The launcher registers the canvas size under
--   HKCU\Software\Wine\Explorer\Desktops\Fusion = 1920x1080
-- and deletes the global Explorer\Desktop key, so exactly one desktop exists.

-- The virtual desktop container, floated at exactly the canvas size.
--
-- Not fullscreen: Fusion will not maximise past 1920x1080 however large the
-- canvas is, so a fullscreen container on the 2560x1440 monitor just wraps it
-- in a black L-shaped border. Matching the window to the canvas removes that
-- and makes the window draggable between monitors.
--
-- The title is matched exactly. A substring match on "wine desktop" is wrong:
-- a stale, process-less "Wine Desktop" window can linger in the client list and
-- would swallow the rule.
--
-- If the canvas size ever changes (fusion-box.sh --size), change it here too —
-- the two must agree or the border comes back.
hl.window_rule({
    name  = "fusion-virtual-desktop",
    match = { class = "^explorer\\.exe$", title = "^Fusion - Wine Desktop$" },
    float     = true,
    center    = true,
    size      = { 2560, 1440 },
    no_blur   = true,
    no_shadow = true,
    no_anim   = true,
    opaque    = true,
    idle_inhibit = "focus",
})

-- The nested sway session (bin/fusion-nested.sh), the alternative to the
-- virtual desktop above. Same idea, one window for Hyprland to deal with, but
-- inside it a real compositor handles Fusion's palettes and dialogs, so the
-- translucent ones stop coming out black.
--
-- The rootful Xwayland window that bin/fusion-nested.sh starts. Matched by
-- class, not title: the title carries the display number (":2", ":3"…) and
-- that changes with whatever else is running.
hl.window_rule({
    name  = "fusion-nested",
    match = { class = "^org\\.freedesktop\\.Xwayland$" },
    float     = true,
    center    = true,
    size      = { 2560, 1440 },
    no_blur   = true,
    no_shadow = true,
    no_anim   = true,
    opaque    = true,
    idle_inhibit = "focus",
})

-- Safety net: if the virtual desktop is ever disabled, Fusion's windows would
-- otherwise get tiled individually, which is exactly the mess we're avoiding.
-- Float them all so the app is at least usable.
hl.window_rule({
    name  = "fusion-float-fallback",
    match = { class = "^(fusion360\\.exe|adcefwebbrowser\\.exe|adskidentitymanager\\.exe|nlauncher\\.exe)$" },
    float     = true,
    no_blur   = true,
    no_shadow = true,
    opaque    = true,
})

-- Fusion's splash and its transient tool windows must not yank focus around
-- while it boots, otherwise the main window loses input mid-startup.
hl.window_rule({
    name  = "fusion-no-focus-steal",
    match = { class = "^(fusion360\\.exe|adcefwebbrowser\\.exe)$", title = "^$" },
    no_focus = true,
})

-- ═════════════════════════════ TRANSPARENCY ═════════════════════════════════
hl.window_rule({
    name  = "terminal-opacity",
    match = { class = "^(kitty|foot|Alacritty)$" },
    opacity = "0.94 0.88",
})
-- Electron apps (VS Code, Claude, Obsidian) have no real background transparency
-- of their own, so Hyprland fades the whole window instead. Blur still lands
-- behind them because decoration.blur.ignore_opacity is on. Text fades with the
-- window, so these are the readability knob: raise them if it reads washed out.
-- Both numbers are equal on purpose: they stay transparent while focused too.
hl.window_rule({
    name  = "electron-opacity",
    match = { class = "^(code|com\\.anthropic\\.Claude|md\\.Obsidian)$" },
    opacity = "0.90 0.90",   -- focused / unfocused
})

hl.window_rule({
    name  = "opaque-media",
    match = { class = "^(mpv|vlc|resolve|gthumb|org\\.kde\\.gwenview|Upscayl|firefox|zen)$" },
    opaque = true,
})

-- ═══════════════════════════════ LAYERS ═════════════════════════════════════
-- Quickshell and rofi namespaces: blur, and no weird shadows.

hl.layer_rule({
    name  = "blur-quickshell",
    match = { namespace = "^qs-(bar|popup|notifications|osd|launcher)$" },
    blur  = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({ name = "blur-rofi",    match = { namespace = "^rofi$" },    blur = true, ignore_alpha = 0.25 })
hl.layer_rule({ name = "blur-waybar",  match = { namespace = "^waybar$" },  blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "blur-swaync",  match = { namespace = "^swaync" },   blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "blur-wlogout", match = { namespace = "^logout" },   blur = true })
hl.layer_rule({ name = "no-anim-lock", match = { namespace = "^hyprlock$" }, no_anim = true })

-- The wallpaper layer (awww / wallpaper engine) must never blur or animate
hl.layer_rule({ name = "wallpaper", match = { namespace = "^(awww|swww|wallpaperengine)" }, no_anim = true, order = -1 })
