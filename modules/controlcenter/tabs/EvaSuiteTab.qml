import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../../components"

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.92)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.85)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    component ServiceTile: Rectangle {
        id: st
        property string title: ""
        property string status: ""
        property bool active: false
        property color activeColor: root.primary
        property string actionLabel: ""
        signal clicked()

        Layout.fillWidth: true
        height: 42
        color: stMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                     : (st.active ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04) : "#ffffff")
        border.width: 1
        border.color: stMouse.containsMouse ? root.primary
                                            : (st.active ? root.primary : root.itemBorder)

        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: st.title
                    color: st.active ? root.primary : root.fg
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Glowing Status LED
                Rectangle {
                    width: 5
                    height: 5
                    radius: 2.5
                    color: st.active ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                    border.width: 0.5
                    border.color: st.active ? "#ffffff" : "transparent"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: st.status
                    color: st.active ? root.primary : root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: st.actionLabel ? st.actionLabel : (st.active ? "● ACTIVE" : "▶ LAUNCH")
                    color: stMouse.containsMouse ? root.primary : root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: stMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: st.clicked()
        }
    }

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
        // 1. Global stats
        evalinkRpcCall("getGlobalStat", [], function(res) {
            if (res) {
                root.evalinkDlSpeed = root.formatSpeed(res.downloadSpeed);
                root.evalinkUlSpeed = root.formatSpeed(res.uploadSpeed);
                root.evalinkActiveCount = parseInt(res.numActive) || 0;
                root.evalinkWaitingCount = parseInt(res.numWaiting) || 0;
                root.evalinkStoppedCount = parseInt(res.numStopped) || 0;
            }
        });

        // 2. Active tasks
        evalinkRpcCall("tellActive", [], function(activeList) {
            var all = Array.isArray(activeList) ? activeList.map(function(t) { return root.formatTask(t, "active"); }) : [];

            // 3. Waiting & Stopped tasks
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

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ============================================================
        // COLUMN 1: EVA SUITE ORCHESTRATOR & SERVICE MATRIX
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 700
            Layout.minimumWidth: 560
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header with EvaCore Version & Reload
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ EVA SUITE ORCHESTRATION // EVACORE"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 70
                        height: 18
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.evaSuiteStatus.evacore.installed ? root.secondary : root.itemBorder

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle { width: 4; height: 4; radius: 2; color: root.evaSuiteStatus.evacore.installed ? root.primary : root.fgDim }
                            Text {
                                text: root.evaSuiteStatus.evacore.installed ? "v0.1.0" : "OFFLINE"
                                color: root.evaSuiteStatus.evacore.installed ? root.secondary : root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }

                // 6 Service Telemetry Tiles Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 4
                    rowSpacing: 4

                    // 6 Service Telemetry Tiles
                    ServiceTile {
                        title: "󰝰 EVAFILE"
                        status: root.evaSuiteStatus.file.running ? (root.evaSuiteStatus.file.count + " RUNNING") : "STANDBY"
                        active: root.evaSuiteStatus.file.running
                        actionLabel: root.evaSuiteStatus.file.running ? "● ACTIVE" : "▶ OPEN"
                        onClicked: root.launchEvaFile("~/Downloads")
                    }

                    ServiceTile {
                        title: "󰆍 EVATERM"
                        status: root.evaSuiteStatus.term.running ? (root.evaSuiteStatus.term.count + " ACTIVE") : "STANDBY"
                        active: root.evaSuiteStatus.term.running
                        actionLabel: root.evaSuiteStatus.term.running ? "● ACTIVE" : "▶ SPAWN"
                        onClicked: root.launchEvaTerm()
                    }

                    ServiceTile {
                        title: "󰒋 EVASORT"
                        status: root.evaSuiteStatus.sort.running ? "WATCHER ON" : "STANDBY"
                        active: root.evaSuiteStatus.sort.running
                        actionLabel: root.evaSuiteStatus.sort.running ? "■ STOP" : "▶ WATCH"
                        onClicked: root.toggleEvaSortDaemon()
                    }

                    ServiceTile {
                        title: "󰇚 EVALINK"
                        status: root.evalinkOnline ? "ONLINE" : "STANDBY"
                        active: root.evalinkOnline
                        actionLabel: root.evalinkOnline ? "● READY" : "▶ START"
                        onClicked: {
                            if (!root.evalinkOnline) root.evalinkStartDaemon();
                        }
                    }

                    ServiceTile {
                        title: "󰎆 EVATUBE"
                        status: root.evaSuiteStatus.tube.available ? "READY" : "OFFLINE"
                        active: root.evaSuiteStatus.tube.available
                        actionLabel: root.evaSuiteStatus.tube.available ? "▶ LAUNCH" : "✕ N/A"
                        onClicked: {
                            if (root.evaSuiteStatus.tube.available) root.launchEvaTerm("~/evatube", "evatube");
                        }
                    }

                    ServiceTile {
                        title: "󰵆 QUICKSHELL"
                        status: "ACTIVE"
                        active: true
                        actionLabel: "⟳ RELOAD"
                        onClicked: root.restartQuickshell()
                    }
                }


                // Unified Directory Routing Pipeline Deck
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        // Header Bar: Pipeline Title + Meta Info + Action Controls
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "▶ DIRECTORY ROUTING PIPELINE"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 0.8
                            }

                            // Meta pill: ~/Downloads
                            Rectangle {
                                height: 18
                                implicitWidth: srcMetaRow.implicitWidth + 8
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)

                                RowLayout {
                                    id: srcMetaRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text { text: "SRC:"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                    Text { text: root.sortSourceDir; color: root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Watcher Status Badge
                            Rectangle {
                                height: 18
                                implicitWidth: sortDaemonRow.implicitWidth + 8
                                color: root.evaSuiteStatus.sort.running ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "#ffffff"
                                border.width: 1
                                border.color: root.evaSuiteStatus.sort.running ? root.secondary : root.itemBorder

                                RowLayout {
                                    id: sortDaemonRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Rectangle { width: 4; height: 4; radius: 2; color: root.evaSuiteStatus.sort.running ? root.primary : root.fgDim }
                                    Text {
                                        text: root.evaSuiteStatus.sort.running ? "WATCHER ON" : "STANDBY"
                                        color: root.evaSuiteStatus.sort.running ? root.secondary : root.fgDim
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleEvaSortDaemon()
                                }
                            }

                            // Clean Downloads Now Action Button
                            Rectangle {
                                height: 18
                                implicitWidth: sortRunRow.implicitWidth + 8
                                color: sortRunMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary

                                RowLayout {
                                    id: sortRunRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text { text: "󰒋"; color: sortRunMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                                    Text { text: "CLEAN DOWNLOADS"; color: sortRunMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                }

                                MouseArea {
                                    id: sortRunMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.runEvaSort("~/Downloads")
                                }
                            }
                        }

                        // Scrollable List of Clean Category Cards
                        Flickable {
                            id: catFlickable
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: catCol.implicitHeight

                            Column {
                                id: catCol
                                width: catFlickable.width
                                spacing: 4

                                Repeater {
                                    model: root.sortCategories

                                    Rectangle {
                                        id: catCard
                                        required property var modelData
                                        width: catCol.width
                                        height: 36
                                        color: catMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05) : "#ffffff"
                                        border.width: 1
                                        border.color: catMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)

                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Behavior on border.color { ColorAnimation { duration: 100 } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            // Category Icon + Name
                                            RowLayout {
                                                spacing: 5
                                                Text {
                                                    text: catCard.modelData.icon || "󰒋"
                                                    color: root.primary
                                                    font.pixelSize: 10
                                                }

                                                Text {
                                                    text: (catCard.modelData.name || "CATEGORY").toUpperCase()
                                                    color: root.fg
                                                    font.family: root.hudFont
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                }
                                            }

                                            Text {
                                                text: "▶"
                                                color: root.fgDim
                                                font.pixelSize: 6
                                            }

                                            // Clickable Destination Chip
                                            Rectangle {
                                                height: 18
                                                implicitWidth: destRow.implicitWidth + 8
                                                color: destMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                                                border.width: 0.5
                                                border.color: destMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)

                                                RowLayout {
                                                    id: destRow
                                                    anchors.centerIn: parent
                                                    spacing: 3
                                                    Text {
                                                        text: "󰝰"
                                                        color: destMouse.containsMouse ? "#ffffff" : root.secondary
                                                        font.pixelSize: 7
                                                    }
                                                    Text {
                                                        text: catCard.modelData.dest || ""
                                                        color: destMouse.containsMouse ? "#ffffff" : root.secondary
                                                        font.family: root.hudFont
                                                        font.pixelSize: 7
                                                        font.bold: true
                                                    }
                                                }

                                                MouseArea {
                                                    id: destMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.launchEvaFile(catCard.modelData.dest_full || catCard.modelData.dest)
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Clean Format Summary Text (replaces 12-19 tiny badges per card!)
                                            Text {
                                                text: {
                                                    var exts = catCard.modelData.exts || [];
                                                    var sample = exts.slice(0, 3).join(", ");
                                                    return (catCard.modelData.count || exts.length) + " formats (" + sample + (exts.length > 3 ? ", …" : "") + ")";
                                                }
                                                color: root.fgDim
                                                font.family: root.hudFont
                                                font.pixelSize: 7
                                            }
                                        }

                                        MouseArea {
                                            id: catMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Status Toast
                Text {
                    visible: root.evaSortFeedback.length > 0
                    text: root.evaSortFeedback
                    color: root.secondary
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ============================================================
        // COLUMN 2: EVALINK PROTOCOL // DOWNLINK MATRIX
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 440
            Layout.minimumWidth: 380
            Layout.maximumWidth: 480
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Top Hazard Line Strip
                NervHazardLines {
                    Layout.fillWidth: true
                    height: 8
                    stripeColor: root.primary
                    bgColor: "#ffffff"
                }

                // Header with RPC Status indicator badge
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "▶ EVALINK DOWNLINK MATRIX"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 68
                        height: 18
                        color: root.evalinkOnline ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.evalinkOnline ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle { width: 4; height: 4; radius: 2; color: root.evalinkOnline ? "#ffffff" : root.fgDim }
                            Text {
                                text: root.evalinkOnline ? "ONLINE" : "OFFLINE"
                                color: root.evalinkOnline ? "#ffffff" : root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.evalinkOnline) root.evalinkStartDaemon();
                            }
                        }
                    }
                }

                // Global Bandwidth Telemetry Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 6

                        // Downlink Speed
                        Text { text: "DL: " + root.evalinkDlSpeed; color: root.secondary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }

                        // Uplink Speed
                        Text { text: "UL: " + root.evalinkUlSpeed; color: root.primary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }

                        Item { Layout.fillWidth: true }

                        // Counters
                        Text {
                            text: "ACT: " + root.evalinkActiveCount + " | Q: " + root.evalinkWaitingCount + " | DONE: " + root.evalinkStoppedCount
                            color: root.fgMuted
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }

                // Scrollable Download Tasks List
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: tasksColumn.implicitHeight

                    Column {
                        id: tasksColumn
                        width: parent.width
                        spacing: 4

                        // Empty State: Tactical Downlink Radar HUD
                        Item {
                            id: emptyHudContainer
                            width: tasksColumn.width
                            visible: root.evalinkTasks.length === 0
                            height: visible ? (emptyHudCol.implicitHeight + 10) : 0
                            clip: true

                            ColumnLayout {
                                id: emptyHudCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 10

                                // Radar Crosshair Reticle (declarative, power-gated zero idle CPU)
                                Item {
                                    id: radarReticle
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 90
                                    height: 90

                                    // Outer Radar Ring
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.02)
                                        border.width: 1
                                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
                                    }

                                    // Mid Radar Ring
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 60
                                        height: 60
                                        radius: 30
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)
                                    }

                                    // Inner Core Ring
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 30
                                        height: 30
                                        radius: 15
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)
                                    }

                                    // Horizontal Reticle
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                    }

                                    // Vertical Reticle
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 1
                                        height: parent.height
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                    }

                                    // Center Target Beacon
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: root.primary
                                    }

                                    // Sweeping Radar Beam (Rotates only when visible and empty)
                                    Item {
                                        anchors.fill: parent

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.verticalCenter
                                            width: 1.5
                                            height: parent.height / 2
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: root.primary }
                                            }
                                        }

                                        RotationAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 4000
                                            loops: Animation.Infinite
                                            running: root.visible && root.evalinkTasks.length === 0
                                        }
                                    }
                                }

                                // Status Title & Subtitle
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "󰇚 NERV DOWNLINK // STANDBY"
                                        color: root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 9
                                        font.bold: true
                                        font.letterSpacing: 0.8
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "ARIA2C RPC :6800 // LOCALHOST"
                                        color: root.fgDim
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                    }
                                }

                                // Rapid Action Presets
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    // Paste Clipboard URL
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 24
                                        color: pasteMouse.containsMouse ? root.primary : "#ffffff"
                                        border.width: 1
                                        border.color: root.secondary

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "󰅌"; color: pasteMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                                            Text { text: "PASTE CLIPBOARD"; color: pasteMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                        }

                                        MouseArea {
                                            id: pasteMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: clipPasteProcess.running = true
                                        }
                                    }

                                    // Open Downloads in EvaFile
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 24
                                        color: openDlMouse.containsMouse ? root.primary : "#ffffff"
                                        border.width: 1
                                        border.color: root.secondary

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Text { text: "󰝰"; color: openDlMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                                            Text { text: "OPEN DOWNLOADS"; color: openDlMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                        }

                                        MouseArea {
                                            id: openDlMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.launchEvaFile("~/Downloads")
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.evalinkTasks

                            Rectangle {
                                id: taskCard
                                required property var modelData
                                width: tasksColumn.width
                                height: 56
                                color: "#ffffff"
                                border.width: 1
                                border.color: taskCard.modelData.status === "active" ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 3

                                    // Row 1: Filename & Speed Badge
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: taskCard.modelData.status === "active" ? "▶" : (taskCard.modelData.status === "paused" ? "⏸" : "✓")
                                            color: taskCard.modelData.status === "active" ? root.secondary : (taskCard.modelData.status === "paused" ? root.primary : root.fgMuted)
                                            font.pixelSize: 8
                                        }

                                        Text {
                                            text: taskCard.modelData.name
                                            color: taskCard.modelData.status === "active" ? root.secondary : root.fg
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: taskCard.modelData.speedStr
                                            color: taskCard.modelData.status === "active" ? root.secondary : root.fgMuted
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            font.bold: true
                                        }
                                    }

                                    // Row 2: Tactical Progress Bar
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 3
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15)

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * Math.max(0, Math.min(1.0, taskCard.modelData.pct))
                                            color: taskCard.modelData.status === "active" ? root.secondary : root.primary
                                        }
                                    }

                                    // Row 3: Telemetry & Controls
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: Math.round(taskCard.modelData.pct * 100) + "% | " + taskCard.modelData.sizeStr
                                            color: root.fgMuted
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "ETA " + taskCard.modelData.eta
                                            color: root.fgDim
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            visible: taskCard.modelData.status === "active"
                                        }

                                        // Pause / Resume Button
                                        Rectangle {
                                            width: 42
                                            height: 16
                                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                            border.width: 1
                                            border.color: root.secondary
                                            visible: taskCard.modelData.status === "active" || taskCard.modelData.status === "paused"

                                            Text {
                                                anchors.centerIn: parent
                                                text: taskCard.modelData.status === "active" ? "⏸" : "▶"
                                                color: root.secondary
                                                font.pixelSize: 7
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (taskCard.modelData.status === "active") root.evalinkPause(taskCard.modelData.gid);
                                                    else root.evalinkResume(taskCard.modelData.gid);
                                                }
                                            }
                                        }

                                        // Cancel Button
                                        Rectangle {
                                            width: 18
                                            height: 16
                                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                            border.width: 1
                                            border.color: root.primary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: root.primary
                                                font.pixelSize: 7
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.evalinkCancel(taskCard.modelData.gid)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Quick URL Injector Box
                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 4
                        spacing: 4

                        TextInput {
                            id: urlInput
                            Layout.fillWidth: true
                            color: root.fg
                            font.family: root.hudFont
                            font.pixelSize: 8
                            clip: true
                            selectByMouse: true
                            text: root.newDownloadUrl
                            onTextChanged: root.newDownloadUrl = text
                            onAccepted: {
                                root.evalinkAddUri(text);
                                urlInput.text = "";
                            }

                            Text {
                                anchors.fill: parent
                                visible: !urlInput.text && !urlInput.activeFocus
                                text: "INPUT URL (HTTP / MAGNET / TORRENT) >"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 8
                            }
                        }

                        Rectangle {
                            width: 54
                            height: 16
                            color: urlInjectMouse.containsMouse ? root.primary : "#ffffff"
                            border.width: 1
                            border.color: root.secondary

                            Text {
                                anchors.centerIn: parent
                                text: "+ INJECT"
                                color: urlInjectMouse.containsMouse ? "#ffffff" : root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            MouseArea {
                                id: urlInjectMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.evalinkAddUri(urlInput.text);
                                    urlInput.text = "";
                                }
                            }
                        }
                    }
                }

                // Global Batch Action Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Pause All
                    Rectangle {
                        Layout.fillWidth: true
                        height: 20
                        color: pauseAllMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary

                        Text {
                            anchors.centerIn: parent
                            text: "⏸ PAUSE ALL"
                            color: pauseAllMouse.containsMouse ? "#ffffff" : root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: pauseAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.evalinkPauseAll()
                        }
                    }

                    // Resume All
                    Rectangle {
                        Layout.fillWidth: true
                        height: 20
                        color: resumeAllMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary

                        Text {
                            anchors.centerIn: parent
                            text: "▶ RESUME ALL"
                            color: resumeAllMouse.containsMouse ? "#ffffff" : root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: resumeAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.evalinkResumeAll()
                        }
                    }

                    // Purge Completed
                    Rectangle {
                        Layout.fillWidth: true
                        height: 20
                        color: purgeMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.primary

                        Text {
                            anchors.centerIn: parent
                            text: "⟳ PURGE"
                            color: purgeMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: purgeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.evalinkPurge()
                        }
                    }
                }
            }
        }
    }
}
