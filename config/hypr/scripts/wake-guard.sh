#!/usr/bin/env bash
# Wake guard: power the PC back off after a spurious power-on.
#
# Every few weeks the PC turns itself back on 30–65 s after a clean poweroff.
# Home Assistant is not sending WoL at those times; the prime suspect is the
# r8169 NIC's Wake-on-LAN misfiring (see the vault, Environment/PC de
# escritorio). WoL stays on because it is how the PC is powered on remotely, so
# instead this catches the bad boots: if this boot started less than WINDOW s
# after a clean poweroff and nobody touches anything for GRACE s, power off.
#
# "Touching" is any Wayland input (keyboard, mouse, Sunshine/Moonlight), read
# through a throwaway hypridle that ignores every inhibitor.
#
#   wake-guard.sh          → run at session start (conf/autostart.lua)
#   wake-guard.sh check    → only print whether this boot looks spurious
#   wake-guard.sh test     → pretend it is, wait 20 s, print instead of powering off
set -uo pipefail

WINDOW=90                       # s from the previous poweroff to this boot
GRACE=300                       # s to wait for input before powering off
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
LOG="$STATE/wake-guard.log"
mkdir -p "$STATE"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }

# Seconds between the end of the previous boot and the start of this one, or
# nothing if the previous boot did not end in a poweroff (reboot, crash, none).
gap_after_poweroff() {
    journalctl -b -1 -n 400 -q --no-pager 2>/dev/null \
        | grep -q 'systemd-poweroff.service: Deactivated' || return 0
    journalctl --list-boots -o json --no-pager 2>/dev/null | python3 -c '
import json, sys
b = {x["index"]: x for x in json.load(sys.stdin)}
if -1 in b and 0 in b:
    print((b[0]["first_entry"] - b[-1]["last_entry"]) // 1000000)'
}

mode="${1:-run}"
gap=$(gap_after_poweroff)

if [ "$mode" = check ]; then
    if [ -n "$gap" ] && [ "$gap" -lt "$WINDOW" ]; then
        echo "spurious: booted ${gap}s after a clean poweroff"
    else
        echo "normal: ${gap:-previous boot did not end in a poweroff}${gap:+s after poweroff}"
    fi
    exit 0
fi

if [ "$mode" = test ]; then
    GRACE=20
elif [ -z "$gap" ] || [ "$gap" -ge "$WINDOW" ]; then
    exit 0
else
    log "booted ${gap}s after a clean poweroff, waiting ${GRACE}s for input"
fi

flag=$(mktemp -u "${XDG_RUNTIME_DIR:-/tmp}/wake-guard.XXXXXX")
conf=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/wake-guard.XXXXXX.conf")
# timeout = 1 marks the session idle after 1 s without input, so any later
# input fires on-resume. Inhibitors are ignored: a video or game rule holding
# idle off must not hide input, and the real hypridle owns sleep handling.
# on-timeout must be set: with none, hypridle 0.1.8 skips on-resume too
# ("Skipping onResumed: onTimeout was inhibited").
cat > "$conf" <<EOF
general {
    ignore_dbus_inhibit = true
    ignore_systemd_inhibit = true
    ignore_wayland_inhibit = true
    inhibit_sleep = 0
}
listener {
    timeout = 1
    ignore_inhibit = true
    on-timeout = true
    on-resume = touch $flag
}
EOF
hypridle -q -c "$conf" &
watcher=$!
trap 'kill $watcher 2>/dev/null; rm -f "$conf" "$flag"' EXIT

notify-send -a "Wake guard" -u critical "Spurious power-on" \
    "The PC turned itself on right after shutting down. It will power off in $((GRACE / 60)) min unless you touch the keyboard or mouse." 2>/dev/null

for _ in $(seq "$GRACE"); do
    if [ -e "$flag" ]; then
        [ "$mode" = test ] && echo "input seen, cancelled" || log "input seen, staying on"
        notify-send -a "Wake guard" "Staying on" "Input detected, the automatic poweroff is cancelled." 2>/dev/null
        exit 0
    fi
    sleep 1
done

if [ "$mode" = test ]; then
    echo "no input in ${GRACE}s: would power off now"
else
    log "no input in ${GRACE}s, powering off"
    systemctl poweroff
fi
