#!/usr/bin/env bash
# Power menu with confirmation. Replaces wlogout (still installed if you want it).
# Uses its own compact theme: no search box, uptime as the caption.
set -uo pipefail
THEME="$HOME/.config/rofi/themes/power.rasi"
CONFIRM_THEME="$HOME/.config/rofi/themes/power-confirm.rasi"
pkill -x rofi && exit 0

UP=$(uptime -p 2>/dev/null | sed 's/^up //')

# The question goes in -mesg, not -p: power.rasi does not draw the input bar.
# No leading spaces on the rows: power-confirm.rasi centres them, and the two
# they used to carry to fake an indent would push both off centre.
confirm() { # $1 = what we are about to do
    local sel
    sel=$(printf 'Yes\nNo\n' |
          rofi -dmenu -i -theme "$CONFIRM_THEME" -selected-row 1 -u 0 \
               -mesg "<b>$1?</b>")
    [[ "$sel" == "Yes" ]]
}

# -u 4 tints "Power off" with the error colour, so the destructive row reads as one.
SEL=$(printf '󰌾  Lock\n󰍃  Log out\n󰤄  Suspend\n󰜉  Reboot\n󰐥  Power off\n󱄄  Restart the shell\n' |
      rofi -dmenu -i -theme "$THEME" -u 4 -mesg "󰅐  Up for ${UP:-?}")

case "$SEL" in
    *Lock)                exec hyprlock ;;
    *"Log out")
        confirm "Log out" || exit 0
        hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null ||
        hyprctl dispatch exit 2>/dev/null ||
        loginctl terminate-user "" ;;
    *Suspend)             hyprlock & sleep 0.4; systemctl suspend ;;
    *Reboot)              confirm "Reboot" && systemctl reboot ;;
    *"Power off")         confirm "Power off" && systemctl poweroff ;;
    *"Restart the shell") qs kill 2>/dev/null; sleep 0.5; setsid qs -d -n >/dev/null 2>&1 & ;;
esac
