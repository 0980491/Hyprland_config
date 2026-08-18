pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Material You palette read from colors.json (matugen writes it on every
// wallpaper change). Touch the file and the bar recolours itself live.
Singleton {
    id: root

    property bool ready: false

    FileView {
        id: file
        path: Qt.resolvedUrl("colors.json").toString().replace("file://", "")
        watchChanges: true
        blockLoading: true
        onLoaded: root.reload()
        onFileChanged: reload()
    }

    property var c: ({})

    function reload() {
        try {
            root.c = JSON.parse(file.text());
            root.ready = true;
        } catch (e) {
            console.warn("[Theme] could not read colors.json:", e);
        }
    }

    function col(name, fallback) {
        return (c && c[name]) ? c[name] : fallback;
    }

    // ── Colours ──
    readonly property color surface:        col("surface", "#16130f")
    readonly property color surfaceDim:     col("surface_dim", "#16130f")
    readonly property color surfaceLow:     col("surface_container_low", "#201a15")
    readonly property color surfaceC:       col("surface_container", "#261e18")
    readonly property color surfaceHigh:    col("surface_container_high", "#312822")
    readonly property color surfaceHighest: col("surface_container_highest", "#3c332d")
    // NOTE: never name a property onXxx when a property Xxx exists — QML reads it
    // as a signal handler and the binding silently returns nothing.
    readonly property color text:           col("on_surface", "#f0dfd6")
    readonly property color textDim:        col("on_surface_variant", "#d6c3b7")
    readonly property color outline:        col("outline", "#9f8d83")
    readonly property color outlineVar:     col("outline_variant", "#52443b")

    readonly property color primary:        col("primary", "#ffb784")
    readonly property color textOnPrimary:  col("on_primary", "#4f2500")
    readonly property color primaryC:       col("primary_container", "#6d390c")
    readonly property color textOnPrimaryC: col("on_primary_container", "#ffdcc6")
    readonly property color secondary:      col("secondary", "#e4bfa7")
    readonly property color secondaryC:     col("secondary_container", "#5b412f")
    readonly property color tertiary:       col("tertiary", "#c8ca94")
    readonly property color tertiaryC:      col("tertiary_container", "#47491f")
    readonly property color error:          col("error", "#ffb4ab")
    readonly property color errorC:         col("error_container", "#93000a")
    readonly property color textOnError:    col("on_error", "#690005")

    // ── Derived surfaces ──
    // The bar and the panels borrow the wallpaper's accent so they don't stay
    // the same dark grey no matter what is behind them.
    readonly property color barBg:
        Qt.alpha(Qt.tint(surface, Qt.alpha(primary, Config.barTint)), Config.barOpacity)
    readonly property color barBorder:
        Qt.alpha(Qt.tint(outlineVar, Qt.alpha(primary, 0.35)), 0.7)
    readonly property color panelBg:
        Qt.tint(surfaceC, Qt.alpha(primary, Config.panelTint))

    // ── Metrics ──
    readonly property int barHeight:   40
    readonly property int radius:      12
    // Bar islands only, so popups and toasts keep the squarer corners.
    // barHeight / 2 (= 20) would make them full pills.
    readonly property int islandRadius: 18
    readonly property int radiusSmall: 8
    readonly property int gap:         6
    readonly property int padH:        10

    // Breathing room between an island's edge and the widgets inside it. It is
    // one number because it has to be: the islands pad their row by this much
    // horizontally, and a widget's hover highlight is barHeight minus twice
    // this, so the gap around a highlight is the same on all four sides. They
    // used to be set apart from each other (6 at the sides, 4 top and bottom)
    // and the highlight sat visibly closer to the top and bottom edges.
    readonly property int islandPad:   6

    // Corner radius for anything sitting inside an island (hover highlights,
    // the active pill). Concentric with the island: a rounded shape inset by N
    // keeps its curves parallel to the outer one when its radius is N smaller.
    // At the old flat radiusSmall the highlight read as a squarer box floating
    // inside a much rounder capsule.
    readonly property int radiusInner: islandRadius - islandPad

    // ── Typography ──
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize:      13
    readonly property int iconSize:      16

    // ── Standard animation ──
    readonly property int anim: 180
}
