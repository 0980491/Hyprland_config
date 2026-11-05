-- ──────────────────────────────── AUTOSTART ─────────────────────────────────
local V = require("conf.vars")

hl.on("hyprland.start", function()
    -- 1) Environment for portals and user services (screenshare, file pickers)
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland.service")

    -- 2) Polkit agent (system password dialogs)
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- 3) Desktop shell: bar + notifications + OSD (Quickshell)
    hl.exec_cmd("qs -d -n")

    -- 4) Wallpaper: daemon + restore whatever you had last
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(V.wallpaper .. " restore")

    -- 5) Persistent clipboard (SUPER+V reads this)
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- 6) Idle handling: screen blanking and the 1 h suspend.
    -- caffeine's inhibitor dies with the session, so clear a state file left
    -- saying "on" or the bar button lights up for an inhibitor that is gone.
    hl.exec_cmd("hypridle")
    hl.exec_cmd(V.scripts .. "/caffeine.sh sync")

    -- 6a) The PC sometimes powers itself back on seconds after a clean poweroff
    -- (WoL misfire, suspected). If this boot is one of those and nobody touches
    -- anything for 5 min, this powers it off again. Does nothing on a normal boot.
    hl.exec_cmd(V.scripts .. "/wake-guard.sh")

    -- 6b) Drag a tiled window to another workspace with the wheel and Hyprland
    -- leaves it floating. This listens on the event socket and tiles it back.
    hl.exec_cmd(V.scripts .. "/keep-tiled.py")

    -- 7) Remote streaming
    hl.exec_cmd("sunshine")

    -- 8) Lock the screen on login (you had it this way)
    hl.exec_cmd("hyprlock")

    -- 9) Land on the middle workspace of every monitor (see conf/workspaces.lua).
    -- The "default = true" rules already say this and are enough for the other
    -- outputs, but Hyprland has created and focused workspace 1 on the primary
    -- one before it ever reads them, so that monitor needs to be told. Focus
    -- ends up back on DP-3, which is where it was anyway.
    -- Only monitors that are actually there: dispatching to one that is not
    -- still succeeds, and would leave its workspace sitting on another screen.
    hl.exec_cmd([[sh -c 'sleep 1
        for pair in HDMI-A-1:13 DP-2:6 DP-1:8 DP-3:3; do
            m=${pair%%:*}; ws=${pair##*:}
            hyprctl monitors -j | jq -e --arg m "$m" "any(.[]; .name==\$m)" >/dev/null 2>&1 || continue
            hyprctl dispatch focusmonitor "$m" >/dev/null 2>&1
            hyprctl dispatch workspace "$ws" >/dev/null 2>&1
        done']])
end)

-- On logout, leave the wallpaper and the shell cleaned up
hl.on("hyprland.shutdown", function()
    hl.exec_cmd("pkill -f '[l]inux-wallpaperengine'")  -- name is >15 chars, -x won't match
    hl.exec_cmd("qs kill")
end)

-- ────────────────────── AUTOMATION (new in Lua) ─────────────────────────────

-- Plugging or unplugging an output kills the layer surfaces Wallpaper Engine
-- draws on, and it never asks for new ones: the animation stops dead and the
-- still underneath is what you keep looking at. DP-1 drops its link on its own
-- every so often, which is why the wallpaper "paused itself" with nothing
-- fullscreen anywhere. The script debounces the burst of events and restarts it.
local function wallpaper_refresh()
    hl.exec_cmd(V.wallpaper .. " refresh")
end

hl.on("monitor.added", wallpaper_refresh)
hl.on("monitor.removed", wallpaper_refresh)

-- When a game goes fullscreen, pop a native Hyprland notification (handy to
-- confirm tearing / VRR kicked in).
hl.on("window.fullscreen", function(w)
    if w == nil then return end
    local cls = w.class or ""
    if cls:match("^steam_app_") then
        hl.notification.create({
            text = "Game went fullscreen: tearing and VRR active",
            timeout = 2500,
            icon = "ok",
        })
    end
end)

-- Changing the wallpaper makes matugen rewrite conf/colors.lua. On reload,
-- refresh the terminal palette too.
--
-- A reload also re-runs conf/look.lua, which wipes anything set at runtime with
-- hyprctl. That is what broke game mode: scripts/gamemode.sh turns the effects
-- off, then restarts the wallpaper, matugen rewrites conf/colors.lua, Hyprland
-- reloads, and every effect comes straight back a few seconds later. So if game
-- mode is still marked as on, put its settings back after the reload.
hl.on("config.reloaded", function()
    hl.exec_cmd("pkill -USR1 -x kitty")

    local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local f = io.open(state .. "/hypr/gamemode", "r")
    if f == nil then return end
    local mode = f:read("l")
    f:close()
    if mode ~= "on" then return end

    hl.config({
        animations = { enabled = false },
        general    = { gaps_in = 0, gaps_out = 0 },
        decoration = {
            rounding         = 0,
            inactive_opacity = 1.0,
            blur   = { enabled = false },
            shadow = { enabled = false },
            glow   = { enabled = false },
        },
    })
end)
