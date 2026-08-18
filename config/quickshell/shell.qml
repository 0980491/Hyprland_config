//  ╔══════════════════════════════════════════════════════════════════════════╗
//  ║  Desktop shell built on Quickshell                                        ║
//  ║                                                                          ║
//  ║  Contains: one bar per monitor, the notification server (you had none     ║
//  ║  running before), floating toasts and a volume OSD.                       ║
//  ║  Colours come from colors.json, which matugen rewrites on every wallpaper ║
//  ║  change → the bar recolours live, nothing needs restarting.               ║
//  ║                                                                          ║
//  ║  Start:   qs -d -n                                                        ║
//  ║  Reload:  automatic when a file is saved                                  ║
//  ║  Stop:    qs kill                                                         ║
//  ╚══════════════════════════════════════════════════════════════════════════╝
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    // Drive it from outside (keybinds, scripts):
    //   qs ipc call panel toggle calendar|notifications|volume
    //   qs ipc call panel close
    //   qs ipc call panel dnd
    IpcHandler {
        target: "panel"

        function toggle(name: string): void { Panels.toggle(name, Panels.focusedScreenName()); }
        function close(): void { Panels.close(); }
        function dnd(): void { Notifications.doNotDisturb = !Notifications.doNotDisturb; }

        // Readable state, so scripts and keybinds can show it instead of guessing
        function dndState(): string { return Notifications.doNotDisturb ? "on" : "off"; }
    }

    // One bar per screen
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    // Toasts on every screen
    Variants {
        model: Quickshell.screens
        delegate: NotificationToasts {}
    }

    // Workspace overview on every screen (only shows on the focused one)
    Variants {
        model: Quickshell.screens
        delegate: Overview {}
    }

    // Wallpaper carousel, same deal
    Variants {
        model: Quickshell.screens
        delegate: WallpaperPicker {}
    }
}
