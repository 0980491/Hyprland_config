import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Focused window on this monitor: app icon + elided title.
BarItem {
    id: root
    required property var monitorScreen

    readonly property var hMonitor: Hyprland.monitorFor(monitorScreen)
    readonly property var win: {
        const active = Hyprland.activeToplevel;
        if (!active) return null;
        if (!hMonitor || !active.monitor) return active;
        return active.monitor.id === hMonitor.id ? active : null;
    }

    readonly property string appClass: win && win.lastIpcObject ? (win.lastIpcObject.class || "") : ""

    visible: win !== null
    tooltip: win ? win.title : ""
    implicitWidth: Math.min(row.implicitWidth + padding * 2, 460)

    onClicked: Hyprland.dispatch("focuswindow address:" + (win ? win.address : ""))
    onMiddleClicked: Hyprland.dispatch("killactive")

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: {
                const c = root.appClass.toLowerCase();
                if (c.includes("kitty") || c.includes("foot") || c.includes("term")) return "";
                if (c.includes("firefox") || c.includes("zen") || c.includes("brave") || c.includes("chrom")) return "";
                if (c.includes("code") || c.includes("cursor")) return "";
                if (c.includes("dolphin") || c.includes("nautilus") || c.includes("thunar")) return "";
                if (c.includes("discord") || c.includes("vesktop")) return "";
                if (c.includes("steam")) return "";
                if (c.includes("spotify") || c.includes("music")) return "";
                if (c.includes("mpv") || c.includes("vlc")) return "";
                if (c.includes("obs")) return "";
                if (c.includes("blender") || c.includes("resolve") || c.includes("gimp") || c.includes("krita")) return "";
                if (c.includes("prusa") || c.includes("fusion") || c.includes("cad")) return "";
                return "";
            }
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            Layout.maximumWidth: 380
            Layout.preferredWidth: Math.min(implicitWidth, 380)
            text: root.win ? root.win.title : ""
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
    }
}
