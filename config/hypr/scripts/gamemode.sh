#!/usr/bin/env bash
# Game mode: drops every effect that costs GPU and stops the session from
# blanking or suspending while you play with a controller.
# It does not touch notifications — see the note further down.
# Same key toggles it back (SUPER+F12).
set -uo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/gamemode"
mkdir -p "$(dirname "$STATE")"

# hyprctl eval runs Lua in the live instance (Lua config, 0.55+).
# If the session still runs hyprlang, fall back to hyprctl keyword.
hy() { # hy "<lua>" "<keyword fallback>"
    hyprctl eval "$1" >/dev/null 2>&1 || hyprctl keyword $2 >/dev/null 2>&1 || true
}

if [[ "$(cat "$STATE" 2>/dev/null)" == "on" ]]; then
    # ── Back to normal ──
    # Mark it off first: the config.reloaded hook in conf/autostart.lua reads
    # this file, and would put game mode straight back otherwise.
    echo off > "$STATE"

    # A plain reload re-applies conf/look.lua exactly as written. Listing the
    # values here by hand drifted out of sync with it: this branch used to turn
    # the glow back ON and set rounding to 10, when look.lua has the glow
    # disabled and rounding at 8.
    hyprctl reload >/dev/null 2>&1

    pgrep -f '[h]ypridle' >/dev/null || (setsid hypridle >/dev/null 2>&1 &)
    SKIP_THEME=1 WE_FPS=60 "$HOME/.config/hypr/scripts/wallpaper.sh" restore >/dev/null 2>&1 &

    notify-send -a "Game mode" -t 2500 "Game mode: OFF" "effects and idle handling restored"
else
    # ── Performance mode ──
    hy 'hl.config({ animations = { enabled = false } })'                  "animations:enabled 0"
    hy 'hl.config({ decoration = { blur = { enabled = false } } })'       "decoration:blur:enabled 0"
    hy 'hl.config({ decoration = { shadow = { enabled = false } } })'     "decoration:shadow:enabled 0"
    hy 'hl.config({ decoration = { glow = { enabled = false } } })'       "decoration:glow:enabled 0"
    hy 'hl.config({ decoration = { rounding = 0 } })'                     "decoration:rounding 0"
    hy 'hl.config({ decoration = { inactive_opacity = 1.0 } })'           "decoration:inactive_opacity 1.0"
    hy 'hl.config({ general = { gaps_in = 0, gaps_out = 0 } })'           "general:gaps_in 0"

    # don't blank or suspend while playing with a controller
    pkill -f '[h]ypridle' 2>/dev/null || true

    # Notifications are left alone on purpose. This used to toggle do-not-disturb
    # on the way in and again on the way out, which turned DND *off* when you
    # already had it on before starting to play. Silence them with the quick
    # settings tile if you want them quiet.

    # Kill the animated wallpaper outright. Dropping it to 15 fps still left
    # it rendering, and behind a fullscreen game it is not even on screen.
    "$HOME/.config/hypr/scripts/wallpaper.sh" static >/dev/null 2>&1 &

    echo on > "$STATE"
    notify-send -a "Game mode" -t 2500 "Game mode: ON" "no blur, no animations, no suspend"
fi
