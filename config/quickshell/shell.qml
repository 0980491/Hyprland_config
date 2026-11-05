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
    // The settings window. Its own target rather than another name under
    // `panel`, so `qs ipc call settings open` reads like what it does.
    IpcHandler {
        target: "settings"

        function toggle(): void { Panels.toggle("settings", Panels.focusedScreenName()); }
        function open(): void { Panels.set("settings", Panels.focusedScreenName()); }
        function close(): void { Panels.close(); }

        // Straight to one page:
        //   qs ipc call settings show general|appearance|wallpaper|notifications|monitors|bluetooth
        function show(page: string): void {
            Panels.settingsPage = page;
            Panels.set("settings", Panels.focusedScreenName());
        }
    }

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

    // Settings window, same deal again
    Variants {
        model: Quickshell.screens
        delegate: Settings {}
    }
}
