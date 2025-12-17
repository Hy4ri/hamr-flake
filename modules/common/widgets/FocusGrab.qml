import QtQuick
import Quickshell.Hyprland

// A wrapper around HyprlandFocusGrab that handles focus recovery
// - Tracks when external tools (slurp, screenshot) take the grab
// - Supports click-to-restore via regrabFocus()
// 
// NOTE: For proper keyboard focus, also set WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
// on the PanelWindow. This is the primary fix for focus issues.
Item {
    id: root
    
    required property var window
    property bool active: false
    property Item focusTarget: null  // Item to focus after regrab (e.g., TextField)
    property bool closeOnCleared: false  // If true, emit closeRequested when cleared
    
    // Emitted when grab is cleared (if closeOnCleared is true)
    signal closeRequested()
    
    // Track if grab was cleared by external tool (slurp, screenshot, etc.)
    property bool clearedByExternal: false
    
    // Expose the inner grab for advanced use cases
    readonly property alias grab: grab
    
    // Re-grab focus - call this on user interaction (click)
    function regrabFocus() {
        if (!root.active) return;
        
        grab.active = false;
        grab.active = true;
        clearedByExternal = false;
        
        if (focusTarget) {
            focusTarget.forceActiveFocus();
        }
    }
    
    // Activate the grab
    function activate() {
        grab.active = true;
        clearedByExternal = false;
        if (focusTarget) {
            focusTarget.forceActiveFocus();
        }
    }
    
    // Deactivate the grab
    function deactivate() {
        grab.active = false;
    }
    
    HyprlandFocusGrab {
        id: grab
        windows: [root.window]
        active: root.active
        
        onCleared: {
            root.clearedByExternal = true;
            if (root.closeOnCleared && !active) {
                root.closeRequested();
            }
        }
        
        onActiveChanged: {
            if (active) {
                root.clearedByExternal = false;
            }
        }
    }
}
