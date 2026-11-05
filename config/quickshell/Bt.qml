pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Bluetooth state and the multi-step jobs behind the settings page.
//
// It is a singleton rather than living in Settings.qml because there is one
// settings window per monitor: discovery, a pairing in progress and the
// "it did not answer" marks have to be the same whichever one you look at,
// and they must keep running if you close the window mid-pairing.
//
// The three lists the page shows:
//   connected  connected right now
//   saved      paired before, not connected
//   nearby     found by the scan, never paired (unnamed ones hidden unless
//              Config.btShowUnnamed — most are phones and TVs advertising BLE)
//
// Discovery only runs while the Bluetooth page is open or a job needs it.
// That matters twice over: BlueZ drops unpaired devices the moment discovery
// stops, so the nearby list is fresh each time you open the page; and a cheap
// dongle that is scanning steals airtime from a connected gamepad.
//
// The pairing agent (PIN codes, confirmations) is scripts/bt-agent.py, run by
// the bt-agent.service user unit. Quickshell does not register one itself.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapter !== null
    readonly property bool enabled: root.available && root.adapter.enabled
    readonly property bool scanning: root.enabled && root.adapter.discovering

    readonly property bool pageOpen: Panels.openPanel === "settings" && Panels.settingsPage === "bluetooth"

    // address → { kind: "connect"|"pair"|"repair", name, started, step, tries }
    property var jobs: ({})
    // address → short text saying what went wrong last time
    property var issues: ({})

    readonly property bool busy: Object.keys(root.jobs).length > 0
    readonly property bool wantScan: root.enabled && (root.pageOpen || root.needsScan)
    readonly property bool needsScan: {
        for (const a in root.jobs)
            if (root.jobs[a].kind !== "connect") return true;
        return false;
    }

    // ── Lists ──
    function label(d) { return d ? (d.deviceName || d.name || d.address) : ""; }
    function named(d) { return d.deviceName !== "" && d.deviceName !== d.address.replace(/:/g, "-"); }
    function byName(a, b) { return root.label(a).localeCompare(root.label(b)); }

    readonly property var connected: {
        const out = [];
        for (const d of Bluetooth.devices.values) if (d.connected) out.push(d);
        return out.sort(root.byName);
    }
    readonly property var saved: {
        const out = [];
        for (const d of Bluetooth.devices.values) if (d.paired && !d.connected) out.push(d);
        return out.sort(root.byName);
    }
    readonly property var nearby: {
        const out = [];
        for (const d of Bluetooth.devices.values)
            if (!d.paired && !d.connected && (Config.btShowUnnamed || root.named(d))) out.push(d);
        return out.sort((a, b) => (root.named(b) - root.named(a)) || root.byName(a, b));
    }
    readonly property int hiddenCount: {
        let n = 0;
        for (const d of Bluetooth.devices.values)
            if (!d.paired && !d.connected && !root.named(d)) n++;
        return n;
    }
    // A re-pair whose device was forgotten and has not shown up again yet:
    // it has no device object, so the page lists it from the job instead.
    readonly property var waiting: {
        const out = [];
        for (const a in root.jobs)
            if (root.jobs[a].kind === "repair" && !root.find(a))
                out.push({ address: a, name: root.jobs[a].name });
        return out;
    }

    function find(address) {
        for (const d of Bluetooth.devices.values) if (d.address === address) return d;
        return null;
    }

    function icon(d) {
        const i = d ? (d.icon || "") : "";
        if (i.indexOf("gaming") >= 0) return "󰊴";
        if (i.indexOf("headset") >= 0) return "󰋎";
        if (i.indexOf("headphone") >= 0 || i.indexOf("audio") >= 0) return "󰋋";
        if (i.indexOf("keyboard") >= 0) return "󰌌";
        if (i.indexOf("mouse") >= 0) return "󰍽";
        if (i.indexOf("phone") >= 0) return "󰄜";
        if (i.indexOf("computer") >= 0) return "󰟀";
        if (i.indexOf("video") >= 0 || i.indexOf("display") >= 0) return "󰔂";
        return "󰂯";
    }

    function jobFor(d) { return d ? (root.jobs[d.address] || null) : null; }
    function issueFor(d) { return d ? (root.issues[d.address] || "") : ""; }

    // What the row says under the name while something is happening.
    function status(d) {
        const j = root.jobFor(d);
        if (j) {
            if (j.kind === "connect") return "Connecting…";
            if (j.step === "wait") return "Waiting for it in pairing mode…";
            if (j.step === "connect") return "Paired, connecting…";
            return "Pairing…";
        }
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        return "";
    }

    // ── Actions ──
    function setIssue(address, text) {
        const next = Object.assign({}, root.issues);
        if (text) next[address] = text; else delete next[address];
        root.issues = next;
    }
    function setJob(address, job) {
        const next = Object.assign({}, root.jobs);
        if (job) next[address] = job; else delete next[address];
        root.jobs = next;
    }
    function startJob(d, kind, step) {
        root.setIssue(d.address, "");
        root.setJob(d.address, {
            kind: kind, name: root.label(d), started: Date.now(), step: step, tries: 0
        });
    }

    function setEnabled(on) { if (root.adapter) root.adapter.enabled = on; }

    function connect(d) {
        root.startJob(d, "connect", "connect");
        d.connect();
    }
    function disconnect(d) {
        root.setJob(d.address, null);
        d.disconnect();
    }
    function pair(d) {
        root.startJob(d, "pair", "pair");
        d.pair();
    }
    function cancel(address) {
        const d = root.find(address);
        if (d && d.pairing) d.cancelPair();
        root.setJob(address, null);
    }
    function forget(d) {
        root.setJob(d.address, null);
        root.setIssue(d.address, "");
        d.forget();
    }
    function setAutoConnect(d, on) { d.trusted = on; }

    // The fix for a device that "no longer connects": its side lost the bond
    // (paired to something else, or its pairing button was pressed), so the
    // key we hold is refused. Drop ours, wait for it to show up in pairing
    // mode, then pair, trust and connect — what had to be done by hand before.
    function repair(d) {
        const a = d.address;
        const name = root.label(d);
        d.forget();
        root.setIssue(a, "");
        root.setJob(a, { kind: "repair", name: name, started: Date.now(), step: "wait", tries: 0 });
    }

    // ── Job runner ──
    // A plain 1 s tick instead of chained signal handlers: device objects
    // vanish (forget) and reappear (discovery) mid-job, and polling by address
    // survives that where a Connections on the old object would not.
    readonly property var limits: ({ connect: 15000, pair: 45000, repair: 120000 })

    Timer {
        interval: 1000
        repeat: true
        running: root.busy
        onTriggered: root.tick()
    }

    function tick() {
        const now = Date.now();
        for (const a in root.jobs) {
            const j = root.jobs[a];
            const d = root.find(a);
            const late = now - j.started > root.limits[j.kind];

            if (d && d.connected && d.paired) {
                if (!d.trusted) d.trusted = true;
                root.setJob(a, null);
                continue;
            }

            if (j.kind === "connect") {
                if (late) {
                    root.setJob(a, null);
                    root.setIssue(a, "Didn't answer. If it's on, put it in pairing mode and press Re-pair.");
                }
                continue;
            }

            if (late) {
                root.setJob(a, null);
                root.setIssue(a, j.step === "wait"
                    ? "Never showed up. Hold its pairing button until the light flashes fast, then Re-pair."
                    : "Pairing didn't finish. Try again with the device in pairing mode.");
                continue;
            }

            if (!d) continue;  // repair still waiting for it to be discovered

            if (j.step === "wait") {
                j.step = "pair";
                j.tries = 1;
                j.since = now;
                d.pair();
            } else if (j.step === "pair") {
                if (d.paired) {
                    d.trusted = true;
                    j.step = "connect";
                    j.since = now;
                    d.connect();
                } else if (!d.pairing && now - (j.since || j.started) > 4000) {
                    // the pair call failed (often a page timeout while it was
                    // still waking up); give it a couple more goes
                    if (j.tries >= 3) {
                        root.setJob(a, null);
                        root.setIssue(a, "It refused to pair. Put it back in pairing mode and try again.");
                        continue;
                    }
                    j.tries++;
                    j.since = now;
                    d.pair();
                }
            } else if (j.step === "connect") {
                if (!d.connected && d.state === BluetoothDeviceState.Disconnected
                        && now - (j.since || j.started) > 5000) {
                    j.since = now;
                    d.connect();
                }
            }
            root.setJob(a, j);
        }
    }

    // ── Discovery ──
    // Pairable rides along with discovery: the agent only accepts a pairing
    // confirmation while the adapter is pairable, so this is also what keeps
    // strangers from pairing when the page is closed.
    onWantScanChanged: root.applyScan()
    Component.onCompleted: root.applyScan()

    function applyScan() {
        if (!root.adapter || !root.adapter.enabled) return;
        if (root.adapter.pairable !== root.wantScan) root.adapter.pairable = root.wantScan;
        if (root.adapter.discovering !== root.wantScan) root.adapter.discovering = root.wantScan;
    }

    // BlueZ can drop discovery on its own (adapter reset, another client
    // stopping it); put it back while we still want it.
    Timer {
        interval: 5000
        repeat: true
        running: root.wantScan
        onTriggered: root.applyScan()
    }

    Connections {
        target: root.adapter
        function onEnabledChanged() { root.applyScan(); }
    }

    // ── Late adapter ──
    // bluetooth.service only starts once the dongle exists (it is skipped with
    // "unmet condition /sys/class/bluetooth" otherwise), and Quickshell's
    // Bluetooth module binds to BlueZ once, at startup: if bluetoothd was not
    // on the bus then, the module stays empty for the life of the process,
    // even after the dongle shows up. Plugging the dongle in after login, or
    // it resetting itself, left every Bluetooth UI blank. So while there is
    // no adapter, check every few seconds whether BlueZ now has one, and if
    // it does, restart the shell — at most once a minute (stamp file), so a
    // BlueZ that lists an adapter Quickshell still cannot use cannot loop.
    property real loadedAt: Date.now()

    Timer {
        interval: 5000
        repeat: true
        running: !root.available
        onTriggered: if (Date.now() - root.loadedAt > 10000 && !lateCheck.running) lateCheck.running = true
    }

    Process {
        id: lateCheck
        command: ["/bin/sh", "-c",
            "busctl --system --no-pager tree org.bluez 2>/dev/null | grep -q '/org/bluez/hci' || exit 1; "
          + "s=\"${XDG_RUNTIME_DIR:-/tmp}/qs-bt-restart\"; now=$(date +%s); "
          + "[ -f \"$s\" ] && [ $((now - $(cat \"$s\"))) -lt 60 ] && exit 1; "
          + "echo \"$now\" > \"$s\"; exit 0"]
        onExited: code => {
            if (code !== 0 || root.available) return;
            console.warn("[Bt] BlueZ has an adapter this shell never saw; restarting the shell");
            // Through Hyprland, like the SUPER+SHIFT+R bind: a child of this
            // process dies with it on `qs kill` (tried: the shell went down
            // and never came back), a child of the compositor does not.
            // `qs kill` returns before the old instance is gone, and `-n` makes
            // the new one quit if it still sees it — so wait for it (max 10 s).
            // Without the wait the bar vanished on 2026-10-25.
            Quickshell.execDetached(["hyprctl", "eval", "hl.exec_cmd(\"sleep 1; qs kill; for i in $(seq 50); do pgrep -x qs >/dev/null || break; sleep 0.2; done; qs -d -n\")"]);
        }
    }

    // ── Toasts ──
    // Connected / disconnected and a one-time low battery warning, for paired
    // devices only. connectedChanged does not fire for what is already
    // connected at startup, so a shell reload does not spam the history.
    property var warnedLow: ({})

    function toast(title, body) {
        if (!Config.btNotify) return;
        Quickshell.execDetached(["notify-send", "-a", "Bluetooth", "-i", "bluetooth", title, body || ""]);
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData

            function onConnectedChanged() {
                const d = modelData;
                if (!d.paired && !d.connected) return;
                const batt = d.batteryAvailable ? Math.round(d.battery * 100) + "% battery" : "";
                if (d.connected) root.toast(root.label(d) + " connected", batt);
                else root.toast(root.label(d) + " disconnected", "");
            }

            function onBatteryChanged() {
                const d = modelData;
                if (!d.connected || !d.batteryAvailable) return;
                const low = d.battery <= 0.15;
                const was = !!root.warnedLow[d.address];
                if (low && !was) {
                    root.toast(root.label(d) + " is low on battery", Math.round(d.battery * 100) + "% left");
                    root.warnedLow = Object.assign({}, root.warnedLow, { [d.address]: true });
                } else if (!low && was && d.battery > 0.25) {
                    const next = Object.assign({}, root.warnedLow);
                    delete next[d.address];
                    root.warnedLow = next;
                }
            }
        }
    }
}
