#!/usr/bin/env bash
# Wi-Fi networks through nmcli: connect, ask for the password, forget.
set -uo pipefail
THEME="$HOME/.config/rofi/themes/list.rasi"
pkill -x rofi && exit 0

notify() { notify-send -a "WiFi" -t 3000 "$1" "${2:-}"; }

WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
if [[ -z "$WIFI_DEV" ]]; then
    echo "This machine has no Wi-Fi" | rofi -dmenu -p "Wi-Fi" -theme "$THEME" >/dev/null
    exit 0
fi

RADIO=$(nmcli radio wifi)
if [[ "$RADIO" == "disabled" ]]; then
    SEL=$(printf '󰖩  Turn Wi-Fi on\n󰅖  Cancel\n' | rofi -dmenu -i -p "Wi-Fi is off" -theme "$THEME")
    [[ "$SEL" == *"Turn Wi-Fi on" ]] && { nmcli radio wifi on; notify "Wi-Fi enabled"; }
    exit 0
fi

nmcli device wifi rescan >/dev/null 2>&1 &

CURRENT=$(nmcli -t -f ACTIVE,SSID device wifi | awk -F: '$1=="yes"{print $2; exit}')

menu() {
    printf '\0message\x1f%s\n' "${CURRENT:+Connected to <b>$CURRENT</b>}"
    nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list |
    awk -F: '$4 != "" {
        sig=$2; sec=($3=="" ? "open" : $3);
        icon = (sig>75 ? "󰤨" : sig>50 ? "󰤥" : sig>25 ? "󰤢" : "󰤟");
        mark = ($1=="*" ? " ✓" : "");
        printf "%s  %s%s  (%s%%, %s)\n", icon, $4, mark, sig, sec
    }' | awk '!seen[$0]++'
    printf '󰑓  Rescan\n'
    printf '󰖪  Turn Wi-Fi off\n'
    printf '󰒓  Network settings\n'
}

SEL=$(menu | rofi -dmenu -i -p "Wi-Fi" -theme "$THEME")
[[ -z "$SEL" ]] && exit 0

case "$SEL" in
    *"Rescan")            nmcli device wifi rescan >/dev/null 2>&1; exec "$0" ;;
    *"Turn Wi-Fi off")    nmcli radio wifi off; notify "Wi-Fi disabled"; exit 0 ;;
    *"Network settings")  setsid nm-connection-editor >/dev/null 2>&1 & exit 0 ;;
esac

# "󰤨  SSID ✓  (85%, WPA2)"  →  SSID
SSID=$(sed -E 's/^[^ ]+  //; s/ ✓//; s/  \([0-9]+%.*\)$//' <<< "$SEL")
[[ -z "$SSID" ]] && exit 0

if [[ "$SSID" == "$CURRENT" ]]; then
    SEL2=$(printf '󰅖  Disconnect\n󰗨  Forget this network\n󰜺  Nothing\n' |
            rofi -dmenu -i -p "$SSID" -theme "$THEME")
    case "$SEL2" in
        *"Disconnect")    nmcli connection down id "$SSID" >/dev/null && notify "Disconnected" "$SSID" ;;
        *"Forget"*)       nmcli connection delete id "$SSID" >/dev/null && notify "Network forgotten" "$SSID" ;;
    esac
    exit 0
fi

# Already saved? connect straight away. Otherwise ask for the password
if nmcli -t -f NAME connection show | grep -qxF "$SSID"; then
    nmcli connection up id "$SSID" >/dev/null 2>&1 &&
        notify "Connected" "$SSID" || notify "Could not connect" "$SSID"
    exit 0
fi

PASS=$(rofi -dmenu -password -i -p "Password for $SSID" -theme "$THEME" </dev/null)
if [[ -z "$PASS" ]]; then
    nmcli device wifi connect "$SSID" ifname "$WIFI_DEV" >/dev/null 2>&1 &&
        notify "Connected" "$SSID" || notify "Could not connect" "$SSID"
else
    nmcli device wifi connect "$SSID" password "$PASS" ifname "$WIFI_DEV" >/dev/null 2>&1 &&
        notify "Connected" "$SSID" || notify "Wrong password or out of range" "$SSID"
fi
