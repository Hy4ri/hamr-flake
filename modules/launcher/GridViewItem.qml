import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    required property var itemData
    
    property alias colBackground: background.color
    property alias colText: itemName.color
    property alias radius: background.radius
    property alias margins: background.anchors.margins
    property alias padding: itemColumnLayout.anchors.margins
    margins: Appearance.sizes.imageBrowserItemMargins
    padding: Appearance.sizes.imageBrowserItemPadding

    signal activated()

    hoverEnabled: true
    onClicked: root.activated()

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.verysmall
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            id: itemColumnLayout
            anchors.fill: parent
            spacing: 4

            Item {
                id: iconContainer
                Layout.fillHeight: true
                Layout.fillWidth: true

                Loader {
                    id: iconLoader
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) * 0.7
                    height: width
                    
                    sourceComponent: {
                        const iconType = root.itemData?.iconType ?? "material";
                        if (iconType === "text") return textIconComponent;
                        if (iconType === "image") return imageIconComponent;
                        return materialIconComponent;
                    }
                }

                Component {
                    id: textIconComponent
                    StyledText {
                        anchors.fill: parent
                        text: root.itemData?.icon ?? ""
                        font.pixelSize: parent.height * 0.8
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Component {
                    id: materialIconComponent
                    MaterialSymbol {
                        anchors.fill: parent
                        text: root.itemData?.icon ?? "help"
                        iconSize: parent.height * 0.6
                        color: root.colText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Component {
                    id: imageIconComponent
                    Image {
                        anchors.fill: parent
                        source: root.itemData?.icon ?? ""
                        sourceSize.width: parent.width
                        sourceSize.height: parent.height
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }

            StyledText {
                id: itemName
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4

                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                text: root.itemData?.name ?? ""
                visible: text !== ""
            }
        }
    }
}
