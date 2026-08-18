import QtQuick
import QtQuick.Layouts

// A standalone capsule in the bar. The bar is not one wide container any more:
// each group of widgets sits in its own island, with nothing but transparent
// gap in between (the Hyprland layerrule blurs only what is actually painted,
// so the gaps stay clear — see conf/rules.lua, ignore_alpha).
//
// Children are laid out in a row:  Island { ClockWidget {} ResourcesWidget {} }
Rectangle {
    id: root

    default property alias content: row.data
    property int padding: Theme.islandPad
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    radius: Theme.islandRadius
    color: Theme.barBg          // blur comes from the Hyprland layerrule
    border.width: 1
    border.color: Theme.barBorder

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap
    }
}
