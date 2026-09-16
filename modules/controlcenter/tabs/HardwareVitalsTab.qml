import QtQuick
import QtQuick.Layouts
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

    component MetricBar: Rectangle {
        id: mb
        property real pct: 0
        property color barColor: root.primary
        property int barHeight: 12
        property color borderColor: root.itemBorder
        property int animDuration: 250

        Layout.fillWidth: true
        height: barHeight
        color: "#ffffff"
        border.width: 1
        border.color: borderColor

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: Math.max(0, Math.min(parent.width - 2, (parent.width - 2) * (Math.max(0, Math.min(100, mb.pct)) / 100)))
            color: mb.barColor

            Behavior on width {
                NumberAnimation { duration: mb.animDuration; easing.type: Easing.OutCubic }
            }
        }
    }

    component StorageMetric: ColumnLayout {
        property string title: ""
        property string detail: ""
        property real pct: 0
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Text { text: title; color: root.fg; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { text: detail; color: root.secondary; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }
        }

        MetricBar { pct: pct }
    }

    // Telemetry properties
    property real cpuLoad: 0
    property var coreLoads: [0, 0, 0, 0, 0, 0, 0, 0]
    property real cpuTemp: 0
    property real batteryCap: 100
    property string batteryStatus: "AC POWER"
    property string ramUsedGb: "0.0"
    property string ramTotalGb: "0.0"
    property int ramPct: 0
    property string swapUsedGb: "0.0"
    property string swapTotalGb: "0.0"
    property int swapPct: 0
    property string rootUsed: "0G"
    property string rootTotal: "0G"
    property int rootPct: 0
    property string homeUsed: "0G"
    property string homeTotal: "0G"
    property int homePct: 0
    property string cpuModel: "Scanning..."
    property string hostName: NervSettings.hudBranding + "-NODE"
    property string kernelVer: "Loading..."
    property string boardName: "Scanning Hardware..."

    // GPU Telemetry properties
    property string gpu1Name: "Intel Iris Xe Graphics (TigerLake GT2)"
    property int gpu1Clock: 0
    property int gpu1MaxClock: 1300
    property int gpu1Pct: 0
    property string gpu1Driver: "i915"
    property string gpu2Name: "NVIDIA GeForce MX330 (GP108M)"
    property string gpu2Status: "STANDBY"
    property string gpu2Driver: "nouveau"

    // Live Query Process using compiled C++ binary
    Process {
        id: telemetryProcess
        command: [Quickshell.configPath("scripts/nerv_vitals")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data) {
                        for (var k in data) {
                            if (data[k] !== undefined && root[k] !== undefined) {
                                if (k === "batteryStatus" && typeof data[k] === "string")
                                    root.batteryStatus = data[k].toUpperCase();
                                else
                                    root[k] = data[k];
                            }
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: {
            if (!telemetryProcess.running) telemetryProcess.running = true;
        }
    }

    onVisibleChanged: {
        if (root.visible && !telemetryProcess.running) {
            telemetryProcess.running = true;
        }
    }

    anchors.fill: parent

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ============================================================
        // COLUMN 1: NEURAL PROCESSOR CORES
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 300
            Layout.minimumWidth: 260
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header Row
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ NEURAL PROCESSOR CORES"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.cpuLoad.toFixed(1) + "% LOAD"
                        color: root.secondary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                // CPU Model name
                Text {
                    text: root.cpuModel
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Master CPU Load Bar Track
                MetricBar { pct: root.cpuLoad; barColor: root.accent }

                // Core Topology Grid Header
                Text {
                    text: "CORE TOPOLOGY GRID (" + root.coreLoads.length + " THREADS):"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1
                    Layout.topMargin: 4
                }

                // 2-Column Core Topology Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 8

                    Repeater {
                        model: root.coreLoads.length

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Core Index Label
                            Text {
                                text: (index < 10 ? "0" + index : index) + ":"
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                Layout.preferredWidth: 20
                            }

                            // Core Mini Progress Bar
                            MetricBar {
                                pct: root.coreLoads[index] || 0
                                barHeight: 10
                                borderColor: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)
                                animDuration: 200
                            }

                            // Core Percentage Label
                            Text {
                                text: Math.round(root.coreLoads[index] || 0) + "%"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 30
                            }
                        }
                    }
                }

                // Divider Line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
                    Layout.topMargin: 4
                    Layout.bottomMargin: 2
                }

                // GPU Matrix Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ VISUAL RENDER ENGINE (GPU)"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "[ DUAL GPU ]"
                        color: root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                // GPU 01 Card: Intel Iris Xe
                Rectangle {
                    Layout.fillWidth: true
                    height: 64
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "GPU 01: INTEL IRIS XE (GT2)"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: root.gpu1Clock + " / " + root.gpu1MaxClock + " MHz (" + root.gpu1Pct + "%)"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        // Clock Frequency Scaling Bar
                        MetricBar {
                            pct: root.gpu1Pct
                            barHeight: 8
                            barColor: root.accent
                            borderColor: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "DRIVER: " + root.gpu1Driver + " // DRI MESA"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "ROLE: PRIMARY DISPLAY"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }

                // GPU 02 Card: NVIDIA GeForce MX330
                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "GPU 02: NVIDIA GEFORCE MX330"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: root.gpu2Status === "ACTIVE" ? "#00e5ff" : root.fgDim
                            }

                            Text {
                                text: root.gpu2Status
                                color: root.gpu2Status === "ACTIVE" ? root.secondary : root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "ARCH: PASCAL (GP108M)"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "DRIVER: " + root.gpu2Driver + " PRIME"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ============================================================
        // COLUMN 2: THERMALS & POWER + NODE IDENTITY & EKG
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Section 1: THERMALS & POWER
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ THERMALS & POWER"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                }

                // Thermals Card
                Rectangle {
                    Layout.fillWidth: true
                    height: 90
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Row 1: CPU TEMP
                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 1
                                Text { text: "CPU TEMP"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                                Text { text: Math.round(root.cpuTemp) + "°C"; color: root.accent; font.family: root.hudFont; font.pixelSize: 18; font.bold: true }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 14
                                height: 14
                                color: "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                            }
                        }

                        // Row 2: INTERNAL CELL
                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 1
                                Text { text: "INTERNAL CELL"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                                Text { text: root.batteryStatus; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: Math.round(root.batteryCap) + "%"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }

                // Section 2: NODE IDENTITY & VITAL TELEMETRY
                Text {
                    text: "NODE IDENTITY & VITAL TELEMETRY:"
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "HOST: " + root.hostName
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Text {
                        text: "KERNEL: " + root.kernelVer
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Text {
                        text: "BOARD: " + root.boardName
                        color: root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 8
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "STATUS: SYNC NOMINAL •"
                        color: root.secondary
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                        Layout.topMargin: 2
                    }
                }

                // PULSE EKG Header with Dual Metric Indicators
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "PULSE EKG:"
                        color: root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    // Orange Beacon & Label for CPU
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: root.secondary
                    }
                    Text {
                        text: "CPU: " + Math.round(root.cpuLoad) + "%"
                        color: root.secondary
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }

                    Item { Layout.preferredWidth: 6 }

                    // Red Beacon & Label for Memory
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: root.primary
                    }
                    Text {
                        text: "MEM: " + Math.round(root.ramPct) + "%"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                // Live Cardiac EKG Oscilloscope Waveform Canvas (Dual CPU & MEM Waveforms)
                Rectangle {
                    Layout.fillWidth: true
                    height: 110
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder
                    clip: true

                    property real animOffset: 0.0

                    NumberAnimation on animOffset {
                        from: 0.0
                        to: 360.0
                        duration: 3200
                        loops: Animation.Infinite
                        running: root.visible && (root.opacity > 0.01)
                    }

                    onAnimOffsetChanged: if (root.visible && root.opacity > 0.01) ekgCanvas.requestPaint()

                    Canvas {
                        id: ekgCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.Image
                        renderStrategy: Canvas.Immediate

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            // 1. Background HUD Grid lines
                            ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12);
                            ctx.lineWidth = 0.6;
                            for (var gx = 0; gx <= width; gx += 20) {
                                ctx.beginPath();
                                ctx.moveTo(gx, 0);
                                ctx.lineTo(gx, height);
                                ctx.stroke();
                            }
                            for (var gy = 0; gy <= height; gy += 20) {
                                ctx.beginPath();
                                ctx.moveTo(0, gy);
                                ctx.lineTo(width, gy);
                                ctx.stroke();
                            }

                            // Center crosshair (+)
                            ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35);
                            ctx.lineWidth = 1.0;
                            var midX = width / 2;
                            var midY = height / 2;
                            ctx.beginPath();
                            ctx.moveTo(midX - 8, midY);
                            ctx.lineTo(midX + 8, midY);
                            ctx.moveTo(midX, midY - 8);
                            ctx.lineTo(midX, midY + 8);
                            ctx.stroke();

                            // EKG Cardiac Trace Function parameterized by baseline and amplitude factor
                            function getEkgY(xNorm, baseMidY, ampFactor) {
                                if (xNorm < 0.15) {
                                    // Isoelectric baseline
                                    return baseMidY;
                                } else if (xNorm < 0.28) {
                                    // P Wave (atrial depolarization)
                                    var pPhase = (xNorm - 0.15) / 0.13;
                                    return baseMidY - Math.sin(pPhase * Math.PI) * (8.0 * ampFactor);
                                } else if (xNorm < 0.38) {
                                    // PR segment
                                    return baseMidY;
                                } else if (xNorm < 0.41) {
                                    // Q wave (small downward dip)
                                    var qPhase = (xNorm - 0.38) / 0.03;
                                    return baseMidY + Math.sin(qPhase * Math.PI) * (6.0 * ampFactor);
                                } else if (xNorm < 0.47) {
                                    // R peak (sharp ventricular spike)
                                    var rPhase = (xNorm - 0.41) / 0.06;
                                    return baseMidY - Math.sin(rPhase * Math.PI) * (38.0 * ampFactor);
                                } else if (xNorm < 0.52) {
                                    // S wave (sharp downward dip)
                                    var sPhase = (xNorm - 0.47) / 0.05;
                                    return baseMidY + Math.sin(sPhase * Math.PI) * (11.0 * ampFactor);
                                } else if (xNorm < 0.65) {
                                    // ST segment
                                    return baseMidY;
                                } else if (xNorm < 0.85) {
                                    // T wave (ventricular repolarization)
                                    var tPhase = (xNorm - 0.65) / 0.20;
                                    return baseMidY - Math.sin(tPhase * Math.PI) * (13.0 * ampFactor);
                                } else {
                                    // Baseline
                                    return baseMidY;
                                }
                            }

                            var period = 180;
                            var baseMid = height / 2;

                            // --------------------------------------------------
                            // 2. RED WAVE: MEMORY USAGE (root.ramPct)
                            // --------------------------------------------------
                            // Amplitude scales from 0.35 (at 0%) to 1.55 (at 100%)
                            var memAmp = 0.35 + (Math.max(0, Math.min(100, root.ramPct)) / 100.0) * 1.20;
                            var memOffset = (parent.animOffset + 90) % period; // 90px phase shift

                            ctx.beginPath();
                            ctx.strokeStyle = root.primary;
                            ctx.lineWidth = 1.6;
                            for (var mx = 0; mx <= width; mx += 1.5) {
                                var mCycleX = (mx + memOffset) % period;
                                var mNormX = mCycleX / period;
                                var my = getEkgY(mNormX, baseMid, memAmp);

                                if (mx === 0) ctx.moveTo(mx, my);
                                else ctx.lineTo(mx, my);
                            }
                            ctx.stroke();

                            // --------------------------------------------------
                            // 3. ORANGE WAVE: CPU LOAD (root.cpuLoad)
                            // --------------------------------------------------
                            // Amplitude scales from 0.35 (at 0%) to 1.55 (at 100%)
                            var cpuAmp = 0.35 + (Math.max(0, Math.min(100, root.cpuLoad)) / 100.0) * 1.20;
                            var cpuOffset = parent.animOffset % period;

                            ctx.beginPath();
                            ctx.strokeStyle = root.secondary;
                            ctx.lineWidth = 1.8;
                            for (var cx = 0; cx <= width; cx += 1.5) {
                                var cCycleX = (cx + cpuOffset) % period;
                                var cNormX = cCycleX / period;
                                var cy = getEkgY(cNormX, baseMid, cpuAmp);

                                if (cx === 0) ctx.moveTo(cx, cy);
                                else ctx.lineTo(cx, cy);
                            }
                            ctx.stroke();
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ============================================================
        // COLUMN 3: MEMORY & STORAGE BUFFERS
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 300
            Layout.minimumWidth: 260
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Header
                Text {
                    text: "▶ MEMORY & STORAGE BUFFERS"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                StorageMetric {
                    title: "RAM BUFFER"
                    detail: root.ramUsedGb + " / " + root.ramTotalGb + " GB (" + root.ramPct + "%)"
                    pct: root.ramPct
                }

                StorageMetric {
                    title: "SWAP MEMORY"
                    detail: root.swapUsedGb + " / " + root.swapTotalGb + " GB (" + root.swapPct + "%)"
                    pct: root.swapPct
                }

                // FILESYSTEM PARTITIONS Section
                Text {
                    text: "FILESYSTEM PARTITIONS:"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1
                    Layout.topMargin: 4
                }

                StorageMetric {
                    title: "ROOT [ / ]"
                    detail: root.rootUsed + " / " + root.rootTotal + " (" + root.rootPct + "%)"
                    pct: root.rootPct
                }

                StorageMetric {
                    title: "USER [ /home ]"
                    detail: root.homeUsed + " / " + root.homeTotal + " (" + root.homePct + "%)"
                    pct: root.homePct
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
