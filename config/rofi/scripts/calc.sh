#!/usr/bin/env bash
# Calculator backed by qalc: type an expression, Enter copies the result.
set -uo pipefail
pkill -x rofi && exit 0

HIST="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-calc-history"
touch "$HIST"

EXPR=$(tac "$HIST" | rofi -dmenu -i -p "=" -theme "/home/ooooooooo/.config/rofi/themes/list.rasi" \
        -mesg "Examples: 5 GiB to MiB · 20% of 350 · sqrt(2) · 100 USD to EUR")
[[ -z "$EXPR" ]] && exit 0

RES=$(qalc -t "$EXPR" 2>/dev/null)
[[ -z "$RES" ]] && { notify-send -a Calc "Could not parse that" "$EXPR"; exit 1; }

echo "$EXPR" >> "$HIST"
tail -n 200 "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"

CHOICE=$(printf '%s\n' "$RES" "↻ New expression" | rofi -dmenu -i -p "$EXPR =" -theme "/home/ooooooooo/.config/rofi/themes/list.rasi")
case "$CHOICE" in
    "↻ New expression") exec "$0" ;;
    "") exit 0 ;;
    *) printf '%s' "$RES" | wl-copy; notify-send -a Calc -t 2000 "$EXPR = $RES" "copied" ;;
esac
