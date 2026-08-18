import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire

// Control centre: toggles, volume, audio outputs and paired bluetooth devices
// in one place, so you rarely need to leave the bar.
BarItem {
    id: root
    panel: "quicksettings"

    readonly property bool showPopup: Panels.isOpen("quicksettings", screenName)
    active: showPopup
    implicitWidth: 30
    tooltip: "Quick settings"

    onClicked: Panels.toggle("quicksettings", root.screenName)

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property int vol: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    PwObjectTracker {
        objects: {
            const l = [];
            if (root.sink) l.push(root.sink);
            if (root.source) l.push(root.source);
            for (const n of Pipewire.nodes.values) if (n.isSink && !n.isStream) l.push(n);
            return l;
        }
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var wifiDev: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi) return d;
        return null;
    }

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        color: root.showPopup ? Theme.textOnPrimaryC : Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.iconSize
    }

    // ── Panel ──
    PopupCard {
        visible: root.showPopup
        anchor.item: root
        implicitWidth: 380
        cardHeight: body.implicitHeight + 24

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            // ── Toggles ──
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    // only toggles this machine can actually do
                    model: {
                        const t = [];
                        if (root.wifiDev)
                            t.push({ key: "wifi", icon: "󰤨", label: "Wi-Fi", on: Networking.wifiEnabled });
                        if (root.btAdapter)
                            t.push({ key: "bt", icon: "󰂯", label: "Bluetooth", on: root.btAdapter.enabled });
                        t.push({ key: "dnd", icon: "󰂛", label: "Do not disturb", on: Notifications.doNotDisturb });
                        if (root.source)
                            t.push({ key: "mic", icon: "󰍬", label: "Microphone", on: !root.micMuted });
                        t.push({ key: "game", icon: "󰊴", label: "Game mode", on: Sys.gameMode });
                        return t;
                    }

                    delegate: Rectangle {
                        id: toggle
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Theme.radiusSmall
                        color: toggle.modelData.on ? Theme.primaryC
                             : tMouse.containsMouse ? Theme.surfaceHigh
                             : Theme.surfaceLow
                        Behavior on color { ColorAnimation { duration: Theme.anim } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: toggle.modelData.icon
                                color: toggle.modelData.on ? Theme.textOnPrimaryC : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.iconSize + 2
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: -1

                                Text {
                                    text: toggle.modelData.label
                                    color: toggle.modelData.on ? Theme.textOnPrimaryC : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    font.bold: true
                                }
                                Text {
                                    text: toggle.modelData.on ? "on" : "off"
                                    color: toggle.modelData.on ? Theme.textOnPrimaryC : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 4
                                }
                            }
                        }

                        MouseArea {
                            id: tMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                switch (toggle.modelData.key) {
                                case "wifi": Networking.wifiEnabled = !Networking.wifiEnabled; break;
                                case "bt":   if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled; break;
                                case "dnd":  Notifications.doNotDisturb = !Notifications.doNotDisturb; break;
                                case "mic":  if (root.source && root.source.audio)
                                                 root.source.audio.muted = !root.source.audio.muted;
                                             break;
                                case "game": Sys.toggleGameMode(); break;
                                }
                            }
                        }
                    }
                }
            }

            // ── Volume ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.muted ? "󰝟" : "󰕾"
                    color: root.muted ? Theme.error : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
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
                        color: root.muted ? Theme.outline : Theme.primary
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
                        onWheel: wv => {
                            if (!root.sink || !root.sink.audio) return;
                            const step = wv.angleDelta.y > 0 ? 0.02 : -0.02;
                            root.sink.audio.volume = Math.max(0, Math.min(1.4, root.sink.audio.volume + step));
                        }
                    }
                }

                Text {
                    text: root.vol + "%"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVar }

            // ── Audio outputs ──
            Text {
                text: "Audio output"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: true
            }

            Repeater {
                model: {
                    const out = [];
                    for (const n of Pipewire.nodes.values)
                        if (n.isSink && !n.isStream) out.push(n);
                    return out;
                }

                delegate: Rectangle {
                    id: sinkRow
                    required property var modelData
                    readonly property bool isCurrent: root.sink && modelData.id === root.sink.id

                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Theme.radiusSmall
                    color: sinkRow.isCurrent ? Theme.primaryC
                         : sinkMouse.containsMouse ? Theme.surfaceHigh
                         : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: sinkRow.isCurrent ? "󰄬" : "󰧉"
                            color: sinkRow.isCurrent ? Theme.textOnPrimaryC : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: sinkRow.modelData.nickname || sinkRow.modelData.description || sinkRow.modelData.name
                            color: sinkRow.isCurrent ? Theme.textOnPrimaryC : Theme.text
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
                        onClicked: Pipewire.preferredDefaultAudioSink = sinkRow.modelData
                    }
                }
            }

            // ── Bluetooth devices ──
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.outlineVar
                visible: btList.count > 0
            }

            Text {
                text: "Bluetooth"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: true
                visible: btList.count > 0
            }

            Repeater {
                id: btList
                model: {
                    const out = [];
                    for (const d of Bluetooth.devices.values)
                        if (d.paired || d.connected) out.push(d);
                    return out;
                }

                delegate: Rectangle {
                    id: btRow
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Theme.radiusSmall
                    color: btRow.modelData.connected ? Theme.primaryC
                         : btMouse.containsMouse ? Theme.surfaceHigh
                         : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: btRow.modelData.connected ? "󰂱" : "󰂲"
                            color: btRow.modelData.connected ? Theme.textOnPrimaryC : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: btRow.modelData.deviceName || btRow.modelData.name
                            color: btRow.modelData.connected ? Theme.textOnPrimaryC : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: btRow.modelData.batteryAvailable
                            text: Math.round(btRow.modelData.battery * 100) + "%"
                            color: btRow.modelData.connected ? Theme.textOnPrimaryC : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }

                    MouseArea {
                        id: btMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (btRow.modelData.connected) btRow.modelData.disconnect();
                            else btRow.modelData.connect();
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVar }

            // ── Shortcuts out to the bigger menus ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "Wi-Fi", cmd: ["/bin/sh", "-c", "$HOME/.config/rofi/scripts/wifi.sh"] },
                        { label: "Bluetooth", cmd: ["/bin/sh", "-c", "$HOME/.config/rofi/scripts/bluetooth.sh"] },
                        { label: "Mixer", cmd: ["pavucontrol"] }
                    ]

                    delegate: Rectangle {
                        id: linkBtn
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.radiusSmall
                        color: linkMouse.containsMouse ? Theme.surfaceHigh : Theme.surfaceLow

                        Text {
                            anchors.centerIn: parent
                            text: linkBtn.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }

                        MouseArea {
                            id: linkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(linkBtn.modelData.cmd);
                                Panels.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
