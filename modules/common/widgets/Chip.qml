pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property color backgroundColor: Appearance.colors.colSurfaceContainerHighest
    property color textColor: Appearance.m3colors.m3onSurface

    readonly property int chipHeight: 18
    readonly property bool hasIcon: root.icon !== ""

    implicitWidth: contentRow.width + 10
    implicitHeight: chipHeight
    height: chipHeight

    radius: chipHeight / 2
    color: root.backgroundColor
    border.width: 1
    border.color: Appearance.colors.colOutline

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 3

        MaterialSymbol {
            visible: root.hasIcon
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            iconSize: 11
            color: root.textColor
        }

        Text {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.textColor
            font {
                family: Appearance.font.family.main
                pixelSize: 9
                weight: Font.Medium
            }
        }
    }
}
