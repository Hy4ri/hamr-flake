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

    readonly property int chipHeight: 24
    readonly property bool hasIcon: root.icon !== ""

    implicitWidth: contentRow.width + 12
    implicitHeight: chipHeight
    height: chipHeight

    radius: chipHeight / 2
    color: root.backgroundColor
    border.width: 2
    border.color: Appearance.colors.colPrimary

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            visible: root.hasIcon
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            iconSize: 14
            color: root.textColor
        }

        Text {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.textColor
            font {
                family: Appearance.font.family.main
                pixelSize: 11
                weight: Font.Medium
            }
        }
    }
}
