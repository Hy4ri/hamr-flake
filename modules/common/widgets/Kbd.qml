/**
 * Kbd - Keyboard shortcut hint component
 * 
 * Displays a keyboard key or shortcut in a styled box, similar to <kbd> in HTML.
 * Use for showing keyboard shortcuts on buttons and in help text.
 * 
 * Usage:
 *   Kbd { keys: "Ctrl+Enter" }
 *   Kbd { keys: "Esc" }
 *   Kbd { keys: ["Ctrl", "S"] }  // Renders as "Ctrl + S"
 *   Kbd { keys: "Esc"; textColor: "white" }  // Custom text color
 */
import QtQuick
import QtQuick.Layouts
import qs.modules.common

Rectangle {
    id: root
    
    // Single key string like "Esc", "Enter", "Ctrl+S"
    // Or array of keys like ["Ctrl", "Enter"] which renders with + separator
    property var keys: ""
    
    // Custom text color (for use on colored backgrounds)
    property color textColor: Appearance.m3colors.m3onSurfaceVariant
    
    // Computed display text
    readonly property string displayText: {
        if (Array.isArray(keys)) {
            return keys.join(" + ");
        }
        return keys;
    }
    
    implicitWidth: keyText.implicitWidth + 8
    implicitHeight: keyText.implicitHeight + 4
    
    radius: 4
    color: Appearance.colors.colSurfaceContainerHighest
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    
    Text {
        id: keyText
        anchors.centerIn: parent
        
        text: root.displayText
        font.family: Appearance.font.family.monospace ?? Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.Medium
        color: root.textColor
    }
}
