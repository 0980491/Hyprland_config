#!/usr/bin/env bash
# Clipboard history (cliphist). Alt+Delete removes an entry, Alt+c wipes it all.
set -uo pipefail
pkill -x rofi && exit 0

SEL=$(cliphist list | rofi -dmenu -i -p "Clipboard" \
        -theme "/home/ooooooooo/.config/rofi/themes/clipboard.rasi" \
        -kb-custom-1 "Alt+Delete" -kb-custom-2 "Alt+c")
RET=$?

case $RET in
    0)  [[ -n "$SEL" ]] && cliphist decode <<< "$SEL" | wl-copy ;;
    10) [[ -n "$SEL" ]] && cliphist delete <<< "$SEL" ;;
    11) cliphist wipe ;;
esac
