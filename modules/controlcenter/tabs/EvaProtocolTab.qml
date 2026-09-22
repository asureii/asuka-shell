import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "protocol"

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.94)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.85)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // ============================================================
    // 1. LIVE TASK MONITOR BACKEND
    // ============================================================
    property int totalTasks: 0
    property real totalCpu: 0.0
    property var allProcesses: []
    property string filterQuery: ""
    property var filteredProcesses: []
    property string selectedPid: ""
    property string selectedProcName: ""

    function updateFilteredList() {
        var q = root.filterQuery.trim().toLowerCase();
        root.filteredProcesses = !q
            ? root.allProcesses
            : root.allProcesses.filter(p => p.name.toLowerCase().indexOf(q) !== -1 || p.pid.indexOf(q) !== -1);
    }

    function terminateProcess(pid) {
        if (!pid) return;
        Quickshell.execDetached(["kill", pid]);
        root.magiLogs = root.magiLogs.concat(["> PROCESS " + pid + " (" + root.selectedProcName + ") TERMINATED // SIGTERM"]).slice(-50);
        root.selectedPid = "";
        root.selectedProcName = "";
        if (!taskFetcher.running) {
            taskFetcher.running = true;
        }
    }

    Process {
        id: taskFetcher
        command: ["bash", "-c", "
tasks=$(ps -e --no-headers | wc -l)
c1=($(grep '^cpu ' /proc/stat))
sleep 0.04
c2=($(grep '^cpu ' /proc/stat))
t1=0; t2=0
for v in \"${c1[@]:1}\"; do ((t1+=v)); done
for v in \"${c2[@]:1}\"; do ((t2+=v)); done
id1=$((c1[4]+c1[5])); id2=$((c2[4]+c2[5]))
dt=$((t2-t1)); did=$((id2-id1))
cpu_tot=$(( (dt-did)*100 / (dt > 0 ? dt : 1) ))

procs=$(ps -eo pid,%cpu,%mem,comm --sort=-%cpu --no-headers | head -n 45 | awk 'BEGIN {print \"[\"} {if (NR>1) printf \",\\n\"; printf \"{\\\"pid\\\":\\\"%s\\\",\\\"cpu\\\":\\\"%s%%\\\",\\\"mem\\\":\\\"%s%%\\\",\\\"name\\\":\\\"%s\\\"}\", $1, $2, $3, $4} END {print \"]\"}')

echo \"{\\\"tasks\\\":$tasks,\\\"cpu\\\":$cpu_tot,\\\"procs\\\":$procs}\"
"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data) {
                        if (data.tasks !== undefined) root.totalTasks = data.tasks;
                        if (data.cpu !== undefined) root.totalCpu = data.cpu;
                        if (data.procs && Array.isArray(data.procs)) {
                            root.allProcesses = data.procs;
                            root.updateFilteredList();
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: {
            if (!taskFetcher.running) {
                taskFetcher.running = true;
            }
        }
    }

    // ============================================================
    // 2. MAGI TRI-CORE DELIBERATION ENGINE (Ollama Qwen 2.5 0.5B)
    // ============================================================
    property bool isDeliberating: false
    property bool consensusPassed: true
    property string consensusText: "3-0 UNANIMOUS"
    property string consensusStatus: "APPROVED // 承認"

    property var melchiorData: ({
        name: "MELCHIOR • 01",
        role: "SCIENTIST // 科学者",
        vote: "AGREE",
        thought: "Logical consistency and computational efficiency validated."
    })
    property var balthasarData: ({
        name: "BALTHASAR • 02",
        role: "MOTHER // 母親",
        vote: "AGREE",
        thought: "System safety and critical fail-safe protocols verified."
    })
    property var casperData: ({
        name: "CASPER • 03",
        role: "WOMAN // 女性",
        vote: "AGREE",
        thought: "User intent and operational necessity approved."
    })

    function deliberateTask(pid, procName) {
        root.isDeliberating = true;
        magiDeliberateProcess.command = [
            "python3",
            Quickshell.configPath("scripts/magi_deliberate.py"),
            "--type", "process",
            "--name", procName || "unknown",
            "--pid", pid || "0"
        ];
        magiDeliberateProcess.running = true;
    }

    function deliberateQuery(queryText) {
        root.isDeliberating = true;
        magiDeliberateProcess.command = [
            "python3",
            Quickshell.configPath("scripts/magi_deliberate.py"),
            "--query", queryText
        ];
        magiDeliberateProcess.running = true;
    }

    Process {
        id: magiDeliberateProcess
        command: ["python3", Quickshell.configPath("scripts/magi_deliberate.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isDeliberating = false;
                try {
                    var res = JSON.parse(text.trim());
                    if (res) {
                        if (res.melchior) root.melchiorData = res.melchior;
                        if (res.balthasar) root.balthasarData = res.balthasar;
                        if (res.casper) root.casperData = res.casper;
                        if (res.consensus) root.consensusText = res.consensus;
                        if (res.status) root.consensusStatus = res.status;
                        root.consensusPassed = (res.passed !== undefined) ? res.passed : true;

                        // Append resolution to terminal log stream
                        var logHeader = "> MAGI DELIBERATION: " + res.consensus + " [" + (res.engine || "LLM") + " // " + res.elapsed_ms + "ms]";
                        var mLog = "  • MELCHIOR-01: [" + res.melchior.vote + "] " + res.melchior.thought;
                        var bLog = "  • BALTHASAR-02: [" + res.balthasar.vote + "] " + res.balthasar.thought;
                        var cLog = "  • CASPER-03: [" + res.casper.vote + "] " + res.casper.thought;
                        root.magiLogs = root.magiLogs.concat([logHeader, mLog, bLog, cLog]).slice(-50);
                    }
                } catch (e) {
                    root.consensusPassed = true;
                    root.consensusText = "3-0 UNANIMOUS";
                    root.consensusStatus = "APPROVED // 承認";
                }
            }
        }
    }

    // ============================================================
    // 3. MAGI / EVACORE COMMAND DISPATCH BACKEND
    // ============================================================
    property var magiLogs: [
        "SYSTEM INITIALIZED // MAGI SYSTEM READY",
        "TRI-CORE STATUS: MELCHIOR-1, BALTHASAR-2, CASPER-3 ONLINE",
        "NODE LINK: ACTIVE // ENGINE: OLLAMA QWEN 2.5 (0.5B)"
    ]
    property bool magiBusy: false

    function dispatchMagiCommand(cmdText) {
        cmdText = (cmdText || "").trim();
        if (!cmdText) return;
        root.magiLogs = root.magiLogs.concat(["> " + cmdText]).slice(-50);
        root.magiBusy = true;

        // Also trigger deliberation on the query
        root.deliberateQuery(cmdText);

        magiCmdProcess.command = [Quickshell.configPath("scripts/evacore_bridge.py"), "command", cmdText];
        magiCmdProcess.running = true;
    }

    Process {
        id: magiCmdProcess
        command: [Quickshell.configPath("scripts/evacore_bridge.py"), "command", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.magiBusy = false;
                try {
                    var data = JSON.parse(text.trim());
                    var out = (data && data.output) ? data.output : text.trim();
                    root.magiLogs = root.magiLogs.concat(out.split("\n").filter(l => l.length > 0)).slice(-50);
                } catch (e) {
                    root.magiLogs = root.magiLogs.concat([text.trim() || "COMMAND EXECUTED"]).slice(-50);
                }
            }
        }
    }

    Component.onCompleted: {
        taskFetcher.running = true;
    }

    onVisibleChanged: {
        if (visible && !taskFetcher.running) {
            taskFetcher.running = true;
        }
    }

    anchors.fill: parent

    // ============================================================
    // MAIN 3-WING COMMAND CONSOLE
    // ============================================================
    RowLayout {
        anchors.fill: parent
        spacing: 6

        // ============================================================
        // 1. LEFT WING: TASK MONITOR
        // ============================================================
        TaskMonitorWing {
            id: taskWing
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            Layout.minimumWidth: 220
            Layout.maximumWidth: 280

            totalTasks: root.totalTasks
            totalCpu: root.totalCpu
            filteredProcesses: root.filteredProcesses
            selectedPid: root.selectedPid
            selectedProcName: root.selectedProcName
            isTaskFetching: taskFetcher.running

            onFilterChanged: (query) => {
                root.filterQuery = query;
                root.updateFilteredList();
            }

            onProcessSelected: (pid, procName) => {
                root.selectedPid = pid;
                root.selectedProcName = procName;
                if (pid.length > 0) {
                    root.deliberateTask(pid, procName);
                }
            }

            onProcessTerminateRequested: (pid) => {
                root.terminateProcess(pid);
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
        // 2. CENTER: THE FLOATING MAGI TRIAD SCHEMATIC
        // ============================================================
        MagiTriadSchematic {
            id: magiSchematic
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 500
            Layout.minimumWidth: 440

            selectedPid: root.selectedPid
            selectedProcName: root.selectedProcName
            isDeliberating: root.isDeliberating
            consensusPassed: root.consensusPassed
            consensusText: root.consensusText
            consensusStatus: root.consensusStatus

            melchiorData: root.melchiorData
            balthasarData: root.balthasarData
            casperData: root.casperData

            onTerminateProcessRequested: (pid) => root.terminateProcess(pid)
            onReDeliberateRequested: {
                if (root.selectedPid.length > 0) {
                    root.deliberateTask(root.selectedPid, root.selectedProcName);
                }
            }
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
        // 3. RIGHT WING: EVACORE DISPATCH
        // ============================================================
        EvaDispatchWing {
            id: dispatchWing
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            Layout.minimumWidth: 230
            Layout.maximumWidth: 300

            magiLogs: root.magiLogs
            magiBusy: root.magiBusy
            magiDeliberating: root.isDeliberating

            onDispatchCommand: (cmdText) => root.dispatchMagiCommand(cmdText)
            onTriggerQuickAction: (actionName) => root.dispatchMagiCommand(actionName)
        }
    }
}
