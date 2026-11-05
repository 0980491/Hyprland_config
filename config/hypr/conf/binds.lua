-- ───────────────────────────────── KEYBINDS ─────────────────────────────────
local V = require("conf.vars")

local mod    = "SUPER"
local remote = "SUPER + ALT" -- alias for when you play over Sunshine/Moonlight
                             -- and the client swallows the SUPER key

--- Registers the same bind on SUPER and on SUPER+ALT.
---@param key string
---@param dispatcher any
---@param desc string|nil
---@param opts table|nil
local function bind(key, dispatcher, desc, opts)
    opts = opts or {}
    opts.description = desc
    hl.bind(mod .. " + " .. key, dispatcher, opts)
    hl.bind(remote .. " + " .. key, dispatcher, opts)
end

--- Plain bind, no duplicate.
local function bind1(key, dispatcher, desc, opts)
    opts = opts or {}
    opts.description = desc
    hl.bind(key, dispatcher, opts)
end

-- ══════════════════════════════ APPLICATIONS ════════════════════════════════
bind("Return", hl.dsp.exec_cmd(V.terminal),                 "Terminal")
bind("E",      hl.dsp.exec_cmd(V.fileManager),              "File manager")
bind("D",      hl.dsp.exec_cmd(V.launcher),                 "App launcher")
bind("SPACE",  hl.dsp.exec_cmd(V.launcher),                 "App launcher")
bind("B",      hl.dsp.exec_cmd("qs ipc call panel toggle wallpaper"), "Pick a wallpaper")
-- bind1, not bind: the SUPER+ALT twin of this one is the same combo, and it
-- would just register twice. It is the escape hatch for when the shell is down.
bind1("SUPER + SHIFT + ALT + B", hl.dsp.exec_cmd(V.wallPicker), "Pick a wallpaper (rofi fallback)")
bind("slash",  hl.dsp.exec_cmd(V.keybinds),                 "Show every keybind")

-- rofi menus
bind("C",         hl.dsp.exec_cmd(V.clipboard),  "Clipboard history")
bind("period",    hl.dsp.exec_cmd(V.emoji),      "Emoji picker")
bind("N",         hl.dsp.exec_cmd(V.wifi),       "Wi-Fi networks")
bind("SHIFT + B", hl.dsp.exec_cmd(V.bluetooth),  "Bluetooth")
bind("SHIFT + TAB", hl.dsp.exec_cmd(V.windows),  "Window switcher")
bind("ESCAPE",    hl.dsp.exec_cmd(V.powermenu),  "Power menu")

-- Screenshots
bind("S",         hl.dsp.exec_cmd(V.screenshot .. " region"), "Screenshot a region")
bind("SHIFT + S", hl.dsp.exec_cmd(V.screenshot .. " edit"),   "Screenshot and annotate")
bind1("PRINT",    hl.dsp.exec_cmd(V.screenshot .. " monitor"), "Screenshot this monitor")
bind1("SHIFT + PRINT", hl.dsp.exec_cmd(V.screenshot .. " window"), "Screenshot the focused window")

-- Lock and session
bind("L", hl.dsp.exec_cmd("hyprlock"), "Lock the screen")
-- No bare "quit Hyprland" bind on purpose: SUPER+M was one keystroke away from
-- killing the whole session and kept getting hit by accident. Logging out lives
-- in the power menu (SUPER+ESCAPE), behind a confirmation.

-- ═══════════════════════════════ WINDOWS ════════════════════════════════════
bind("Q",         hl.dsp.window.close(),                          "Close window")
bind("SHIFT + Q", hl.dsp.window.kill(),                           "Kill window (SIGKILL)")
bind("F",         hl.dsp.window.fullscreen(),                     "Fullscreen")
bind("SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize")
bind("W",         hl.dsp.window.float({ action = "toggle" }),      "Toggle floating")
bind("SHIFT + C", hl.dsp.window.center(),                         "Center window")
bind("P",         hl.dsp.window.pseudo(),                         "Pseudo-tile")
bind("SHIFT + P", hl.dsp.window.pin(),                            "Pin to every workspace")
bind("J",         hl.dsp.layout("togglesplit"),                   "Flip the split (dwindle)")

-- Tabbed groups
bind("G",         hl.dsp.group.toggle(),                          "Group / ungroup as tabs")
bind("SHIFT + G", hl.dsp.group.lock_active(),                     "Lock the group")
bind("bracketleft",  hl.dsp.group.prev(),                         "Previous tab in group")
bind("bracketright", hl.dsp.group.next(),                         "Next tab in group")

-- Focus and window movement
for key, dir in pairs({ left = "l", right = "r", up = "u", down = "d" }) do
    bind(key, hl.dsp.focus({ direction = dir }), "Move focus")
    bind("SHIFT + " .. key, hl.dsp.window.move({ direction = dir, group_aware = true }), "Move window")
    bind("CTRL + " .. key, hl.dsp.focus({ monitor = dir }), "Focus another monitor")
    bind("CTRL + SHIFT + " .. key, hl.dsp.window.move({ monitor = dir, follow = true }), "Send window to another monitor")
end

-- No scratchpad. SUPER+A used to toggle a hidden "magic" workspace and kept
-- getting hit by accident; SUPER+SHIFT+A (send a window into it) goes with it,
-- because without the toggle a window sent there is gone with no way back.

-- Cycle windows (classic Alt+Tab)
bind1("ALT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end, "Cycle windows")

-- ═══════════════════════════════ WORKSPACES ═════════════════════════════════
for i = 1, 10 do
    local key = i % 10 -- 10 maps to the 0 key
    bind(tostring(key),           hl.dsp.focus({ workspace = i }),          "Go to workspace " .. i)
    bind("SHIFT + " .. key,       hl.dsp.window.move({ workspace = i }),    "Move to workspace " .. i)
    bind("CTRL + " .. key,        hl.dsp.window.move({ workspace = i, follow = true }), "Move to workspace " .. i .. " and follow")
end

-- Workspaces 11-20 on F1-F10 (handy for the secondary monitor)
for i = 1, 10 do
    bind("F" .. i,           hl.dsp.focus({ workspace = 10 + i }),       "Go to workspace " .. (10 + i))
    bind("SHIFT + F" .. i,   hl.dsp.window.move({ workspace = 10 + i }), "Move to workspace " .. (10 + i))
end

-- m+1 / m-1 cycle only the workspaces of the monitor you are on, so you never
-- fall off the end of one screen onto the first workspace of the other.
bind("mouse_down", hl.dsp.focus({ workspace = "m+1" }), "Next workspace on this monitor")
bind("mouse_up",   hl.dsp.focus({ workspace = "m-1" }), "Previous workspace on this monitor")
bind("comma",      hl.dsp.focus({ workspace = "m-1" }), "Previous workspace on this monitor")
bind("semicolon",  hl.dsp.focus({ workspace = "m+1" }), "Next workspace on this monitor")

-- ═════════════════════════════ MOUSE AND ZOOM ═══════════════════════════════
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- Magnifier: SUPER+CTRL+wheel. SUPER+CTRL+0 resets it.
local function zoom(delta)
    return function()
        local cur = hl.get_config("cursor.zoom_factor") or 1.0
        local new = math.max(1.0, math.min(6.0, cur + delta))
        hl.config({ cursor = { zoom_factor = new } })
    end
end
hl.bind(mod .. " + CTRL + mouse_down", zoom(0.25), { description = "Zoom in" })
hl.bind(mod .. " + CTRL + mouse_up",   zoom(-0.25), { description = "Zoom out" })
hl.bind(mod .. " + CTRL + 0", function()
    hl.config({ cursor = { zoom_factor = 1.0 } })
end, { description = "Reset zoom" })

-- ═══════════════════════════ RESIZE SUBMAP ══════════════════════════════════
-- SUPER+R enters resize mode: arrows resize, ESC leaves.
bind("R", hl.dsp.submap("resize"), "Resize mode")

hl.define_submap("resize", function()
    local step = 40
    hl.bind("right", hl.dsp.window.resize({ x = step,  y = 0, relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0, y = step,  relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })

    hl.bind("L", hl.dsp.window.resize({ x = step,  y = 0, relative = true }), { repeating = true })
    hl.bind("H", hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = step,  relative = true }), { repeating = true })
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })

    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

-- ═══════════════════════════ MEDIA AND SYSTEM ═══════════════════════════════
bind1("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up", { locked = true, repeating = true })
bind1("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        "Volume down", { locked = true, repeating = true })
bind1("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       "Mute", { locked = true })
bind1("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     "Mute microphone", { locked = true })
bind1("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), "Brightness up", { locked = true, repeating = true })
bind1("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), "Brightness down", { locked = true, repeating = true })

bind1("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),        "Next track", { locked = true })
bind1("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),    "Previous track", { locked = true })
bind1("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"),  "Play / pause", { locked = true })
bind1("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"),  "Play / pause", { locked = true })
bind1("XF86AudioStop",  hl.dsp.exec_cmd("playerctl stop"),        "Stop", { locked = true })

-- Alternative without media keys: SUPER + / SUPER -
bind("equal", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume up", { repeating = true })
bind("minus", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        "Volume down", { repeating = true })

-- ═══════════════════════════════ UTILITIES ══════════════════════════════════
bind("SHIFT + N", hl.dsp.exec_cmd(V.scripts .. "/nightlight.sh"),  "Night light (hyprsunset)")
bind("SHIFT + W", hl.dsp.exec_cmd(V.wallpaper .. " random"),       "Random wallpaper")
bind("SHIFT + R", hl.dsp.exec_cmd("qs kill; qs -d"),               "Restart the shell (Quickshell)")
bind("SHIFT + X", hl.dsp.exec_cmd("hyprpicker -a"),                "Colour picker")
bind("F12",       hl.dsp.exec_cmd(V.gamemode),                     "Toggle game mode (performance)")
-- Workspace overview. TAB is the main one: this keyboard has no grave accent
-- key, so the old SUPER+` was unreachable — it stays as a second way in for any
-- keyboard that does have it. The rofi window switcher moved to SUPER+SHIFT+TAB.
bind("TAB",   hl.dsp.exec_cmd("qs ipc call panel toggle overview"), "Workspace overview")
bind("grave", hl.dsp.exec_cmd("qs ipc call panel toggle overview"), "Workspace overview")

-- Gap toggle: compact desktop for split-screen work
bind("SHIFT + T", function()
    local gaps = hl.get_config("general.gaps_out")
    local isOn = type(gaps) == "table" and (gaps.top or 0) > 0
    if isOn then
        hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })
        hl.notification.create({ text = "Gaps: off", timeout = 1200, icon = "ok" })
    else
        hl.config({ general = { gaps_in = 5, gaps_out = 10, border_size = 2 } })
        hl.notification.create({ text = "Gaps: on", timeout = 1200, icon = "ok" })
    end
end, "Toggle gaps")

-- HDMI output in "iPad" mode. SUPER+I or SUPER+ALT+I switches it, SUPER+O (or
-- SUPER+ALT+O) puts it back — the ALT variants are the ones that survive a
-- Moonlight session, which is when you actually need this.
bind("I", function()
    hl.monitor({ output = "HDMI-A-1", mode = "2160x1620@60", position = "3000x3000", scale = 2 })
    hl.notification.create({ text = "HDMI-A-1 → 2160x1620 @2x", timeout = 2000, icon = "ok" })
end, "HDMI in iPad mode")

bind("O", function()
    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@75.01", position = "-1920x180", scale = 1 })
    hl.notification.create({ text = "HDMI-A-1 → 1080p 75 Hz", timeout = 2000, icon = "ok" })
end, "HDMI back to normal")

-- Same thing, but with every other output disabled: Sunshine grabs the first
-- monitor Wayland lists and that is DP-3 as long as DP-3 is awake, so when the
-- 2K panel was left on there is no way to move the stream from the client. The
-- script arms a deadman that brings the screens back if no client is connected
-- two minutes later (see scripts/remote-only.sh — there is no SSH here).
bind("SHIFT + I", hl.dsp.exec_cmd(V.remoteOnly .. " on"),  "Stream screen only (iPad mode)")
bind("SHIFT + O", hl.dsp.exec_cmd(V.remoteOnly .. " off"), "All monitors back on")
