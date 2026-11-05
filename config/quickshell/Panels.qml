pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Shared panel state.
//
// Behaviour, on purpose as simple as it can be:
//  · hovering a bar widget opens its panel
//  · moving the pointer off the widget AND off the panel closes it
//  · clicking closes it if it is already open (so nothing ever stays stuck)
//  · moving onto another widget switches panels straight away
//  · one panel at a time, and only on the monitor of the bar you used
//
// From outside:
//   qs ipc call panel toggle calendar|notifications|volume|resources|quicksettings|media|overview
//   (the settings window has its own target: qs ipc call settings toggle)
//   qs ipc call panel close
//   qs ipc call panel dnd
Singleton {
    id: root

    property string openPanel: ""
    property string openScreen: ""

    // Which page the settings window is showing. It lives here rather than in
    // Settings.qml because there is one of those windows per monitor and they
    // all have to agree — and because the IPC handler in shell.qml can then
    // point it at a page before opening the window.
    property string settingsPage: "general"

    // Full-screen, keyboard-driven panels must not close on hover
    readonly property bool sticky: openPanel === "overview" || openPanel === "wallpaper"
                                || openPanel === "settings"

    readonly property int openDelay: 110
    readonly property int closeDelay: 250

    function focusedScreenName() {
        const m = Hyprland.focusedMonitor;
        return m ? m.name : "";
    }

    // ── hover ──
    function hoverOpen(name, screenName) {
        if (root.sticky) return;
        closeTimer.stop();

        // switching between widgets should feel instant
        if (root.openPanel !== "") {
            root.set(name, screenName);
            return;
        }
        openTimer.pending = name;
        openTimer.pendingScreen = screenName;
        openTimer.restart();
    }

    function hoverLeave() {
        if (root.sticky) return;
        openTimer.stop();
        closeTimer.restart();
    }

    // Called by the popup while the pointer is over it
    function keepOpen() {
        if (root.sticky) return;
        closeTimer.stop();
        openTimer.stop();
    }
    function scheduleClose() {
        if (root.sticky) return;
        closeTimer.restart();
    }

    // ── click ──
    function toggle(name, screenName) {
        const scr = screenName || focusedScreenName();
        if (root.openPanel === name && root.openScreen === scr) root.close();
        else root.set(name, scr);
    }

    function set(name, screenName) {
        openTimer.stop();
        closeTimer.stop();
        root.openPanel = name;
        root.openScreen = screenName || focusedScreenName();
    }

    function close() {
        openTimer.stop();
        closeTimer.stop();
        root.openPanel = "";
        root.openScreen = "";
    }

    function isOpen(name, screenName) {
        return root.openPanel === name && root.openScreen === screenName;
    }

    Timer {
        id: openTimer
        property string pending: ""
        property string pendingScreen: ""
        interval: root.openDelay
        onTriggered: {
            root.openPanel = openTimer.pending;
            root.openScreen = openTimer.pendingScreen;
        }
    }

    Timer {
        id: closeTimer
        interval: root.closeDelay
        onTriggered: root.close()
    }
}
