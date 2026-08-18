import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// On-screen display for volume changes, bottom centre. Hides itself.
PanelWindow {
    id: root
    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: false

    anchors { bottom: true }
    margins { bottom: 90 }

    implicitWidth: 260
    implicitHeight: 62
    color: "transparent"

    // Only on the monitor you are actually looking at, so the OSD doesn't
    // pop up on every screen at once.
    readonly property bool onFocusedMonitor: {
        const m = Hyprland.focusedMonitor;
        return m && modelData ? m.name === modelData.name : true;
    }

    visible: shown && onFocusedMonitor

    property bool shown: false
    property bool firstRun: true

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int vol: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    function flash() {
        if (firstRun) { firstRun = false; return; }   // don't flash on startup
        shown = true;
        hideTimer.restart();
    }

    onVolChanged: flash()
    onMutedChanged: flash()

    Timer {
        id: hideTimer
        interval: 1600
        onTriggered: root.shown = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surfaceC
        border.width: 1
        border.color: Theme.outlineVar
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: root.muted ? "󰝟"
                    : root.vol === 0 ? "󰕿"
                    : root.vol < 34 ? "󰕿"
                    : root.vol < 67 ? "󰖀" : "󰕾"
                color: root.muted ? Theme.error : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 22
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.surfaceHighest

                Rectangle {
                    width: parent.width * Math.min(1, root.vol / 100)
                    height: parent.height
                    radius: 4
                    color: root.muted ? Theme.outline
                         : root.vol > 100 ? Theme.error : Theme.primary
                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }

            Text {
                text: root.muted ? "--" : root.vol + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
