-- ────────────────────────────────── MONITORS ────────────────────────────────
-- hyprctl monitors all   → every output and the modes it supports
--
-- vrr = 3  →  FreeSync only for fullscreen windows with game/video content.
--            Safest option: no flicker on the desktop. If the monitor doesn't
--            support FreeSync it is simply ignored. vrr = 0 turns it off.
--
-- Colour: these panels are 100% sRGB with "HDR400" (a badge, not real HDR).
-- Letting Hyprland pick wide gamut / switch to HDR on fullscreen is what was
-- washing the colours out after leaving a fullscreen window, so:
--   cm = "srgb"        → always sRGB primaries, never BT.2020
--   supports_hdr = -1  → tell Hyprland this panel has no usable HDR
-- and render.cm_auto_hdr is off in look.lua.

-- Main: 1440p 165 Hz, 10-bit
hl.monitor({
    output   = "DP-3",
    mode     = "2560x1440@165",
    position = "0x0",
    scale    = 1,
    bitdepth = 10,
    cm       = "srgb",
    supports_hdr = -1,
    vrr      = 3,
})

-- Second: 1440p 165 Hz, 10-bit (to the left of the main one)
hl.monitor({
    output   = "DP-2",
    mode     = "2560x1440@165",
    position = "-2560x0",
    scale    = 1,
    bitdepth = 10,
    cm       = "srgb",
    supports_hdr = -1,
    vrr      = 3,
})

-- 1080p 75 Hz
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@75.01",
    position = "-1920x180",
    scale    = 1,
})

-- 1080p 60 Hz, scaled 1.5 — kept on purpose, this screen is watched from far
-- away and over the remote session. It leaves 1280x720 of usable desktop, half
-- of DP-3. Menus keep their own size and their own text on every monitor; what
-- had to give was anything drawn proportionally to the screen instead of to the
-- window: the rofi themes now carry a `calc(<size> min <percent>%)` ceiling so
-- they shrink to fit rather than being cut off, and the launcher's picture is
-- scaled to the launcher (see themes/launcher.rasi).
hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@60",
    position = "-1300x-720",
    scale    = 1.5,
})

-- Any new output you plug in: preferred mode, placed to the right.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
