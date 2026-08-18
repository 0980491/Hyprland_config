#!/usr/bin/env bash
# Screenshots: region, monitor, window, or region + editor (satty).
# Always copies to the clipboard AND saves the file.
#
#   screenshot.sh region | monitor | window | edit | menu
set -uo pipefail

DIR="$HOME/General/Photos/Hyprshot"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

notify_shot() {
    notify-send -a "Screenshot" -i "$1" -t 4000 \
        "Screenshot saved" "$(basename "$1")\nCopied to the clipboard"
}

# Freeze-free region select with a themed selection box
region() {
    local geom
    geom=$(slurp -d -b '#19120d99' -c '#ffb784ff' -w 2) || exit 0
    grim -g "$geom" "$1"
}

case "${1:-region}" in
    region)
        region "$FILE" || exit 1
        wl-copy < "$FILE"
        notify_shot "$FILE"
        ;;
    monitor)
        MON=$(hyprctl activeworkspace -j | jq -r '.monitor')
        grim -o "$MON" "$FILE"
        wl-copy < "$FILE"
        notify_shot "$FILE"
        ;;
    window)
        GEOM=$(hyprctl activewindow -j |
               jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$GEOM" "$FILE"
        wl-copy < "$FILE"
        notify_shot "$FILE"
        ;;
    edit)
        # Region → satty to crop, draw arrows, add text or blur things out.
        # Enter saves to $FILE and quits; Ctrl+C copies without saving.
        TMP=$(mktemp --suffix=.png)
        region "$TMP" || { rm -f "$TMP"; exit 1; }
        satty -f "$TMP" -o "$FILE" \
              --copy-command wl-copy \
              --actions-on-enter save-to-file \
              --early-exit save
        rm -f "$TMP"
        [[ -s "$FILE" ]] && { wl-copy < "$FILE"; notify_shot "$FILE"; }
        ;;
    menu)
        THEME="$HOME/.config/rofi/themes/list.rasi"
        SEL=$(printf '󰆞  Region\n󰃉  Region and annotate\n󰍹  Whole monitor\n󰖯  Focused window\n󰃰  Region after 5 s\n' |
              rofi -dmenu -i -p "Screenshot" -theme "$THEME")
        case "$SEL" in
            *"Region and annotate") exec "$0" edit ;;
            *"Region after 5 s")    sleep 5; exec "$0" region ;;
            *"Region")              exec "$0" region ;;
            *"Whole monitor")       exec "$0" monitor ;;
            *"Focused window")      exec "$0" window ;;
        esac
        ;;
    *)
        echo "Usage: screenshot.sh [region|monitor|window|edit|menu]" >&2
        exit 1
        ;;
esac
