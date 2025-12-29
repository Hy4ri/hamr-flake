pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool isNewSession: false
    property real sessionStartTime: 0

    property bool dpmsWasOff: false
    property real dpmsOnTime: 0
    readonly property int dpmsResumeWindowMs: 5 * 60 * 1000

    property string lastLaunchedApp: ""
    property real lastLaunchTime: 0
    readonly property int sequenceWindowMs: 10 * 60 * 1000
    
    // Check if we're within the sequence window of the last launch
    function isWithinSequenceWindow() {
        if (!lastLaunchedApp || lastLaunchTime === 0) return false;
        return (Date.now() - lastLaunchTime) < sequenceWindowMs;
    }
    
    // Record an app launch for sequence tracking
    function recordLaunch(appId) {
        lastLaunchedApp = appId;
        lastLaunchTime = Date.now();
    }
    
    // Check if this is the first launch of the session
    function isSessionStart() {
        if (!isNewSession) return false;
        const timeSinceSessionStart = Date.now() - sessionStartTime;
        return timeSinceSessionStart < 5 * 60 * 1000;  // Within 5 minutes of session start
    }
    
    // Check if user just returned from idle (DPMS was off, now on)
    function isResumeFromIdle() {
        if (!dpmsWasOff || dpmsOnTime === 0) return false;
        const timeSinceResume = Date.now() - dpmsOnTime;
        return timeSinceResume < dpmsResumeWindowMs;
    }
    
    // Get context object for suggestion calculation - fetches current values on demand
    function getContext() {
        const now = new Date();
        return {
            currentHour: now.getHours(),
            currentDay: now.getDay() === 0 ? 6 : now.getDay() - 1,  // Monday=0, Sunday=6
            workspace: CompositorService.currentWorkspace,
            workspaceId: CompositorService.currentWorkspaceId,
            monitor: CompositorService.currentMonitor,
            lastApp: isWithinSequenceWindow() ? lastLaunchedApp : "",
            isSessionStart: isSessionStart(),
            isResumeFromIdle: isResumeFromIdle(),
            runningApps: CompositorService.runningAppIds
        };
    }
    
    Component.onCompleted: {
        if (Persistent.isNewCompositorInstance) {
            isNewSession = true;
            sessionStartTime = Date.now();
        }
    }

    Connections {
        target: CompositorService
        function onCompositorEvent(eventName, eventData) {
            if (eventName === "dpms") {
                const data = eventData ?? "";
                const parts = data.split(",");
                const state = parts[0];

                if (state === "0") {
                    root.dpmsWasOff = true;
                } else if (state === "1" && root.dpmsWasOff) {
                    root.dpmsOnTime = Date.now();
                }
            }
        }
    }
}
