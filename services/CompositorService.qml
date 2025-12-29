pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common
import qs

Singleton {
    id: root

    property bool isHyprland: false
    property bool isNiri: false
    property string compositor: "unknown"

    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")

    Component.onCompleted: {
        detectCompositor();
        updateFocusedScreenName();
    }

    Timer {
        id: compositorInitTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: detectCompositor()
    }

    function detectCompositor() {
        if (hyprlandSignature && hyprlandSignature.length > 0 && !niriSocket) {
            isHyprland = true;
            isNiri = false;
            compositor = "hyprland";
            console.info("CompositorService: Detected Hyprland");
            return;
        }

        if (niriSocket && niriSocket.length > 0) {
            isNiri = true;
            isHyprland = false;
            compositor = "niri";
            console.info("CompositorService: Detected Niri with socket:", niriSocket);
            return;
        }

        isHyprland = false;
        isNiri = false;
        compositor = "unknown";
        console.warn("CompositorService: No compositor detected");
    }

    function getFocusedScreen() {
        if (isHyprland && Hyprland.focusedMonitor) {
            const monitorName = Hyprland.focusedMonitor.name;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === monitorName) {
                    return Quickshell.screens[i];
                }
            }
        }

        if (isNiri && NiriService.currentOutput) {
            const outputName = NiriService.currentOutput;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === outputName) {
                    return Quickshell.screens[i];
                }
            }
        }

        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    property string focusedScreenName: ""
    
    function updateFocusedScreenName() {
        if (compositor === "hyprland") {
            focusedScreenName = Hyprland.focusedMonitor?.name ?? "";
        } else if (compositor === "niri") {
            focusedScreenName = NiriService.currentOutput ?? "";
        } else {
            focusedScreenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
        }
    }
    
    Connections {
        target: NiriService
        enabled: isNiri && (GlobalStates.launcherOpen || GlobalStates.launcherMinimized)
        function onCurrentOutputChanged() {
            root.updateFocusedScreenName();
        }
    }
    
    Connections {
        target: isHyprland ? Hyprland : null
        enabled: isHyprland && (GlobalStates.launcherOpen || GlobalStates.launcherMinimized)
        function onFocusedMonitorChanged() {
            root.updateFocusedScreenName();
        }
    }
    
    Connections {
        target: GlobalStates
        function onLauncherOpenChanged() {
            if (GlobalStates.launcherOpen) {
                root.updateFocusedScreenName();
                root.updateCurrentContext();
            }
        }
        function onLauncherMinimizedChanged() {
            if (GlobalStates.launcherMinimized) {
                root.updateFocusedScreenName();
            }
        }
    }

    function isScreenFocused(screen) {
        if (!screen) return false;
        if (Quickshell.screens.length === 1) return true;
        return screen.name === focusedScreenName;
    }

    function getScreenScale(screen) {
        if (!screen) return 1;

        if (isHyprland) {
            const hyprMonitor = Hyprland.monitors?.values?.find(m => m.name === screen.name);
            if (hyprMonitor?.scale !== undefined) {
                return hyprMonitor.scale;
            }
        }

        if (isNiri) {
            const niriScale = NiriService.displayScales[screen.name];
            if (niriScale !== undefined) {
                return niriScale;
            }
        }

        return screen?.devicePixelRatio ?? 1;
    }

    property string currentWorkspace: ""
    property int currentWorkspaceId: -1
    property string currentMonitor: ""
    
    function updateCurrentContext() {
        if (isHyprland) {
            currentWorkspace = Hyprland.focusedMonitor?.activeWorkspace?.name ?? "";
            currentWorkspaceId = Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1;
            currentMonitor = Hyprland.focusedMonitor?.name ?? "";
        } else if (isNiri) {
            currentWorkspace = NiriService.currentWorkspaceName;
            const wsId = NiriService.focusedWorkspaceId;
            if (wsId === "" || wsId === undefined || wsId === null) {
                currentWorkspaceId = -1;
            } else {
                const parsed = parseInt(wsId, 10);
                currentWorkspaceId = isNaN(parsed) ? -1 : parsed;
            }
            currentMonitor = NiriService.currentOutput ?? "";
        } else {
            currentWorkspace = "";
            currentWorkspaceId = -1;
            currentMonitor = "";
        }
    }

    readonly property var runningAppIds: {
        const apps = new Set();

        if (isHyprland) {
            const workspaces = Hyprland.workspaces?.values ?? [];
            for (const ws of workspaces) {
                const toplevels = ws.toplevels?.values ?? [];
                for (const toplevel of toplevels) {
                    const appClass = toplevel.lastIpcObject?.class ?? "";
                    if (appClass) {
                        apps.add(appClass.toLowerCase());
                    }
                }
            }
        }

        if (isNiri) {
            for (const w of NiriService.windows) {
                if (w.app_id) {
                    apps.add(w.app_id.toLowerCase());
                }
            }
        }

        return Array.from(apps);
    }

    signal compositorEvent(string eventName, var eventData)

    Connections {
        target: isHyprland ? Hyprland : null
        enabled: isHyprland

        function onRawEvent(event) {
            root.compositorEvent(event.name, event.data);
        }
    }

    Connections {
        target: isNiri ? NiriService : null
        enabled: isNiri

        function onWindowListChanged() {
            root.compositorEvent("windowschanged", null);
        }
    }
}
