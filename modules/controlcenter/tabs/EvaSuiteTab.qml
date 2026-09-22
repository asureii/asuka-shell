import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../components"
import "./evasuite"

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.94)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Decoupled Dual-Wing Selection State
    // Left Wing: 0: EVAFILE, 1: EVATERM, 2: EVASORT (default: 2 EVASORT)
    // Right Wing: 3: EVALINK, 4: EVATUBE, 5: QUICKSHELL (default: 3 EVALINK)
    property int selectedLeftIndex: 2
    property int selectedRightIndex: 3

    // ============================================================
    // EVACORE & EVA SUITE BACKEND
    // ============================================================
    property var evaSuiteStatus: ({
        evacore: { installed: false, version: "" },
        shell: { running: false, pid: null },
        sort: { running: false, pid: null },
        file: { running: false, count: 0, pids: [] },
        term: { running: false, count: 0, pids: [] },
        link: { running: false, pid: null },
        tube: { available: false }
    })
    property string evaSortFeedback: ""
    property string activeSortRules: ""
    property string sortSourceDir: "~/Downloads"
    property string sortStrategy: "rename"
    property var sortCategories: [
        { name: "Music", icon: "󰝚", dest: "~/Music", dest_full: "/home/camellia/Music", exts: [".mp3", ".flac", ".wav", ".ogg", ".m4a", ".opus"], count: 12 },
        { name: "Videos", icon: "󰕧", dest: "~/Videos", dest_full: "/home/camellia/Videos", exts: [".mp4", ".mkv", ".avi", ".mov", ".webm"], count: 12 },
        { name: "Pictures", icon: "󰋩", dest: "~/Pictures", dest_full: "/home/camellia/Pictures", exts: [".jpg", ".png", ".gif", ".webp", ".svg"], count: 18 },
        { name: "Documents", icon: "󰈙", dest: "~/Documents", dest_full: "/home/camellia/Documents", exts: [".pdf", ".docx", ".xlsx", ".txt", ".md"], count: 19 },
        { name: "Archives", icon: "󰛫", dest: "~/Downloads/Archives", dest_full: "/home/camellia/Downloads/Archives", exts: [".zip", ".tar", ".gz", ".7z", ".rar"], count: 13 },
        { name: "Installers", icon: "󰏖", dest: "~/Downloads/Installers", dest_full: "/home/camellia/Downloads/Installers", exts: [".deb", ".rpm", ".appimage", ".exe"], count: 9 },
        { name: "Torrents", icon: "󰇚", dest: "~/Downloads/Torrents", dest_full: "/home/camellia/Downloads/Torrents", exts: [".torrent"], count: 1 }
    ]

    Process {
        id: evaStatusProcess
        command: [Quickshell.configPath("scripts/evacore_bridge.py"), "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data) root.evaSuiteStatus = data;
                } catch (e) {}
            }
        }
    }

    Process {
        id: evaSortProcess
        command: [Quickshell.configPath("scripts/evacore_bridge.py"), "sort_run"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data.success) {
                        root.evaSortFeedback = "✓ SORT COMPLETED: " + (data.output || "Cleaned");
                    } else {
                        root.evaSortFeedback = "✕ SORT ERROR: " + (data.error || "Failed");
                    }
                } catch (e) {
                    root.evaSortFeedback = "SORT DISPATCHED";
                }
                evaSortFeedbackTimer.restart();
                evaStatusProcess.running = true;
            }
        }
    }

    Process {
        id: evaSortDaemonProcess
        command: [Quickshell.configPath("scripts/evacore_bridge.py"), "sort_toggle_daemon"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    root.evaSortFeedback = "WATCHER: " + (data.action ? data.action.toUpperCase() : "TOGGLED");
                } catch (e) {
                    root.evaSortFeedback = "WATCHER TOGGLED";
                }
                evaSortFeedbackTimer.restart();
                evaStatusProcess.running = true;
            }
        }
    }

    Process {
        id: evaRulesProcess
        command: [Quickshell.configPath("scripts/evacore_bridge.py"), "sort_rules"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data) {
                        if (data.rules_text) root.activeSortRules = data.rules_text;
                        if (Array.isArray(data.categories) && data.categories.length > 0) root.sortCategories = data.categories;
                        if (data.source) root.sortSourceDir = data.source;
                        if (data.strategy) root.sortStrategy = data.strategy;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: clipPasteProcess
        command: ["wl-paste", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                var clip = text.trim();
                if (clip.length > 0) {
                    root.newDownloadUrl = clip;
                }
            }
        }
    }

    Timer {
        id: evaSortFeedbackTimer
        interval: 4000
        repeat: false
        onTriggered: root.evaSortFeedback = ""
    }

    Timer {
        id: evaSuiteTimer
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: {
            if (!evaStatusProcess.running) evaStatusProcess.running = true;
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            if (!evaStatusProcess.running) evaStatusProcess.running = true;
            root.fetchEvalinkStatus();
        }
    }

    function launchEvaFile(path) {
        Quickshell.execDetached([Quickshell.configPath("scripts/evacore_bridge.py"), "launch_file", path || ""]);
        evaStatusProcess.running = true;
    }

    function launchEvaTerm(cwd, cmd) {
        Quickshell.execDetached([Quickshell.configPath("scripts/evacore_bridge.py"), "launch_term", cwd || "", cmd || ""]);
        evaStatusProcess.running = true;
    }

    function runEvaSort(path) {
        root.evaSortFeedback = "EXECUTING DIRECTORY SORT...";
        evaSortProcess.command = [Quickshell.configPath("scripts/evacore_bridge.py"), "sort_run", path || ""];
        evaSortProcess.running = true;
    }

    function toggleEvaSortDaemon() {
        root.evaSortFeedback = "TOGGLING WATCHER DAEMON...";
        evaSortDaemonProcess.running = true;
    }

    function restartQuickshell() {
        Quickshell.execDetached([Quickshell.configPath("scripts/evacore_bridge.py"), "shell_restart"]);
    }

    function downloadStreamWithEvaTube(url, format, dest) {
        var execCmd = "evatube";
        if (url && url.length > 0) {
            execCmd += " '" + url + "'";
        }
        root.launchEvaTerm(dest || "~/Videos", execCmd);
    }

    // ============================================================
    // EVALINK DOWNLOAD MANAGER BACKEND (JSON-RPC)
    // ============================================================
    property bool evalinkOnline: false
    property string evalinkDlSpeed: "0 B/s"
    property string evalinkUlSpeed: "0 B/s"
    property int evalinkActiveCount: 0
    property int evalinkWaitingCount: 0
    property int evalinkStoppedCount: 0
    property var evalinkTasks: []
    property string newDownloadUrl: ""

    function formatBytes(bytes) {
        var b = parseFloat(bytes) || 0;
        if (b < 1024) return b.toFixed(0) + " B";
        var kb = b / 1024;
        if (kb < 1024) return kb.toFixed(1) + " KB";
        var mb = kb / 1024;
        if (mb < 1024) return mb.toFixed(1) + " MB";
        var gb = mb / 1024;
        return gb.toFixed(2) + " GB";
    }

    function formatSpeed(bytesPerSec) {
        return formatBytes(bytesPerSec) + "/s";
    }

    function formatEta(completed, total, speed) {
        var c = parseFloat(completed) || 0;
        var t = parseFloat(total) || 0;
        var s = parseFloat(speed) || 0;
        if (s <= 0 || t <= c) return "--:--";
        var remainingSecs = Math.round((t - c) / s);
        var m = Math.floor(remainingSecs / 60);
        var sec = remainingSecs % 60;
        if (m < 60) return (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec;
        var h = Math.floor(m / 60);
        m = m % 60;
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    function evalinkRpcCall(method, params, callback) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://127.0.0.1:6800/jsonrpc", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 2000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var json = JSON.parse(xhr.responseText);
                        root.evalinkOnline = true;
                        if (callback) callback(json.result);
                    } catch (e) {
                        if (callback) callback(null);
                    }
                } else {
                    root.evalinkOnline = false;
                    if (callback) callback(null);
                }
            }
        };
        xhr.ontimeout = function() { root.evalinkOnline = false; };
        xhr.onerror = function() { root.evalinkOnline = false; };
        xhr.send(JSON.stringify({
            jsonrpc: "2.0",
            id: "evalink-hud",
            method: "aria2." + method,
            params: params || []
        }));
    }

    function formatTask(t, type) {
        var name = "UNNAMED_DOWNLOAD";
        if (t.files && t.files.length > 0) {
            var f = t.files[0];
            if (f.path && f.path.length > 0) name = f.path.split("/").pop();
            else if (f.uris && f.uris.length > 0) name = f.uris[0].uri.split("/").pop().split("?")[0];
        }
        var comp = parseFloat(t.completedLength) || 0;
        var total = parseFloat(t.totalLength) || 0;
        var isStop = (type === "stopped");
        var isWait = (type === "waiting");
        return {
            gid: t.gid,
            name: name,
            status: t.status,
            completed: comp,
            total: total,
            pct: isStop ? 1.0 : (total > 0 ? (comp / total) : 0),
            speed: (isStop || isWait) ? 0 : t.downloadSpeed,
            speedStr: isStop ? t.status.toUpperCase() : (isWait ? "PAUSED" : root.formatSpeed(t.downloadSpeed)),
            sizeStr: isStop ? root.formatBytes(comp) : (root.formatBytes(comp) + " / " + (total > 0 ? root.formatBytes(total) : "UNKNOWN")),
            eta: isStop ? (t.status === "complete" ? "DONE" : "STOPPED") : (isWait ? "--:--" : root.formatEta(comp, total, t.downloadSpeed))
        };
    }

    function fetchEvalinkStatus() {
        evalinkRpcCall("getGlobalStat", [], function(res) {
            if (res) {
                root.evalinkDlSpeed = root.formatSpeed(res.downloadSpeed);
                root.evalinkUlSpeed = root.formatSpeed(res.uploadSpeed);
                root.evalinkActiveCount = parseInt(res.numActive) || 0;
                root.evalinkWaitingCount = parseInt(res.numWaiting) || 0;
                root.evalinkStoppedCount = parseInt(res.numStopped) || 0;
            }
        });

        evalinkRpcCall("tellActive", [], function(activeList) {
            var all = Array.isArray(activeList) ? activeList.map(function(t) { return root.formatTask(t, "active"); }) : [];

            evalinkRpcCall("tellWaiting", [0, 20], function(waitList) {
                if (Array.isArray(waitList)) {
                    all = all.concat(waitList.map(function(t) { return root.formatTask(t, "waiting"); }));
                }

                evalinkRpcCall("tellStopped", [0, 20], function(stopList) {
                    if (Array.isArray(stopList)) {
                        all = all.concat(stopList.map(function(t) { return root.formatTask(t, "stopped"); }));
                    }
                    root.evalinkTasks = all;
                });
            });
        });
    }

    function evalinkAddUri(url) {
        if (!url || url.trim().length === 0) return;
        evalinkRpcCall("addUri", [[url.trim()]], function(res) {
            root.newDownloadUrl = "";
            root.fetchEvalinkStatus();
        });
    }

    function evalinkPause(gid) { evalinkRpcCall("pause", [gid], function() { root.fetchEvalinkStatus(); }); }
    function evalinkResume(gid) { evalinkRpcCall("unpause", [gid], function() { root.fetchEvalinkStatus(); }); }
    function evalinkCancel(gid) { evalinkRpcCall("remove", [gid], function() { root.fetchEvalinkStatus(); }); }
    function evalinkPauseAll() { evalinkRpcCall("pauseAll", [], function() { root.fetchEvalinkStatus(); }); }
    function evalinkResumeAll() { evalinkRpcCall("unpauseAll", [], function() { root.fetchEvalinkStatus(); }); }
    function evalinkPurge() { evalinkRpcCall("purgeDownloadResult", [], function() { root.fetchEvalinkStatus(); }); }

    function evalinkStartDaemon() {
        Quickshell.execDetached([Quickshell.configPath("scripts/evalink_bridge.py"), "start"]);
        evalinkTimer.restart();
    }

    Timer {
        id: evalinkTimer
        interval: 1500
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchEvalinkStatus()
    }

    Component.onCompleted: {
        evaStatusProcess.running = true;
        evaRulesProcess.running = true;
        root.fetchEvalinkStatus();
    }

    anchors.fill: parent

    // ============================================================
    // MAIN 3-COLUMN DUAL-WING COCKPIT
    // (LEFT WING: 1 of 3 Apps | CENTER: HEX NEXUS | RIGHT WING: 1 of 3 Apps)
    // ============================================================
    RowLayout {
        anchors.fill: parent
        spacing: 8

        // ============================================================
        // 1. LEFT WING: DEDICATED APP PANEL
        //    (EVAFILE when 0, EVATERM when 1, EVASORT when 2)
        // ============================================================
        Item {
            id: leftWingContainer
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 380
            Layout.minimumWidth: 340

            // Panel 0: EvaFile
            EvaFilePanel {
                anchors.fill: parent
                statusData: root.evaSuiteStatus
                opacity: (root.visible && root.selectedLeftIndex === 0) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                onLaunchRequested: (path) => root.launchEvaFile(path)
            }

            // Panel 1: EvaTerm
            EvaTermPanel {
                anchors.fill: parent
                statusData: root.evaSuiteStatus
                opacity: (root.visible && root.selectedLeftIndex === 1) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                onLaunchRequested: (cwd, cmd) => root.launchEvaTerm(cwd, cmd)
            }

            // Panel 2: EvaSort
            EvaSortPanel {
                anchors.fill: parent
                statusData: root.evaSuiteStatus
                sortCategories: root.sortCategories
                sortSourceDir: root.sortSourceDir
                sortStrategy: root.sortStrategy
                sortFeedback: root.evaSortFeedback
                opacity: (root.visible && root.selectedLeftIndex === 2) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                onRunSortRequested: (path) => root.runEvaSort(path)
                onToggleDaemonRequested: root.toggleEvaSortDaemon()
                onOpenFolderRequested: (path) => root.launchEvaFile(path)
            }
        }

        // ============================================================
        // LEFT DATA BUS CONNECTOR (ACTIVE LASER BUS)
        // ============================================================
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: 14
            Layout.minimumWidth: 14

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                color: root.highlight
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: 4
                height: 4
                radius: 2
                color: root.highlight
            }
        }

        // ============================================================
        // 2. CENTER: THE DUAL-AXIS HEXAGON COMMAND NEXUS
        // ============================================================
        EvaHexNexus {
            id: hexNexus
            Layout.fillHeight: true
            Layout.preferredWidth: 350
            Layout.minimumWidth: 330
            Layout.maximumWidth: 370

            selectedLeftIndex: root.selectedLeftIndex
            selectedRightIndex: root.selectedRightIndex
            statusData: root.evaSuiteStatus
            evalinkOnline: root.evalinkOnline

            onLeftAppSelected: (idx) => root.selectedLeftIndex = idx
            onRightAppSelected: (idx) => root.selectedRightIndex = idx
            onReprobeRequested: {
                evaStatusProcess.running = true;
                evaRulesProcess.running = true;
                root.fetchEvalinkStatus();
            }
            onShellRestartRequested: root.restartQuickshell()
        }

        // ============================================================
        // RIGHT DATA BUS CONNECTOR (ACTIVE LASER BUS)
        // ============================================================
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: 14
            Layout.minimumWidth: 14

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                color: root.highlight
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: 4
                height: 4
                radius: 2
                color: root.highlight
            }
        }

        // ============================================================
        // 3. RIGHT WING: DEDICATED APP PANEL
        //    (EVALINK when 3, EVATUBE when 4, QUICKSHELL when 5)
        // ============================================================
        Item {
            id: rightWingContainer
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 380
            Layout.minimumWidth: 340

            // Panel 3: EvaLink
            EvaLinkPanel {
                anchors.fill: parent
                evalinkOnline: root.evalinkOnline
                dlSpeed: root.evalinkDlSpeed
                ulSpeed: root.evalinkUlSpeed
                activeCount: root.evalinkActiveCount
                waitingCount: root.evalinkWaitingCount
                stoppedCount: root.evalinkStoppedCount
                downloadTasks: root.evalinkTasks
                newDownloadUrl: root.newDownloadUrl
                opacity: (root.visible && root.selectedRightIndex === 3) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                onAddUriRequested: (url) => root.evalinkAddUri(url)
                onPauseRequested: (gid) => root.evalinkPause(gid)
                onResumeRequested: (gid) => root.evalinkResume(gid)
                onCancelRequested: (gid) => root.evalinkCancel(gid)
                onPauseAllRequested: root.evalinkPauseAll()
                onResumeAllRequested: root.evalinkResumeAll()
                onPurgeRequested: root.evalinkPurge()
                onStartDaemonRequested: root.evalinkStartDaemon()
                onPasteClipboardRequested: clipPasteProcess.running = true
                onOpenDownloadsRequested: root.launchEvaFile("~/Downloads")
            }

            // Panel 4: EvaTube
            EvaTubePanel {
                anchors.fill: parent
                statusData: root.evaSuiteStatus
                opacity: (root.visible && root.selectedRightIndex === 4) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                onLaunchTuiRequested: root.launchEvaTerm("~/evatube", "evatube")
                onDownloadStreamRequested: (url, format, dest) => root.downloadStreamWithEvaTube(url, format, dest)
                onOpenFolderRequested: (path) => root.launchEvaFile(path)
            }

            // Panel 5: QuickShell
            QuickShellPanel {
                anchors.fill: parent
                statusData: root.evaSuiteStatus
                opacity: (root.visible && root.selectedRightIndex === 5) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                onReloadRequested: root.restartQuickshell()
                onReprobeRequested: {
                    evaStatusProcess.running = true;
                    evaRulesProcess.running = true;
                }
                onOpenConfigRequested: root.launchEvaFile("~/.config/quickshell/evangelion")
            }
        }
    }
}
