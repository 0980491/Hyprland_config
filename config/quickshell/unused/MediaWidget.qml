import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// What's playing (Spotify, browser, mpv…).
// Bar: play state + scrolling title. Scroll changes track, middle click
// play/pauses, click opens the full player with cover art and progress.
BarItem {
    id: root
    panel: "media"

    // Which player we are driving. Without pinning it, pausing made the
    // "prefer whatever is playing" rule fall through to a different player, so
    // the next press of play talked to the wrong one and seemed dead.
    property string pinnedId: ""

    readonly property bool showPopup: Panels.isOpen("media", screenName)
    active: showPopup

    readonly property var players: Mpris.players.values
    readonly property var player: {
        if (players.length === 0) return null;
        if (pinnedId !== "") {
            for (const p of players) if (p.uniqueId === pinnedId) return p;
        }
        // nothing pinned yet: whatever is actually playing wins
        for (const p of players) if (p.isPlaying) return p;
        return players[0];
    }

    // Pin whatever we touch, then act on it
    function togglePlay() {
        const p = root.player;
        if (!p) return;
        root.pinnedId = p.uniqueId;
        if (p.isPlaying) {
            if (p.canPause) p.pause();
            else if (p.canTogglePlaying) p.togglePlaying();
        } else {
            if (p.canPlay) p.play();
            else if (p.canTogglePlaying) p.togglePlaying();
        }
    }

    function step(forward) {
        const p = root.player;
        if (!p) return;
        root.pinnedId = p.uniqueId;
        if (forward) { if (p.canGoNext) p.next(); }
        else { if (p.canGoPrevious) p.previous(); }
    }

    function nextPlayer() {
        if (players.length < 2) return;
        let i = 0;
        for (let n = 0; n < players.length; n++)
            if (players[n].uniqueId === root.pinnedId) { i = n; break; }
        root.pinnedId = players[(i + 1) % players.length].uniqueId;
    }

    visible: player !== null
    implicitWidth: Math.min(row.implicitWidth + padding * 2, 320)

    tooltip: player
        ? (player.identity + "<br>" + (player.trackTitle || "") +
           (player.trackArtist ? "<br>" + player.trackArtist : ""))
        : ""

    onClicked: Panels.toggle("media", root.screenName)
    onMiddleClicked: root.togglePlay()
    onRightClicked: root.nextPlayer()
    onScrolled: delta => root.step(delta > 0)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.player && root.player.isPlaying ? "󰎈" : "󰏤"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.iconSize - 1
        }

        // Text scrolls when it doesn't fit
        Item {
            implicitWidth: Math.min(label.implicitWidth, 240)
            implicitHeight: label.implicitHeight
            clip: true

            Text {
                id: label
                text: {
                    if (!root.player) return "";
                    const t = root.player.trackTitle || "";
                    const a = root.player.trackArtist || "";
                    return a ? a + " — " + t : t;
                }
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1

                property bool overflows: implicitWidth > 240

                SequentialAnimation on x {
                    running: label.overflows
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2000 }
                    NumberAnimation {
                        to: -(label.implicitWidth - 240)
                        duration: Math.max(2000, (label.implicitWidth - 240) * 30)
                        easing.type: Easing.InOutQuad
                    }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { to: 0; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    // ── Full player ──
    PopupCard {
        visible: root.showPopup && root.player !== null
        anchor.item: root
        implicitWidth: 400
        cardHeight: 190

        // Keeps position ticking while the popup is open
        Timer {
            running: root.showPopup && root.player !== null
            interval: 1000
            repeat: true
            onTriggered: if (root.player) root.player.positionChanged()
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // Cover art
            Rectangle {
                Layout.preferredWidth: 130
                Layout.preferredHeight: 130
                Layout.alignment: Qt.AlignVCenter
                radius: Theme.radiusSmall
                color: Theme.surfaceHigh
                clip: true

                Text {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "󰎈"
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: 44
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackTitle || "Nothing playing") : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackArtist || "") : ""
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackAlbum || "") : ""
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                // Progress
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    visible: root.player !== null && root.player.lengthSupported && root.player.length > 0

                    Rectangle {
                        id: seek
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Theme.surfaceHighest

                        Rectangle {
                            width: {
                                if (!root.player || !root.player.length) return 0;
                                return parent.width * Math.min(1, root.player.position / root.player.length);
                            }
                            height: parent.height
                            radius: 3
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            enabled: root.player !== null && root.player.canSeek
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mv => {
                                if (!root.player) return;
                                root.player.position = (mv.x / seek.width) * root.player.length;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: root.player ? Config.formatTime(root.player.position) : ""
                            color: Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 4
                        }
                        Text {
                            text: root.player ? Config.formatTime(root.player.length) : ""
                            color: Theme.outline
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 4
                        }
                    }
                }

                // Controls
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6

                    Repeater {
                        model: [
                            { icon: "󰒮", act: "prev" },
                            { icon: "play", act: "play" },
                            { icon: "󰒭", act: "next" },
                            { icon: "󰵀", act: "swap" }
                        ]

                        delegate: Rectangle {
                            id: ctl
                            required property var modelData

                            readonly property bool isPlay: ctl.modelData.act === "play"
                            implicitWidth: isPlay ? 42 : 32
                            implicitHeight: 32
                            radius: Theme.radiusSmall
                            visible: ctl.modelData.act !== "swap" || root.players.length > 1
                            color: isPlay ? Theme.primaryC
                                 : ctlMouse.containsMouse ? Theme.surfaceHigh
                                 : Theme.surfaceLow

                            Text {
                                anchors.centerIn: parent
                                text: ctl.isPlay
                                    ? (root.player && root.player.isPlaying ? "󰏤" : "󰐊")
                                    : ctl.modelData.icon
                                color: ctl.isPlay ? Theme.textOnPrimaryC : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.iconSize
                            }

                            MouseArea {
                                id: ctlMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    switch (ctl.modelData.act) {
                                    case "prev": root.step(false); break;
                                    case "play": root.togglePlay(); break;
                                    case "next": root.step(true); break;
                                    case "swap": root.nextPlayer(); break;
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.player ? root.player.identity : ""
                        color: Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 4
                        elide: Text.ElideRight
                        Layout.maximumWidth: 110
                    }
                }
            }
        }
    }
}
