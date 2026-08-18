pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Talking to Hyprland, which is configured in Lua.
//
// This exists because of one trap: the old space-separated dispatcher strings
// are dead. Hyprland splices whatever you send into `hl.dispatch(...)`, so
// `Hyprland.dispatch("workspace 3")` arrives as `hl.dispatch(workspace 3)` and
// comes straight back as a Lua syntax error. Nothing happens, nothing is
// logged on our side, and the click looks like it was simply ignored — which is
// exactly how it looked in the overview.
//
// The Lua form is `hl.dsp.focus({ workspace = 3 })`. Everything routes through
// here so there is one place to keep it right.
Singleton {
    id: root

    // Switch to a workspace by id.
    function goToWorkspace(id) {
        // A workspace object knows how to activate itself over IPC, which is
        // better than a dispatch string. It only exists once the workspace has
        // been used though, so the empty pinned ones still need the fallback.
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id === id) {
                ws.activate();
                return;
            }
        }
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
    }

    // Focus a window by its Hyprland address.
    //
    // Two things bite here. hl.focus only accepts direction, monitor, window,
    // urgent_or_last or last — `address = ...` is rejected, it has to be
    // window = "address:0x…". And Quickshell hands out the address without the
    // 0x that Hyprland then refuses to match ("hl.focus: window not found").
    function focusWindow(address) {
        const a = address.startsWith("0x") ? address : "0x" + address;
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + a + '" })');
    }

    // Send a window to another workspace without going there yourself.
    //
    // follow = false is not optional here: left out, the dispatcher behaves like
    // movetoworkspace and drags the monitor along, so dropping a window on
    // another card in the overview would yank you off the workspace you were
    // organising from. Same address quirk as focusWindow — the 0x has to be put
    // back on.
    function moveWindowToWorkspace(address, id) {
        const a = address.startsWith("0x") ? address : "0x" + address;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + id
                        + ', window = "address:' + a + '", follow = false })');
    }
}
