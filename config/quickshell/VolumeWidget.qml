import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Audio: scroll changes the volume, click opens the mixer (pick an output and
// set the level), middle click mutes, right click opens pavucontrol.
BarItem {
    id: root
    panel: "volume"

    readonly property bool showPopup: Panels.isOpen("volume", screenName)
    active: showPopup
    implicitWidth: row.implicitWidth + padding * 2

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property int vol: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    // Keeps the objects we read alive
    PwObjectTracker {
        objects: {
            const l = [];
            if (root.sink) l.push(root.sink);
            if (root.source) l.push(root.source);
            for (const n of Pipewire.nodes.values) if (n.isSink && !n.isStream) l.push(n);
            return l;
        }
    }

    tooltip: (sink ? (sink.nickname || sink.description || sink.name) : "no output") +
             "<br>" + (muted ? "muted" : vol + "%")

    onClicked: Panels.toggle("volume", root.screenName)
    onMiddleClicked: if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    onRightClicked: Quickshell.execDetached(["pavucontrol"])
    onScrolled: delta => {
        if (!sink || !sink.audio) return;
        const step = 0.02;
        let v = sink.audio.volume + (delta > 0 ? step : -step);
        sink.audio.volume = Math.max(0, Math.min(1.4, v));
        if (v > 0) sink.audio.muted = false;
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.muted ? "󰝟"
                : root.vol === 0 ? "󰕿"
                : root.vol < 34 ? "󰕿"
                : root.vol < 67 ? "󰖀"
                : "󰕾"
            color: root.muted ? Theme.error : Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize
        }

        // No fixed width: it left a dead gap to the right of the number. The
        // font is monospaced, so the capsule only resizes crossing 9→10→100%.
        Text {
            text: root.muted ? "--" : root.vol + "%"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        // Microphone muted: visible warning
        Text {
            visible: root.source && root.source.audio && root.source.audio.muted
            text: "󰍭"
            color: Theme.error
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize - 2
        }
    }

    // ── Mixer ──
    PopupCard {
        visible: root.showPopup
        anchor.item: root
        implicitWidth: 340
        cardHeight: col.implicitHeight + 24

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            Text {
                text: "Audio output"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            // Volume slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.muted ? "󰝟" : "󰕾"
                    color: root.muted ? Theme.error : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted
                    }
                }

                Rectangle {
                    id: track
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: Theme.surfaceHighest

                    Rectangle {
                        width: parent.width * Math.min(1, root.vol / 100)
                        height: parent.height
                        radius: 4
                        color: Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        function setFrom(x) {
                            if (!root.sink || !root.sink.audio) return;
                            root.sink.audio.volume = Math.max(0, Math.min(1, x / track.width));
                            root.sink.audio.muted = false;
                        }
                        onPressed: mv => setFrom(mv.x)
                        onPositionChanged: mv => { if (pressed) setFrom(mv.x); }
                    }
                }

                Text {
                    text: root.vol + "%"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVar }

            // Available outputs
            Repeater {
                model: {
                    const out = [];
                    for (const n of Pipewire.nodes.values)
                        if (n.isSink && !n.isStream) out.push(n);
                    return out;
                }

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isCurrent: root.sink && modelData.id === root.sink.id

                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Theme.radiusSmall
                    color: isCurrent ? Theme.primaryC
                         : sinkMouse.containsMouse ? Theme.surfaceHigh
                         : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: parent.parent.isCurrent ? "󰄬" : "󰧉"
                            color: parent.parent.isCurrent ? Theme.textOnPrimaryC : Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.nickname || modelData.description || modelData.name
                            color: parent.parent.isCurrent ? Theme.textOnPrimaryC : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVar }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "Mixer", cmd: ["pavucontrol"] },
                        { label: "EasyEffects", cmd: ["easyeffects"] }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.radiusSmall
                        color: btnMouse.containsMouse ? Theme.surfaceHigh : Theme.surfaceLow

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(modelData.cmd);
                                Panels.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
