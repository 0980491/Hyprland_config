#!/usr/bin/env bash
# Caffeine: keep the machine awake.
#
# hypridle suspends after 1 h of *input* idleness, which has nothing to do with
# whether the box is busy — a long unattended job would get cut off. This holds
# a systemd inhibitor for as long as it runs, and hypridle honours it because
# hypridle.conf keeps ignore_systemd_inhibit = false. logind refuses the suspend
# too (mode=block), so it is covered from both ends.
#
#   caffeine.sh            → toggle (what the bar button does)
#   caffeine.sh on|off
#   caffeine.sh status     → prints on/off, exits 0 when on
#   caffeine.sh sync       → drop a stale state file (run at session start)
set -uo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/caffeine"
TAG="hypr-caffeine"                                # how we find our own process
mkdir -p "$(dirname "$STATE")"

running() { pgrep -f "[s]ystemd-inhibit.*$TAG" >/dev/null 2>&1; }

start() {
    if ! running; then
        setsid systemd-inhibit \
            --what=idle:sleep --mode=block \
            --who="Caffeine" --why="$TAG" \
            sleep infinity >/dev/null 2>&1 &
    fi
    echo on > "$STATE"
}

stop() {
    pkill -f "[s]ystemd-inhibit.*$TAG" 2>/dev/null || true
    echo off > "$STATE"
}

case "${1:-toggle}" in
    on)
        start
        notify-send -a "Caffeine" -t 2500 "Caffeine: ON" "suspend is held off"
        ;;
    off)
        stop
        notify-send -a "Caffeine" -t 2500 "Caffeine: OFF" "suspends again after 1 h idle"
        ;;
    status)
        running && { echo on; exit 0; }
        echo off; exit 1
        ;;
    sync)
        # The inhibitor dies with the session, so a state file left saying "on"
        # from last login would light the button up for nothing.
        running || echo off > "$STATE"
        ;;
    toggle)
        if running; then
            "$0" off
        else
            "$0" on
        fi
        ;;
    *)
        echo "usage: ${0##*/} [toggle|on|off|status|sync]" >&2
        exit 2
        ;;
esac
