#!/usr/bin/env bash
# Emoji picker: copies the emoji to the clipboard.
set -uo pipefail
LIST="$HOME/.config/rofi/emoji.txt"
pkill -x rofi && exit 0
[[ -f "$LIST" ]] || { notify-send "Emoji" "Missing $LIST"; exit 1; }

SEL=$(rofi -dmenu -i -p "Emoji" -theme "/home/ooooooooo/.config/rofi/themes/emoji.rasi" < "$LIST")
[[ -z "$SEL" ]] && exit 0
printf '%s' "${SEL%% *}" | wl-copy
notify-send -a Emoji -t 1500 "Copied: ${SEL%% *}"
