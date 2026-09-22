import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Item {
    id: root

    // Dual-Wing Selection State
    // Left Wing: 0: EVAFILE, 1: EVATERM, 2: EVASORT
    // Right Wing: 3: EVALINK, 4: EVATUBE, 5: QUICKSHELL
    property int selectedLeftIndex: 2
    property int selectedRightIndex: 3
    property int hoveredIndex: -1

    property var statusData: ({
        evacore: { installed: false, version: "0.1.0" },
        shell: { running: true, pid: null },
        sort: { running: false, pid: null },
        file: { running: false, count: 0, pids: [] },
        term: { running: false, count: 0, pids: [] },
        link: { running: false, pid: null },
        tube: { available: false }
    })
    property bool evalinkOnline: false

    signal leftAppSelected(int index)
    signal rightAppSelected(int index)
    signal reprobeRequested()
    signal shellRestartRequested()

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

    // Metadata for the 6 EVA items with exact 60-degree sector midpoint angles
    // 0° = North (UP), 90° = East (RIGHT), 180° = South (DOWN), 270° / -90° = West (LEFT)
    readonly property var evaItems: [
        { id: "evafile", name: "EVAFILE", code: "01", side: "left", angle: -30, icon: "󰝰", desc: "FILE BROWSER", sub: "VFS" },
        { id: "evaterm", name: "EVATERM", code: "02", side: "left", angle: -90, icon: "󰆍", desc: "GPU TERMINAL", sub: "SHELL" },
        { id: "evasort", name: "EVASORT", code: "03", side: "left", angle: -150, icon: "󰒋", desc: "AUTO PIPELINE", sub: "DOWNLOADS" },
        { id: "evalink", name: "EVALINK", code: "04", side: "right", angle: 30, icon: "󰇚", desc: "DOWNLINK RPC", sub: "ARIA2" },
        { id: "evatube", name: "EVATUBE", code: "05", side: "right", angle: 90, icon: "󰎆", desc: "MEDIA STREAM", sub: "INGEST" },
        { id: "quickshell", name: "QUICKSHELL", code: "06", side: "right", angle: 150, icon: "󰵆", desc: "SHELL CORE", sub: "IPC" }
    ]

    function getItemStatus(idx) {
        if (!root.statusData) return "STANDBY";
        switch (idx) {
            case 0: return root.statusData.file && root.statusData.file.running ? (root.statusData.file.count + " RUN") : "STANDBY";
            case 1: return root.statusData.term && root.statusData.term.running ? (root.statusData.term.count + " ACT") : "STANDBY";
            case 2: return root.statusData.sort && root.statusData.sort.running ? "WATCH ON" : "STANDBY";
            case 3: return root.evalinkOnline ? "ONLINE" : "STANDBY";
            case 4: return root.statusData.tube && root.statusData.tube.available ? "READY" : "OFFLINE";
            case 5: return "ACTIVE";
            default: return "READY";
        }
    }

    function isItemActive(idx) {
        if (!root.statusData) return false;
        switch (idx) {
            case 0: return !!(root.statusData.file && root.statusData.file.running);
            case 1: return !!(root.statusData.term && root.statusData.term.running);
            case 2: return !!(root.statusData.sort && root.statusData.sort.running);
            case 3: return root.evalinkOnline;
            case 4: return !!(root.statusData.tube && root.statusData.tube.available);
            case 5: return true;
            default: return false;
        }
    }

    function isItemSelected(idx) {
        if (idx <= 2) return root.selectedLeftIndex === idx;
        return root.selectedRightIndex === idx;
    }

    // Outer Background Box
    Rectangle {
        anchors.fill: parent
        color: root.panelBg
        border.width: 1
        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

        // Top Directional Specular Highlight Lip
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#ffffff"
            opacity: 0.85
        }

        // Tactical Corner Brackets
        Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 8; height: 1; color: root.primary }
        Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 1; height: 8; color: root.primary }
        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 8; height: 1; color: root.primary }
        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 1; height: 8; color: root.primary }
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 8; height: 1; color: root.primary }
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 1; height: 8; color: root.primary }
        Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 8; height: 1; color: root.primary }
        Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 1; height: 8; color: root.primary }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            // Top Header Deck
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    width: 3
                    height: 14
                    color: root.primary
                }

                Text {
                    text: "▶ EVACORE HEX-NEXUS // DUAL-AXIS"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 58
                    height: 16
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: root.primary
                        }
                        Text {
                            text: "MAGI-01"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }
            }

            // Hazard Line Divider
            NervHazardLines {
                Layout.fillWidth: true
                height: 6
                stripeColor: root.primary
                bgColor: "#ffffff"
            }

            // Hexagon Interactive Stage
            Item {
                id: hexStage
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real cx: width / 2
                readonly property real cy: height / 2
                // Hexagon radius sized to fill the stage cleanly
                readonly property real hexR: Math.min(width * 0.46, height * 0.46)

                // 1. Vector Canvas: Pointy-Topped Hexagon Geometry & AT-Field Mesh
                Canvas {
                    id: hexCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.Image
                    renderStrategy: Canvas.Immediate

                    property int activeLeft: root.selectedLeftIndex
                    property int activeRight: root.selectedRightIndex
                    property int hovered: root.hoveredIndex
                    property real radius: hexStage.hexR

                    onActiveLeftChanged: requestPaint()
                    onActiveRightChanged: requestPaint()
                    onHoveredChanged: requestPaint()
                    onRadiusChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var cx = width / 2;
                        var cy = height / 2;
                        var R = hexStage.hexR;
                        if (R <= 10) return;

                        // 6 Vertices: 0° is North (UP), 60° Top-Right, 120° Bottom-Right, 180° South, 240° Bottom-Left, 300° Top-Left
                        var pts = [];
                        for (var i = 0; i < 6; i++) {
                            var deg = i * 60;
                            var rad = deg * Math.PI / 180;
                            pts.push({
                                x: cx + R * Math.sin(rad),
                                y: cy - R * Math.cos(rad)
                            });
                        }

                        // Outer Hexagon Background Fill
                        ctx.beginPath();
                        ctx.moveTo(pts[0].x, pts[0].y);
                        for (var j = 1; j < 6; j++) {
                            ctx.lineTo(pts[j].x, pts[j].y);
                        }
                        ctx.closePath();
                        ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.85);
                        ctx.fill();

                        // Concentric Internal Hexagon Rings (AT-Field Gridlines)
                        var innerScales = [0.82, 0.62, 0.42];
                        for (var s = 0; s < innerScales.length; s++) {
                            var sc = innerScales[s];
                            ctx.beginPath();
                            for (var k = 0; k < 6; k++) {
                                var inDeg = k * 60;
                                var inRad = inDeg * Math.PI / 180;
                                var ix = cx + (R * sc) * Math.sin(inRad);
                                var iy = cy - (R * sc) * Math.cos(inRad);
                                if (k === 0) ctx.moveTo(ix, iy);
                                else ctx.lineTo(ix, iy);
                            }
                            ctx.closePath();
                            ctx.lineWidth = 1.0;
                            ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.16);
                            ctx.stroke();
                        }

                        // Radial Spokes from Center to 6 Vertices
                        ctx.beginPath();
                        for (var m = 0; m < 6; m++) {
                            ctx.moveTo(cx, cy);
                            ctx.lineTo(pts[m].x, pts[m].y);
                        }
                        ctx.lineWidth = 1.0;
                        ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22);
                        ctx.stroke();

                        // Sector vertex pairs:
                        // 0: EVAFILE (Top-Left): between V5 (300°) and V0 (0°)
                        // 1: EVATERM (Mid-Left): between V4 (240°) and V5 (300°)
                        // 2: EVASORT (Bottom-Left): between V3 (180°) and V4 (240°)
                        // 3: EVALINK (Top-Right): between V0 (0°) and V1 (60°)
                        // 4: EVATUBE (Mid-Right): between V1 (60°) and V2 (120°)
                        // 5: QUICKSHELL (Bottom-Right): between V2 (120°) and V3 (180°)
                        var sectorPairs = [
                            [5, 0], // 0: EVAFILE (Top-Left)
                            [4, 5], // 1: EVATERM (Mid-Left)
                            [3, 4], // 2: EVASORT (Bottom-Left)
                            [0, 1], // 3: EVALINK (Top-Right)
                            [1, 2], // 4: EVATUBE (Mid-Right)
                            [2, 3]  // 5: QUICKSHELL (Bottom-Right)
                        ];

                        // Helper function to highlight a sector
                        function drawSector(idx, isHighlight) {
                            if (idx < 0 || idx >= 6) return;
                            var pair = sectorPairs[idx];
                            var pA = pts[pair[0]];
                            var pB = pts[pair[1]];

                            ctx.beginPath();
                            ctx.moveTo(cx, cy);
                            ctx.lineTo(pA.x, pA.y);
                            ctx.lineTo(pB.x, pB.y);
                            ctx.closePath();
                            ctx.fillStyle = isHighlight
                                ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)
                                : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08);
                            ctx.fill();

                            // Bright Outer Perimeter Edge
                            ctx.beginPath();
                            ctx.moveTo(pA.x, pA.y);
                            ctx.lineTo(pB.x, pB.y);
                            ctx.lineWidth = isHighlight ? 3.5 : 1.5;
                            ctx.strokeStyle = isHighlight ? root.highlight : root.primary;
                            ctx.stroke();
                        }

                        // Hovered sector
                        if (hovered >= 0 && hovered !== activeLeft && hovered !== activeRight) {
                            drawSector(hovered, false);
                        }

                        // Render both active Left and active Right sectors
                        drawSector(activeLeft, true);
                        drawSector(activeRight, true);

                        // Outer Hexagon Red Border Outline
                        ctx.beginPath();
                        ctx.moveTo(pts[0].x, pts[0].y);
                        for (var n = 1; n < 6; n++) {
                            ctx.lineTo(pts[n].x, pts[n].y);
                        }
                        ctx.closePath();
                        ctx.lineWidth = 2.0;
                        ctx.strokeStyle = root.primary;
                        ctx.stroke();
                    }
                }

                // 2. TEXT AND ICONS RENDERED DIRECTLY INSIDE EACH OF THE 6 HEXAGON SECTORS
                // No outer card boxes! Integrated seamlessly inside the hexagon!
                Repeater {
                    model: root.evaItems

                    Item {
                        id: sectorContent
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.isItemSelected(sectorContent.index)
                        readonly property bool isHovered: root.hoveredIndex === sectorContent.index
                        readonly property bool isActive: root.isItemActive(sectorContent.index)
                        readonly property bool isLeftSide: sectorContent.index <= 2

                        // Calculate label anchor position inside sector:
                        // Center is (cx, cy), distance from center is approx 0.64 * hexR (between core and perimeter)
                        readonly property real rad: sectorContent.modelData.angle * Math.PI / 180
                        readonly property real dist: hexStage.hexR * 0.65

                        x: hexStage.cx + dist * Math.sin(rad) - width / 2
                        y: hexStage.cy - dist * Math.cos(rad) - height / 2
                        width: 82
                        height: 34

                        scale: isHovered ? 1.06 : (isSelected ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            // Row 1: Icon + App Name + Status LED
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    text: sectorContent.modelData.icon
                                    color: sectorContent.isSelected ? root.highlight : (sectorContent.isHovered ? root.primary : root.fg)
                                    font.pixelSize: 10
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Text {
                                    text: sectorContent.modelData.name
                                    color: sectorContent.isSelected ? root.highlight : (sectorContent.isHovered ? root.primary : root.fg)
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                // Glowing LED status dot
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: sectorContent.isActive ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                    border.width: 0.5
                                    border.color: sectorContent.isActive ? "#ffffff" : "transparent"
                                }
                            }

                            // Row 2: Status & Sub-descriptor
                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 3

                                Text {
                                    text: sectorContent.modelData.sub
                                    color: sectorContent.isSelected ? root.primary : root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 6
                                    font.bold: true
                                }

                                Text {
                                    text: "•"
                                    color: root.itemBorder
                                    font.pixelSize: 6
                                }

                                Text {
                                    text: root.getItemStatus(sectorContent.index)
                                    color: sectorContent.isActive ? root.primary : root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 6
                                    font.bold: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoveredIndex = sectorContent.index
                            onExited: {
                                if (root.hoveredIndex === sectorContent.index) {
                                    root.hoveredIndex = -1;
                                }
                            }
                            onClicked: {
                                if (sectorContent.isLeftSide) {
                                    root.selectedLeftIndex = sectorContent.index;
                                    root.leftAppSelected(sectorContent.index);
                                } else {
                                    root.selectedRightIndex = sectorContent.index;
                                    root.rightAppSelected(sectorContent.index);
                                }
                            }
                        }
                    }
                }

                // 3. Central MAGI Dual Targeting Reticle & Needles Hub
                Item {
                    id: reticleHub
                    anchors.centerIn: parent
                    width: hexStage.hexR * 0.76
                    height: width

                    // Left Needle Pivot: Points to active Left App
                    Item {
                        id: leftNeedlePivot
                        anchors.fill: parent

                        readonly property real targetAngle: {
                            if (root.selectedLeftIndex >= 0 && root.selectedLeftIndex <= 2) {
                                return root.evaItems[root.selectedLeftIndex].angle;
                            }
                            return -150;
                        }

                        rotation: targetAngle
                        Behavior on rotation {
                            NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                        }

                        // Left Laser Pointer Needle (pointing from center outward toward selected facet)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.verticalCenter
                            width: 2.5
                            height: parent.height * 0.48
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.highlight }
                                GradientStop { position: 1.0; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) }
                            }

                            // Pointer Arrow Tip
                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 5
                                height: 5
                                rotation: 45
                                color: root.highlight
                            }
                        }
                    }

                    // Right Needle Pivot: Points to active Right App
                    Item {
                        id: rightNeedlePivot
                        anchors.fill: parent

                        readonly property real targetAngle: {
                            if (root.selectedRightIndex >= 3 && root.selectedRightIndex <= 5) {
                                return root.evaItems[root.selectedRightIndex].angle;
                            }
                            return 30;
                        }

                        rotation: targetAngle
                        Behavior on rotation {
                            NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                        }

                        // Right Laser Pointer Needle (pointing from center outward toward selected facet)
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.verticalCenter
                            width: 2.5
                            height: parent.height * 0.48
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.highlight }
                                GradientStop { position: 1.0; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) }
                            }

                            // Pointer Arrow Tip
                            Rectangle {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 5
                                height: 5
                                rotation: 45
                                color: root.highlight
                            }
                        }
                    }

                    // Inner Hexagon Core Hub (The NERV Consensus Circle)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.58
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        border.width: 1.5
                        border.color: root.primary

                        // Top Directional Specular Lip
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.6
                            height: 1
                            color: "#ffffff"
                            opacity: 0.95
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "EVACORE"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                                font.letterSpacing: 0.8
                            }

                            // Active Left App Indicator
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "◀ " + root.evaItems[root.selectedLeftIndex].name
                                color: root.highlight
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 30
                                height: 1
                                color: root.itemBorder
                            }

                            // Active Right App Indicator
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.evaItems[root.selectedRightIndex].name + " ▶"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "DUAL AXIS"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 6
                                font.bold: true
                            }
                        }

                        // Center Pulse Radar Dot
                        Rectangle {
                            anchors.centerIn: parent
                            width: 4
                            height: 4
                            radius: 2
                            color: root.primary
                            opacity: 0.8
                        }
                    }
                }
            }

            // Bottom Telemetry & Rapid Controls Deck
            Rectangle {
                Layout.fillWidth: true
                height: 26
                color: root.itemBg
                border.width: 1
                border.color: root.itemBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 4

                    Text {
                        text: "L: " + root.evaItems[root.selectedLeftIndex].name + " | R: " + root.evaItems[root.selectedRightIndex].name
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    // Re-probe Button
                    Rectangle {
                        width: 52
                        height: 16
                        color: reprobeMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary

                        Text {
                            anchors.centerIn: parent
                            text: "⟳ RE-PROBE"
                            color: reprobeMouse.containsMouse ? "#ffffff" : root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 6
                            font.bold: true
                        }

                        MouseArea {
                            id: reprobeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.reprobeRequested()
                        }
                    }

                    // Reload Shell Button
                    Rectangle {
                        width: 50
                        height: 16
                        color: reloadMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.primary

                        Text {
                            anchors.centerIn: parent
                            text: "󰵆 RESTART"
                            color: reloadMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 6
                            font.bold: true
                        }

                        MouseArea {
                            id: reloadMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shellRestartRequested()
                        }
                    }
                }
            }
        }
    }
}
