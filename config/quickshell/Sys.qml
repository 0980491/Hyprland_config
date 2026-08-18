pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// System state. One streaming process (scripts/sysinfo.sh) instead of spawning
// commands every second.
Singleton {
    id: root

    property int cpu: 0
    property int cpuTemp: 0
    property var cores: []
    property int mem: 0
    property real memUsed: 0
    property real memTotal: 0
    property int gpu: 0
    property int gpuTemp: 0
    property int vram: 0
    property real vramUsed: 0
    property real vramTotal: 0
    property int disk: 0
    property int rx: 0            // bytes/s down
    property int tx: 0            // bytes/s up
    property string iface: ""

    // "1.2 MB/s" style formatting
    function rate(bytes) {
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB/s";
        if (bytes >= 1024)    return Math.round(bytes / 1024) + " kB/s";
        return bytes + " B/s";
    }

    Process {
        id: proc
        running: true
        command: [Qt.resolvedUrl("scripts/sysinfo.sh").toString().replace("file://", ""), "3"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    root.cpu = d.cpu; root.cpuTemp = d.cpuTemp;
                    root.cores = d.cores || [];
                    root.mem = d.mem; root.memUsed = d.memUsed; root.memTotal = d.memTotal;
                    root.gpu = d.gpu; root.gpuTemp = d.gpuTemp;
                    root.vram = d.vram; root.vramUsed = d.vramUsed; root.vramTotal = d.vramTotal;
                    root.disk = d.disk;
                    root.rx = d.rx || 0; root.tx = d.tx || 0;
                    root.iface = d.iface || "";
                } catch (e) { /* partial line, ignore */ }
            }
        }
    }

    // ── Game mode (written by scripts/gamemode.sh) ──
    // Same story as caffeine below: bound to text() this never updated, so the
    // toggle in QuickSettings kept showing whatever the state was when the
    // shell last loaded. Assign it from the handlers instead.
    property bool gameMode: false

    FileView {
        id: gameModeFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/hypr/gamemode"
        watchChanges: true
        blockLoading: true
        onLoaded: root.gameMode = text().trim() === "on"
        onFileChanged: reload()
    }

    function toggleGameMode() {
        Quickshell.execDetached(["/bin/sh", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/gamemode.sh"]);
    }

    // ── Caffeine (written by scripts/caffeine.sh) ──
    // Holds a systemd inhibitor so the 1 h idle suspend in hypridle.conf never
    // fires while a long job is running.
    // Assigned from onLoaded rather than bound to text(): a binding on text()
    // does not re-evaluate when the file changes, so the button stayed dark
    // with the inhibitor running. Theme.qml reloads the same way.
    property bool caffeine: false

    FileView {
        id: caffeineFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/hypr/caffeine"
        watchChanges: true
        blockLoading: true
        onLoaded: root.caffeine = text().trim() === "on"
        onFileChanged: reload()
    }

    function toggleCaffeine() {
        Quickshell.execDetached(["/bin/sh", "-c", Quickshell.env("HOME") + "/.config/hypr/scripts/caffeine.sh"]);
    }

    // ── Battery-powered peripherals (wireless mouse/keyboard) ──
    readonly property var peripherals: {
        const out = [];
        for (const d of UPower.devices.values) {
            if (d.isLaptopBattery) continue;
            if (!d.isPresent || d.percentage <= 0) continue;
            if (d.type === UPowerDeviceType.LinePower) continue;
            out.push(d);
        }
        return out;
    }
}
