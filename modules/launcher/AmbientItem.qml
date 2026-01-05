pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property var item: null
    property string pluginId: ""

    readonly property string itemId: item?.id ?? ""
    readonly property string itemName: item?.name ?? ""
    readonly property string itemDescription: item?.description ?? ""
    readonly property string itemIcon: item?.icon ?? ""
    readonly property var itemChips: item?.chips ?? []
    readonly property var itemBadges: item?.badges ?? []
    readonly property var itemActions: item?.actions ?? []

    signal dismissed()
    signal actionClicked(string actionId)

    implicitHeight: 26
    implicitWidth: contentRow.implicitWidth + 8
    radius: Appearance.rounding.small
    color: itemMouse.containsMouse ? Appearance.colors.colSurfaceContainerHigh : Appearance.colors.colSurfaceContainer
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    MouseArea {
        id: itemMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            visible: root.itemIcon !== ""
            text: root.itemIcon
            iconSize: 14
            color: Appearance.colors.colPrimary
        }

        Text {
            text: root.itemName
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.m3colors.m3onSurface
        }

        Text {
            visible: root.itemDescription !== ""
            text: root.itemDescription
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.m3colors.m3outline
        }

        Repeater {
            model: root.itemBadges.slice(0, 3)

            delegate: Badge {
                required property var modelData
                text: modelData.text ?? ""
                icon: modelData.icon ?? ""
                image: modelData.image ?? ""
                textColor: modelData.color ? Qt.color(modelData.color) : Appearance.m3colors.m3onSurface
            }
        }

        Repeater {
            model: root.itemChips.slice(0, 2)

            delegate: Chip {
                required property var modelData
                text: modelData.text ?? ""
                icon: modelData.icon ?? ""
                backgroundColor: modelData.background ? Qt.color(modelData.background) : Appearance.colors.colSurfaceContainerHighest
                textColor: modelData.color ? Qt.color(modelData.color) : Appearance.m3colors.m3onSurface
            }
        }

        Repeater {
            model: root.itemActions.slice(0, 3)

            delegate: Rectangle {
                id: actionBtn
                required property var modelData
                required property int index

                implicitWidth: 20
                implicitHeight: 20
                radius: Appearance.rounding.small
                color: actionMouse.containsMouse ? Appearance.colors.colSurfaceContainerHighest : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: actionBtn.modelData.icon ?? ""
                    iconSize: 12
                    color: actionMouse.containsMouse ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
                }

                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.actionClicked(actionBtn.modelData.id ?? "")
                }

                StyledToolTip {
                    visible: actionMouse.containsMouse
                    text: actionBtn.modelData.name ?? ""
                }
            }
        }

        Rectangle {
            id: dismissBtn
            implicitWidth: 20
            implicitHeight: 20
            radius: Appearance.rounding.small
            color: dismissMouse.containsMouse ? Appearance.colors.colSurfaceContainerHighest : "transparent"

            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: 12
                color: dismissMouse.containsMouse ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
            }

            MouseArea {
                id: dismissMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismissed()
            }

            StyledToolTip {
                visible: dismissMouse.containsMouse
                text: "Dismiss"
            }
        }
    }
}
