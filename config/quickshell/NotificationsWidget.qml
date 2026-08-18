import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Bell with a counter, plus the notification centre.
// Right click toggles do-not-disturb.
BarItem {
    id: root
    panel: "notifications"

    readonly property bool showPopup: Panels.isOpen("notifications", screenName)
    active: showPopup
    implicitWidth: row.implicitWidth + padding * 2

    readonly property int count: Notifications.count

    tooltip: Notifications.doNotDisturb
        ? "Do not disturb is on"
        : (count === 0 ? "No notifications" : count + " notification(s)")

    onClicked: Panels.toggle("notifications", root.screenName)
    onRightClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: Notifications.doNotDisturb ? "󰂛" : (root.count > 0 ? "󱅫" : "󰂜")
            color: Notifications.doNotDisturb ? Theme.outline
                 : root.count > 0 ? Theme.primary
                 : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }

        Rectangle {
            visible: root.count > 0 && !Notifications.doNotDisturb
            implicitWidth: badge.implicitWidth + 8
            implicitHeight: 15
            radius: 8
            color: Theme.primary

            Text {
                id: badge
                anchors.centerIn: parent
                text: root.count > 9 ? "9+" : root.count
                color: Theme.textOnPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 4
                font.bold: true
            }
        }
    }

    // ── Notification centre ──
    PopupCard {
        visible: root.showPopup
        anchor.item: root
        implicitWidth: 400
        cardHeight: 460

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                // Do not disturb
                Rectangle {
                    implicitWidth: dndText.implicitWidth + 16
                    implicitHeight: 24
                    radius: Theme.radiusSmall
                    color: Notifications.doNotDisturb ? Theme.primaryC
                         : dndMouse.containsMouse ? Theme.surfaceHigh : Theme.surfaceLow

                    Text {
                        id: dndText
                        anchors.centerIn: parent
                        text: Notifications.doNotDisturb ? "󰂛 Silenced" : "󰂚 Alerts"
                        color: Notifications.doNotDisturb ? Theme.textOnPrimaryC : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }

                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
                    }
                }

                // Clear all
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: Theme.radiusSmall
                    color: clearMouse.containsMouse ? Theme.errorC : Theme.surfaceLow

                    Text {
                        anchors.centerIn: parent
                        text: "󰩹"
                        color: clearMouse.containsMouse ? Theme.text : Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.clearHistory()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVar }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: Notifications.count === 0
                text: "󰂜\nNothing here"
                horizontalAlignment: Text.AlignHCenter
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 4
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: Notifications.history
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: item
                    required property var modelData

                    width: ListView.view.width
                    implicitHeight: itemBody.implicitHeight + 16
                    radius: Theme.radiusSmall
                    color: itemMouse.containsMouse ? Theme.surfaceHigh : Theme.surfaceLow

                    RowLayout {
                        id: itemBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 8

                        IconImage {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 24
                            implicitHeight: 24
                            source: item.modelData.appIcon !== ""
                                ? Quickshell.iconPath(item.modelData.appIcon, true) : ""
                            visible: source !== ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: item.modelData.summary
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: item.modelData.body !== ""
                                text: item.modelData.body
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                textFormat: Text.StyledText
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: "󰅖"
                            color: xMouse.containsMouse ? Theme.error : Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1

                            MouseArea {
                                id: xMouse
                                anchors.fill: parent
                                anchors.margins: -5
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifications.dismiss(item.modelData)
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                    }
                }
            }
        }
    }
}
