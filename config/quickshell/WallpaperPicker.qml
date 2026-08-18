import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland

// Wallpaper picker: a coverflow carousel over the whole screen.
//
// Replaces the rofi grid, which could only show tiny thumbnails in a list.
// Static images and Wallpaper Engine scenes live in the same carousel — a
// scene is previewed with the still frame Wallpaper Engine ships with it.
//
// The catalogue comes from `wallpaper.sh list-json`, so this file never has to
// know where the wallpapers live or how they are applied.
//
// Scenes we have captured ourselves show that capture instead: it is the full
// resolution of the monitor, while the frame Wallpaper Engine ships is often a
// 192px GIF. F6 retakes it for scenes that did not capture well.
//
//   qs ipc call panel toggle wallpaper      (bound to SUPER+B)
//
// Keys: ← → move · ↵ apply · Tab pick which monitor · R random
//       F6 recapture · Del remove the wallpaper · F5 rescan · Esc close
//       type to filter
PanelWindow {
    id: root
    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "qs-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property string screenName: modelData ? modelData.name : ""
    visible: Panels.isOpen("wallpaper", screenName)

    readonly property string wallScript: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh"

    // ── catalogue ──
    property var allItems: []
    property var monitors: []
    property var currentByMonitor: ({})
    property bool loaded: false

    // "" targets every monitor, otherwise the name of one of them
    property string target: ""

    property string query: ""

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase();
        if (q === "") return root.allItems;
        return root.allItems.filter(i => i.title.toLowerCase().indexOf(q) !== -1);
    }

    readonly property var currentItem:
        (view.currentIndex >= 0 && view.currentIndex < filtered.length)
            ? filtered[view.currentIndex] : null

    Process {
        id: catalogue
        command: [root.wallScript, "list-json"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    root.allItems = d.items || [];
                    root.monitors = d.monitors || [];
                    root.currentByMonitor = d.current || {};
                    root.loaded = true;
                    root.selectCurrent();
                } catch (e) {
                    console.warn("[WallpaperPicker] bad catalogue:", e);
                }
            }
        }
    }

    // The catalogue stats 119 workshop folders, so it is read once and kept.
    // Which wallpaper is up is the half that goes stale — applying one from
    // here, from rofi or from `random` all change it — and re-reading it is
    // 7 ms, so it happens on every open. Without this the carousel starts on
    // whatever was current the first time the picker was opened this session.
    Process {
        id: currentState
        command: [root.wallScript, "current"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.currentByMonitor = JSON.parse(line);
                    root.selectCurrent();
                } catch (e) {
                    console.warn("[WallpaperPicker] bad state:", e);
                }
            }
        }
    }

    function reload() {
        root.loaded = false;
        catalogue.running = false;
        catalogue.running = true;
    }

    // Open on whatever is already up, so the carousel starts where you are
    // instead of at the first file in the folder.
    function selectCurrent() {
        const mon = root.target !== "" ? root.target : root.screenName;
        const cur = root.currentByMonitor[mon];
        if (!cur) return;
        const wanted = cur.type === "we" ? cur.id : cur.path;
        for (let i = 0; i < root.filtered.length; i++) {
            if (root.filtered[i].value === wanted) { view.currentIndex = i; return; }
        }
    }

    onVisibleChanged: {
        if (!visible) return;
        // Clearing the box is what resets the filter: assigning root.query on
        // its own would leave the text sitting there, out of sync with it.
        search.text = "";
        root.query = "";
        if (!root.loaded) root.reload();
        // Always last: it re-centres once the answer comes back, and it has to
        // win over the index reset that clearing the filter just caused.
        currentState.running = false;
        currentState.running = true;
        search.forceActiveFocus();
    }

    // ── actions ──
    function run(args) {
        Quickshell.execDetached([root.wallScript].concat(args));
        Panels.close();
    }

    function applyCurrent() {
        const it = root.currentItem;
        if (!it) return;
        const args = [it.kind === "we" ? "we" : "image", it.value];
        if (root.target !== "") args.push(root.target);
        root.run(args);
    }

    // Retake the still for the centred scene. Applies it too, since the capture
    // only happens while the scene is actually up. Dropping `loaded` makes the
    // next open rescan, so the card picks the new capture up.
    function recaptureCurrent() {
        const it = root.currentItem;
        if (!it || it.kind !== "we") return;
        root.loaded = false;
        root.run(["recapture", it.value]);
    }

    function cycleTarget() {
        // "" (every monitor) first, then one entry per monitor
        const list = [""].concat(root.monitors);
        const i = list.indexOf(root.target);
        root.target = list[(i + 1) % list.length];
        root.selectCurrent();
    }

    // Dim everything behind. Heavy on purpose: the cards are photographs and a
    // half-lit browser window behind them fights with every one of them.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.surface, 0.95)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: Panels.close()
        }
    }

    Item {
        anchors.fill: parent

        // Scrolling anywhere over the overlay walks the carousel. PathView only
        // handles dragging on its own, and the pointer is rarely on a card.
        // One notch is one card: the deltas are accumulated so a trackpad's
        // stream of small events does not fly through the whole catalogue.
        WheelHandler {
            property real acc: 0
            readonly property real notch: 120

            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                // vertical wheel or horizontal tilt, whichever the mouse sends
                acc += (event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x);
                while (acc >= notch)  { view.decrementCurrentIndex(); acc -= notch; }
                while (acc <= -notch) { view.incrementCurrentIndex(); acc += notch; }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            // clears the bar at the top of the screen
            anchors.topMargin: Theme.barHeight + 22
            anchors.bottomMargin: 30
            spacing: 0

            // ── search ──
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 440
                implicitHeight: 42
                radius: Theme.radius
                color: Theme.surfaceHigh
                border.width: 1
                border.color: search.activeFocus ? Theme.primary : Theme.outlineVar

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: ""   // magnifier
                        color: Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        selectByMouse: true
                        selectionColor: Theme.primaryC
                        clip: true
                        focus: true

                        onTextChanged: {
                            root.query = text;
                            view.currentIndex = 0;
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: "Type to filter…"
                            color: Theme.outline
                            font: search.font
                        }

                        // The carousel is driven from here: the search box keeps
                        // focus the whole time, so every key has to be routed by
                        // hand. Left/Right win over moving the text cursor.
                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                Panels.close(); event.accepted = true; break;
                            case Qt.Key_Left:
                                view.decrementCurrentIndex(); event.accepted = true; break;
                            case Qt.Key_Right:
                                view.incrementCurrentIndex(); event.accepted = true; break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.applyCurrent(); event.accepted = true; break;
                            case Qt.Key_Tab:
                                root.cycleTarget(); event.accepted = true; break;
                            case Qt.Key_Delete:
                                root.run(["off"]); event.accepted = true; break;
                            case Qt.Key_F5:
                                root.reload(); event.accepted = true; break;
                            case Qt.Key_F6:
                                root.recaptureCurrent(); event.accepted = true; break;
                            case Qt.Key_R:
                                // only when it is not being typed into the filter
                                if (event.modifiers & Qt.ControlModifier) {
                                    root.run(root.target !== "" ? ["random", root.target] : ["random"]);
                                    event.accepted = true;
                                }
                                break;
                            }
                        }
                    }

                    Text {
                        text: root.filtered.length + "/" + root.allItems.length
                        color: Theme.outline
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            // ── carousel ──
            PathView {
                id: view
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property int cardW: Math.min(560, Math.round(width * 0.34))
                readonly property int cardH: Math.round(cardW * 0.58)

                model: root.filtered
                // With fewer cards than slots the wrap-around puts the centre
                // one off to the side, so the path only ever gets as many
                // slots as there are cards to fill them.
                pathItemCount: Math.max(1, Math.min(9, root.filtered.length))
                cacheItemCount: 4
                highlightRangeMode: PathView.StrictlyEnforceRange
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                movementDirection: PathView.Shortest
                clip: true
                interactive: true

                // Straight line through the middle of the panel. The 3D look is
                // all in the delegate: angle, scale and stacking order come from
                // these attributes.
                path: Path {
                    startX: 0
                    startY: view.height / 2

                    PathAttribute { name: "cScale"; value: 0.50 }
                    PathAttribute { name: "cAngle"; value: 64 }
                    PathAttribute { name: "cZ";     value: 0 }
                    PathAttribute { name: "cDim";   value: 0.35 }

                    PathLine { x: view.width * 0.5 - view.cardW * 0.62; y: view.height / 2 }
                    PathAttribute { name: "cScale"; value: 0.74 }
                    PathAttribute { name: "cAngle"; value: 58 }
                    PathAttribute { name: "cZ";     value: 40 }
                    PathAttribute { name: "cDim";   value: 0.75 }

                    PathLine { x: view.width * 0.5; y: view.height / 2 }
                    PathAttribute { name: "cScale"; value: 1.0 }
                    PathAttribute { name: "cAngle"; value: 0 }
                    PathAttribute { name: "cZ";     value: 100 }
                    PathAttribute { name: "cDim";   value: 1.0 }

                    PathLine { x: view.width * 0.5 + view.cardW * 0.62; y: view.height / 2 }
                    PathAttribute { name: "cScale"; value: 0.74 }
                    PathAttribute { name: "cAngle"; value: -58 }
                    PathAttribute { name: "cZ";     value: 40 }
                    PathAttribute { name: "cDim";   value: 0.75 }

                    PathLine { x: view.width; y: view.height / 2 }
                    PathAttribute { name: "cScale"; value: 0.50 }
                    PathAttribute { name: "cAngle"; value: -64 }
                    PathAttribute { name: "cZ";     value: 0 }
                    PathAttribute { name: "cDim";   value: 0.35 }
                }

                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index

                    width: view.cardW
                    height: view.cardH

                    readonly property bool isCurrent: view.currentIndex === card.index

                    // Cached delegates are built before they are on the path, so
                    // the attached properties are undefined for a frame. The
                    // fallbacks keep that out of the log (and out of the layout).
                    scale:   PathView.cScale === undefined ? 0.5 : PathView.cScale
                    z:       PathView.cZ     === undefined ? 0   : PathView.cZ
                    opacity: PathView.cDim   === undefined ? 0   : PathView.cDim

                    transform: Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: card.PathView.cAngle === undefined ? 0 : card.PathView.cAngle
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Theme.surfaceLow
                        border.width: card.isCurrent ? 2 : 1
                        border.color: card.isCurrent ? Theme.primary : Theme.outlineVar

                        Image {
                            anchors.fill: parent
                            // The mtime is on the URL only to key the pixmap
                            // cache: a recapture writes over the same path, and
                            // without this the old thumbnail would be served
                            // until Quickshell restarts. QUrl ignores the query
                            // when it resolves a file:// URL to a local path.
                            source: "file://" + card.modelData.preview
                                    + "?" + (card.modelData.stamp || "0")
                            fillMode: Image.PreserveAspectCrop
                            // The originals are up to 4K; the card is ~560px.
                            // Without this every visible card decodes full size.
                            sourceSize.height: 420
                            asynchronous: true
                            cache: true
                        }

                        // Wallpaper Engine badge, so animated scenes are obvious
                        Rectangle {
                            visible: card.modelData.kind === "we"
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 8
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: 13
                            color: Qt.alpha(Theme.surface, 0.75)

                            Text {
                                anchors.centerIn: parent
                                text: "󰅧"   // nf-md-video
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // click a side card to bring it in, the middle one to apply
                            if (card.isCurrent) root.applyCurrent();
                            else view.currentIndex = card.index;
                        }
                    }
                }
            }

            // ── title of the centred card ──
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.currentItem ? root.currentItem.title
                        : (root.loaded ? "Nothing matches that" : "Reading the catalogue…")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 3
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.maximumWidth: root.width - 120
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.target === ""
                        ? "every monitor"
                        : "only " + root.target
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }

                // Where this card's picture comes from. A scene still on the
                // stock preview will have to be captured the first time it is
                // applied; one with its own capture costs nothing to put up.
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.currentItem && root.currentItem.kind === "we"
                    text: (root.currentItem && root.currentItem.cached)
                        ? "own capture   ·   F6 to retake it"
                        : "Wallpaper Engine preview   ·   captured on first use"
                    color: Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // ── key hints ──
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                text: "←→ move   ·   ↵ apply   ·   Tab monitor   ·   Ctrl+R random   ·   F6 recapture   ·   Del remove   ·   Esc close"
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
}
