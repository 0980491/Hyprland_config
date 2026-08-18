import QtQuick
import Quickshell

// Shared shell for every bar popup.
//
// The gap under the bar is real transparent space inside the popup window
// (anchor.margins does not reliably push xdg popups), and hovering the card
// keeps the panel open — see Panels.
PopupWindow {
    id: root

    default property alias content: card.data
    property int gap: 14

    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    // Height of the visible card; the window itself is that plus the gap
    property int cardHeight: 200
    implicitHeight: cardHeight + gap

    color: "transparent"

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.cardHeight

        radius: Theme.radius
        // opaque on purpose: text has to read well over any wallpaper
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.outlineVar

        // Keeps the panel alive while the pointer is inside it.
        // HoverHandler, not MouseArea: child MouseAreas (buttons, sliders,
        // list rows) steal hover from a parent MouseArea, which is what made
        // big panels close while you were still using them.
        HoverHandler {
            id: cardHover
            onHoveredChanged: {
                if (cardHover.hovered) Panels.keepOpen();
                else Panels.scheduleClose();
            }
        }

        // Clicking anywhere inside must never close the panel
        TapHandler {
            acceptedButtons: Qt.AllButtons
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: Panels.keepOpen()
        }
    }
}
