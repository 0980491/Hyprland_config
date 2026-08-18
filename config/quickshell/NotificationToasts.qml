import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// Floating toasts, top right of the given monitor.
PanelWindow {
    id: root
    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "qs-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 10; right: 12 }

    implicitWidth: 390
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    // Toasts only on the focused monitor (set Config.toastsOnFocusedOnly to
    // false if you'd rather see them on every screen).
    readonly property bool onFocusedMonitor: {
        if (!Config.toastsOnFocusedOnly) return true;
        const m = Hyprland.focusedMonitor;
        return m && modelData ? m.name === modelData.name : true;
    }

    visible: Notifications.popupList.length > 0 && onFocusedMonitor

    ColumnLayout {
        id: stack
        anchors.top: parent.top
        anchors.right: parent.right
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifications.popups

            delegate: Rectangle {
                id: card
                required property var modelData

                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property bool low: modelData.urgency === NotificationUrgency.Low

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 20
                radius: Theme.radius
                color: Theme.surfaceC
                border.width: critical ? 2 : 1
                border.color: critical ? Theme.error : Theme.outlineVar

                // Slides in from the right
                x: 0
                opacity: 0
                Component.onCompleted: appear.start()
                ParallelAnimation {
                    id: appear
                    NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 220 }
                    NumberAnimation { target: card; property: "x"; from: 60; to: 0; duration: 300; easing.type: Easing.OutQuint }
                }

                // Remaining-time bar
                Rectangle {
                    id: lifebar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: 2
                    anchors.bottomMargin: 2
                    height: 2
                    radius: 1
                    color: card.critical ? Theme.error : Theme.primary
                    width: parent.width - 4
                    visible: timer.interval > 0 && !hover.containsMouse

                    NumberAnimation on width {
                        running: lifebar.visible
                        from: card.width - 4
                        to: 0
                        duration: timer.interval
                    }
                }

                Timer {
                    id: timer
                    interval: Notifications.timeoutFor(card.modelData)
                    running: interval > 0 && !hover.containsMouse
                    onTriggered: Notifications.expirePopup(card.modelData)
                }

                RowLayout {
                    id: body
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 10

                    // Notification image, or the app icon
                    Item {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 38
                        implicitHeight: 38

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Theme.surfaceHigh
                            visible: !img.visible
                            Text {
                                anchors.centerIn: parent
                                text: card.critical ? "󰀦" : "󰎟"
                                color: card.critical ? Theme.error : Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 18
                            }
                        }

                        IconImage {
                            id: img
                            anchors.fill: parent
                            source: card.modelData.image !== "" ? card.modelData.image
                                  : card.modelData.appIcon !== "" ? Quickshell.iconPath(card.modelData.appIcon, true)
                                  : ""
                            visible: source !== ""
                            smooth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: card.modelData.appName
                                color: Theme.outline
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: card.modelData.body !== ""
                            text: card.modelData.body
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.WordWrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                        }

                        // Whatever actions the app offers
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            visible: card.modelData.actions.length > 0
                            spacing: 6

                            Repeater {
                                model: card.modelData.actions

                                delegate: Rectangle {
                                    required property var modelData
                                    implicitWidth: actText.implicitWidth + 18
                                    implicitHeight: 26
                                    radius: Theme.radiusSmall
                                    color: actMouse.containsMouse ? Theme.primaryC : Theme.surfaceHigh

                                    Text {
                                        id: actText
                                        anchors.centerIn: parent
                                        text: modelData.text
                                        color: actMouse.containsMouse ? Theme.textOnPrimaryC : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 2
                                    }

                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: modelData.invoke()
                                    }
                                }
                            }
                        }
                    }

                    // Close
                    Text {
                        Layout.alignment: Qt.AlignTop
                        text: "󰅖"
                        color: closeMouse.containsMouse ? Theme.error : Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.dismiss(card.modelData)
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.MiddleButton
                    onClicked: Notifications.expirePopup(card.modelData)
                    z: -1
                }
            }
        }
    }
}
