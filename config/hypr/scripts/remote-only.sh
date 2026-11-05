#!/usr/bin/env bash
# ────────────────────────────── REMOTE-ONLY MODE ────────────────────────────
# Leaves HDMI-A-1 — the screen you actually watch over Moonlight — as the only
# output there is, and puts it in iPad mode.
#
# Why: Sunshine's wlgrab always grabs the FIRST monitor of the Wayland list and
# there is no way to pick one from the client. That is DP-3 whenever DP-3 is
# awake. At home DP-3 drops its DP link when you switch the panel off and the
# output disappears on its own, so Sunshine lands on HDMI-A-1 by itself; from
# outside there is nobody to press that button. Disabling the output does the
# same thing the power button did.
#
#   remote-only.sh on     iPad mode on HDMI-A-1, every other output disabled
#   remote-only.sh off    back to the layout declared in conf/monitors.lua
#   remote-only.sh status what is on right now
#
# THE DEADMAN. This box has no SSH (Sunshine + Tailscale is the only way in),
# so a capture that never comes back means no way in until you are physically
# at the desk. After disabling the outputs the script waits DEADMAN seconds and
# looks at Sunshine's log: if no client is connected by then, or the capture is
# spewing errors, it puts the screens back so a reconnect always finds
# something to grab. Disarm it with `keep` if you want the timer gone early.
set -uo pipefail

KEEP="HDMI-A-1"                 # the output the stream lives on
IPAD_MODE="2160x1620@60"        # 4:3, matches the iPad; @2x so text is legible
IPAD_POS="3000x3000"            # parked away from the others' rectangles
IPAD_SCALE=2
DEADMAN="${DEADMAN:-120}"       # seconds before the safety net fires
SUNSHINE_LOG="$HOME/.config/sunshine/sunshine.log"
STATE="${XDG_RUNTIME_DIR:-/run/user/$UID}/remote-only"

# hyprctl needs an instance; a --instance-less call picks the wrong one when a
# nested Hyprland is running (which is how config changes get tested here).
export HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t /run/user/"$UID"/hypr/ 2>/dev/null | head -1)}"

# `hyprctl keyword` is dead under the Lua config ("can't work with non-legacy
# parsers"), and monitors are not dispatchers, so eval is the only door in.
lua() { hyprctl eval "$1" >/dev/null; }

outputs() { hyprctl monitors -j | jq -r '.[].name'; }

notify() { hyprctl notify -1 2500 "rgb(a6da95)" "$1" >/dev/null 2>&1; }

client_connected() {
    [[ "$(grep -aoE 'CLIENT (CONNECTED|DISCONNECTED)' "$SUNSHINE_LOG" 2>/dev/null | tail -1)" \
        == "CLIENT CONNECTED" ]]
}

# Runs detached: the shell that armed it is long gone by the time it fires.
deadman() {
    local from_line="$1" errors
    sleep "$DEADMAN"
    [[ -f "$STATE" ]] || exit 0                      # `keep` or `off` cancelled it

    errors=$(tail -n "+$from_line" "$SUNSHINE_LOG" 2>/dev/null |
             grep -ciE 'Could not initialize|Failed to (initialize|create) (display|encoder)')

    if client_connected && (( errors < 5 )); then
        exit 0
    fi

    "$0" off
    notify "Deadman: screens restored (no stream on $KEEP)"
}

case "${1:-status}" in
on)
    lua "hl.monitor({ output = '$KEEP', mode = '$IPAD_MODE', position = '$IPAD_POS', scale = $IPAD_SCALE })"

    # Everything that is not the streaming screen goes away. Hyprland moves the
    # workspaces of a disabled output onto the surviving one and puts them back
    # when it returns, so nothing is lost — windows just pile up meanwhile.
    while read -r out; do
        [[ "$out" == "$KEEP" ]] && continue
        lua "hl.monitor({ output = '$out', disabled = true })"
    done < <(outputs)

    date +%s > "$STATE"
    setsid -f "$0" __deadman "$(( $(wc -l < "$SUNSHINE_LOG" 2>/dev/null || echo 0) + 1 ))" \
        >/dev/null 2>&1
    notify "Remote-only: $KEEP at ${IPAD_MODE%@*} @${IPAD_SCALE}x"
    ;;

off)
    rm -f "$STATE"
    # A reload replays conf/monitors.lua, which is the only place the real
    # layout is written down. Duplicating those modes here would rot.
    hyprctl reload >/dev/null
    notify "Remote-only: off, monitors back to normal"
    ;;

keep)
    rm -f "$STATE"
    notify "Remote-only: deadman disarmed"
    ;;

status)
    [[ -f "$STATE" ]] && echo "remote-only: ON (deadman armed $(date -d "@$(cat "$STATE")" '+%H:%M:%S'))" \
                      || echo "remote-only: off"
    hyprctl monitors -j | jq -r '.[] | "  \(.name)  \(.width)x\(.height)@\(.refreshRate|floor)  at \(.x)x\(.y)  scale \(.scale)"'
    ;;

__deadman) deadman "${2:-1}" ;;

*)  echo "Usage: remote-only.sh [on|off|keep|status]" >&2; exit 1 ;;
esac
