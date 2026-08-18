import QtQuick
import QtQuick.Layouts

// Quick actions: game mode and caffeine. They call the very same scripts the
// keybinds do, so there is only one source of truth.
//
// Nothing else lives here on purpose — you reach the rest by keyboard:
//   screenshot   SUPER+S (region), SUPER+SHIFT+S (annotate), PRINT (monitor)
//   clipboard    SUPER+C
//   wallpaper    SUPER+B
//   night light  SUPER+SHIFT+N
//
// Power is NOT here any more: the bar places it as its own IconButton so it
// can sit right-most, after quick settings.
//
// Written out one by one rather than through a Repeater because caffeine is a
// toggle: its `active` binding has to track Sys.caffeine live, and a model
// array would rebuild every delegate on each change.
Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight - Theme.islandPad * 2

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap

        IconButton {
            icon: "󰊴"
            tip: "Game mode (performance)"
            command: ["/bin/sh", "-c", "$HOME/.config/hypr/scripts/gamemode.sh"]
        }

        IconButton {
            icon: "󰅶"
            active: Sys.caffeine
            tip: Sys.caffeine ? "Caffeine on — no suspend"
                              : "Caffeine — keep awake (no suspend)"
            command: ["/bin/sh", "-c", "$HOME/.config/hypr/scripts/caffeine.sh"]
        }
    }
}
