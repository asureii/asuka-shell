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

    // Live Task Telemetry
    property int totalTasks: 0
    property real totalCpu: 0.0
    property var allProcesses: []
    property string filterQuery: ""
    property var filteredProcesses: []
    property string selectedPid: ""
    property string selectedProcName: ""

    function updateFilteredList() {
        var q = root.filterQuery.trim().toLowerCase();
        root.filteredProcesses = !q ? root.allProcesses : root.allProcesses.filter(p => p.name.toLowerCase().indexOf(q) !== -1 || p.pid.indexOf(q) !== -1);
    }

    function terminateProcess(pid) {
        if (!pid) return;
        Quickshell.execDetached(["kill", pid]);
        root.selectedPid = "";
        root.selectedProcName = "";
        if (!taskFetcher.running) {
            taskFetcher.running = true;
        }
    }

    // MAGI / EvaCore Command Deck
    property var magiLogs: [
        "SYSTEM INITIALIZED // MAGI SYSTEM READY",
        "NODE LINK: ACTIVE // LATENCY 12ms",
        "Type 'help' or 'status' to query Eva Suite services."
    ]
    property bool magiBusy: false

    function dispatchMagiCommand(cmdText) {
        cmdText = (cmdText || "").trim();
        if (!cmdText) return;
        root.magiLogs = root.magiLogs.concat(["> " + cmdText]).slice(-50);
        root.magiBusy = true;
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

    // Process to query live Linux task list and CPU utilization
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

    // Refresh poll timer
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

    onVisibleChanged: {
        if (root.visible && !taskFetcher.running) {
            taskFetcher.running = true;
        }
    }

    anchors.fill: parent

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // ============================================================
        // LEFT PANEL: [ TASK MONITOR ] (Live Linux Process Monitor)
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 230
            Layout.minimumWidth: 210
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Top Hazard Line Strip
                NervHazardLines {
                    Layout.fillWidth: true
                    height: 10
                    stripeColor: root.primary
                    bgColor: "#ffffff"
                }

                // Header Info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "[ TASK MONITOR ]"
                            color: root.fg
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: taskFetcher.running ? root.secondary : root.primary
                        }
                    }

                    Text {
                        text: "TASKS: " + (root.totalTasks > 0 ? root.totalTasks : root.allProcesses.length) + " | CPU: " + root.totalCpu.toFixed(1) + "%"
                        color: root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }

                    // Filter search input box
                    Rectangle {
                        Layout.fillWidth: true
                        height: 20
                        color: "#ffffff"
                        border.width: 1
                        border.color: filterInput.activeFocus ? root.secondary : root.itemBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            Text {
                                text: "FILTER >"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            TextInput {
                                id: filterInput
                                Layout.fillWidth: true
                                color: root.accent
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                clip: true
                                selectByMouse: true

                                onTextChanged: {
                                    root.filterQuery = text;
                                    root.updateFilteredList();
                                }
                            }
                        }
                    }

                    // Table Headers
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 4

                        Text { text: "PID"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; Layout.preferredWidth: 38 }
                        Text { text: "PROCESS"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; Layout.fillWidth: true }
                        Text { text: "CPU"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                        Text { text: "MEM"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight }
                    }
                }

                // Process Table Rows (Scrollable List)
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: processColumn.implicitHeight

                    Column {
                        id: processColumn
                        width: parent.width

                        Repeater {
                            model: root.filteredProcesses

                            Rectangle {
                                width: processColumn.width
                                height: 18
                                readonly property bool isSelected: root.selectedPid === modelData.pid
                                color: isSelected ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                                  : (rowMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                                                                            : (index % 2 === 0 ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04) : "#ffffff"))
                                border.width: isSelected ? 1 : 0
                                border.color: root.secondary

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 4

                                    Text {
                                        text: modelData.pid
                                        color: isSelected ? root.secondary : root.fgDim
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                        Layout.preferredWidth: 38
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Rectangle {
                                            readonly property bool isEva: modelData.name.toLowerCase().indexOf("eva") !== -1 || modelData.name === "quickshell" || modelData.name === "aria2c"
                                            visible: isEva
                                            width: 24
                                            height: 12
                                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)
                                            border.width: 1
                                            border.color: root.secondary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "EVA"
                                                color: root.secondary
                                                font.family: root.hudFont
                                                font.pixelSize: 5
                                                font.bold: true
                                            }
                                        }

                                        Text {
                                            text: modelData.name
                                            color: isSelected ? root.secondary : (modelData.name.toLowerCase().indexOf("eva") !== -1 ? root.accent : root.fg)
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Text {
                                        text: modelData.cpu
                                        color: root.secondary
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 30
                                    }

                                    Text {
                                        text: modelData.mem
                                        color: isSelected ? root.secondary : root.fgMuted
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                        horizontalAlignment: Text.AlignRight
                                        Layout.preferredWidth: 30
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.selectedPid === modelData.pid) {
                                            root.selectedPid = "";
                                            root.selectedProcName = "";
                                        } else {
                                            root.selectedPid = modelData.pid;
                                            root.selectedProcName = modelData.name;
                                        }
                                    }
                                    onDoubleClicked: {
                                        root.terminateProcess(modelData.pid);
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom Hazard Line Strip
                NervHazardLines {
                    Layout.fillWidth: true
                    height: 10
                    stripeColor: root.primary
                    bgColor: "#ffffff"
                    scrollLeft: true
                }
            }
        }

        // ============================================================
        // MIDDLE AREA: PROJECT EVANGELION // MAGI SYSTEM (1:1 RECREATION)
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)
            clip: true

            Item {
                anchors.fill: parent

                // Top Centered Title with Top-to-Bottom Tactical Laser Scan Effect
                Item {
                    id: mainTitle
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: baseTitleText.implicitWidth
                    height: baseTitleText.implicitHeight

                    // Base Text in Primary Red (#cf2824)
                    Text {
                        id: baseTitleText
                        anchors.centerIn: parent
                        text: "PROJECT EVANGELION"
                        color: "#cf2824"
                        font.family: root.hudFont
                        font.pixelSize: 26
                        font.bold: true
                        font.letterSpacing: 6
                    }

                    // Scanning Band overlay clipped in Active Orange/Red (#e32a10)
                    Item {
                        id: scanBand
                        width: parent.width
                        height: 14
                        clip: true

                        property real scanY: -height
                        y: scanY

                        NumberAnimation on scanY {
                            from: -scanBand.height
                            to: mainTitle.height + 4
                            duration: 2200
                            loops: Animation.Infinite
                            running: root.visible && (root.opacity > 0.01)
                            easing.type: Easing.InOutSine
                        }

                        // Overlay Text in Accent (#e32a10) aligned with Base Text
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -scanBand.y
                            text: "PROJECT EVANGELION"
                            color: "#e32a10"
                            font.family: root.hudFont
                            font.pixelSize: 26
                            font.bold: true
                            font.letterSpacing: 6
                        }
                    }
                }

                // Main Interactive Canvas for the MAGI Geometric Grid
                Canvas {
                    id: magiShapeCanvas
                    anchors.top: mainTitle.bottom
                    anchors.topMargin: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: bottomBar.top
                    anchors.bottomMargin: 8

                    renderTarget: Canvas.Image
                    renderStrategy: Canvas.Immediate

                    // Hover state tracking
                    property bool balHovered: false
                    property bool casperHovered: false
                    property bool melchiorHovered: false

                    onBalHoveredChanged: requestPaint()
                    onCasperHoveredChanged: requestPaint()
                    onMelchiorHoveredChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var cx = width / 2;
                        var w = width;
                        var h = height;

                        var pad = 14;
                        var leftEdge = pad;
                        var rightEdge = w - pad;

                        var yBase = 30;

                        var balW = w * 0.42;
                        var balLeft = cx - balW / 2;
                        var balRight = cx + balW / 2;
                        var balStraightH = h * 0.24;
                        var balTaperY = yBase + h * 0.38;
                        var balBottomHalfW = balW * 0.18;

                        var bottomGap = 18;
                        var magiY = balTaperY;
                        var nodeTop = magiY + 26;
                        var nodeBot = h - 50;
                        var centerGap = 28;

                        var balTaperDx = balW / 2 - balBottomHalfW;
                        var balTaperDy = balTaperY - yBase - balStraightH;
                        var taperSlope = balTaperDy / balTaperDx;

                        var cChamferDx = (cx - centerGap - leftEdge) * 0.38;
                        var chamferH = taperSlope * cChamferDx;

                        // -- Colors
                        var normalStroke = root.primary;
                        var normalFill = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04);
                        var hoverStroke = root.secondary;
                        var hoverFill = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.14);

                        ctx.lineWidth = 1.5;

                        // --------------------------------------------------
                        // 1. TOP-LEFT: 質 問 BOX
                        // --------------------------------------------------
                        ctx.strokeStyle = normalStroke;
                        ctx.fillStyle = normalFill;
                        var qBoxW = balLeft - leftEdge;
                        var qBoxH = 36;
                        ctx.beginPath();
                        ctx.moveTo(leftEdge, yBase);
                        ctx.lineTo(balLeft, yBase);
                        ctx.stroke();
                        ctx.strokeRect(leftEdge, yBase, qBoxW, qBoxH);

                        // --------------------------------------------------
                        // 2. TOP-RIGHT: 解 決 BOX
                        // --------------------------------------------------
                        var rBoxW = rightEdge - balRight;
                        var rBoxH = 36;
                        ctx.beginPath();
                        ctx.moveTo(balRight, yBase);
                        ctx.lineTo(rightEdge, yBase);
                        ctx.stroke();
                        ctx.strokeRect(balRight, yBase, rBoxW, rBoxH);

                        // 合 意 box below 解決
                        var gBoxW = Math.min(92, rBoxW * 0.72);
                        var gBoxH = 30;
                        var gBoxX = balRight + (rBoxW - gBoxW) / 2;
                        var gBoxY = yBase + rBoxH + 12;
                        ctx.strokeRect(gBoxX, gBoxY, gBoxW, gBoxH);

                        // --------------------------------------------------
                        // 3. BALTHASAR • 02 — wide trapezoid
                        // --------------------------------------------------
                        ctx.strokeStyle = balHovered ? hoverStroke : normalStroke;
                        ctx.fillStyle = balHovered ? hoverFill : normalFill;
                        ctx.lineWidth = balHovered ? 2.0 : 1.5;
                        ctx.beginPath();
                        ctx.moveTo(balLeft, yBase);
                        ctx.lineTo(balRight, yBase);
                        ctx.lineTo(balRight, yBase + balStraightH);
                        ctx.lineTo(cx + balBottomHalfW, balTaperY);
                        ctx.lineTo(cx - balBottomHalfW, balTaperY);
                        ctx.lineTo(balLeft, yBase + balStraightH);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();

                        // --------------------------------------------------
                        // 4. CASPER • 03
                        // --------------------------------------------------
                        ctx.strokeStyle = casperHovered ? hoverStroke : normalStroke;
                        ctx.fillStyle = casperHovered ? hoverFill : normalFill;
                        ctx.lineWidth = casperHovered ? 2.0 : 1.5;
                        var cL = leftEdge;
                        var cR = cx - centerGap;
                        var cTop = nodeTop;
                        var cBot = nodeBot;
                        var cChamferStartX = cL + (cR - cL) * 0.62;

                        ctx.beginPath();
                        ctx.moveTo(cL, cTop);
                        ctx.lineTo(cChamferStartX, cTop);
                        ctx.lineTo(cR, cTop + chamferH);
                        ctx.lineTo(cR, cBot);
                        ctx.lineTo(cL, cBot);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();

                        // --------------------------------------------------
                        // 5. MELCHIOR • 01
                        // --------------------------------------------------
                        ctx.strokeStyle = melchiorHovered ? hoverStroke : normalStroke;
                        ctx.fillStyle = melchiorHovered ? hoverFill : normalFill;
                        ctx.lineWidth = melchiorHovered ? 2.0 : 1.5;
                        var mL = cx + centerGap;
                        var mR = rightEdge;
                        var mTop = nodeTop;
                        var mBot = nodeBot;
                        var mChamferStartX = mR - (mR - mL) * 0.62;

                        ctx.beginPath();
                        ctx.moveTo(mChamferStartX, mTop);
                        ctx.lineTo(mR, mTop);
                        ctx.lineTo(mR, mBot);
                        ctx.lineTo(mL, mBot);
                        ctx.lineTo(mL, mTop + chamferH);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();

                        // --------------------------------------------------
                        // 6. Center crosshair (+)
                        // --------------------------------------------------
                        ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.6);
                        ctx.lineWidth = 1.0;
                        var crossY = (nodeTop + nodeBot) / 2;
                        ctx.beginPath();
                        ctx.moveTo(cx - 7, crossY);
                        ctx.lineTo(cx + 7, crossY);
                        ctx.moveTo(cx, crossY - 7);
                        ctx.lineTo(cx, crossY + 7);
                        ctx.stroke();
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    // ==========================================
                    // MOUSE AREAS FOR HOVER INTERACTION
                    // ==========================================

                    // BALTHASAR hover area (trapezoid bounding box)
                    MouseArea {
                        x: parent.balLeft_
                        y: parent.yBase
                        width: parent.balW
                        height: parent.balTaperY_ - parent.yBase
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.balHovered = true
                        onExited: parent.balHovered = false
                    }

                    // CASPER hover area
                    MouseArea {
                        x: 14
                        y: parent.nodeTop_
                        width: parent.width / 2 - parent.centerGap_ - 14
                        height: parent.nodeBot_ - parent.nodeTop_
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.casperHovered = true
                        onExited: parent.casperHovered = false
                    }

                    // MELCHIOR hover area
                    MouseArea {
                        x: parent.width / 2 + parent.centerGap_
                        y: parent.nodeTop_
                        width: parent.width - 14 - parent.width / 2 - parent.centerGap_
                        height: parent.nodeBot_ - parent.nodeTop_
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.melchiorHovered = true
                        onExited: parent.melchiorHovered = false
                    }

                    // ==========================================
                    // TEXT OVERLAYS POSITIONED INSIDE SHAPES
                    // ==========================================

                    // Helper properties for text positioning
                    readonly property real yBase: 30
                    readonly property real balW: width * 0.42
                    readonly property real balLeft_: width / 2 - balW / 2
                    readonly property real balRight_: width / 2 + balW / 2
                    readonly property real balTaperY_: yBase + height * 0.38
                    readonly property real nodeTop_: balTaperY_ + 26
                    readonly property real nodeBot_: height - 50
                    readonly property real centerGap_: 28

                    // 質 問
                    Text {
                        x: 14
                        y: parent.yBase
                        width: parent.balLeft_ - 14
                        height: 36
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "質 問"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 17
                        font.bold: true
                        font.letterSpacing: 6
                    }

                    // Telemetry under 質 問
                    ColumnLayout {
                        x: 20
                        y: parent.yBase + 42
                        spacing: 3
                        Text { text: "CODE: 473"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                        Text { text: "FILE: MAGI_SYS"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                        Text { text: "EXTENTION: 3023"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                        Text { text: "EX_MODE: OFF"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                        Text { text: "PRIORITY: AAA"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                    }

                    // 解 決
                    Text {
                        x: parent.balRight_
                        y: parent.yBase
                        width: (parent.width - 14) - parent.balRight_
                        height: 36
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "解 決"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 17
                        font.bold: true
                        font.letterSpacing: 6
                    }

                    // 合 意
                    Text {
                        readonly property real rBoxW: (parent.width - 14) - parent.balRight_
                        readonly property real gBW: Math.min(92, rBoxW * 0.72)
                        x: parent.balRight_ + (rBoxW - gBW) / 2
                        y: parent.yBase + 36 + 12
                        width: gBW
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "合 意"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 15
                        font.bold: true
                        font.letterSpacing: 4
                    }

                    // BALTHASAR • 02 — centered in the trapezoid
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.yBase + (parent.balTaperY_ - parent.yBase) * 0.45 - height / 2
                        text: "BALTHASAR • 02"
                        color: parent.balHovered ? root.secondary : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // MAGI
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.balTaperY_ + 2
                        text: "MAGI"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 2
                    }

                    // CASPER • 03 — centered in the left node
                    Text {
                        x: (14 + (parent.width / 2 - parent.centerGap_)) / 2 - width / 2
                        y: (parent.nodeTop_ + parent.nodeBot_) / 2 - height / 2
                        text: "CASPER • 03"
                        color: parent.casperHovered ? root.secondary : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 13
                        font.bold: true
                        font.letterSpacing: 1.5

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // MELCHIOR • 01 — centered in the right node
                    Text {
                        x: ((parent.width / 2 + parent.centerGap_) + (parent.width - 14)) / 2 - width / 2
                        y: (parent.nodeTop_ + parent.nodeBot_) / 2 - height / 2
                        text: "MELCHIOR • 01"
                        color: parent.melchiorHovered ? root.secondary : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 13
                        font.bold: true
                        font.letterSpacing: 1.5

                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Bottom Access Code & Question Bar
                Rectangle {
                    id: bottomBar
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    height: 48
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.selectedPid.length > 0 ? root.secondary : root.itemBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "ACCESS CODE: [ " + (root.selectedPid ? "PID: " + root.selectedPid : "...........") + " ]"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Text {
                                text: root.selectedPid ? ("QUESTION:    terminate process '" + root.selectedProcName + "'?") : "QUESTION:    launch or terminate <process>"
                                color: root.selectedPid ? root.accent : root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        // Tactical Terminate Button
                        Rectangle {
                            visible: root.selectedPid.length > 0
                            Layout.preferredWidth: 90
                            Layout.preferredHeight: 24
                            color: killMouse.containsMouse ? root.primary : "#ffffff"
                            border.width: 1
                            border.color: root.secondary

                            Text {
                                anchors.centerIn: parent
                                text: "[ TERMINATE ]"
                                color: killMouse.containsMouse ? "#ffffff" : root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            MouseArea {
                                id: killMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.terminateProcess(root.selectedPid)
                            }
                        }
                    }
                }
            }
        }

        // ============================================================
        // RIGHT PANEL: [ MAGI AI READOUT ] (Placeholder)
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 230
            Layout.minimumWidth: 210
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Top Hazard Line Strip
                NervHazardLines {
                    Layout.fillWidth: true
                    height: 10
                    stripeColor: root.primary
                    bgColor: "#ffffff"
                }

                // Header Info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "[ MAGI // EVACORE DISPATCH ]"
                            color: root.fg
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: root.magiBusy ? root.secondary : root.primary
                        }
                    }

                    Text {
                        text: "EVA ORCHESTRATOR: ONLINE // LATENCY: 12ms"
                        color: root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                // Quick Dispatch Action Pills
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        height: 18
                        color: qStatMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary
                        Text { anchors.centerIn: parent; text: "STATUS"; color: qStatMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        MouseArea { id: qStatMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dispatchMagiCommand("status") }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 18
                        color: qSortMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary
                        Text { anchors.centerIn: parent; text: "SORT"; color: qSortMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        MouseArea { id: qSortMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dispatchMagiCommand("sort") }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 18
                        color: qFileMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary
                        Text { anchors.centerIn: parent; text: "FILE"; color: qFileMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        MouseArea { id: qFileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dispatchMagiCommand("file") }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 18
                        color: qTermMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary
                        Text { anchors.centerIn: parent; text: "TERM"; color: qTermMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        MouseArea { id: qTermMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dispatchMagiCommand("term") }
                    }
                }

                // Main Buffer Area (Scrollable Terminal Log Stream)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 8
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder
                    clip: true

                    Flickable {
                        id: logFlickable
                        anchors.fill: parent
                        anchors.margins: 6
                        contentWidth: width
                        contentHeight: logColumn.implicitHeight
                        clip: true

                        onContentHeightChanged: {
                            logFlickable.contentY = Math.max(0, logColumn.implicitHeight - logFlickable.height);
                        }

                        Column {
                            id: logColumn
                            width: parent.width
                            spacing: 3

                            Repeater {
                                model: root.magiLogs

                                Text {
                                    width: logColumn.width
                                    text: modelData
                                    color: modelData.startsWith(">") ? root.secondary : (modelData.indexOf("ONLINE") !== -1 || modelData.indexOf("ACTIVE") !== -1 || modelData.indexOf("✓") !== -1 ? root.primary : root.fgMuted)
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }
                }

                // Bottom Input & Send Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    height: 26
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.secondary

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Text {
                            text: "MAGI >"
                            color: root.fgDim
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                        }

                        TextInput {
                            id: aiInput
                            Layout.fillWidth: true
                            color: root.fg
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            clip: true
                            selectByMouse: true
                            onAccepted: {
                                root.dispatchMagiCommand(text);
                                text = "";
                            }
                        }

                        Rectangle {
                            width: 44
                            height: 18
                            color: sendMouse.containsMouse ? root.primary : "#ffffff"
                            border.width: 1
                            border.color: root.secondary

                            Text {
                                anchors.centerIn: parent
                                text: "DISPATCH"
                                color: sendMouse.containsMouse ? "#ffffff" : root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 6
                                font.bold: true
                            }

                            MouseArea {
                                id: sendMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.dispatchMagiCommand(aiInput.text);
                                    aiInput.text = "";
                                }
                            }
                        }
                    }
                }

                // Bottom Hazard Line Strip
                NervHazardLines {
                    Layout.fillWidth: true
                    height: 10
                    stripeColor: root.primary
                    bgColor: "#ffffff"
                    scrollLeft: true
                }
            }
        }
    }
}
