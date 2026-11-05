import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Settings panel: the things this shell can actually change, in one window.
//
// It is a sticky panel like Overview and the wallpaper carousel — same
// Panels.qml state machine, same Theme.qml colours, so it recolours with the
// wallpaper like everything else. Open it with `qs ipc call settings toggle`,
// Esc or a click outside closes it.
//
// Two kinds of switch live here and they behave differently on purpose:
//
//   · shell settings (clock, tint, toasts) are written to settings.json by
//     Config.set(). Only what you changed goes in the file, so the defaults in
//     Config.qml stay the single source of truth and the small undo arrow next
//     to a changed row deletes the key rather than writing the default back.
//   · system state (caffeine, game mode, wallpaper, remote-only) is NOT stored
//     here. Those rows shell out to the very same scripts the keybinds use, so
//     there is still one source of truth per thing.
//
// Nothing in this file writes to conf/*.lua. Monitors and workspaces are shown
// read-only for that reason: Hyprland owns them, and a GUI that edited them
// would drift from the Lua config the moment you touched either side.
PanelWindow {
    id: root
    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "qs-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property string screenName: modelData ? modelData.name : ""
    visible: Panels.isOpen("settings", screenName)

    readonly property string wallScript: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh"
    readonly property string remoteScript: Quickshell.env("HOME") + "/.config/hypr/scripts/remote-only.sh"

    // Which page is open is kept in Panels, not here: there is one of these
    // windows per monitor, and `qs ipc call settings show wallpaper` has to
    // land on the same page whichever monitor you open it from.
    readonly property var pages: [
        { key: "general",       icon: "󰒓", label: "General",       blurb: "Clock and bar widgets" },
        { key: "appearance",    icon: "󰸌", label: "Appearance",    blurb: "Tint, opacity, palette" },
        { key: "wallpaper",     icon: "󰸉", label: "Wallpaper",     blurb: "What is up, and how to change it" },
        { key: "notifications", icon: "󰂚", label: "Notifications", blurb: "Toasts, do not disturb, idle" },
        { key: "monitors",      icon: "󰍹", label: "Monitors",      blurb: "Outputs and workspaces" },
        { key: "bluetooth",     icon: "󰂯", label: "Bluetooth",     blurb: "Connected, saved and nearby devices" }
    ]

    readonly property int page: {
        for (let i = 0; i < root.pages.length; i++)
            if (root.pages[i].key === Panels.settingsPage) return i;
        return 0;
    }

    // What is on each monitor right now. Re-read on every open: applying a
    // wallpaper from the carousel, from rofi or from `random` all change it
    // behind our back (the carousel does the same for the same reason).
    property var wallByMonitor: ({})

    Process {
        id: wallState
        command: [root.wallScript, "current"]
        stdout: SplitParser {
            onRead: line => {
                try { root.wallByMonitor = JSON.parse(line); }
                catch (e) { console.warn("[Settings] bad wallpaper state:", e); }
            }
        }
    }

    onVisibleChanged: {
        if (!visible) return;
        wallState.running = false;
        wallState.running = true;
        keys.forceActiveFocus();
    }

    function run(script, args) { Quickshell.execDetached([script].concat(args)); }

    // Dragging a slider writes the file on every pixel otherwise. The commit is
    // delayed instead, so a drag lands one write and the bar still follows
    // along while you move it.
    Timer {
        id: commit
        property string key: ""
        property real val: 0
        interval: 180
        onTriggered: if (commit.key !== "") Config.set(commit.key, Math.round(commit.val * 1000) / 1000)
    }
    function push(key, v) { commit.key = key; commit.val = v; commit.restart(); }
    function pushNow(key, v) {
        commit.stop();
        commit.key = "";
        Config.set(key, Math.round(v * 1000) / 1000);
    }

    // ── Building blocks ───────────────────────────────────────────────────────

    component Card: Rectangle {
        id: card
        property string title: ""
        default property alias content: inner.data

        Layout.fillWidth: true
        implicitHeight: box.implicitHeight + 20
        radius: Theme.radius
        color: Qt.alpha(Theme.surfaceLow, 0.75)
        border.width: 1
        border.color: Theme.outlineVar

        ColumnLayout {
            id: box
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 6

            Text {
                visible: card.title !== ""
                text: card.title
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: true
                Layout.bottomMargin: 2
            }

            ColumnLayout {
                id: inner
                Layout.fillWidth: true
                spacing: 4
            }
        }
    }

    // A row with a label, an optional explanation, and a pill switch. `changed`
    // lights the undo arrow: it means settings.json is overriding the default.
    component ToggleRow: Rectangle {
        id: trow
        property string label: ""
        property string hint: ""
        property bool checked: false
        property bool changed: false
        signal toggled()
        signal cleared()

        Layout.fillWidth: true
        implicitHeight: Math.max(42, texts.implicitHeight + 16)
        radius: Theme.radiusSmall
        color: tm.containsMouse && trow.enabled ? Theme.surfaceHigh : "transparent"
        opacity: trow.enabled ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        MouseArea {
            id: tm
            anchors.fill: parent
            hoverEnabled: trow.enabled
            cursorShape: trow.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (trow.enabled) trow.toggled()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            // Sized to its text, with the spacer below eating the rest: binding
            // this column to fillWidth instead left a row whose hint is empty
            // (Show AM/PM) with its switch floating in the middle of the card.
            ColumnLayout {
                id: texts
                Layout.fillWidth: false
                Layout.maximumWidth: trow.width - 120
                spacing: 0

                Text {
                    text: trow.label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                Text {
                    visible: trow.hint !== ""
                    text: trow.hint
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 4
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Item { Layout.fillWidth: true }

            UndoDot { shown: trow.changed; onCleared: trow.cleared() }

            Rectangle {
                implicitWidth: 40
                implicitHeight: 22
                radius: 11
                color: trow.checked ? Theme.primary : Theme.surfaceHighest
                Behavior on color { ColorAnimation { duration: Theme.anim } }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    y: 3
                    x: trow.checked ? parent.width - width - 3 : 3
                    color: trow.checked ? Theme.textOnPrimary : Theme.outline
                    Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                }
            }
        }
    }

    // The little "back to the default" arrow. Its own MouseArea has to sit
    // above the row's, which it does by being declared later in the tree.
    component UndoDot: Item {
        id: dot
        property bool shown: false
        signal cleared()

        visible: dot.shown
        implicitWidth: dot.shown ? 22 : 0
        implicitHeight: 22

        Text {
            anchors.centerIn: parent
            text: "󰜉"
            color: um.containsMouse ? Theme.primary : Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }

        MouseArea {
            id: um
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dot.cleared()
        }
    }

    component SliderRow: Item {
        id: srow
        property string label: ""
        property string hint: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property bool changed: false
        signal moved(real v)
        signal committed(real v)
        signal cleared()

        // While the pointer is down the row follows the pointer, not the
        // config: the write is debounced, so binding straight to it would make
        // the handle stutter back a frame behind the finger.
        property bool dragging: false
        property real dragValue: 0
        readonly property real shown: srow.dragging ? srow.dragValue : srow.value

        Layout.fillWidth: true
        implicitHeight: 54

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: srow.label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }

                UndoDot { shown: srow.changed; onCleared: srow.cleared() }

                Text {
                    text: Math.round(srow.shown * 100) + "%"
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }

            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.surfaceHighest

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (srow.shown - srow.from) / (srow.to - srow.from)))
                    height: parent.height
                    radius: 4
                    color: Theme.primary
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    function valueAt(x) {
                        const t = Math.max(0, Math.min(1, (x - 8) / track.width));
                        return srow.from + t * (srow.to - srow.from);
                    }
                    onPressed: mv => {
                        srow.dragging = true;
                        srow.dragValue = valueAt(mv.x);
                        srow.moved(srow.dragValue);
                    }
                    onPositionChanged: mv => {
                        if (!pressed) return;
                        srow.dragValue = valueAt(mv.x);
                        srow.moved(srow.dragValue);
                    }
                    onReleased: {
                        srow.committed(srow.dragValue);
                        srow.dragging = false;
                    }
                }
            }

            Text {
                visible: srow.hint !== ""
                text: srow.hint
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 4
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }

    component ActionBtn: Rectangle {
        id: btn
        property string label: ""
        property string icon: ""
        property bool danger: false
        signal activated()

        Layout.fillWidth: true
        implicitHeight: 32
        radius: Theme.radiusSmall
        color: am.containsMouse ? (btn.danger ? Theme.errorC : Theme.surfaceHigh) : Theme.surfaceLow
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 7

            Text {
                visible: btn.icon !== ""
                text: btn.icon
                color: btn.danger && am.containsMouse ? Theme.text : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
            Text {
                text: btn.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        MouseArea {
            id: am
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }

    component InfoRow: RowLayout {
        property string k: ""
        property string v: ""
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: parent.k
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
        Item { Layout.fillWidth: true }
        Text {
            text: parent.v
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
        }
    }

    // Small inline button for device rows. `confirm` makes it ask once: the
    // first click turns it into "Sure?" for a few seconds and only the second
    // one fires — for Forget, which costs a full re-pair to undo.
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string icon: ""
        property bool on: false
        property bool danger: false
        property bool confirm: false
        property bool arming: false
        signal activated()

        implicitWidth: chipRow.implicitWidth + 18
        implicitHeight: 26
        radius: Theme.radiusSmall
        color: chip.arming ? Theme.errorC
             : chip.on ? Theme.primaryC
             : chm.containsMouse ? (chip.danger ? Theme.errorC : Theme.surfaceHighest)
             : Theme.surfaceHigh
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        Timer { id: disarm; interval: 3000; onTriggered: chip.arming = false }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: chip.icon !== ""
                text: chip.icon
                color: chip.on ? Theme.textOnPrimaryC : chip.danger ? Theme.error : Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
            Text {
                text: chip.arming ? "Sure?" : chip.label
                color: chip.on ? Theme.textOnPrimaryC : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
            }
        }

        MouseArea {
            id: chm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (chip.confirm && !chip.arming) { chip.arming = true; disarm.restart(); return; }
                chip.arming = false;
                chip.activated();
            }
        }
    }

    // One device. `kind` is which list it sits in: connected, saved or nearby.
    component DeviceRow: Rectangle {
        id: drow
        property var dev: null
        property string kind: "saved"
        readonly property var job: Bt.jobFor(drow.dev)
        readonly property string status: drow.dev ? Bt.status(drow.dev) : ""
        readonly property string issue: Bt.issueFor(drow.dev)

        Layout.fillWidth: true
        implicitHeight: Math.max(48, dcol.implicitHeight + 14)
        radius: Theme.radiusSmall
        color: dm.containsMouse ? Theme.surfaceHigh : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 10

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                color: drow.kind === "connected" ? Theme.primaryC : Theme.surfaceHighest

                Text {
                    anchors.centerIn: parent
                    text: Bt.icon(drow.dev)
                    color: drow.kind === "connected" ? Theme.textOnPrimaryC : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.iconSize
                }
            }

            ColumnLayout {
                id: dcol
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: Bt.label(drow.dev)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        elide: Text.ElideRight
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: drow.status !== "" ? drow.status
                        : drow.issue !== "" ? drow.issue
                        : drow.dev ? drow.dev.address
                            + (drow.kind !== "nearby" && !drow.dev.trusted ? "  ·  won't reconnect by itself" : "")
                        : ""
                    color: drow.status !== "" ? Theme.primary
                         : drow.issue !== "" ? Theme.error
                         : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 4
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                visible: drow.dev !== null && drow.dev.batteryAvailable
                text: drow.dev && drow.dev.batteryAvailable ? "󰁹 " + Math.round(drow.dev.battery * 100) + "%" : ""
                color: drow.dev && drow.dev.battery <= 0.15 ? Theme.error : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 3
            }

            // ── actions ──
            Chip {
                visible: drow.job !== null
                label: "Cancel"
                icon: "󰅖"
                onActivated: Bt.cancel(drow.dev.address)
            }
            Chip {
                visible: drow.job === null && drow.kind === "nearby"
                label: "Pair"
                icon: "󰂰"
                onActivated: Bt.pair(drow.dev)
            }
            Chip {
                visible: drow.job === null && drow.kind === "saved"
                label: "Connect"
                icon: "󰂱"
                onActivated: Bt.connect(drow.dev)
            }
            Chip {
                visible: drow.kind === "connected"
                label: "Disconnect"
                icon: "󰂲"
                onActivated: Bt.disconnect(drow.dev)
            }
            Chip {
                visible: drow.job === null && drow.kind === "saved"
                label: "Re-pair"
                icon: "󰑓"
                onActivated: Bt.repair(drow.dev)
            }
            Chip {
                visible: drow.kind !== "nearby"
                label: "Auto"
                icon: "󰁪"
                on: drow.dev !== null && drow.dev.trusted
                onActivated: Bt.setAutoConnect(drow.dev, !drow.dev.trusted)
            }
            Chip {
                visible: drow.job === null && drow.kind !== "nearby"
                label: "Forget"
                icon: "󰆴"
                danger: true
                confirm: true
                onActivated: Bt.forget(drow.dev)
            }
        }
    }

    component Note: Text {
        Layout.fillWidth: true
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 4
        wrapMode: Text.WordWrap
        topPadding: 2
    }

    // ── Window ────────────────────────────────────────────────────────────────

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
        id: keys
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: Panels.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.width - 140, 1000)
        height: Math.min(root.height - 140, 660)
        radius: Theme.radius + 6
        color: Theme.panelBg
        border.width: 1
        border.color: Theme.barBorder

        // Swallow clicks so they do not reach the backdrop and close the panel.
        // First child on purpose: everything declared after it sits on top and
        // still gets its own clicks.
        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // ── Sidebar ──
            // No fill and no divider: a tinted panel behind the page list drew a
            // hard vertical seam down the middle of the window. The selected
            // entry's own pill is enough to say where you are.
            Item {
                Layout.preferredWidth: 208
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        spacing: 8

                        Text {
                            text: "󰒓"
                            color: Theme.primary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.iconSize + 4
                        }
                        ColumnLayout {
                            spacing: -2
                            Text {
                                text: "Settings"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 2
                                font.bold: true
                            }
                            Text {
                                text: root.screenName
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 4
                            }
                        }
                    }

                    Repeater {
                        model: root.pages

                        delegate: Rectangle {
                            id: nav
                            required property int index
                            required property var modelData
                            readonly property bool current: root.page === nav.index

                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: Theme.radiusSmall
                            color: nav.current ? Theme.primaryC
                                 : nm.containsMouse ? Theme.surfaceHigh
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.anim } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    text: nav.modelData.icon
                                    color: nav.current ? Theme.textOnPrimaryC : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.iconSize
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: nav.modelData.label
                                    color: nav.current ? Theme.textOnPrimaryC : Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: nm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Panels.settingsPage = nav.modelData.key
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        text: "settings.json · " + Object.keys(Config.overrides || {}).length + " changed"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 4
                        elide: Text.ElideRight
                    }

                    ActionBtn {
                        label: "Back to defaults"
                        icon: "󰜉"
                        danger: true
                        visible: Object.keys(Config.overrides || {}).length > 0
                        onActivated: Config.resetAll()
                    }
                }
            }

            // ── Content ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: -2

                        Text {
                            text: root.pages[root.page].label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 4
                            font.bold: true
                        }
                        Text {
                            text: root.pages[root.page].blurb
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }

                    Rectangle {
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Theme.radiusSmall
                        color: cm.containsMouse ? Theme.errorC : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.anim } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.iconSize
                        }

                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Panels.close()
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVar }

                // One Flickable per page. Loader would rebuild a page every time
                // you come back to it and lose the scroll position with it.
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.page

                    // ── 1 · General ──
                    Flickable {
                        contentHeight: general.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: general
                            width: parent.width
                            spacing: 10

                            Card {
                                title: "Clock"

                                ToggleRow {
                                    label: "12-hour clock"
                                    hint: "1:05 PM instead of 13:05"
                                    checked: Config.clock12h
                                    changed: Config.isSet("clock12h")
                                    onToggled: Config.set("clock12h", !Config.clock12h)
                                    onCleared: Config.unset("clock12h")
                                }
                                ToggleRow {
                                    label: "Show AM/PM"
                                    enabled: Config.clock12h
                                    checked: Config.clockShowMeridiem
                                    changed: Config.isSet("clockShowMeridiem")
                                    onToggled: Config.set("clockShowMeridiem", !Config.clockShowMeridiem)
                                    onCleared: Config.unset("clockShowMeridiem")
                                }
                            }

                            Card {
                                title: "Bar"

                                ToggleRow {
                                    label: "Network speed"
                                    hint: "Up and down rate next to the network icon"
                                    checked: Config.showNetSpeed
                                    changed: Config.isSet("showNetSpeed")
                                    onToggled: Config.set("showNetSpeed", !Config.showNetSpeed)
                                    onCleared: Config.unset("showNetSpeed")
                                }
                            }

                            Card {
                                title: "Where this lives"
                                Note {
                                    text: "Changes are written to ~/.config/quickshell/settings.json, one key per "
                                        + "thing you changed. The defaults stay in Config.qml, so deleting that "
                                        + "file puts everything back exactly as it shipped."
                                }
                            }
                        }
                    }

                    // ── 2 · Appearance ──
                    Flickable {
                        contentHeight: appearance.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: appearance
                            width: parent.width
                            spacing: 10

                            Card {
                                title: "Bar and panels"

                                SliderRow {
                                    label: "Bar tint"
                                    hint: "How much of the wallpaper accent is mixed into the bar"
                                    from: 0; to: 0.5
                                    value: Config.barTint
                                    changed: Config.isSet("barTint")
                                    onMoved: v => root.push("barTint", v)
                                    onCommitted: v => root.pushNow("barTint", v)
                                    onCleared: Config.unset("barTint")
                                }
                                SliderRow {
                                    label: "Bar opacity"
                                    hint: "How much of the blurred wallpaper shows through"
                                    from: 0.3; to: 1
                                    value: Config.barOpacity
                                    changed: Config.isSet("barOpacity")
                                    onMoved: v => root.push("barOpacity", v)
                                    onCommitted: v => root.pushNow("barOpacity", v)
                                    onCleared: Config.unset("barOpacity")
                                }
                                SliderRow {
                                    label: "Panel tint"
                                    hint: "Same idea for popups and this window"
                                    from: 0; to: 0.4
                                    value: Config.panelTint
                                    changed: Config.isSet("panelTint")
                                    onMoved: v => root.push("panelTint", v)
                                    onCommitted: v => root.pushNow("panelTint", v)
                                    onCleared: Config.unset("panelTint")
                                }
                            }

                            Card {
                                title: "Palette"

                                Note {
                                    text: "Read-only: matugen writes colors.json from the wallpaper on every "
                                        + "change, and the whole shell recolours live. The Wallpaper page "
                                        + "rebuilds it."
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    columns: 4
                                    rowSpacing: 6
                                    columnSpacing: 6

                                    Repeater {
                                        model: [
                                            { name: "primary",   c: Theme.primary },
                                            { name: "secondary", c: Theme.secondary },
                                            { name: "tertiary",  c: Theme.tertiary },
                                            { name: "error",     c: Theme.error },
                                            { name: "surface",   c: Theme.surface },
                                            { name: "container", c: Theme.surfaceC },
                                            { name: "outline",   c: Theme.outline },
                                            { name: "text",      c: Theme.text }
                                        ]

                                        delegate: Rectangle {
                                            id: swatch
                                            required property var modelData

                                            Layout.fillWidth: true
                                            implicitHeight: 42
                                            radius: Theme.radiusSmall
                                            color: swatch.modelData.c
                                            border.width: 1
                                            border.color: Theme.outlineVar

                                            Text {
                                                anchors.centerIn: parent
                                                text: swatch.modelData.name
                                                color: Theme.textDim
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSize - 5
                                                // The label rides on top of the colour it names, so it
                                                // gets its own plate rather than guessing a contrast.
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    z: -1
                                                    width: parent.implicitWidth + 8
                                                    height: parent.implicitHeight + 3
                                                    radius: 4
                                                    color: Qt.alpha(Theme.surface, 0.75)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── 3 · Wallpaper ──
                    Flickable {
                        contentHeight: wallpaper.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: wallpaper
                            width: parent.width
                            spacing: 10

                            Card {
                                title: "Up right now"

                                Repeater {
                                    model: Hyprland.monitors

                                    delegate: InfoRow {
                                        required property var modelData
                                        readonly property var w: root.wallByMonitor[modelData.name]
                                        k: modelData.name
                                        v: !w ? "—"
                                           : w.type === "we" ? "Wallpaper Engine · " + w.id
                                           : (w.path || "").split("/").pop()
                                    }
                                }
                            }

                            Card {
                                title: "Change it"

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    ActionBtn {
                                        label: "Carousel"
                                        icon: "󰸉"
                                        onActivated: Panels.toggle("wallpaper", root.screenName)
                                    }
                                    ActionBtn {
                                        label: "Random"
                                        icon: "󰒟"
                                        onActivated: { root.run(root.wallScript, ["random"]); Panels.close(); }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    ActionBtn {
                                        label: "Rebuild palette"
                                        icon: "󰏘"
                                        onActivated: root.run(root.wallScript, ["theme"])
                                    }
                                    ActionBtn {
                                        label: "Restore"
                                        icon: "󰑓"
                                        onActivated: root.run(root.wallScript, ["restore"])
                                    }
                                }

                                Note {
                                    text: "Rebuild palette re-runs matugen over the wallpaper that is up and "
                                        + "recolours the shell, GTK, Qt, kitty and the rest. Restore re-applies "
                                        + "the saved wallpaper per monitor — the fix when a hotplug leaves a "
                                        + "screen with no wallpaper behind it."
                                }
                            }

                            Card {
                                title: "Still frame"

                                ActionBtn {
                                    label: "Stop the animation, keep the frame"
                                    icon: "󰏤"
                                    onActivated: root.run(root.wallScript, ["static"])
                                }

                                Note {
                                    text: "What game mode does: it parks linux-wallpaperengine and leaves the "
                                        + "captured still in its place, without touching the saved state. "
                                        + "Restore brings the scene back."
                                }
                            }
                        }
                    }

                    // ── 4 · Notifications and idle ──
                    Flickable {
                        contentHeight: notifs.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: notifs
                            width: parent.width
                            spacing: 10

                            Card {
                                title: "Notifications"

                                ToggleRow {
                                    label: "Do not disturb"
                                    hint: "Toasts are hidden; everything still lands in history"
                                    checked: Notifications.doNotDisturb
                                    onToggled: Notifications.doNotDisturb = !Notifications.doNotDisturb
                                }
                                ToggleRow {
                                    label: "Critical breaks through"
                                    hint: "Off because plenty of apps mark routine notifications critical"
                                    checked: Config.dndAllowsCritical
                                    changed: Config.isSet("dndAllowsCritical")
                                    onToggled: Config.set("dndAllowsCritical", !Config.dndAllowsCritical)
                                    onCleared: Config.unset("dndAllowsCritical")
                                }
                                ToggleRow {
                                    label: "Toasts only on the focused monitor"
                                    checked: Config.toastsOnFocusedOnly
                                    changed: Config.isSet("toastsOnFocusedOnly")
                                    onToggled: Config.set("toastsOnFocusedOnly", !Config.toastsOnFocusedOnly)
                                    onCleared: Config.unset("toastsOnFocusedOnly")
                                }

                                InfoRow { k: "In history"; v: Notifications.count + "" }

                                ActionBtn {
                                    label: "Clear history"
                                    icon: "󰎟"
                                    danger: true
                                    onActivated: Notifications.clearHistory()
                                }
                            }

                            Card {
                                title: "Idle and power"

                                ToggleRow {
                                    label: "Caffeine"
                                    hint: "Holds a systemd inhibitor so the idle suspend never fires"
                                    checked: Sys.caffeine
                                    onToggled: Sys.toggleCaffeine()
                                }
                                ToggleRow {
                                    label: "Game mode"
                                    hint: "Performance profile; also parks the animated wallpaper"
                                    checked: Sys.gameMode
                                    onToggled: Sys.toggleGameMode()
                                }

                                Note {
                                    text: "The screen never locks on idle here, on purpose — you wake and "
                                        + "unlock this machine remotely over Sunshine. Idle only blanks the "
                                        + "screens and suspends after an hour of no input, and caffeine is "
                                        + "what holds that off. Both live in hypridle.conf, not in this panel."
                                }
                            }
                        }
                    }

                    // ── 5 · Monitors ──
                    Flickable {
                        contentHeight: monitors.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: monitors
                            width: parent.width
                            spacing: 10

                            Repeater {
                                model: Hyprland.monitors

                                delegate: Card {
                                    id: mon
                                    required property var modelData
                                    title: mon.modelData.name + (mon.modelData.focused ? "  ·  focused" : "")

                                    InfoRow {
                                        k: "Resolution"
                                        v: mon.modelData.width + " × " + mon.modelData.height
                                         + (mon.modelData.lastIpcObject && mon.modelData.lastIpcObject.refreshRate
                                            ? " @ " + Math.round(mon.modelData.lastIpcObject.refreshRate) + " Hz" : "")
                                    }
                                    InfoRow { k: "Scale"; v: (mon.modelData.scale || 1).toFixed(2) + "×" }
                                    InfoRow { k: "Position"; v: mon.modelData.x + ", " + mon.modelData.y }
                                    InfoRow {
                                        k: "Active workspace"
                                        v: mon.modelData.activeWorkspace ? (mon.modelData.activeWorkspace.id + "") : "—"
                                    }
                                    InfoRow {
                                        k: "Pinned workspaces"
                                        v: {
                                            const w = Config.workspacesByMonitor[mon.modelData.name];
                                            return w && w.length ? w.join(", ") : "—";
                                        }
                                    }
                                }
                            }

                            Card {
                                title: "Remote session"

                                ActionBtn {
                                    label: "iPad mode on HDMI-A-1, everything else off"
                                    icon: "󰑬"
                                    onActivated: root.run(root.remoteScript, ["on"])
                                }
                                ActionBtn {
                                    label: "Back to the normal layout"
                                    icon: "󰍹"
                                    onActivated: root.run(root.remoteScript, ["off"])
                                }

                                Note {
                                    text: "Same thing SUPER+SHIFT+I and SUPER+SHIFT+O do. Sunshine captures the "
                                        + "first Wayland output in the list, so turning the others off is what "
                                        + "moves the stream to the screen you are actually looking at. The "
                                        + "script arms its own 120 s deadman and puts the screens back if no "
                                        + "stream shows up."
                                }
                            }

                            Card {
                                title: "Layout"
                                Note {
                                    text: "Read-only on purpose: monitors, scales and the workspaces pinned to "
                                        + "each one live in conf/monitors.lua and conf/workspaces.lua. A panel "
                                        + "that wrote them too would drift from the Lua config the moment you "
                                        + "edited either side."
                                }
                            }
                        }
                    }

                    // ── 6 · Bluetooth ──
                    // All the state and the multi-step jobs live in Bt.qml; this is
                    // only the view. Opening the page is what starts the scan.
                    Flickable {
                        contentHeight: bluetooth.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: bluetooth
                            width: parent.width
                            spacing: 10

                            Card {
                                title: "Adapter"

                                Note {
                                    visible: !Bt.available
                                    text: "No Bluetooth adapter. This PC has none built in: plug the USB "
                                        + "dongle in and this page comes alive by itself."
                                }

                                ToggleRow {
                                    visible: Bt.available
                                    label: "Bluetooth"
                                    hint: Bt.available ? (Bt.adapter.name + "  ·  " + Bt.adapter.adapterId) : ""
                                    checked: Bt.enabled
                                    onToggled: Bt.setEnabled(!Bt.enabled)
                                }

                                RowLayout {
                                    visible: Bt.enabled
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 10
                                    spacing: 8

                                    Text {
                                        text: "󰑓"
                                        color: Theme.primary
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                        RotationAnimation on rotation {
                                            running: Bt.scanning && root.visible
                                            from: 0; to: 360; duration: 1400
                                            loops: Animation.Infinite
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: Bt.scanning
                                            ? "Searching while this page is open · " + Bt.nearby.length + " nearby"
                                              + (Bt.hiddenCount > 0 && !Config.btShowUnnamed
                                                 ? " (" + Bt.hiddenCount + " unnamed hidden)" : "")
                                            : "Not searching"
                                        color: Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 3
                                    }
                                }
                            }

                            Card {
                                title: "Connected"
                                visible: Bt.enabled

                                Note {
                                    visible: Bt.connected.length === 0
                                    text: "Nothing connected right now."
                                }
                                Repeater {
                                    model: Bt.connected
                                    delegate: DeviceRow {
                                        required property var modelData
                                        dev: modelData
                                        kind: "connected"
                                    }
                                }
                            }

                            Card {
                                title: "Saved"
                                visible: Bt.enabled

                                Note {
                                    visible: Bt.saved.length === 0 && Bt.waiting.length === 0
                                    text: "No other paired devices."
                                }
                                Repeater {
                                    model: Bt.saved
                                    delegate: DeviceRow {
                                        required property var modelData
                                        dev: modelData
                                        kind: "saved"
                                    }
                                }

                                // Re-pairs whose device was forgotten and has not been
                                // discovered again yet: there is no device object to
                                // draw, only the job.
                                Repeater {
                                    model: Bt.waiting
                                    delegate: Rectangle {
                                        id: wrow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 48
                                        radius: Theme.radiusSmall
                                        color: Qt.alpha(Theme.primaryC, 0.35)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 10

                                            Text {
                                                text: "󰑓"
                                                color: Theme.primary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.iconSize
                                                Layout.preferredWidth: 32
                                                horizontalAlignment: Text.AlignHCenter
                                                RotationAnimation on rotation {
                                                    running: root.visible
                                                    from: 0; to: 360; duration: 1400
                                                    loops: Animation.Infinite
                                                }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Text {
                                                    text: wrow.modelData.name
                                                    color: Theme.text
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSize - 1
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: "Put it in pairing mode now (hold its pairing button until the "
                                                        + "light flashes fast). It pairs and connects as soon as it shows up."
                                                    color: Theme.primary
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSize - 4
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                            Chip {
                                                label: "Cancel"
                                                icon: "󰅖"
                                                onActivated: Bt.cancel(wrow.modelData.address)
                                            }
                                        }
                                    }
                                }
                            }

                            Card {
                                title: "Nearby"
                                visible: Bt.enabled

                                Note {
                                    visible: Bt.nearby.length === 0
                                    text: Bt.scanning
                                        ? "Looking… put the device in pairing mode and it shows up here with its name."
                                        : "Starting the search…"
                                }
                                Repeater {
                                    model: Bt.nearby
                                    delegate: DeviceRow {
                                        required property var modelData
                                        dev: modelData
                                        kind: "nearby"
                                    }
                                }

                                ToggleRow {
                                    label: "Show unnamed devices"
                                    hint: "Ones that only advertise an address — mostly phones and TVs"
                                    checked: Config.btShowUnnamed
                                    changed: Config.isSet("btShowUnnamed")
                                    onToggled: Config.set("btShowUnnamed", !Config.btShowUnnamed)
                                    onCleared: Config.unset("btShowUnnamed")
                                }
                            }

                            Card {
                                title: "Notifications"
                                visible: Bt.available

                                ToggleRow {
                                    label: "Connect and disconnect toasts"
                                    hint: "Also warns once when a device drops to 15 % battery"
                                    checked: Config.btNotify
                                    changed: Config.isSet("btNotify")
                                    onToggled: Config.set("btNotify", !Config.btNotify)
                                    onCleared: Config.unset("btNotify")
                                }
                            }

                            Card {
                                title: "When a saved device stops connecting"
                                Note {
                                    text: "Turn it on and press its home button first — Auto devices reconnect "
                                        + "on their own. If it still won't, the device has forgotten this PC "
                                        + "(it was paired to something else, or its pairing button was pressed), "
                                        + "so the key stored here is refused. Re-pair fixes that in one go: it "
                                        + "forgets the old pairing, waits up to two minutes for the device in "
                                        + "pairing mode, then pairs, trusts and connects it."
                                }
                                Note {
                                    text: "Codes for keyboards and phones arrive as a notification from the "
                                        + "pairing agent (bt-agent.service). New devices are paired with Auto on."
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
