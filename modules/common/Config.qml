pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions

Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 50 // milliseconds
    property bool blockWrites: false

    function setNestedValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = root.options;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.reload()
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.writeAdapter()
        }
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        JsonAdapter {
            id: configOptionsJsonAdapter

            // ==================== APPS ====================
            property JsonObject apps: JsonObject {
                property string terminal: "ghostty" // Terminal for shell actions
            }

            // ==================== SEARCH ====================
            property JsonObject search: JsonObject {
                property int nonAppResultDelay: 30 // Prevents lagging when typing
                property int debounceMs: 50 // Debounce for search input (ms)
                property int maxHistoryItems: 500 // Max search history entries (affects memory & fuzzy search speed)
                property string engineBaseUrl: "https://www.google.com/search?q="
                property list<string> excludedSites: ["quora.com", "facebook.com"]
                property JsonObject prefix: JsonObject {
                    property string action: "/"
                    property string app: ">"
                    property string clipboard: ";"
                    property string emojis: ":"
                    property string file: "~"
                    property string math: "="
                    property string shellCommand: "$"
                    property string shellHistory: "!"
                    property string webSearch: "?"
                }
                property JsonObject shellHistory: JsonObject {
                    property bool enable: true
                    property string shell: "auto" // "auto", "zsh", "bash", "fish"
                    property string customHistoryPath: "" // Override auto-detection
                    property int maxEntries: 500
                }
                // Action button shortcuts (Ctrl + key)
                // Default: u, i, o, p for actions 1-4
                // Note: j/k are used for navigation, l for select
                property list<string> actionKeys: ["u", "i", "o", "p"]
            }

            // ==================== IMAGE BROWSER ====================
            property JsonObject imageBrowser: JsonObject {
                property bool useSystemFileDialog: false
            }
        }
    }
}
