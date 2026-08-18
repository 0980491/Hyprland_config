import QtQuick
import QtQuick.Layouts
import Quickshell

// Clock, dead centre of the bar. Click opens a month calendar.
BarItem {
    id: root
    panel: "calendar"

    readonly property bool showPopup: Panels.isOpen("calendar", screenName)
    active: showPopup
    implicitWidth: row.implicitWidth + padding * 2

    readonly property var now: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    onClicked: Panels.toggle("calendar", root.screenName)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: {
                const fmt = Config.clock12h
                    ? (Config.clockShowMeridiem ? "h:mm AP" : "h:mm")
                    : "HH:mm";
                return Qt.formatDateTime(root.now, fmt);
            }
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 12
            color: Theme.outlineVar
        }

        Text {
            text: Qt.formatDateTime(root.now, "ddd d MMM")
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
    }

    // ── Calendar ──
    PopupCard {
        id: popup
        visible: root.showPopup
        anchor.item: root
        implicitWidth: 310
        cardHeight: cal.implicitHeight + 24

        ColumnLayout {
            id: cal
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            // One column pitch for the whole calendar. The initials and the
            // numbers used to be sized independently — the initials split the
            // full width seven ways, the numbers sat in fixed 39px cells — so
            // the two rows drifted further apart with every day of the week.
            // Both grids are centred, so the leftover pixels split evenly
            // instead of piling up on one side.
            readonly property int cellW: Math.floor((popup.implicitWidth - 24) / 7)

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: {
                        const months = ["January", "February", "March", "April", "May", "June",
                                        "July", "August", "September", "October", "November", "December"];
                        return months[grid.month] + " " + grid.year;
                    }
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                Repeater {
                    model: [{ t: "‹", d: -1 }, { t: "•", d: 0 }, { t: "›", d: 1 }]
                    delegate: Rectangle {
                        id: navBtn
                        required property var modelData
                        implicitWidth: 24
                        implicitHeight: 24
                        radius: 6
                        color: navMouse.containsMouse ? Theme.surfaceHigh : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: navBtn.modelData.t
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (navBtn.modelData.d === 0) grid.goToday();
                                else grid.shift(navBtn.modelData.d);
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 0
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    delegate: Text {
                        required property string modelData
                        Layout.preferredWidth: cal.cellW
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                        font.bold: true
                    }
                }
            }

            Grid {
                id: grid
                Layout.alignment: Qt.AlignHCenter
                columns: 7
                rowSpacing: 2
                columnSpacing: 0

                property int year: root.now.getFullYear()
                property int month: root.now.getMonth()

                function goToday() {
                    year = root.now.getFullYear();
                    month = root.now.getMonth();
                }
                function shift(d) {
                    let m = month + d, y = year;
                    if (m < 0) { m = 11; y--; }
                    if (m > 11) { m = 0; y++; }
                    month = m; year = y;
                }

                // Monday is the first column
                readonly property int firstDow: {
                    const d = new Date(year, month, 1).getDay();
                    return (d + 6) % 7;
                }
                readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()

                Repeater {
                    model: grid.firstDow + grid.daysInMonth

                    delegate: Item {
                        id: cell
                        required property int index

                        readonly property int day: index - grid.firstDow + 1
                        readonly property bool isToday: day === root.now.getDate()
                            && grid.month === root.now.getMonth()
                            && grid.year === root.now.getFullYear()

                        implicitWidth: cal.cellW
                        implicitHeight: 30

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            visible: cell.isToday
                            color: Theme.primary
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cell.day > 0
                            text: cell.day > 0 ? cell.day : ""
                            color: cell.isToday ? Theme.textOnPrimary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: cell.isToday
                        }
                    }
                }
            }
        }
    }
}
