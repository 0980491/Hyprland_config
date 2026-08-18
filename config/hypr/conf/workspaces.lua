-- ───────────────────── WORKSPACES PINNED TO MONITORS ────────────────────────
-- This used to be done with exec-once + hyprctl dispatch moveworkspacetomonitor.
-- Rules are declarative: no startup ordering, no sleeps.
--
-- Keep these ids in sync with ~/.config/quickshell/Config.qml so the bar shows
-- the same dots.

-- Main 1440p (DP-3): workspaces 1-5, always present.
-- The session starts on the middle one (3), not the first: with the dots
-- centred in the bar, landing in the middle means you can go either way
-- without wrapping around. Same idea on HDMI-A-1 below (13 of 11-15).
for i = 1, 5 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = "DP-3",
        persistent = true,
        default    = (i == 3),
    })
end

-- Second 1440p (DP-2): workspaces 6-7
for i = 6, 7 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = "DP-2",
        default   = (i == 6),
    })
end

-- Scaled 1080p (DP-1): workspace 8
hl.workspace_rule({ workspace = "8", monitor = "DP-1", default = true })

-- 1080p 75 Hz (HDMI-A-1): workspaces 11-15, always present
for i = 11, 15 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = "HDMI-A-1",
        persistent = true,
        default    = (i == 13),
    })
end

-- Virtual output for wayvnc / sunshine
hl.workspace_rule({ workspace = "32", monitor = "HEADLESS-2" })

-- Workspace 9: clean desktop for games (no gaps, no borders, no shadows)
hl.workspace_rule({
    workspace    = "9",
    monitor      = "DP-3",
    gaps_in      = 0,
    gaps_out     = 0,
    no_border    = true,
    no_rounding  = true,
    no_shadow    = true,
    default_name = "game",
})

-- No "smart gaps" here on purpose: they stripped the border and the rounded
-- corners whenever a workspace held a single window, so one window looked
-- square and flat while two side by side looked right. Now a lone window keeps
-- the same gaps, border and rounding as any other.
