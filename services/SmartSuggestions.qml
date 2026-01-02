pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell

Singleton {
    id: root

    // Suggestion weights for different signal types (based on research)
    // Sequence and session are most predictive (2-3x more than time alone)
    readonly property var weights: ({
        sequence: 0.35,     // Highest - apps opened after others
        session: 0.35,      // High - first app at session start
        resumeFromIdle: 0.30, // High - apps opened after returning from idle
        time: 0.20,         // Medium - time of day patterns
        workspace: 0.20,    // Medium - workspace segregation
        runningApps: 0.20,  // Medium - correlation with open apps
        launchFromEmpty: 0.15, // Medium - apps launched without search query
        displayCount: 0.15, // Medium - single vs multi-monitor setup
        sessionDuration: 0.12, // Medium-low - time since session start
        day: 0.10,          // Lower - day of week patterns
        monitor: 0.08,      // Lowest - less important than workspace
        streak: 0.08        // Lowest - habit detection bonus
    })

    // Frecency influence on final score (0.0 - 1.0)
    // Research suggests 0.3-0.5 range to not overwhelm context signals
    readonly property real frecencyInfluence: 0.4

    // Maximum suggestions to return
    readonly property int maxSuggestions: 2
    
    // Minimum confidence threshold (research suggests 0.25 for more suggestions)
    readonly property real minConfidence: 0.25

    // Get smart suggestions based on current context
    // Returns array of { item, confidence, reasons }
    function getSuggestions() {
        if (!HistoryManager.historyLoaded) return [];
        
        const context = ContextTracker.getContext();
        const appItems = HistoryManager.getAppHistoryItems();
        
        if (appItems.length === 0) return [];
        
        // Calculate max frecency for normalization
        let maxFrecency = 1;
        for (const item of appItems) {
            const frecency = FrecencyScorer.getFrecencyScore(item);
            if (frecency > maxFrecency) maxFrecency = frecency;
        }
        
        const candidates = [];
        
        for (const item of appItems) {
            const result = calculateItemConfidence(item, context, appItems);
            
            // Combine context confidence with frecency
            // Formula: finalScore = contextConfidence * (1 + normalizedFrecency * frecencyInfluence)
            const frecency = FrecencyScorer.getFrecencyScore(item);
            const normalizedFrecency = frecency / maxFrecency;  // 0-1 range
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
        
        // Sort by confidence descending
        candidates.sort((a, b) => b.confidence - a.confidence);
        
        // Return top suggestions, ensuring diversity
        return deduplicateSuggestions(candidates).slice(0, maxSuggestions);
    }

    // Calculate confidence score for a single item
    function calculateItemConfidence(item, context, allAppItems) {
        const scores = [];
        const reasons = [];
        const minEvents = StatisticalUtils.minEventsForPattern;
        
        // 1. Time-of-day confidence (±30 min window)
        // Only show time patterns if we have data from multiple different hours
        if (item.hourSlotCounts) {
            const uniqueHoursWithData = item.hourSlotCounts.filter(c => c > 0).length;
            const hourCount = item.hourSlotCounts[context.currentHour] ?? 0;
            if (hourCount >= minEvents && uniqueHoursWithData >= 3) {
                const timeScore = StatisticalUtils.wilsonScore(hourCount, item.count);
                if (timeScore > 0.1) {
                    scores.push({ type: 'time', score: timeScore, weight: weights.time });
                    reasons.push(`Often used around ${formatHour(context.currentHour)}`);
                }
            }
        }
        
        // 2. Day-of-week confidence
        // Only show day patterns if we have data from multiple different days
        // Otherwise "used on Friday" when all data is from Friday is meaningless
        if (item.dayOfWeekCounts) {
            const uniqueDaysWithData = item.dayOfWeekCounts.filter(c => c > 0).length;
            const dayCount = item.dayOfWeekCounts[context.currentDay] ?? 0;
            if (dayCount >= minEvents && uniqueDaysWithData >= 3) {
                const dayScore = StatisticalUtils.wilsonScore(dayCount, item.count);
                if (dayScore > 0.1) {
                    scores.push({ type: 'day', score: dayScore, weight: weights.day });
                    reasons.push(`Often used on ${formatDay(context.currentDay)}`);
                }
            }
        }
        
        // 3. Workspace affinity
        // Only show workspace patterns if we have data from multiple workspaces
        if (item.workspaceCounts && context.workspace) {
            const uniqueWorkspaces = Object.keys(item.workspaceCounts).length;
            const wsCount = item.workspaceCounts[context.workspace] ?? 0;
            if (wsCount >= minEvents && uniqueWorkspaces >= 2) {
                const wsScore = StatisticalUtils.wilsonScore(wsCount, item.count);
                if (wsScore > 0.15) {
                    scores.push({ type: 'workspace', score: wsScore, weight: weights.workspace });
                    reasons.push(`Used on workspace ${context.workspace}`);
                }
            }
        }
        
        // 4. Monitor affinity
        // Only show monitor patterns if we have data from multiple monitors
        if (item.monitorCounts && context.monitor) {
            const uniqueMonitors = Object.keys(item.monitorCounts).length;
            const monCount = item.monitorCounts[context.monitor] ?? 0;
            if (monCount >= minEvents && uniqueMonitors >= 2) {
                const monScore = StatisticalUtils.wilsonScore(monCount, item.count);
                if (monScore > 0.15) {
                    scores.push({ type: 'monitor', score: monScore, weight: weights.monitor });
                    reasons.push(`Used on ${context.monitor}`);
                }
            }
        }
        
        // 5. Sequence (opened after another app)
        if (item.launchedAfter && context.lastApp) {
            const seqCount = item.launchedAfter[context.lastApp] ?? 0;
            if (seqCount >= minEvents) {
                const lastAppCount = HistoryManager.getAppLaunchCount(context.lastApp);
                const totalLaunches = allAppItems.reduce((sum, a) => sum + a.count, 0);
                
                const seqConfidence = StatisticalUtils.getSequenceConfidence(
                    seqCount, lastAppCount, item.count, totalLaunches
                );
                
                if (seqConfidence > 0.1) {
                    scores.push({ type: 'sequence', score: seqConfidence, weight: weights.sequence });
                    reasons.push(`Often opened after ${context.lastApp}`);
                }
            }
        }
        
        // 6. Session start (first app after login/boot)
        if (context.isSessionStart && item.sessionStartCount >= minEvents) {
            const sessionScore = StatisticalUtils.wilsonScore(item.sessionStartCount, item.count);
            if (sessionScore > 0.15) {
                scores.push({ type: 'session', score: sessionScore, weight: weights.session });
                reasons.push("Usually opened at session start");
            }
        }
        
        // 7. Resume from idle (first app after returning from idle/DPMS)
        if (context.isResumeFromIdle && item.resumeFromIdleCount >= minEvents) {
            const resumeScore = StatisticalUtils.wilsonScore(item.resumeFromIdleCount, item.count);
            if (resumeScore > 0.15) {
                scores.push({ type: 'resumeFromIdle', score: resumeScore, weight: weights.resumeFromIdle });
                reasons.push("Often opened after returning");
            }
        }
        
        // 8. Running apps correlation (other apps currently open)
        if (item.launchedAfter && context.runningApps?.length > 0) {
            let runningAppScore = 0;
            let matchedApp = "";
            
            for (const runningApp of context.runningApps) {
                if (runningApp === item.name) continue;
                
                const coCount = item.launchedAfter[runningApp] ?? 0;
                if (coCount >= minEvents) {
                    const score = StatisticalUtils.wilsonScore(coCount, item.count);
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
        
        // 9. Streak bonus (habit detection)
        if (item.consecutiveDays >= 3) {
            const streakScore = Math.min(item.consecutiveDays / 10, 1);
            scores.push({ type: 'streak', score: streakScore, weight: weights.streak });
            reasons.push(`${item.consecutiveDays}-day streak`);
        }
        
        // 10. Launch from empty (apps often launched without typing)
        if (item.launchFromEmptyCount >= minEvents) {
            const emptyScore = StatisticalUtils.wilsonScore(item.launchFromEmptyCount, item.count);
            if (emptyScore > 0.15) {
                scores.push({ type: 'launchFromEmpty', score: emptyScore, weight: weights.launchFromEmpty });
                reasons.push("Quick launch favorite");
            }
        }
        
        // 11. Display count affinity (single vs multi-monitor)
        if (item.displayCountCounts && context.displayCount) {
            const uniqueDisplayCounts = Object.keys(item.displayCountCounts).length;
            const displayKey = String(context.displayCount);
            const displayCountVal = item.displayCountCounts[displayKey] ?? 0;
            if (displayCountVal >= minEvents && uniqueDisplayCounts >= 2) {
                const displayScore = StatisticalUtils.wilsonScore(displayCountVal, item.count);
                if (displayScore > 0.15) {
                    scores.push({ type: 'displayCount', score: displayScore, weight: weights.displayCount });
                    const label = context.displayCount === 1 ? "single monitor" : `${context.displayCount} monitors`;
                    reasons.push(`Often used with ${label}`);
                }
            }
        }
        
        // 12. Session duration bucket
        if (item.sessionDurationCounts && context.sessionDurationBucket >= 0) {
            const uniqueBuckets = item.sessionDurationCounts.filter(c => c > 0).length;
            const bucketCount = item.sessionDurationCounts[context.sessionDurationBucket] ?? 0;
            if (bucketCount >= minEvents && uniqueBuckets >= 2) {
                const bucketScore = StatisticalUtils.wilsonScore(bucketCount, item.count);
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

    // Remove duplicate suggestions (same app from different signals)
    function deduplicateSuggestions(candidates) {
        const seen = new Set();
        const result = [];
        
        for (const candidate of candidates) {
            if (!seen.has(candidate.item.name)) {
                seen.add(candidate.item.name);
                result.push(candidate);
            }
        }
        
        return result;
    }

    // Format hour for display (e.g., "9am", "2pm")
    function formatHour(hour) {
        if (hour === 0) return "12am";
        if (hour === 12) return "12pm";
        if (hour < 12) return `${hour}am`;
        return `${hour - 12}pm`;
    }

    // Format day for display
    function formatDay(day) {
        const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
        return days[day] ?? "";
    }

    // Check if suggestions are available (for UI to show/hide suggestion section)
    readonly property bool hasSuggestions: HistoryManager.historyLoaded && getSuggestions().length > 0

    // Get primary reason for a suggestion (for display)
    function getPrimaryReason(suggestion) {
        if (suggestion.reasons.length === 0) return "Suggested";
        return suggestion.reasons[0];
    }
}
