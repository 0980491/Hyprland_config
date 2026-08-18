#!/usr/bin/env bash
# Night light via hyprsunset: cycles normal → warm → very warm.
set -uo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/nightlight"
mkdir -p "$(dirname "$STATE")"
CUR="$(cat "$STATE" 2>/dev/null || echo off)"

ensure_daemon() {
    pgrep -f '[h]yprsunset' >/dev/null || { setsid hyprsunset >/dev/null 2>&1 & sleep 0.6; }
}

case "$CUR" in
    off)
        ensure_daemon
        hyprctl hyprsunset temperature 4500 >/dev/null
        echo warm > "$STATE"
        notify-send -a "Night light" -t 2000 "Night light: warm" "4500 K"
        ;;
    warm)
        ensure_daemon
        hyprctl hyprsunset temperature 3200 >/dev/null
        echo verywarm > "$STATE"
        notify-send -a "Night light" -t 2000 "Night light: very warm" "3200 K"
        ;;
    *)
        ensure_daemon
        hyprctl hyprsunset identity >/dev/null
        echo off > "$STATE"
        notify-send -a "Night light" -t 2000 "Night light: off" "normal temperature"
        ;;
esac
