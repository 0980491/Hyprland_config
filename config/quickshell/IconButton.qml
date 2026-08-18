import QtQuick
import Quickshell

// A single icon button: hover highlight, tooltip, and a command to run.
// Extracted from UtilsWidget so the bar can place individual buttons (the
// power button) next to other widgets instead of only as one fixed run.
Rectangle {
    id: root

    property string icon: ""
    property string tip: ""
    property var command: []
    // Toggles (caffeine) set this to show they are engaged; plain actions
    // (screenshot, clipboard) leave it false and look exactly as before.
    property bool active: false

    signal activated()

    implicitWidth: 30
    implicitHeight: Theme.barHeight - Theme.islandPad * 2
    radius: Theme.radiusInner
    color: root.active     ? Theme.primaryC
         : btn.containsMouse ? Theme.surfaceHigh
         : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.anim } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.active     ? Theme.textOnPrimaryC
             : btn.containsMouse ? Theme.primary
             : Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize - 1
        Behavior on color { ColorAnimation { duration: Theme.anim } }
    }

    MouseArea {
        id: btn
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.command.length > 0) Quickshell.execDetached(root.command);
            root.activated();
        }
    }

    Rectangle {
        visible: btn.containsMouse && root.tip !== ""
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: tipText.implicitWidth + 14
        implicitHeight: tipText.implicitHeight + 8
        radius: Theme.radiusSmall
        color: Theme.surfaceHighest
        border.width: 1
        border.color: Theme.outlineVar
        z: 60

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.tip
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
