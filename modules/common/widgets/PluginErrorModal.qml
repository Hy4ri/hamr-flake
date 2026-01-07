import QtQuick
import QtQuick.Layouts
import qs.modules.common

Rectangle {
    id: root
    
    property string pluginId: ""
    property string errorTitle: "Plugin Error"
    property string errorMessage: ""
    property string errorDetails: ""
    
    signal dismissed()
    
    visible: false
    
    implicitWidth: Math.min(content.implicitWidth + 48, 500)
    implicitHeight: content.implicitHeight + 32
    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainer
    border.width: 1
    border.color: Appearance.colors.colError
    
    function show(pluginId, title, message, details) {
        root.pluginId = pluginId ?? "";
        root.errorTitle = title ?? "Plugin Error";
        root.errorMessage = message ?? "";
        root.errorDetails = details ?? "";
        visible = true;
        forceActiveFocus();
    }
    
    function hide() {
        visible = false;
        root.dismissed();
    }
    
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.hide();
            event.accepted = true;
        }
    }
    
    ColumnLayout {
        id: content
        anchors.centerIn: parent
        anchors.margins: 24
        spacing: 16
        width: parent.width - 48
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            MaterialSymbol {
                text: "error"
                iconSize: 24
                color: Appearance.colors.colError
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                Text {
                    text: root.errorTitle
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colError
                }
                
                Text {
                    visible: root.pluginId !== ""
                    text: root.pluginId
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSurfaceVariant
                }
            }
        }
        
        Text {
            Layout.fillWidth: true
            text: root.errorMessage
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSurface
            wrapMode: Text.WordWrap
        }
        
        Rectangle {
            visible: root.errorDetails !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: detailsText.implicitHeight + 16
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHighest
            
            Text {
                id: detailsText
                anchors.fill: parent
                anchors.margins: 8
                text: root.errorDetails
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.m3colors.m3onSurfaceVariant
                wrapMode: Text.WrapAnywhere
            }
        }
        
        RippleButton {
            Layout.alignment: Qt.AlignRight
            implicitHeight: 36
            implicitWidth: dismissRow.implicitWidth + 24
            buttonRadius: Appearance.rounding.small
            
            colBackground: Appearance.colors.colSurfaceContainerHigh
            colBackgroundHover: Appearance.colors.colSurfaceContainerHighest
            colRipple: Appearance.colors.colOutlineVariant
            
            RowLayout {
                id: dismissRow
                anchors.centerIn: parent
                spacing: 6
                
                Text {
                    text: "Dismiss"
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSurface
                }
                
                Kbd {
                    keys: "Esc"
                }
            }
            
            onClicked: root.hide()
        }
    }
}
