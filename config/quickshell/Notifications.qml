pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification server. You had NO daemon running before (swaync was installed
// but switched off, with its config in a misnamed folder), so every notify-send
// went nowhere.
Singleton {
    id: root

    // ── Do Not Disturb ────────────────────────────────────────────────────────
    // Kept on disk, because a plain property reset to false every time the shell
    // restarted: you would think you were still silenced while toasts came back.
    // Same idea as the game-mode flag Sys.qml reads, only this one also writes.
    property bool doNotDisturb: false

    // Guard so loading the file does not immediately write it back.
    property bool dndRestored: false

    onDoNotDisturbChanged: {
        if (root.dndRestored)
            dndFile.setText(root.doNotDisturb ? "on\n" : "off\n");
    }

    FileView {
        id: dndFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/quickshell/dnd"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false          // on a fresh setup the file just isn't there yet

        onLoaded: {
            root.doNotDisturb = dndFile.text().trim() === "on";
            root.dndRestored = true;
        }
        // No file yet: stay off, and the first toggle creates it.
        onLoadFailed: root.dndRestored = true
        // Someone edited it from outside (a script, another shell instance).
        onFileChanged: {
            dndFile.reload();
            root.doNotDisturb = dndFile.text().trim() === "on";
        }
    }

    // Plain JS arrays; ScriptModel turns them into diffing models so
    // Repeater/ListView don't rebuild everything on each change.
    property var popupList: []
    property var historyList: []

    readonly property ScriptModel popups: popupsModel
    readonly property ScriptModel history: historyModel
    readonly property int count: historyList.length

    ScriptModel { id: popupsModel;  values: root.popupList }
    ScriptModel { id: historyModel; values: root.historyList }

    NotificationServer {
        id: server
        keepOnReload: true

        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: notif => {
            notif.tracked = true;

            // When a notification is closed, Quickshell destroys the object, but
            // any list still holding it keeps a dangling entry that reads back as
            // null. That was the source of the "Cannot read property 'urgency' of
            // null" spam, and why Clear all could throw partway through. Purge it
            // from both lists the moment it dies.
            notif.closed.connect(() => {
                root.popupList   = root.popupList.filter(n => n && n !== notif);
                root.historyList = root.historyList.filter(n => n && n !== notif);
            });

            root.historyList = [notif].concat(root.historyList).slice(0, 40);

            // Do not disturb: history only. Critical used to be exempt, but too
            // many apps flag ordinary notifications critical, so the toggle did
            // not actually silence anything — set Config.dndAllowsCritical to
            // bring that exemption back.
            if (root.doNotDisturb
                && !(Config.dndAllowsCritical && notif.urgency === NotificationUrgency.Critical))
                return;

            root.popupList = [notif].concat(root.popupList).slice(0, 5);
        }
    }

    // Every filter below also drops nulls, so a list can never keep a dangling
    // entry even if a notification dies without its closed handler running.
    function expirePopup(notif) {
        root.popupList = root.popupList.filter(n => n && n !== notif);
    }

    function dismiss(notif) {
        root.popupList = root.popupList.filter(n => n && n !== notif);
        root.historyList = root.historyList.filter(n => n && n !== notif);
        if (notif) notif.dismiss();
    }

    function clearHistory() {
        const all = root.historyList.slice();
        root.popupList = [];
        root.historyList = [];
        for (const n of all) if (n) n.dismiss();
    }

    function timeoutFor(notif) {
        if (!notif) return 0;
        if (notif.urgency === NotificationUrgency.Critical) return 0;   // never auto-dismiss
        if (notif.expireTimeout > 0) return notif.expireTimeout;
        return notif.urgency === NotificationUrgency.Low ? 4000 : 6000;
    }
}
