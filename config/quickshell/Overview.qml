import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// Workspace overview: every workspace of this monitor as a card showing live
// thumbnails of the windows on it. Click a card to jump to it, click a window
// to focus it, Esc or right click to close.
//
// This replaces the hyprexpo plugin, which was dropped from hyprland-plugins
// and never made it to the Lua era. No plugin, no compiling, and it survives
// Hyprland updates.
//
// The thumbnails come from ScreencopyView pointed at each window's Wayland
// toplevel (HyprlandToplevel.wayland). Hyprland's toplevel-export protocol can
// capture windows that are not on screen, which is the whole point here.
PanelWindow {
    id: root
    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "qs-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property string screenName: modelData ? modelData.name : ""
    visible: Panels.isOpen("overview", screenName)

    readonly property var hMonitor: Hyprland.monitorFor(modelData)

    // Same list the bar dots use, so both agree
    readonly property var ids: {
        const map = Config.workspacesByMonitor;
        const pinned = (map && map[screenName]) ? map[screenName].slice() : [];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id < 0) continue;
            if (!ws.monitor || !hMonitor || ws.monitor.id !== hMonitor.id) continue;
            if (pinned.indexOf(ws.id) === -1) pinned.push(ws.id);
        }
        pinned.sort((a, b) => a - b);
        return pinned;
    }

    // One row while they fit — with five workspaces a 3-column grid left a hole
    // where the sixth card would have been. Past six, two balanced rows.
    readonly property int cols: ids.length <= 6 ? Math.max(1, ids.length)
                                                : Math.ceil(ids.length / 2)

    readonly property int gridWidth: Math.min(width - 100, 2300)
    readonly property int cardWidth: Math.floor((gridWidth - (cols - 1) * 16) / cols)
    // 16:10 of thumbnail area, plus the header row
    readonly property int cardHeight: Math.round(cardWidth * 0.62) + 46

    function workspaceFor(id) {
        for (const ws of Hyprland.workspaces.values) if (ws.id === id) return ws;
        return null;
    }

    // Dim everything behind
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.surface, 0.72)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: Panels.close()
        }
    }

    Item {
        id: overlay
        anchors.fill: parent
        focus: root.visible

        // Set while a thumbnail is being carried, so the preview below knows
        // what to draw and where. The tiles write to these.
        property var dragSource: null
        property real dragX: 0
        property real dragY: 0

        Keys.onEscapePressed: Panels.close()
        Keys.onPressed: event => {
            // 1-9 jumps straight to the n-th card
            if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const idx = event.key - Qt.Key_1;
                if (idx < root.ids.length) {
                    Hypr.goToWorkspace(root.ids[idx]);
                    Panels.close();
                }
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: root.gridWidth
            spacing: 18

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.screenName + "  ·  click a workspace, press its number, "
                    + "or drag a window onto another card"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: root.cols
                rowSpacing: 16
                columnSpacing: 16

                Repeater {
                    model: root.ids

                    delegate: Rectangle {
                        id: card
                        required property var modelData   // workspace id

                        readonly property var ws: root.workspaceFor(card.modelData)
                        readonly property bool isActive: root.hMonitor
                            && root.hMonitor.activeWorkspace
                            && root.hMonitor.activeWorkspace.id === card.modelData
                        readonly property var windows: ws && ws.toplevels ? ws.toplevels.values : []
                        // Four thumbnails is where a card still reads at a glance
                        readonly property var shown: windows.slice(0, 4)

                        // True while a window is being dragged over this card
                        property bool dropHover: false

                        Layout.preferredWidth: root.cardWidth
                        Layout.preferredHeight: root.cardHeight
                        radius: Theme.radius
                        color: dropHover ? Theme.surfaceHigh : Theme.surfaceC
                        border.width: (isActive || dropHover) ? 2 : 1
                        border.color: dropHover ? Theme.tertiary
                                    : isActive ? Theme.primary
                                    : Theme.outlineVar
                        Behavior on color { ColorAnimation { duration: Theme.anim } }

                        scale: dropHover ? 1.04
                             : cardMouse.containsMouse ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutQuint } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Rectangle {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: 13
                                    color: card.isActive ? Theme.primary : Theme.surfaceHigh

                                    Text {
                                        anchors.centerIn: parent
                                        text: card.modelData
                                        color: card.isActive ? Theme.textOnPrimary : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                        font.bold: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: card.windows.length === 0
                                        ? "empty"
                                        : card.windows.length + (card.windows.length === 1 ? " window" : " windows")
                                    color: Theme.outline
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }

                            // ── thumbnails ──
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Empty workspace: an outline where a window would
                                // be. Drawn rather than a glyph, so it cannot turn
                                // into whatever the font has at that code point.
                                Rectangle {
                                    anchors.centerIn: parent
                                    implicitWidth: Math.min(74, parent.width * 0.35)
                                    implicitHeight: implicitWidth * 0.62
                                    visible: card.windows.length === 0
                                    radius: Theme.radiusSmall
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.outlineVar
                                }

                                GridLayout {
                                    anchors.fill: parent
                                    visible: card.windows.length > 0
                                    // one window fills the card, more go in a 2×2
                                    columns: card.shown.length === 1 ? 1 : 2
                                    rowSpacing: 6
                                    columnSpacing: 6

                                    Repeater {
                                        model: card.shown

                                        delegate: ClippingRectangle {
                                            id: winTile
                                            required property var modelData

                                            readonly property string appClass:
                                                modelData.lastIpcObject ? (modelData.lastIpcObject.class || "") : ""

                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: Theme.radiusSmall
                                            color: Theme.surfaceLow
                                            border.width: 1
                                            border.color: winMouse.containsMouse ? Theme.primary : "transparent"

                                            // live: false takes a single frame instead of streaming.
                                            // Five workspaces times four windows is twenty captures;
                                            // streaming them all would light up the GPU for a panel
                                            // that is on screen for two seconds.
                                            ScreencopyView {
                                                id: shot
                                                anchors.centerIn: parent
                                                captureSource: winTile.modelData.wayland
                                                live: false
                                                paintCursor: false

                                                // One frame is taken when the view is built,
                                                // and it was still on screen sessions later —
                                                // that is why a thumbnail could show a window
                                                // as it looked ages ago. Grab a fresh one every
                                                // time the overview opens: still no streaming,
                                                // but what you see is current.
                                                Connections {
                                                    target: root
                                                    function onVisibleChanged() {
                                                        if (root.visible) shot.captureFrame();
                                                    }
                                                }

                                                readonly property real ar:
                                                    sourceSize.height > 0
                                                        ? sourceSize.width / sourceSize.height : 1.6
                                                width: Math.min(parent.width, parent.height * ar)
                                                height: ar > 0 ? width / ar : parent.height
                                            }

                                            // Until the first frame lands, show the app icon so the
                                            // card is never just an empty box.
                                            IconImage {
                                                anchors.centerIn: parent
                                                implicitSize: 34
                                                visible: !shot.hasContent
                                                source: {
                                                    // Guard the empty class: heuristicLookup("") matches the
                                                    // first .desktop it finds and happily returned feh's icon
                                                    // for windows that have nothing to do with feh.
                                                    if (!winTile.appClass) return "";
                                                    const e = DesktopEntries.heuristicLookup(winTile.appClass);
                                                    return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
                                                }
                                            }

                                            // Title strip, only while hovered
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                implicitHeight: 24
                                                color: Qt.alpha(Theme.surface, 0.85)
                                                visible: winMouse.containsMouse

                                                Text {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 7
                                                    anchors.rightMargin: 7
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: winTile.modelData.title
                                                    color: Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSize - 3
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // ── drag a window onto another card ──
                                            // The thumbnail itself stays put; this
                                            // invisible item is what travels, and the
                                            // DropArea on each card reads it. No
                                            // anchors on purpose: anchoring and then
                                            // dragging fight each other.
                                            // 1x1 and parked under the cursor on press, so
                                            // the drop lands exactly where the pointer is.
                                            // Sized like the tile instead, the hotspot would
                                            // be its centre and dropping near the edge of a
                                            // card would miss.
                                            Item {
                                                id: dragGhost
                                                width: 1
                                                height: 1

                                                readonly property string winAddress: winTile.modelData.address
                                                readonly property int fromWorkspace: card.modelData

                                                Drag.active: winMouse.drag.active
                                                Drag.source: dragGhost
                                                Drag.hotSpot.x: 0
                                                Drag.hotSpot.y: 0
                                            }

                                            // Fade the tile while it is being carried
                                            opacity: winMouse.drag.active ? 0.4 : 1.0
                                            Behavior on opacity { NumberAnimation { duration: Theme.anim } }

                                            MouseArea {
                                                id: winMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: drag.active ? Qt.ClosedHandCursor
                                                                         : Qt.PointingHandCursor

                                                drag.target: dragGhost
                                                drag.threshold: 8

                                                onPressed: mouse => {
                                                    dragGhost.x = mouse.x;
                                                    dragGhost.y = mouse.y;
                                                    const p = winTile.mapToItem(overlay, mouse.x, mouse.y);
                                                    overlay.dragX = p.x;
                                                    overlay.dragY = p.y;
                                                }
                                                onPositionChanged: mouse => {
                                                    if (!winMouse.drag.active) return;
                                                    const p = winTile.mapToItem(overlay, mouse.x, mouse.y);
                                                    overlay.dragX = p.x;
                                                    overlay.dragY = p.y;
                                                }
                                                drag.onActiveChanged: {
                                                    overlay.dragSource = winMouse.drag.active
                                                        ? winTile.modelData.wayland : null;
                                                }
                                                // Without this the release just cancels the
                                                // drag: Qt only delivers the drop when it is
                                                // asked to. Everything else worked without it
                                                // — the card even lit up — and nothing moved.
                                                onReleased: dragGhost.Drag.drop()
                                                // Only a real click focuses; a drag that
                                                // ended somewhere else must not also jump.
                                                onClicked: {
                                                    Hypr.focusWindow(winTile.modelData.address);
                                                    Panels.close();
                                                }
                                            }
                                        }
                                    }
                                }

                                // "+2" when the workspace holds more than fits
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 4
                                    visible: card.windows.length > card.shown.length
                                    implicitWidth: moreText.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: Qt.alpha(Theme.surface, 0.85)

                                    Text {
                                        id: moreText
                                        anchors.centerIn: parent
                                        text: "+" + (card.windows.length - card.shown.length)
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 3
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            z: -1
                            onClicked: {
                                Hypr.goToWorkspace(card.modelData);
                                Panels.close();
                            }
                        }

                        // Drop target: a window dragged from any card lands here.
                        // The overview stays open so you can keep sorting.
                        DropArea {
                            anchors.fill: parent

                            onEntered: drag => {
                                const src = drag.source;
                                // Dropping a window back where it already is is a no-op,
                                // so don't light the card up for it either.
                                card.dropHover = !!src && src.fromWorkspace !== card.modelData;
                            }
                            onExited: card.dropHover = false
                            onDropped: drop => {
                                card.dropHover = false;
                                const src = drop.source;
                                if (!src || !src.winAddress) return;
                                if (src.fromWorkspace === card.modelData) return;
                                Hypr.moveWindowToWorkspace(src.winAddress, card.modelData);
                            }
                        }
                    }
                }
            }
        }

        // ── the window you are carrying ──
        // Sits here, at the top of the overlay, rather than inside the tile:
        // a child of the tile is clipped to it, so the preview would be cut off
        // the instant it left the thumbnail it came from.
        ClippingRectangle {
            id: dragPreview
            visible: overlay.dragSource !== null
            width: 260
            height: 164
            x: overlay.dragX - width / 2
            y: overlay.dragY - height / 2
            z: 999
            radius: Theme.radiusSmall
            color: Theme.surfaceLow
            opacity: 0.92
            border.width: 2
            border.color: Theme.primary

            ScreencopyView {
                anchors.centerIn: parent
                captureSource: overlay.dragSource
                live: false
                paintCursor: false

                readonly property real ar:
                    sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6
                width: Math.min(parent.width, parent.height * ar)
                height: ar > 0 ? width / ar : parent.height
            }
        }
    }
}
