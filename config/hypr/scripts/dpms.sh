#!/usr/bin/env bash
# Turn the screens off/on. Works with both the Lua config (0.55+) and the old
# hyprlang one, so hypridle behaves either way.
set -uo pipefail

case "${1:-on}" in
    off) hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })' >/dev/null 2>&1 ||
         hyprctl dispatch dpms off >/dev/null 2>&1 ;;
    on)  hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'  >/dev/null 2>&1 ||
         hyprctl dispatch dpms on  >/dev/null 2>&1 ;;
    *)   echo "Usage: dpms.sh [on|off]" >&2; exit 1 ;;
esac
