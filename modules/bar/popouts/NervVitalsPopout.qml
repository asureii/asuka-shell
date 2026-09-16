import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../components"

PanelWindow {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color bg: "#ffffff"
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.96)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property color textMain: "#1a0000"
    readonly property color textMuted: Qt.rgba(0.1, 0.0, 0.0, 0.65)
    readonly property color textDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Telemetry State
    readonly property int cpuLoad: NervVitals.cpuLoad
    readonly property int cpuTemp: NervVitals.cpuTemp
    readonly property var coreLoads: NervVitals.coreLoads
    readonly property string ramUsedGb: NervVitals.ramUsedGb
    readonly property string ramTotalGb: NervVitals.ramTotalGb
    readonly property int ramPct: NervVitals.ramPct
    readonly property string swapUsedGb: NervVitals.swapUsedGb
    readonly property string swapTotalGb: NervVitals.swapTotalGb
    readonly property int swapPct: NervVitals.swapPct
    readonly property string rootUsed: NervVitals.rootUsed
    readonly property string rootTotal: NervVitals.rootTotal
    readonly property int rootPct: NervVitals.rootPct
    readonly property string cpuModel: NervVitals.cpuModel
    readonly property string hostName: NervVitals.hostName
    readonly property string kernelVer: NervVitals.kernelVer

    // Dynamic Stacking State (Tier 1: top=46, Tier 2: top=334)
    property bool isStackedBelow: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.isStackedBelow ? 334 : 46
        right: (root.screen ? Math.max(20, Math.round((root.screen.width - 1280) / 2) + 48 + 215 + 8) : (91 + 215 + 8))
    }

    readonly property real cardHeight: 280
    implicitWidth: 220
    implicitHeight: Math.round(root.cardHeight * 1.06)

    mask: Region {
        item: popoutContainer
    }

    color: "transparent"
    visible: false

    property bool isOpen: false
    property real revealProgress: 0.0
    property real beamOpacity: 0.0

    ParallelAnimation {
        id: openAnim
        onStarted: {
            root.beamOpacity = 1.0;
        }
        onFinished: {
            root.revealProgress = 1.0;
            root.beamOpacity = 0.0;
        }
        NumberAnimation {
            id: openProgressAnim
            target: root
            property: "revealProgress"
            from: 0.0
            to: 1.0
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.165
        }
        SequentialAnimation {
            PauseAnimation { duration: 220 }
            NumberAnimation {
                target: root
                property: "beamOpacity"
                from: 1.0
                to: 0.0
                duration: 100
                easing.type: Easing.OutQuad
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        onStarted: {
            root.beamOpacity = 1.0;
        }
        onFinished: {
            root.revealProgress = 0.0;
            root.beamOpacity = 0.0;
            if (!root.isOpen) {
                root.visible = false;
                root.isStackedBelow = false;

                var audioBriActive = (typeof audioBriPopout !== "undefined" && audioBriPopout && audioBriPopout.visible && audioBriPopout.isOpen);
                if (!audioBriActive && typeof networkPopout !== "undefined" && networkPopout && networkPopout.visible && networkPopout.isStackedBelow) {
                    networkPopout.isStackedBelow = false;
                }
            }
        }
        NumberAnimation {
            id: closeProgressAnim
            target: root
            property: "revealProgress"
            from: 1.0
            to: 0.0
            duration: 180
            easing.type: Easing.InCubic
        }
    }

    function toggle() {
        if (!root.isOpen) root.open();
        else root.close();
    }

    function open() {
        var netActive = (typeof networkPopout !== "undefined" && networkPopout && networkPopout.visible && networkPopout.isOpen && !networkPopout.isStackedBelow);
        root.isStackedBelow = netActive;
        root.isOpen = true;
        root.visible = true;
        root.beamOpacity = 1.0;
        openProgressAnim.from = root.revealProgress;
        root.refreshVitals();
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        if (!root.visible || !root.isOpen) {
            root.isOpen = false;
            root.visible = false;
            root.isStackedBelow = false;
            return;
        }
        root.isOpen = false;
        root.beamOpacity = 1.0;
        closeProgressAnim.from = root.revealProgress;
        openAnim.stop();
        closeAnim.restart();
    }

    function refreshVitals() {
        NervVitals.refresh();
    }

    onVisibleChanged: {
        if (root.visible) {
            root.refreshVitals();
        }
    }

    // Popout Container with Scanline Reveal Animation
    Item {
        id: popoutContainer
        width: parent.width
        height: Math.round(root.revealProgress * root.cardHeight)
        focus: true
        clip: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        Item {
            id: animContent
            width: parent.width
            height: root.cardHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            transform: Scale {
                origin.x: animContent.width / 2
                origin.y: 0
                yScale: Math.max(1.0, root.revealProgress)
            }

        // Tactical Chamfered Frame Canvas
        Canvas {
            id: frameCanvas
            anchors.fill: parent
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            property real chamfer: 8
            property real strokeWidth: 2

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var w = width;
                var h = height;
                var c = chamfer;
                var sw = strokeWidth;
                var half = sw / 2;

                ctx.save();
                ctx.beginPath();
                ctx.moveTo(half, half);
                ctx.lineTo(w - c - half, half);
                ctx.lineTo(w - half, c + half);
                ctx.lineTo(w - half, h - half);
                ctx.lineTo(c + half, h - half);
                ctx.lineTo(half, h - c - half);
                ctx.closePath();

                ctx.fillStyle = root.bg;
                ctx.fill();

                ctx.clip();

                ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05);
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (var gy = 4; gy < h; gy += 4) {
                    ctx.moveTo(0, gy);
                    ctx.lineTo(w, gy);
                }
                ctx.stroke();

                ctx.restore();

                ctx.save();
                ctx.beginPath();
                ctx.moveTo(half, half);
                ctx.lineTo(w - c - half, half);
                ctx.lineTo(w - half, c + half);
                ctx.lineTo(w - half, h - half);
                ctx.lineTo(c + half, h - half);
                ctx.lineTo(half, h - c - half);
                ctx.closePath();

                ctx.strokeStyle = root.primary;
                ctx.lineWidth = sw;
                ctx.stroke();
                ctx.restore();
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // Inner Main Layout
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            // 1. TACTICAL HEADER ROW
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                spacing: 4

                Rectangle {
                    width: 3
                    height: 12
                    color: root.primary
                }

                Text {
                    text: NervSettings.hudBranding + " // SYSTEM VITALS"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 14
                    color: closeMouse.containsMouse ? root.primary : "transparent"
                    border.width: 1
                    border.color: root.primary

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
            }

            // 2. CPU LOAD SECTION
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: "#ffffff"
                border.width: 1.5
                border.color: root.primary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "CPU LOAD"
                            color: root.textMain
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.cpuTemp > 0 ? (root.cpuTemp + "°C // " + root.cpuLoad + "%") : (root.cpuLoad + "%")
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }

                    // CPU Model Subtitle
                    Text {
                        text: root.cpuModel.replace(/\(R\)/g, "").replace(/\(TM\)/g, "").trim()
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 6
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // CPU Total Usage Bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.30)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.cpuLoad / 100.0)))
                            color: root.primary

                            Behavior on width {
                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    // Per-Core Mini Load Bars
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: root.coreLoads.length > 0 ? root.coreLoads : 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 3
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                                readonly property real loadVal: typeof modelData === "number" ? modelData : 0

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.max(0, Math.min(parent.width, parent.width * (parent.loadVal / 100.0)))
                                    color: root.primary

                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 3. MEMORY (RAM) SECTION
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "#ffffff"
                border.width: 1.5
                border.color: root.primary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "RAM"; color: root.textMain; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.ramUsedGb + "G / " + root.ramTotalGb + "G (" + root.ramPct + "%)"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.30)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.ramPct / 100.0)))
                            color: root.primary

                            Behavior on width {
                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            // 4. STORAGE (ROOT) SECTION
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "#ffffff"
                border.width: 1.5
                border.color: root.primary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "STORAGE (/)"; color: root.textMain; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.rootUsed + " / " + root.rootTotal + " (" + root.rootPct + "%)"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.30)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.rootPct / 100.0)))
                            color: root.primary

                            Behavior on width {
                                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }

            // 5. SYSTEM TELEMETRY
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "#ffffff"
                border.width: 1.5
                border.color: root.primary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { text: "NODE:"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                                Text { text: root.hostName.toUpperCase(); color: root.primary; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text { text: "KER:"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                                Text { text: root.kernelVer; color: root.primary; font.family: root.hudFont; font.pixelSize: 6; font.bold: true; elide: Text.ElideRight }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Rectangle { width: 2; height: 6; color: root.primary }
                        Text {
                            text: "CPU // " + root.cpuModel.replace(/\(R\)/g, "").replace(/\(TM\)/g, "").trim()
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 6
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // 6. OPEN FULL TAB 05 BUTTON
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                color: fullCcMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                border.width: 1
                border.color: root.primary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 3
                    Text { text: "⚙"; color: fullCcMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 7 }
                    Text {
                        text: "FULL HARDWARE (TAB 05)"
                        color: fullCcMouse.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }
                }

                MouseArea {
                    id: fullCcMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof controlCenter !== "undefined" && controlCenter) {
                            controlCenter.currentTabIndex = 4; // Tab 05 Hardware Vitals
                            if (typeof controlCenter.open === "function") controlCenter.open(); else controlCenter.visible = true;
                        }
                        root.close();
                    }
                }
            }
        }
        }
    }

    // Tactical Laser Scanline Beam
    NervScanlineBeam {
        revealProgress: root.revealProgress
        beamOpacity: root.beamOpacity
        running: openAnim.running || closeAnim.running
        targetHeight: root.cardHeight
        primaryColor: root.primary
        hudFont: root.hudFont
    }
}

