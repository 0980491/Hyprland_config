#!/usr/bin/env bash
# App launcher. Pressing the key again closes rofi.
# The mode buttons at the bottom switch between apps / run / files / windows.
pkill -x rofi && exit 0
exec rofi -show drun -modes "drun,run,filebrowser,window" \
          -theme "$HOME/.config/rofi/themes/launcher.rasi"
