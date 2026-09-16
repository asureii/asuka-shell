pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // CPU Metrics
    property int cpuLoad: 0
    property int cpuTemp: 45
    property var coreLoads: []
    property string cpuModel: ""
    property string hostName: "NERV-NODE"
    property string kernelVer: ""
    property string boardName: ""

    // RAM & Swap Metrics
    property string ramUsedGb: "0.0"
    property string ramTotalGb: "0.0"
    property int ramPct: 0
    property string swapUsedGb: "0.0"
    property string swapTotalGb: "0.0"
    property int swapPct: 0

    // Storage Metrics
    property string rootUsed: "0G"
    property string rootTotal: "0G"
    property int rootPct: 0
    property string homeUsed: "0G"
    property string homeTotal: "0G"
    property int homePct: 0

    // GPU Metrics
    property string gpu1Name: ""
    property int gpu1Clock: 0
    property int gpu1MaxClock: 0
    property int gpu1Pct: 0
    property string gpu1Driver: ""
    property string gpu2Name: ""
    property string gpu2Status: ""
    property string gpu2Driver: ""

    // Battery & Power Metrics
    property int batteryCap: 100
    property string batteryStatus: "AC POWER"
    property bool isAcOnline: true
    property int secondsRemaining: 3600

    // Adaptive Polling Control (2s when active/visible, 8s when hidden/idle)
    property bool activeMode: false

    function refresh() {
        if (!vitalsProcess.running) {
            vitalsProcess.running = true;
        }
    }

    property var vitalsProcess: Process {
        command: [Quickshell.configPath("scripts/nerv_vitals")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data.cpuLoad !== undefined) root.cpuLoad = data.cpuLoad;
                    if (data.cpuTemp !== undefined) root.cpuTemp = data.cpuTemp;
                    if (data.coreLoads) root.coreLoads = data.coreLoads;
                    if (data.cpuModel) root.cpuModel = data.cpuModel;
                    if (data.hostName) root.hostName = data.hostName;
                    if (data.kernelVer) root.kernelVer = data.kernelVer;
                    if (data.boardName) root.boardName = data.boardName;

                    if (data.ramUsedGb) root.ramUsedGb = data.ramUsedGb;
                    if (data.ramTotalGb) root.ramTotalGb = data.ramTotalGb;
                    if (data.ramPct !== undefined) root.ramPct = data.ramPct;

                    if (data.swapUsedGb) root.swapUsedGb = data.swapUsedGb;
                    if (data.swapTotalGb) root.swapTotalGb = data.swapTotalGb;
                    if (data.swapPct !== undefined) root.swapPct = data.swapPct;

                    if (data.rootUsed) root.rootUsed = data.rootUsed;
                    if (data.rootTotal) root.rootTotal = data.rootTotal;
                    if (data.rootPct !== undefined) root.rootPct = data.rootPct;

                    if (data.homeUsed) root.homeUsed = data.homeUsed;
                    if (data.homeTotal) root.homeTotal = data.homeTotal;
                    if (data.homePct !== undefined) root.homePct = data.homePct;

                    if (data.gpu1Name) root.gpu1Name = data.gpu1Name;
                    if (data.gpu1Clock !== undefined) root.gpu1Clock = data.gpu1Clock;
                    if (data.gpu1MaxClock !== undefined) root.gpu1MaxClock = data.gpu1MaxClock;
                    if (data.gpu1Pct !== undefined) root.gpu1Pct = data.gpu1Pct;
                    if (data.gpu1Driver) root.gpu1Driver = data.gpu1Driver;

                    if (data.gpu2Name) root.gpu2Name = data.gpu2Name;
                    if (data.gpu2Status) root.gpu2Status = data.gpu2Status;
                    if (data.gpu2Driver) root.gpu2Driver = data.gpu2Driver;

                    if (data.batteryCap !== undefined) root.batteryCap = Math.round(data.batteryCap);
                    if (data.batteryStatus) root.batteryStatus = data.batteryStatus;
                    if (data.isAcOnline !== undefined) root.isAcOnline = data.isAcOnline;
                    if (data.secondsRemaining !== undefined && data.secondsRemaining > 0) {
                        root.secondsRemaining = data.secondsRemaining;
                    }
                } catch (e) {
                    console.log("Error parsing hardware telemetry:", e);
                }
            }
        }
    }

    property var pollTimer: Timer {
        interval: root.activeMode ? 2000 : 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
