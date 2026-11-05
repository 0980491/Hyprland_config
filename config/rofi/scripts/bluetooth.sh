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

# BlueZ drops unpaired devices from its cache the moment discovery stops, so a
# short --timeout scan purges its own findings before the menu can list them.
# Discovery has to stay up across the re-exec and be torn down explicitly.
SCAN_PID="${XDG_RUNTIME_DIR:-/tmp}/rofi-bt-scan.pid"

scan_alive() {
    [[ -f "$SCAN_PID" ]] && kill -0 "$(cat "$SCAN_PID" 2>/dev/null)" 2>/dev/null
}

start_scan() {
    scan_alive && return 0
    # setsid detaches the scan so it outlives the exec, and the child records
    # its own pid because $! would only ever name the setsid wrapper.
    setsid bash -c 'echo $$ > "'"$SCAN_PID"'"; exec bluetoothctl --timeout 180 scan on' \
        >/dev/null 2>&1 &
    sleep 1
}

stop_scan() {
    if [[ -f "$SCAN_PID" ]]; then
        kill "$(cat "$SCAN_PID" 2>/dev/null)" 2>/dev/null
        rm -f "$SCAN_PID"
    fi
    bluetoothctl scan off >/dev/null 2>&1
}

start_scan

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
[[ -z "$SEL" ]] && { stop_scan; exit 0; }

case "$SEL" in
    # Keep the scan running through the re-exec so findings survive the relist.
    *"Scan for devices")    start_scan; sleep 6; exec "$0" ;;
    *"Turn Bluetooth off")  stop_scan; bluetoothctl power off >/dev/null && notify "Bluetooth disabled"; exit 0 ;;
esac

MAC=$(grep -F "$SEL	" "$MAP" | head -1 | cut -f2)
[[ -z "$MAC" ]] && { stop_scan; exit 0; }

INFO=$(bluetoothctl info "$MAC")
CONN=$(awk '/Connected:/{print $2; exit}' <<< "$INFO")
PAIRED=$(awk '/Paired:/{print $2; exit}' <<< "$INFO")

if [[ "$CONN" == "yes" ]]; then
    stop_scan
    ACT=$(printf '󰅖  Disconnect\n󰗨  Forget\n󰜺  Nothing\n' | rofi -dmenu -i -p "${SEL}" -theme "$THEME")
    case "$ACT" in
        *Disconnect) bluetoothctl disconnect "$MAC" >/dev/null && notify "Disconnected" ;;
        *Forget)     bluetoothctl remove "$MAC" >/dev/null && notify "Device forgotten" ;;
    esac
    exit 0
fi

if [[ "$PAIRED" != "yes" ]]; then
    notify "Pairing…" "$SEL"
    # Keyboards need an agent present to answer the passkey exchange, and
    # pairing needs the adapter bondable — a bare `pair` call has neither.
    bluetoothctl --timeout 30 -- <<< "$(printf 'agent KeyboardDisplay\ndefault-agent\npairable on\npair %s\ntrust %s\nquit\n' "$MAC" "$MAC")" >/dev/null 2>&1
fi
stop_scan

if bluetoothctl connect "$MAC" >/dev/null 2>&1; then
    notify "Connected" "$SEL"
else
    notify "Could not connect" "$SEL"
fi
