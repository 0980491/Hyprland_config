#!/usr/bin/env bash
# Window switcher (every window on every workspace).
pkill -x rofi && exit 0
exec rofi -show window -theme "/home/ooooooooo/.config/rofi/themes/list.rasi"
