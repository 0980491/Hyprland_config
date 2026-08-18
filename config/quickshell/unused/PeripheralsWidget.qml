import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

// Battery of wireless peripherals (your Logitech mouse shows up here).
// Hidden when there are none.
BarItem {
    id: root

    readonly property var devices: Sys.peripherals
    visible: devices.length > 0
    implicitWidth: row.implicitWidth + padding * 2

    tooltip: {
        let s = "";
        for (const d of devices) {
            s += (s ? "<br>" : "") + (d.model || "peripheral") + ": " +
                 Math.round(d.percentage * 100) + "%";
        }
        return s;
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.devices

            delegate: RowLayout {
                required property var modelData
                readonly property int pct: Math.round(modelData.percentage * 100)

                spacing: 4

                Text {
                    text: {
                        const t = modelData.type;
                        if (t === UPowerDeviceType.Mouse) return "󰦋";
                        if (t === UPowerDeviceType.Keyboard) return "󰌌";
                        if (t === UPowerDeviceType.Headphones || t === UPowerDeviceType.Headset) return "󰋋";
                        return "󰂁";
                    }
                    color: parent.pct <= 15 ? Theme.error
                         : parent.pct <= 30 ? Theme.secondary
                         : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize - 2
                }

                Text {
                    text: parent.pct + "%"
                    color: parent.pct <= 15 ? Theme.error : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }
        }
    }
}
