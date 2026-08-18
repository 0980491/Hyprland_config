import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// One bar per monitor.
//
// The bar is a set of separate islands rather than one wide container: the
// window itself is transparent and only the islands are painted, so the space
// between them shows the wallpaper straight through.
PanelWindow {
    id: bar
    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "qs-bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; left: true; right: true }
    margins { top: 6; left: 8; right: 8 }

    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight + 6
    color: "transparent"

    readonly property string screenName: bar.screen ? bar.screen.name : ""

    // ── Left: the clock, then the machine's vitals ──
    RowLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        Island { ClockWidget     { screenName: bar.screenName } }
        Island { ResourcesWidget { screenName: bar.screenName } }
    }

    // ── Centre: workspaces, on their own. Workspaces already carries 12px a
    // side; this padding is on top of that, so the island breathes without
    // moving the dots relative to each other. ──
    Island {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        padding: 14

        Workspaces { monitorScreen: bar.screen }
    }

    // ── Right ──
    RowLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gap

        // Tighter padding than the default: these two carry text, and at
        // Theme.padH the capsule sat noticeably wider than its content.
        Island {
            VolumeWidget  { screenName: bar.screenName; padding: 7 }
            NetworkWidget { screenName: bar.screenName; padding: 7 }
        }

        // Read right to left: power, then quick settings, then the rest.
        Island {
            UtilsWidget {}
            QuickSettings { screenName: bar.screenName }
            IconButton {
                icon: "󰐥"
                tip: "Power"
                command: ["/bin/sh", "-c", "$HOME/.config/rofi/scripts/powermenu.sh"]
            }
        }

        // Alone in the corner
        Island { NotificationsWidget { screenName: bar.screenName } }
    }
}
