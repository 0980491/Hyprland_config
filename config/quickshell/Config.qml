pragma Singleton
import QtQuick
import Quickshell

// User-tweakable settings for the shell. Edit here, save, done — the shell
// reloads itself.
Singleton {
    // Workspaces that are always shown on each monitor, even when empty.
    // Keep these in sync with conf/workspaces.lua on the Hyprland side.
    readonly property var workspacesByMonitor: ({
        "DP-3":     [1, 2, 3, 4, 5],
        "DP-2":     [6, 7],
        "DP-1":     [8],
        "HDMI-A-1": [11, 12, 13, 14, 15]
    })

    // 12-hour clock ("1:05 PM") vs 24-hour ("13:05")
    readonly property bool clock12h: true

    // Show AM/PM next to the time
    readonly property bool clockShowMeridiem: true

    // mm:ss out of microseconds (what MPRIS reports)
    function formatTime(us) {
        const total = Math.max(0, Math.floor(us / 1000000));
        const m = Math.floor(total / 60);
        const sec = total % 60;
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    // Bar and panel background.
    //   barTint    how much of the wallpaper's accent is mixed into the bar
    //              (0 = plain dark surface, 0.35 = strongly tinted)
    //   barOpacity how much of the blurred wallpaper shows through
    readonly property real barTint: 0.22
    readonly property real barOpacity: 0.78
    readonly property real panelTint: 0.12

    // Show upload/download speed next to the network icon
    readonly property bool showNetSpeed: true

    // Show notification toasts only on the monitor with focus
    readonly property bool toastsOnFocusedOnly: true

    // Let urgency=critical through while Do Not Disturb is on.
    // Off, because plenty of apps mark routine notifications critical and the
    // silence stopped meaning anything. Turn it on if you'd rather never miss
    // one — they still land in history either way, DND only hides the toast.
    readonly property bool dndAllowsCritical: false
}
