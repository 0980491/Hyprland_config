#!/usr/bin/env bash
# Bluetooth through bluetoothctl: pair, connect, trust, forget.
set -uo pipefail
THEME="$HOME/.config/rofi/themes/list.rasi"
pkill -x rofi && exit 0

notify() { notify-send -a "Bluetooth" -t 3000 "$1" "${2:-}"; }

if ! command -v bluetoothctl >/dev/null; then
    notify "bluez-utils is missing"; exit 1
fi

POWER=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}')
if [[ "$POWER" != "yes" ]]; then
    SEL=$(printf '󰂯  Turn Bluetooth on\n󰅖  Cancel\n' | rofi -dmenu -i -p "Bluetooth is off" -theme "$THEME")
    if [[ "$SEL" == *"Turn Bluetooth on"* ]]; then
        rfkill unblock bluetooth 2>/dev/null
        bluetoothctl power on >/dev/null && notify "Bluetooth enabled"
        sleep 1; exec "$0"
    fi
    exit 0
fi

# Scan in the background while the menu is open
(bluetoothctl --timeout 12 scan on >/dev/null 2>&1 &) >/dev/null 2>&1

dev_line() { # MAC NAME  → a line with a state icon
    local mac="$1" name="$2" info conn paired icon
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    conn=$(awk '/Connected:/{print $2; exit}' <<< "$info")
    paired=$(awk '/Paired:/{print $2; exit}' <<< "$info")
    if [[ "$conn" == "yes" ]]; then icon="󰂱"; name="$name ✓"
    elif [[ "$paired" == "yes" ]]; then icon="󰂲"
    else icon="󰂰"; fi
    printf '%s  %s\t%s\n' "$icon" "$name" "$mac"
}

MAP="$(mktemp)"; trap 'rm -f "$MAP"' EXIT

menu() {
    printf '\0message\x1fEnter connects or disconnects · scanning…\n'
    while read -r _ mac name; do
        [[ -z "$mac" ]] && continue
        line="$(dev_line "$mac" "$name")"
        printf '%s\n' "$line" >> "$MAP"
        cut -f1 <<< "$line"
    done < <(bluetoothctl devices Paired 2>/dev/null)
    while read -r _ mac name; do
        [[ -z "$mac" ]] && continue
        grep -qF "	$mac" "$MAP" && continue
        line="$(dev_line "$mac" "$name")"
        printf '%s\n' "$line" >> "$MAP"
        cut -f1 <<< "$line"
    done < <(bluetoothctl devices 2>/dev/null)
    printf '󰑓  Scan for devices\n'
    printf '󰂲  Turn Bluetooth off\n'
}

SEL=$(menu | rofi -dmenu -i -p "Bluetooth" -theme "$THEME")
[[ -z "$SEL" ]] && exit 0

case "$SEL" in
    *"Scan for devices")    bluetoothctl --timeout 8 scan on >/dev/null 2>&1; exec "$0" ;;
    *"Turn Bluetooth off")  bluetoothctl power off >/dev/null && notify "Bluetooth disabled"; exit 0 ;;
esac

MAC=$(grep -F "$SEL	" "$MAP" | head -1 | cut -f2)
[[ -z "$MAC" ]] && exit 0

INFO=$(bluetoothctl info "$MAC")
CONN=$(awk '/Connected:/{print $2; exit}' <<< "$INFO")
PAIRED=$(awk '/Paired:/{print $2; exit}' <<< "$INFO")

if [[ "$CONN" == "yes" ]]; then
    ACT=$(printf '󰅖  Disconnect\n󰗨  Forget\n󰜺  Nothing\n' | rofi -dmenu -i -p "${SEL}" -theme "$THEME")
    case "$ACT" in
        *Disconnect) bluetoothctl disconnect "$MAC" >/dev/null && notify "Disconnected" ;;
        *Forget)     bluetoothctl remove "$MAC" >/dev/null && notify "Device forgotten" ;;
    esac
    exit 0
fi

if [[ "$PAIRED" != "yes" ]]; then
    notify "Pairing…" "$SEL"
    bluetoothctl pair "$MAC" >/dev/null 2>&1
    bluetoothctl trust "$MAC" >/dev/null 2>&1
fi

if bluetoothctl connect "$MAC" >/dev/null 2>&1; then
    notify "Connected" "$SEL"
else
    notify "Could not connect" "$SEL"
fi
