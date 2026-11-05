pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User-tweakable settings for the shell.
//
// Two doors, one room: edit the defaults below and save (the shell reloads
// itself), or change them from the settings panel — `qs ipc call settings
// toggle` — which writes *only what you changed* to settings.json next to this
// file. Delete settings.json and everything falls back to what is written here,
// so the defaults in this file are always the real ones.
Singleton {
    id: root

    // What settings.json carries, if anything. Assigned from the FileView
    // handlers rather than bound to text(): a binding on text() is not
    // re-evaluated when the file changes, so the shell would keep the values it
    // read at startup (the same trap documented in Theme.qml and Sys.qml).
    property var overrides: ({})

    FileView {
        id: file
        path: Qt.resolvedUrl("settings.json").toString().replace("file://", "")
        watchChanges: true
        blockLoading: true
        // No file at all is the normal state, not a failure worth logging.
        printErrors: false
        onLoaded: root.parse()
        onFileChanged: reload()
    }

    function parse() {
        try {
            const t = file.text().trim();
            root.overrides = t === "" ? ({}) : JSON.parse(t);
        } catch (e) {
            console.warn("[Config] settings.json is not valid JSON, ignoring it:", e);
            root.overrides = ({});
        }
    }

    // Reading root.overrides here is what makes every property below
    // re-evaluate the moment the file changes.
    function value(key, fallback) {
        const o = root.overrides;
        return (o && o[key] !== undefined) ? o[key] : fallback;
    }

    // Write one key. Everything absent from the file keeps following its default.
    function set(key, v) {
        const next = {};
        for (const k in root.overrides) next[k] = root.overrides[k];
        next[key] = v;
        root.overrides = next;
        file.setText(JSON.stringify(next, null, 4) + "\n");
    }

    // Back to the default for one key: the key leaves the file entirely rather
    // than being written with the default value, so changing the default here
    // later still reaches it.
    function unset(key) {
        const next = {};
        for (const k in root.overrides) if (k !== key) next[k] = root.overrides[k];
        root.overrides = next;
        file.setText(JSON.stringify(next, null, 4) + "\n");
    }

    function resetAll() {
        root.overrides = ({});
        file.setText("{}\n");
    }

    // True when the panel is showing something other than the default, which is
    // what the little "reset" arrows key off.
    function isSet(key) {
        return root.overrides && root.overrides[key] !== undefined;
    }

    // Workspaces that are always shown on each monitor, even when empty.
    // Keep these in sync with conf/workspaces.lua on the Hyprland side. Not
    // exposed for editing in the panel for that reason: the two would drift.
    readonly property var workspacesByMonitor: ({
        "DP-3":     [1, 2, 3, 4, 5],
        "DP-2":     [6, 7],
        "DP-1":     [8],
        "HDMI-A-1": [11, 12, 13, 14, 15]
    })

    // 12-hour clock ("1:05 PM") vs 24-hour ("13:05")
    property bool clock12h: value("clock12h", true)

    // Show AM/PM next to the time
    property bool clockShowMeridiem: value("clockShowMeridiem", true)

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
    property real barTint: value("barTint", 0.22)
    property real barOpacity: value("barOpacity", 0.78)
    property real panelTint: value("panelTint", 0.12)

    // Show upload/download speed next to the network icon
    property bool showNetSpeed: value("showNetSpeed", true)

    // Show notification toasts only on the monitor with focus
    property bool toastsOnFocusedOnly: value("toastsOnFocusedOnly", true)

    // Let urgency=critical through while Do Not Disturb is on.
    // Off, because plenty of apps mark routine notifications critical and the
    // silence stopped meaning anything. Turn it on if you'd rather never miss
    // one — they still land in history either way, DND only hides the toast.
    property bool dndAllowsCritical: value("dndAllowsCritical", false)

    // Bluetooth page: list nearby devices that only advertise an address.
    // Off, because those are almost always phones, TVs and beacons doing BLE
    // advertising, and they bury the one device you are trying to pair.
    property bool btShowUnnamed: value("btShowUnnamed", false)

    // Toast when a paired device connects or drops, and once on low battery
    property bool btNotify: value("btNotify", true)
}
