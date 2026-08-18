import QtQuick
import QtQuick.Layouts

// Standard bar capsule: rounded background, hover state, and click/scroll
// signals. Every bar widget uses it so they all look the same.
//
// Set `panel` to the name of the popup this widget owns: hovering opens it,
// leaving closes it, and clicking pins it open until you click again.
Rectangle {
    id: root

    property bool active: false
    property bool hoverEnabled: true
    property string tooltip: ""
    property int padding: Theme.padH

    property string panel: ""       // panel this widget owns, if any
    property string screenName: ""  // monitor this widget lives on

    readonly property bool hovered: mouse.containsMouse || itemHover.hovered

    signal clicked(var mouse)
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int delta)

    // Each widget sets its own implicitWidth from its content.
    implicitWidth: 28
    // Leaves exactly Theme.islandPad above and below, which is what the island
    // leaves at the sides — so the highlight is inset evenly all the way round.
    implicitHeight: Theme.barHeight - Theme.islandPad * 2
    radius: Theme.radiusInner
    color: root.active ? Theme.primaryC
         : mouse.containsMouse ? Theme.surfaceHigh
         : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.anim } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.hoverEnabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor


        onClicked: mv => {
            if (mv.button === Qt.RightButton) root.rightClicked();
            else if (mv.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked(mv);
        }
        onWheel: wv => root.scrolled(wv.angleDelta.y)
    }

    // Hover tracking lives in a handler so nested MouseAreas can't break it
    HoverHandler {
        id: itemHover
        enabled: root.hoverEnabled
        onHoveredChanged: {
            if (root.panel === "") return;
            if (itemHover.hovered) Panels.hoverOpen(root.panel, root.screenName);
            else Panels.hoverLeave();
        }
    }

    // Lightweight tooltip, no extra windows. Hidden while its panel is open.
    Rectangle {
        visible: root.tooltip !== "" && mouse.containsMouse && !root.active
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: tipText.implicitWidth + 16
        implicitHeight: tipText.implicitHeight + 10
        radius: Theme.radiusSmall
        color: Theme.surfaceHighest
        border.width: 1
        border.color: Theme.outlineVar
        z: 100

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.tooltip
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            textFormat: Text.RichText
        }
    }
}
