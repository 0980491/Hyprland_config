import QtQuick
import QtQuick.Layouts
import Quickshell

// CPU / RAM / GPU. The bar shows CPU %, RAM % and GPU temperature.
// Click opens the detail panel: per-core CPU, RAM used/total, GPU load and VRAM.
// Right click opens btop.
BarItem {
    id: root
    panel: "resources"

    readonly property bool showPopup: Panels.isOpen("resources", screenName)
    active: showPopup
    implicitWidth: row.implicitWidth + padding * 2

    tooltip: "Click for details · right click opens a system monitor"

    onClicked: Panels.toggle("resources", root.screenName)
    // btop if it is installed, htop otherwise — the old bind silently did
    // nothing because btop isn't on this machine.
    onRightClicked: Quickshell.execDetached(["/bin/sh", "-c",
        "command -v btop >/dev/null && exec kitty -e btop || exec kitty -e htop"])

    // One entry per metric shown in the bar
    readonly property var metrics: [
        { icon: "", value: Sys.cpu,     label: Sys.cpu + "%",     level: Sys.cpu, warn: 85 },
        { icon: "", value: Sys.mem,     label: Sys.mem + "%",     level: Sys.mem, warn: 90 },
        { icon: "󰢮", value: Sys.gpuTemp, label: Sys.gpuTemp + "°", level: Sys.gpu, warn: 85 }
    ]

    // Widest label any metric can reach ("100%" / "100°")
    TextMetrics {
        id: widest
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        text: "100%"
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        Repeater {
            model: root.metrics

            delegate: RowLayout {
                id: metric
                required property var modelData
                spacing: 5

                Text {
                    text: metric.modelData.icon
                    color: metric.modelData.value >= metric.modelData.warn ? Theme.error : Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize - 1
                }

                // Vertical level bar
                Rectangle {
                    Layout.preferredWidth: 4
                    Layout.preferredHeight: 18
                    radius: 2
                    color: Theme.surfaceHighest

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * Math.min(100, Math.max(0, metric.modelData.level)) / 100
                        radius: 2
                        color: metric.modelData.level > 85 ? Theme.error
                             : metric.modelData.level > 60 ? Theme.secondary
                             : Theme.primary
                        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: Theme.anim } }
                    }
                }

                Text {
                    text: metric.modelData.label
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    // Fixed width so the row doesn't jitter between 9% and 100%
                    // — but measured from the widest value it can ever show,
                    // not guessed. The old hard-coded 38 left a visible gap.
                    Layout.preferredWidth: widest.width
                }
            }
        }
    }

    // ── Detail panel ──
    PopupCard {
        visible: root.showPopup
        anchor.item: root
        implicitWidth: 360
        cardHeight: body.implicitHeight + 24

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            // ── CPU ──
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "  CPU"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
                Text {
                    text: Sys.cpu + "%  ·  " + Sys.cpuTemp + " °C"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            // Per-core grid
            Grid {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: 6
                columnSpacing: 14

                Repeater {
                    model: Sys.cores

                    delegate: Item {
                        id: core
                        required property int index
                        required property var modelData

                        width: (body.width - 42) / 4
                        height: 20

                        RowLayout {
                            anchors.fill: parent
                            spacing: 5

                            Text {
                                text: core.index
                                color: Theme.outline
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                                Layout.preferredWidth: 14
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: Theme.surfaceHighest

                                Rectangle {
                                    width: parent.width * Math.min(100, core.modelData) / 100
                                    height: parent.height
                                    radius: 3
                                    color: core.modelData > 85 ? Theme.error
                                         : core.modelData > 60 ? Theme.secondary
                                         : Theme.primary
                                    Behavior on width { NumberAnimation { duration: 350 } }
                                }
                            }

                            Text {
                                text: core.modelData
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 3
                                Layout.preferredWidth: 22
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVar }

            // ── Memory, GPU, disk ──
            Repeater {
                model: [
                    {
                        icon: "", name: "RAM",
                        detail: Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GiB",
                        level: Sys.mem
                    },
                    {
                        icon: "󰢮", name: "GPU",
                        detail: Sys.gpu + "% used  ·  " + Sys.gpuTemp + " °C",
                        level: Sys.gpu
                    },
                    {
                        icon: "󰆼", name: "VRAM",
                        detail: Sys.vramUsed.toFixed(1) + " / " + Sys.vramTotal.toFixed(1) + " GiB",
                        level: Sys.vram
                    },
                    {
                        icon: "󰋊", name: "Disk /",
                        detail: Sys.disk + "% used",
                        level: Sys.disk
                    }
                ]

                delegate: ColumnLayout {
                    id: stat
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: stat.modelData.icon + "  " + stat.modelData.name
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: true
                        }
                        Text {
                            text: stat.modelData.detail
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Theme.surfaceHighest

                        Rectangle {
                            width: parent.width * Math.min(100, Math.max(0, stat.modelData.level)) / 100
                            height: parent.height
                            radius: 3
                            color: stat.modelData.level > 85 ? Theme.error
                                 : stat.modelData.level > 60 ? Theme.secondary
                                 : Theme.primary
                            Behavior on width { NumberAnimation { duration: 350 } }
                        }
                    }
                }
            }
        }
    }
}
