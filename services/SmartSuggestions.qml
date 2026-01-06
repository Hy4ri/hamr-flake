pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var weights: ({
        sequence: 0.35,
        session: 0.35,
        resumeFromIdle: 0.30,
        time: 0.20,
        workspace: 0.20,
        runningApps: 0.20,
        launchFromEmpty: 0.15,
        displayCount: 0.15,
        sessionDuration: 0.12,
        day: 0.10,
        monitor: 0.08,
        streak: 0.08
    })

    readonly property real frecencyInfluence: 0.4
    readonly property int maxSuggestions: 2
    readonly property real minConfidence: 0.25

    function getSuggestions() {
        if (!PluginRunner.indexCacheLoaded) return [];
        
        const context = ContextTracker.getContext();
        const appItems = getAppItems();
        
        if (appItems.length === 0) return [];
        
        let maxFrecency = 1;
        for (const item of appItems) {
            const frecency = PluginRunner.getItemFrecency("apps", item.id);
            if (frecency > maxFrecency) maxFrecency = frecency;
        }
        
        const candidates = [];
        
        for (const item of appItems) {
            const result = calculateItemConfidence(item, context, appItems);
            
            const frecency = PluginRunner.getItemFrecency("apps", item.id);
            const normalizedFrecency = frecency / maxFrecency;
            const frecencyBoost = 1 + (normalizedFrecency * frecencyInfluence);
            const finalConfidence = Math.min(result.confidence * frecencyBoost, 1.0);
            
            if (finalConfidence >= minConfidence) {
                candidates.push({
                    item: item,
                    confidence: finalConfidence,
                    reasons: result.reasons
                });
            }
        }
        
        candidates.sort((a, b) => b.confidence - a.confidence);
        
        return deduplicateSuggestions(candidates).slice(0, maxSuggestions);
    }

    function getAppItems() {
        const indexData = PluginRunner.pluginIndexes["apps"];
        if (!indexData?.items) return [];
        return indexData.items.filter(item => (item._count ?? 0) > 0);
    }

    function getAppLaunchCount(appId) {
        const indexData = PluginRunner.pluginIndexes["apps"];
        if (!indexData?.items) return 0;
        const item = indexData.items.find(i => i.appId === appId || i.id === appId);
        return item?._count ?? 0;
    }

    function calculateItemConfidence(item, context, allAppItems) {
        const scores = [];
        const reasons = [];
        const minEvents = StatisticalUtils.minEventsForPattern;
        const count = item._count ?? 0;
        
        if (item._hourSlotCounts) {
            const uniqueHoursWithData = item._hourSlotCounts.filter(c => c > 0).length;
            const hourCount = item._hourSlotCounts[context.currentHour] ?? 0;
            if (hourCount >= minEvents && uniqueHoursWithData >= 3) {
                const timeScore = StatisticalUtils.wilsonScore(hourCount, count);
                if (timeScore > 0.1) {
                    scores.push({ type: 'time', score: timeScore, weight: weights.time });
                    reasons.push(`Often used around ${formatHour(context.currentHour)}`);
                }
            }
        }
        
        if (item._dayOfWeekCounts) {
            const uniqueDaysWithData = item._dayOfWeekCounts.filter(c => c > 0).length;
            const dayCount = item._dayOfWeekCounts[context.currentDay] ?? 0;
            if (dayCount >= minEvents && uniqueDaysWithData >= 3) {
                const dayScore = StatisticalUtils.wilsonScore(dayCount, count);
                if (dayScore > 0.1) {
                    scores.push({ type: 'day', score: dayScore, weight: weights.day });
                    reasons.push(`Often used on ${formatDay(context.currentDay)}`);
                }
            }
        }
        
        if (item._workspaceCounts && context.workspace) {
            const uniqueWorkspaces = Object.keys(item._workspaceCounts).length;
            const wsCount = item._workspaceCounts[context.workspace] ?? 0;
            if (wsCount >= minEvents && uniqueWorkspaces >= 2) {
                const wsScore = StatisticalUtils.wilsonScore(wsCount, count);
                if (wsScore > 0.15) {
                    scores.push({ type: 'workspace', score: wsScore, weight: weights.workspace });
                    reasons.push(`Used on workspace ${context.workspace}`);
                }
            }
        }
        
        if (item._monitorCounts && context.monitor) {
            const uniqueMonitors = Object.keys(item._monitorCounts).length;
            const monCount = item._monitorCounts[context.monitor] ?? 0;
            if (monCount >= minEvents && uniqueMonitors >= 2) {
                const monScore = StatisticalUtils.wilsonScore(monCount, count);
                if (monScore > 0.15) {
                    scores.push({ type: 'monitor', score: monScore, weight: weights.monitor });
                    reasons.push(`Used on ${context.monitor}`);
                }
            }
        }
        
        if (item._launchedAfter && context.lastApp) {
            const seqCount = item._launchedAfter[context.lastApp] ?? 0;
            if (seqCount >= minEvents) {
                const lastAppCount = getAppLaunchCount(context.lastApp);
                const totalLaunches = allAppItems.reduce((sum, a) => sum + (a._count ?? 0), 0);
                
                const seqConfidence = StatisticalUtils.getSequenceConfidence(
                    seqCount, lastAppCount, count, totalLaunches
                );
                
                if (seqConfidence > 0.1) {
                    scores.push({ type: 'sequence', score: seqConfidence, weight: weights.sequence });
                    reasons.push(`Often opened after ${context.lastApp}`);
                }
            }
        }
        
        if (context.isSessionStart && (item._sessionStartCount ?? 0) >= minEvents) {
            const sessionScore = StatisticalUtils.wilsonScore(item._sessionStartCount, count);
            if (sessionScore > 0.15) {
                scores.push({ type: 'session', score: sessionScore, weight: weights.session });
                reasons.push("Usually opened at session start");
            }
        }
        
        if (context.isResumeFromIdle && (item._resumeFromIdleCount ?? 0) >= minEvents) {
            const resumeScore = StatisticalUtils.wilsonScore(item._resumeFromIdleCount, count);
            if (resumeScore > 0.15) {
                scores.push({ type: 'resumeFromIdle', score: resumeScore, weight: weights.resumeFromIdle });
                reasons.push("Often opened after returning");
            }
        }
        
        if (item._launchedAfter && context.runningApps?.length > 0) {
            let runningAppScore = 0;
            let matchedApp = "";
            
            for (const runningApp of context.runningApps) {
                if (runningApp === item.appId) continue;
                
                const coCount = item._launchedAfter[runningApp] ?? 0;
                if (coCount >= minEvents) {
                    const score = StatisticalUtils.wilsonScore(coCount, count);
                    if (score > runningAppScore) {
                        runningAppScore = score;
                        matchedApp = runningApp;
                    }
                }
            }
            
            if (runningAppScore > 0.1) {
                scores.push({ type: 'runningApps', score: runningAppScore, weight: weights.runningApps });
                reasons.push(`Often used with ${matchedApp}`);
            }
        }
        
        if ((item._consecutiveDays ?? 0) >= 3) {
            const streakScore = Math.min(item._consecutiveDays / 10, 1);
            scores.push({ type: 'streak', score: streakScore, weight: weights.streak });
            reasons.push(`${item._consecutiveDays}-day streak`);
        }
        
        if ((item._launchFromEmptyCount ?? 0) >= minEvents) {
            const emptyScore = StatisticalUtils.wilsonScore(item._launchFromEmptyCount, count);
            if (emptyScore > 0.15) {
                scores.push({ type: 'launchFromEmpty', score: emptyScore, weight: weights.launchFromEmpty });
                reasons.push("Quick launch favorite");
            }
        }
        
        if (item._displayCountCounts && context.displayCount) {
            const uniqueDisplayCounts = Object.keys(item._displayCountCounts).length;
            const displayKey = String(context.displayCount);
            const displayCountVal = item._displayCountCounts[displayKey] ?? 0;
            if (displayCountVal >= minEvents && uniqueDisplayCounts >= 2) {
                const displayScore = StatisticalUtils.wilsonScore(displayCountVal, count);
                if (displayScore > 0.15) {
                    scores.push({ type: 'displayCount', score: displayScore, weight: weights.displayCount });
                    const label = context.displayCount === 1 ? "single monitor" : `${context.displayCount} monitors`;
                    reasons.push(`Often used with ${label}`);
                }
            }
        }
        
        if (item._sessionDurationCounts && context.sessionDurationBucket >= 0) {
            const uniqueBuckets = item._sessionDurationCounts.filter(c => c > 0).length;
            const bucketCount = item._sessionDurationCounts[context.sessionDurationBucket] ?? 0;
            if (bucketCount >= minEvents && uniqueBuckets >= 2) {
                const bucketScore = StatisticalUtils.wilsonScore(bucketCount, count);
                if (bucketScore > 0.1) {
                    scores.push({ type: 'sessionDuration', score: bucketScore, weight: weights.sessionDuration });
                    const labels = ["session start", "early session", "mid session", "long session", "extended session"];
                    reasons.push(`Often used in ${labels[context.sessionDurationBucket]}`);
                }
            }
        }
        
        const confidence = StatisticalUtils.calculateCompositeConfidence(scores);
        
        return { confidence, reasons };
    }

    function deduplicateSuggestions(candidates) {
        const seen = new Set();
        const result = [];
        
        for (const candidate of candidates) {
            const key = candidate.item.appId ?? candidate.item.id;
            if (!seen.has(key)) {
                seen.add(key);
                result.push(candidate);
            }
        }
        
        return result;
    }

    function formatHour(hour) {
        if (hour === 0) return "12am";
        if (hour === 12) return "12pm";
        if (hour < 12) return `${hour}am`;
        return `${hour - 12}pm`;
    }

    function formatDay(day) {
        const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
        return days[day] ?? "";
    }

    readonly property bool hasSuggestions: PluginRunner.indexCacheLoaded && getSuggestions().length > 0

    function getPrimaryReason(suggestion) {
        if (suggestion.reasons.length === 0) return "Suggested";
        return suggestion.reasons[0];
    }
}
