#!/usr/bin/env bash
# One-line "now playing", used by hyprlock (hyprlang can't hold playerctl's
# double braces inside its own config).
command -v playerctl >/dev/null || exit 0
status=$(playerctl status 2>/dev/null) || exit 0
[[ "$status" == "Stopped" || -z "$status" ]] && exit 0
icon="󰏤"; [[ "$status" == "Playing" ]] && icon="󰎈"
line=$(playerctl metadata --format '{{ artist }} — {{ title }}' 2>/dev/null | tr -d '\n')
[[ -z "$line" || "$line" == " — " ]] && exit 0
printf '%s  %.42s\n' "$icon" "$line"
