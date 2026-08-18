import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// System tray (Discord, Steam, EasyEffects, OBS…).
// Click activates; right click opens the app's own menu.
Item {
    id: root
    required property var bar

    visible: SystemTray.items.values.length > 0
    implicitWidth: row.implicitWidth + 12
    implicitHeight: Theme.barHeight - 8

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.surfaceLow
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: entry
                required property SystemTrayItem modelData

                implicitWidth: 20
                implicitHeight: 20

                IconImage {
                    anchors.fill: parent
                    source: entry.modelData.icon
                    smooth: true
                    opacity: itemMouse.containsMouse ? 1.0 : 0.9
                    scale: itemMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: mv => {
                        if (mv.button === Qt.LeftButton) {
                            if (entry.modelData.onlyMenu) menuAnchor.open();
                            else entry.modelData.activate();
                        } else if (mv.button === Qt.RightButton) {
                            menuAnchor.open();
                        } else {
                            entry.modelData.secondaryActivate();
                        }
                    }
                }

                QsMenuAnchor {
                    id: menuAnchor
                    menu: entry.modelData.menu
                    anchor.window: root.bar
                    anchor.rect.x: root.x + entry.x + entry.width / 2
                    anchor.rect.y: Theme.barHeight + 4
                }

                // Tooltip with the app title
                Rectangle {
                    visible: itemMouse.containsMouse
                    anchors.top: parent.bottom
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: tt.implicitWidth + 14
                    implicitHeight: tt.implicitHeight + 8
                    radius: Theme.radiusSmall
                    color: Theme.surfaceHighest
                    border.width: 1
                    border.color: Theme.outlineVar
                    z: 50

                    Text {
                        id: tt
                        anchors.centerIn: parent
                        text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }
}
