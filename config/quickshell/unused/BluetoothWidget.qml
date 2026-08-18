import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Bluetooth: icon reflects state and how many devices are connected.
// Click opens the rofi menu; middle click toggles the adapter.
BarItem {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property var connected: {
        const out = [];
        for (const d of Bluetooth.devices.values) if (d.connected) out.push(d);
        return out;
    }

    visible: adapter !== null

    tooltip: {
        if (!enabled) return "Bluetooth is off";
        if (connected.length === 0) return "Bluetooth on, nothing connected";
        let s = "";
        for (const d of connected) {
            s += (s ? "<br>" : "") + (d.deviceName || d.name);
            if (d.batteryAvailable) s += " · " + Math.round(d.battery * 100) + "%";
        }
        return s;
    }

    onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rofi/scripts/bluetooth.sh"])
    onMiddleClicked: if (adapter) adapter.enabled = !adapter.enabled

    padding: 7
    implicitWidth: row.implicitWidth + padding * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: !root.enabled ? "󰂲" : (root.connected.length > 0 ? "󰂱" : "󰂯")
            color: !root.enabled ? Theme.outline
                 : root.connected.length > 0 ? Theme.primary
                 : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            visible: root.connected.length > 1
            text: root.connected.length
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
