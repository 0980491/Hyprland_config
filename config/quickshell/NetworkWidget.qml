import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// Network state (wired or Wi-Fi) plus live throughput.
// Click opens quick settings, right click the Wi-Fi menu.
BarItem {
    id: root
    required property string screenName

    readonly property var wired: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wired && d.connected) return d;
        return null;
    }
    readonly property var wifi: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi) return d;
        return null;
    }
    readonly property var wifiNet: wifi && wifi.connected ? wifi.network : null
    readonly property int signal: wifiNet && wifiNet.signalStrength !== undefined ? wifiNet.signalStrength : 0

    tooltip: (wired ? "Wired connection" + (wired.address ? "<br>" + wired.address : "")
           : wifiNet ? wifiNet.name + " (" + signal + "%)"
           : "Offline") + "<br>↓ " + Sys.rate(Sys.rx) + "   ↑ " + Sys.rate(Sys.tx)

    onClicked: Panels.toggle("quicksettings", root.screenName)
    onRightClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rofi/scripts/wifi.sh"])

    implicitWidth: row.implicitWidth + padding * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.wired ? "󰈀"
                : root.wifiNet ? (root.signal > 75 ? "󰤨" : root.signal > 50 ? "󰤥"
                                 : root.signal > 25 ? "󰤢" : "󰤟")
                : "󰤮"
            color: (root.wired || root.wifiNet) ? Theme.primary : Theme.error
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }

        Text {
            visible: root.wifiNet !== null && !root.wired
            text: root.wifiNet ? root.wifiNet.name : ""
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            elide: Text.ElideRight
            Layout.maximumWidth: 110
        }

        // Live throughput
        ColumnLayout {
            spacing: -2
            visible: Config.showNetSpeed

            Text {
                text: "↓ " + Sys.rate(Sys.rx)
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 5
            }
            Text {
                text: "↑ " + Sys.rate(Sys.tx)
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 5
            }
        }
    }
}
