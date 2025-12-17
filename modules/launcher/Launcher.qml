import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: launcherScope
    property bool dontAutoCancelSearch: false
    
    // Track if state is pending cleanup (soft close occurred, waiting for timeout or reopen)
    property bool statePendingCleanup: false

    // Write launch timestamp for plugins that need to know when hamr was opened
    // (e.g., screenrecord plugin uses this to trim the end of recordings)
    Process {
        id: launchTimestampProc
        command: ["bash", "-c", "mkdir -p ~/.cache/hamr && date +%s%3N > ~/.cache/hamr/launch_timestamp"]
    }
    
    // Deferred cleanup timer for soft close (click-outside)
    // When timer fires, actually clean up state
    Timer {
        id: deferredCleanupTimer
        interval: Config.options.behavior.stateRestoreWindowMs
        repeat: false
        onTriggered: {
            // Timer expired - perform actual cleanup
            if (PluginRunner.isActive()) {
                LauncherSearch.closePlugin();
            }
            if (LauncherSearch.isInExclusiveMode()) {
                LauncherSearch.exclusiveMode = "";
            }
            launcherScope.statePendingCleanup = false;
        }
    }
    
    // Perform immediate cleanup (hard close)
    function performImmediateCleanup() {
        deferredCleanupTimer.stop();
        if (PluginRunner.isActive()) {
            LauncherSearch.closePlugin();
        }
        if (LauncherSearch.isInExclusiveMode()) {
            LauncherSearch.exclusiveMode = "";
        }
        launcherScope.statePendingCleanup = false;
    }

    Connections {
        target: GlobalStates
        function onLauncherOpenChanged() {
            if (GlobalStates.launcherOpen) {
                launchTimestampProc.running = true;
                
                // === OPENING (single handler, not per-screen) ===
                if (launcherScope.statePendingCleanup) {
                    // Reopening within restore window - cancel cleanup, preserve state
                    deferredCleanupTimer.stop();
                    launcherScope.statePendingCleanup = false;
                } else if (!launcherScope.dontAutoCancelSearch) {
                    // Normal open - start fresh
                    launcherScope.cancelSearchOnAllScreens();
                }
            } else {
                // === CLOSING (single handler, not per-screen) ===
                const restoreWindowMs = Config.options.behavior.stateRestoreWindowMs;
                
                if (GlobalStates.softClose && restoreWindowMs > 0) {
                    // Soft close (click-outside): defer cleanup, allow state restore
                    launcherScope.statePendingCleanup = true;
                    deferredCleanupTimer.restart();
                } else {
                    // Hard close (Escape, execute-with-close, etc.): immediate cleanup
                    launcherScope.performImmediateCleanup();
                }
                
                // Reset softClose flag for next close
                GlobalStates.softClose = false;
                
                // Reset dontAutoCancelSearch
                launcherScope.dontAutoCancelSearch = false;
                
                // Hide action hint
                GlobalStates.hideActionHint();
            }
        }
    }
    
    // Helper to cancel search - needs to call into the correct screen's searchWidget
    function cancelSearchOnAllScreens() {
        for (let i = 0; i < launcherVariants.instances.length; i++) {
            let panelWindow = launcherVariants.instances[i];
            if (panelWindow.monitorIsFocused) {
                panelWindow.searchWidget.cancelSearch();
                break;
            }
        }
    }

    Variants {
        id: launcherVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            property string searchingText: ""
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
            property alias searchWidget: searchWidget  // Expose for outer scope access
            screen: modelData
            visible: GlobalStates.launcherOpen && monitorIsFocused

            WlrLayershell.namespace: "quickshell:hamr"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            mask: Region {
                // Accept input on the full screen background for click-outside-to-close
                item: GlobalStates.launcherOpen ? fullScreenBackground : null
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

             FocusGrab {
                 id: grab
                 window: root
                 active: false
                 focusTarget: searchWidget.searchInput
                 
                 property bool canBeActive: root.monitorIsFocused
             }
             
             // Re-grab focus when user clicks anywhere on the launcher content
             function regrabFocus() {
                 if (!GlobalStates.launcherOpen) return;
                 if (GlobalStates.imageBrowserOpen) return;
                 if (!grab.canBeActive) return;
                 
                 grab.regrabFocus();
             }


            Connections {
                target: GlobalStates
                function onLauncherOpenChanged() {
                    if (!GlobalStates.launcherOpen) {
                        // Per-screen UI cleanup on close
                        searchWidget.disableExpandAnimation();
                        grab.deactivate();
                    } else {
                        // Per-screen UI setup on open
                        if (!GlobalStates.imageBrowserOpen) {
                            delayedGrabTimer.start();
                        }
                    }
                }
            }

            // Handle plugin execute with close
            Connections {
                target: PluginRunner
                function onExecuteCommand(command) {
                    if (command.close) {
                        // Hard close - task completed, don't preserve state
                        LauncherSearch.closePlugin();
                        GlobalStates.softClose = false;
                        GlobalStates.launcherOpen = false;
                    }
                }
            }

            // Pause launcher focus grab while ImageBrowser is open
            Connections {
                target: GlobalStates
                function onImageBrowserOpenChanged() {
                    if (GlobalStates.imageBrowserOpen) {
                        grab.deactivate();
                    } else if (GlobalStates.launcherOpen) {
                        delayedGrabTimer.start();
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: 20 // Race condition delay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive)
                        return;
                    if (GlobalStates.imageBrowserOpen)
                        return;
                    if (GlobalStates.launcherOpen) {
                        grab.activate();
                        searchWidget.focusSearchInput();
                    }
                }
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight

            function setSearchingText(text) {
                searchWidget.setSearchingText(text);
                searchWidget.focusFirstItem();
            }

            // Full screen background Item for mask and click detection
            Item {
                id: fullScreenBackground
                anchors.fill: parent

                // Background MouseArea to close when clicking outside search widget
                MouseArea {
                    anchors.fill: parent
                    visible: GlobalStates.launcherOpen
                    onClicked: (mouse) => {
                        // Check if click is outside the search widget bounds
                        const widgetMapped = columnLayout.mapToItem(fullScreenBackground, 0, 0);

                        if (mouse.x < widgetMapped.x || mouse.x > widgetMapped.x + columnLayout.width ||
                            mouse.y < widgetMapped.y || mouse.y > widgetMapped.y + columnLayout.height) {
                            // Click is outside - soft close (preserves state for restore window)
                            GlobalStates.softClose = true;
                            GlobalStates.launcherOpen = false;
                        }
                    }
                }
            }

            // Floating action hint popup - above all launcher content
            Rectangle {
                id: actionHintPopup
                visible: opacity > 0
                opacity: GlobalStates.actionHintVisible ? 1 : 0
                scale: GlobalStates.actionHintVisible ? 1 : 0.9
                z: 1000
                
                // Convert global position to local
                x: {
                    const localPos = fullScreenBackground.mapFromGlobal(GlobalStates.actionHintPosition.x, GlobalStates.actionHintPosition.y);
                    return localPos.x - width / 2;
                }
                y: {
                    const localPos = fullScreenBackground.mapFromGlobal(GlobalStates.actionHintPosition.x, GlobalStates.actionHintPosition.y);
                    return localPos.y;
                }
                
                implicitWidth: hintContent.implicitWidth + 12
                implicitHeight: hintContent.implicitHeight + 6
                radius: 4
                color: Appearance.colors.colSurfaceContainerHigh
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant
                
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                
                RowLayout {
                    id: hintContent
                    anchors.centerIn: parent
                    spacing: 6
                    
                    Kbd {
                        keys: GlobalStates.actionHintKey
                    }
                    
                    Text {
                        text: GlobalStates.actionHintName
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }
                }
            }

            Item {
                id: columnLayout
                visible: GlobalStates.launcherOpen
                
                // Track if we're dragging to avoid binding loop
                property bool isDragging: false
                
                // Calculate position from stored ratios (only when not dragging)
                x: isDragging ? x : Persistent.states.launcher.xRatio * fullScreenBackground.width - width / 2
                y: isDragging ? y : Persistent.states.launcher.yRatio * fullScreenBackground.height
                
                implicitWidth: searchWidget.implicitWidth
                implicitHeight: searchWidget.implicitHeight

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        // Priority: plugin > exclusive mode > close launcher
                        if (PluginRunner.isActive()) {
                            LauncherSearch.exitPlugin();
                        } else if (LauncherSearch.isInExclusiveMode()) {
                            LauncherSearch.exitExclusiveMode();
                        } else {
                            // Hard close - user explicitly pressed Escape
                            GlobalStates.softClose = false;
                            GlobalStates.launcherOpen = false;
                        }
                    }
                }

                SearchWidget {
                    id: searchWidget
                    anchors.horizontalCenter: parent.horizontalCenter
                    Synchronizer on searchingText {
                        property alias source: root.searchingText
                    }
                    
                    // Re-grab focus when user clicks on the launcher widget
                    onUserInteracted: root.regrabFocus()
                    
                    // Drag offset from mouse to widget origin
                    property real dragOffsetX: 0
                    property real dragOffsetY: 0
                    
                    onDragStarted: (mouseX, mouseY) => {
                        columnLayout.isDragging = true;
                        // Calculate offset from global mouse position to columnLayout origin
                        const widgetGlobalPos = columnLayout.mapToGlobal(0, 0);
                        dragOffsetX = mouseX - widgetGlobalPos.x;
                        dragOffsetY = mouseY - widgetGlobalPos.y;
                    }
                    
                    onDragMoved: (mouseX, mouseY) => {
                        // Convert global mouse position to fullScreenBackground coordinates
                        const bgGlobalPos = fullScreenBackground.mapToGlobal(0, 0);
                        let newX = mouseX - bgGlobalPos.x - dragOffsetX;
                        let newY = mouseY - bgGlobalPos.y - dragOffsetY;
                        
                        // Clamp to keep widget visible on screen
                        const screenW = fullScreenBackground.width;
                        const screenH = fullScreenBackground.height;
                        const topMargin = Appearance.sizes.elevationMargin * 20;
                        newX = Math.max(0, Math.min(newX, screenW - columnLayout.width));
                        newY = Math.max(-topMargin, Math.min(newY, screenH - columnLayout.height));
                        
                        columnLayout.x = newX;
                        columnLayout.y = newY;
                    }
                    
                    onDragEnded: {
                        // Save position as ratio for resolution independence
                        const screenW = fullScreenBackground.width;
                        const screenH = fullScreenBackground.height;
                        let xRatio = (columnLayout.x + columnLayout.width / 2) / screenW;
                        let yRatio = columnLayout.y / screenH;
                        
                        // Clamp ratios to keep widget on screen (0.0-1.0)
                        xRatio = Math.max(0.0, Math.min(1.0, xRatio));
                        yRatio = Math.max(0.0, Math.min(1.0, yRatio));
                        
                        Persistent.states.launcher.xRatio = xRatio;
                        Persistent.states.launcher.yRatio = yRatio;
                        
                        columnLayout.isDragging = false;
                    }
                }
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.launcherOpen && launcherScope.dontAutoCancelSearch) {
            // Toggle off - soft close (preserves state for restore window)
            GlobalStates.softClose = true;
            GlobalStates.launcherOpen = false;
            return;
        }
        for (let i = 0; i < launcherVariants.instances.length; i++) {
            let panelWindow = launcherVariants.instances[i];
            if (panelWindow.modelData.name == Hyprland.focusedMonitor.name) {
                launcherScope.dontAutoCancelSearch = true;
                panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
                GlobalStates.launcherOpen = true;
                return;
            }
        }
    }

    function toggleEmojis() {
        if (GlobalStates.launcherOpen && launcherScope.dontAutoCancelSearch) {
            // Toggle off - soft close (preserves state for restore window)
            GlobalStates.softClose = true;
            GlobalStates.launcherOpen = false;
            return;
        }
        for (let i = 0; i < launcherVariants.instances.length; i++) {
            let panelWindow = launcherVariants.instances[i];
            if (panelWindow.modelData.name == Hyprland.focusedMonitor.name) {
                launcherScope.dontAutoCancelSearch = true;
                panelWindow.setSearchingText(Config.options.search.prefix.emojis);
                GlobalStates.launcherOpen = true;
                return;
            }
        }
    }
}
