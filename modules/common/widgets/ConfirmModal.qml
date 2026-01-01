import QtQuick
import QtQuick.Layouts
import qs.modules.common

Rectangle {
    id: root
    
    property string message: "Are you sure?"
    property string confirmText: "Confirm"
    property string cancelText: "Cancel"
    property bool destructive: true
    
    signal confirmed()
    signal cancelled()
    
    visible: false
    
    implicitWidth: content.implicitWidth + 48
    implicitHeight: content.implicitHeight + 32
    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainer
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    
    function show() {
        visible = true;
        forceActiveFocus();
    }
    
    function hide() {
        visible = false;
    }
    
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            root.cancelled();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.confirmed();
            event.accepted = true;
            return;
        }
    }
    
    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: 20
        
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            
            MaterialSymbol {
                text: "warning"
                iconSize: 24
                color: root.destructive ? Appearance.colors.colError : Appearance.m3colors.m3primary
            }
            
            Text {
                text: root.message
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSurface
            }
        }
        
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            
            RippleButton {
                implicitHeight: 36
                implicitWidth: cancelRow.implicitWidth + 24
                buttonRadius: Appearance.rounding.small
                
                colBackground: Appearance.colors.colSurfaceContainerHigh
                colBackgroundHover: Appearance.colors.colSurfaceContainerHighest
                colRipple: Appearance.colors.colOutlineVariant
                
                RowLayout {
                    id: cancelRow
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: root.cancelText
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                    }
                    
                    Kbd {
                        keys: "Esc"
                    }
                }
                
                onClicked: root.cancelled()
            }
            
            RippleButton {
                implicitHeight: 36
                implicitWidth: confirmRow.implicitWidth + 24
                buttonRadius: Appearance.rounding.small
                
                colBackground: root.destructive 
                    ? Qt.darker(Appearance.colors.colErrorContainer, 1.3)
                    : Appearance.colors.colPrimary
                colBackgroundHover: root.destructive
                    ? Qt.darker(Appearance.colors.colErrorContainer, 1.15)
                    : Appearance.colors.colPrimaryHover
                colRipple: root.destructive
                    ? Qt.darker(Appearance.colors.colError, 1.2)
                    : Appearance.colors.colPrimaryActive
                
                RowLayout {
                    id: confirmRow
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Text {
                        text: root.confirmText
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root.destructive
                            ? (Appearance.colors.colOnErrorContainer ?? Appearance.colors.colError)
                            : Appearance.m3colors.m3onPrimary
                    }
                    
                    Kbd {
                        keys: "Enter"
                        textColor: root.destructive
                            ? (Appearance.colors.colOnErrorContainer ?? Appearance.colors.colError)
                            : Appearance.m3colors.m3onPrimary
                    }
                }
                
                onClicked: root.confirmed()
            }
        }
    }
}
