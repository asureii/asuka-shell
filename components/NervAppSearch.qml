pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "scripts/fzf.js" as Fzf

Item {
    id: root

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") ? (Quickshell.env("XDG_STATE_HOME") + "/evacore") : (Quickshell.env("HOME") + "/.local/state/evacore")
    readonly property string stateFile: root.stateDir + "/app_frequencies.json"

    property var frequencies: ({})

    // Load persisted app launch frequencies
    Process {
        id: freqLoader
        command: ["sh", "-c", "cat '" + root.stateFile + "' 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text.trim());
                    if (parsed && typeof parsed === "object") {
                        root.frequencies = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    // Persist frequencies on launch
    Process {
        id: freqSaver
    }

    function incrementFrequency(appId) {
        if (!appId) return;
        var map = Object.assign({}, root.frequencies);
        map[appId] = (map[appId] || 0) + 1;
        root.frequencies = map;

        var jsonStr = JSON.stringify(map);
        freqSaver.command = ["sh", "-c", "mkdir -p '" + root.stateDir + "' && cat << 'EOF' > '" + root.stateFile + "'\n" + jsonStr + "\nEOF"];
        freqSaver.running = true;
    }

    function getFrequency(appId) {
        return (root.frequencies && root.frequencies[appId]) ? root.frequencies[appId] : 0;
    }

    // Main search and scoring entry point
    function search(query, allApps, category) {
        if (!allApps || !Array.isArray(allApps) || allApps.length === 0) return [];

        var rawQuery = (query || "").trim();
        var cat = (category || "ALL").toUpperCase();
        var prefix = "";
        var cleanQuery = rawQuery;

        // Parse special prefix if provided (e.g. >e, >t, >c, >d, >k, >i)
        if (cleanQuery.startsWith(">")) {
            var spaceIdx = cleanQuery.indexOf(" ");
            if (spaceIdx !== -1) {
                prefix = cleanQuery.substring(1, spaceIdx).toLowerCase();
                cleanQuery = cleanQuery.substring(spaceIdx + 1).trim();
            } else {
                prefix = cleanQuery.substring(1).toLowerCase();
                cleanQuery = "";
            }
        }

        var qLower = cleanQuery.toLowerCase();

        // 1. Filter by category or terminal flag
        var candidates = [];
        for (var i = 0; i < allApps.length; i++) {
            var app = allApps[i];

            // Special prefix: >t or >term filters to terminal emulators or cli tools
            if (prefix === "t" || prefix === "term") {
                var isTerm = false;
                var appCats = (app.categories || "").toUpperCase();
                var appGen = (app.genericName || "").toUpperCase();
                var appComm = (app.comment || "").toUpperCase();
                if (appCats.indexOf("TERMINALEMULATOR") !== -1 ||
                    appCats.indexOf("TERMINAL") !== -1 ||
                    appGen.indexOf("TERMINAL") !== -1 ||
                    appComm.indexOf("TERMINAL") !== -1) {
                    isTerm = true;
                }
                if (!isTerm) continue;
            }

            // Normal category filtering
            if (cat !== "ALL") {
                var catMatch = false;
                if (cat === "EVA SUITE" || cat === "EVA") {
                    var nUp = (app.name || "").toUpperCase();
                    var idUp = (app.id || "").toUpperCase();
                    var cUp = (app.categories || "").toUpperCase();
                    var kUp = (app.keywords || "").toUpperCase();
                    if (nUp.indexOf("EVA") !== -1 || idUp.indexOf("EVA") !== -1 ||
                        cUp.indexOf("EVA") !== -1 || cUp.indexOf("X-EVA") !== -1 ||
                        kUp.indexOf("EVA") !== -1) {
                        catMatch = true;
                    }
                } else if (app.categories) {
                    var ac = app.categories.toUpperCase();
                    if (cat === "SYSTEM" && (ac.indexOf("SYSTEM") !== -1 || ac.indexOf("SETTINGS") !== -1 || ac.indexOf("MONITOR") !== -1 || ac.indexOf("TERMINAL") !== -1)) catMatch = true;
                    else if (cat === "NETWORK" && (ac.indexOf("NETWORK") !== -1 || ac.indexOf("WEBBROWSER") !== -1 || ac.indexOf("FILETRANSFER") !== -1)) catMatch = true;
                    else if (cat === "DEV" && (ac.indexOf("DEVELOPMENT") !== -1 || ac.indexOf("BUILDING") !== -1 || ac.indexOf("IDE") !== -1 || ac.indexOf("TEXTEDITOR") !== -1)) catMatch = true;
                    else if (cat === "UTILITY" && (ac.indexOf("UTILITY") !== -1 || ac.indexOf("FILETOOLS") !== -1 || ac.indexOf("FILEMANAGER") !== -1)) catMatch = true;
                    else if (cat === "MEDIA" && (ac.indexOf("AUDIO") !== -1 || ac.indexOf("VIDEO") !== -1 || ac.indexOf("GRAPHICS") !== -1 || ac.indexOf("VIEWER") !== -1)) catMatch = true;
                }
                if (!catMatch) continue;
            }

            candidates.push(app);
        }

        // 2. If no query, return sorted by frecency & running status
        if (!cleanQuery) {
            return candidates.sort(function(a, b) {
                var freqA = root.getFrequency(a.id);
                var freqB = root.getFrequency(b.id);
                if (freqA !== freqB) return freqB - freqA;
                if (a.isRunning !== b.isRunning) return a.isRunning ? -1 : 1;
                return (a.name || "").localeCompare(b.name || "");
            });
        }

        // 3. Prefix-targeted search
        var selectorFn;
        if (prefix === "e" || prefix === "exec") {
            selectorFn = function(item) { return (item.execBinary || item.exec || ""); };
        } else if (prefix === "c" || prefix === "cat") {
            selectorFn = function(item) { return (item.categories || ""); };
        } else if (prefix === "d" || prefix === "desc") {
            selectorFn = function(item) { return (item.comment || ""); };
        } else if (prefix === "k" || prefix === "key") {
            selectorFn = function(item) { return (item.keywords || ""); };
        } else if (prefix === "i" || prefix === "id") {
            selectorFn = function(item) { return (item.id || ""); };
        } else {
            selectorFn = function(item) {
                return [item.name, item.genericName, item.execBinary, item.keywords, item.comment].filter(Boolean).join(" ");
            };
        }

        // 4. Fuzzy search via FZF engine
        var finder = new Fzf.Finder(candidates, {
            selector: selectorFn
        });

        var rawResults = finder.find(qLower);
        var scored = [];

        for (var j = 0; j < rawResults.length; j++) {
            var r = rawResults[j];
            var appItem = r.item;
            var score = r.score;

            var nameLower = (appItem.name || "").toLowerCase();
            var genLower = (appItem.genericName || "").toLowerCase();
            var execLower = (appItem.execBinary || appItem.exec || "").toLowerCase();
            var idLower = (appItem.id || "").toLowerCase();
            var keyLower = (appItem.keywords || "").toLowerCase();
            var commentLower = (appItem.comment || "").toLowerCase();
            var freqCount = root.getFrequency(appItem.id);

            var hasDirectMatch = false;

            // Name match (highest tier)
            if (nameLower === qLower) {
                score += 5000;
                hasDirectMatch = true;
            } else if (nameLower.startsWith(qLower)) {
                score += 2500;
                hasDirectMatch = true;
            } else {
                var words = nameLower.split(/[\s\-_]+/);
                for (var w = 0; w < words.length; w++) {
                    if (words[w].startsWith(qLower)) {
                        score += 1800;
                        hasDirectMatch = true;
                        break;
                    }
                }
                if (!hasDirectMatch && nameLower.indexOf(qLower) !== -1) {
                    score += 1000;
                    hasDirectMatch = true;
                }
            }

            // Generic Name match (e.g. "Terminal emulator" for kitty)
            if (genLower) {
                if (genLower.startsWith(qLower)) {
                    score += 1500;
                    hasDirectMatch = true;
                } else {
                    var gwords = genLower.split(/[\s\-_]+/);
                    for (var gw = 0; gw < gwords.length; gw++) {
                        if (gwords[gw].startsWith(qLower)) {
                            score += 1200;
                            hasDirectMatch = true;
                            break;
                        }
                    }
                    if (!hasDirectMatch && genLower.indexOf(qLower) !== -1) {
                        score += 800;
                        hasDirectMatch = true;
                    }
                }
            }

            // Exec binary / ID match
            if (execLower === qLower || idLower === qLower) {
                score += 3000;
                hasDirectMatch = true;
            } else if (execLower.startsWith(qLower) || idLower.startsWith(qLower)) {
                score += 1500;
                hasDirectMatch = true;
            } else if (execLower.indexOf(qLower) !== -1 || idLower.indexOf(qLower) !== -1) {
                score += 700;
                hasDirectMatch = true;
            }

            // Keywords match
            if (keyLower && keyLower.indexOf(qLower) !== -1) {
                score += 600;
                hasDirectMatch = true;
            }

            // Comment match
            if (commentLower && commentLower.indexOf(qLower) !== -1) {
                score += 300;
                hasDirectMatch = true;
            }

            // Filter out distant fuzzy character scatter if no direct match exists
            if (qLower.length >= 2 && !hasDirectMatch && score < 70) {
                continue;
            }

            if (appItem.isRunning) score += 50;
            score += Math.min(freqCount * 15, 300);

            scored.push({ app: appItem, score: score });
        }

        // 5. Sort by score descending with name-length tie-breaker
        scored.sort(function(a, b) {
            if (a.score === b.score) {
                return (a.app.name || "").length - (b.app.name || "").length;
            }
            return b.score - a.score;
        });

        return scored.map(function(s) {
            return s.app;
        });
    }
}
