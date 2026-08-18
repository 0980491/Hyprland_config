import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Workspaces for this bar's monitor, drawn as dots.
// The dots for this monitor are always visible (see Config.workspacesByMonitor),
// plus any extra workspace that happens to live here right now.
// Click a dot to switch, scroll anywhere on the group to cycle.
Item {
    id: root
    required property var monitorScreen

    readonly property var hMonitor: Hyprland.monitorFor(monitorScreen)
    readonly property string monitorName: monitorScreen ? monitorScreen.name : ""

    // Fixed ids for this monitor, or an empty list for unknown monitors
    readonly property var pinned: {
        const map = Config.workspacesByMonitor;
        return (map && map[monitorName]) ? map[monitorName] : [];
    }

    // Live Hyprland workspaces sitting on this monitor
    readonly property var live: {
        const out = {};
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id < 0) continue;                       // skip special workspaces
            if (!ws.monitor || !hMonitor) continue;
            if (ws.monitor.id !== hMonitor.id) continue;
            out[ws.id] = ws;
        }
        return out;
    }

    // Union of pinned ids and live ones, sorted
    readonly property var entries: {
        const ids = pinned.slice();
        for (const key in live) {
            const id = parseInt(key);
            if (ids.indexOf(id) === -1) ids.push(id);
        }
        ids.sort((a, b) => a - b);

        const activeId = (hMonitor && hMonitor.activeWorkspace) ? hMonitor.activeWorkspace.id : -1;
        return ids.map(id => {
            const ws = live[id] || null;
            return {
                id: id,
                ws: ws,
                active: id === activeId,
                occupied: ws ? (ws.toplevels && ws.toplevels.values.length > 0) : false,
                urgent: ws ? ws.urgent : false
            };
        });
    }

    implicitWidth: row.implicitWidth + 24
    implicitHeight: Theme.barHeight - Theme.islandPad * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: root.entries

            delegate: Item {
                id: slot
                required property var modelData

                Layout.preferredWidth: 14
                Layout.preferredHeight: 14

                Rectangle {
                    id: dot
                    anchors.centerIn: parent

                    // always a circle; the active one is just bigger and brighter
                    width: slot.modelData.active ? 13
                         : slot.modelData.occupied ? 9 : 6
                    height: width
                    radius: width / 2

                    color: slot.modelData.urgent ? Theme.error
                         : slot.modelData.active ? Theme.primary
                         : slot.modelData.occupied ? Theme.secondary
                         : Theme.outlineVar

                    opacity: slot.modelData.active ? 1
                           : slot.modelData.occupied ? 0.85
                           : hover.containsMouse ? 0.7 : 0.45

                    Behavior on width   { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutQuint } }
                    Behavior on height  { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutQuint } }
                    Behavior on color   { ColorAnimation  { duration: Theme.anim } }
                    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.goToWorkspace(slot.modelData.id)
                }

                // Workspace number on hover, so the dots stay readable
                Rectangle {
                    visible: hover.containsMouse
                    anchors.top: parent.bottom
                    anchors.topMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: idText.implicitWidth + 12
                    implicitHeight: idText.implicitHeight + 6
                    radius: Theme.radiusSmall
                    color: Theme.surfaceHighest
                    border.width: 1
                    border.color: Theme.outlineVar
                    z: 80

                    Text {
                        id: idText
                        anchors.centerIn: parent
                        text: slot.modelData.id
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }

    // Scrolling cycles this monitor's own workspaces and wraps around, so it
    // never jumps over to the other screen.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wv => {
            const ids = root.entries.map(e => e.id);
            if (ids.length === 0) return;

            const activeId = (root.hMonitor && root.hMonitor.activeWorkspace)
                ? root.hMonitor.activeWorkspace.id : ids[0];
            let i = ids.indexOf(activeId);
            if (i === -1) i = 0;

            // scroll down goes forward (inverted on request)
            i = (wv.angleDelta.y > 0) ? (i + 1) % ids.length
                                      : (i - 1 + ids.length) % ids.length;
            Hypr.goToWorkspace(ids[i]);
        }
    }
}
