#!/usr/bin/env bash
# Keybind cheat sheet: reads the real binds (and their descriptions) straight
# from Hyprland.
set -uo pipefail
pkill -x rofi && exit 0

hyprctl binds -j | jq -r '
  def mods(m):
    [ if (m/1|floor)%2 == 1 then "SHIFT" else empty end,
      if (m/4|floor)%2 == 1 then "CTRL"  else empty end,
      if (m/8|floor)%2 == 1 then "ALT"   else empty end,
      if (m/64|floor)%2 == 1 then "SUPER" else empty end ] | join("+");
  .[]
  | select((.description // "") != "")
  | [ ((mods(.modmask) | if . == "" then "" else . + "+" end) + (.key // ("mouse:" + (.keycode|tostring)))),
      .description ]
  | @tsv' |
  sort -u -t$'\t' -k2,2 |
  while IFS=$'\t' read -r keys desc; do printf '%-28s  %s\n' "$keys" "$desc"; done |
  rofi -dmenu -i -p "Keybinds" -theme "/home/ooooooooo/.config/rofi/themes/clipboard.rasi" \
       -mesg "SUPER+ALT mirrors every SUPER bind (for Sunshine)" >/dev/null
