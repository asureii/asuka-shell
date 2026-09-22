import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../../../../components"

Item {
    id: root

    property var currentTime: new Date()
    property bool colonBlink: true
    property string localHours: "12"
    property string localMinutes: "00"
    property string localSeconds: "00"
    property string dateBanner: "SATURDAY // 19 SEPTEMBER 2026"
    property string tokyoTime: "14:00:00"
    property string utcTime: "05:00:00"
    property int dayOfYear: 262

    property var weatherData: ({})
    property var storedNotifications: []
    property int hoveredSector: -1
    property int activeSector: 0 // 0: Chrono, 1: Weather, 2: Ops

    signal weatherFocusRequested()
    signal opsFocusRequested()
    signal chronoFocusRequested()

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

    // Multi-plane tilt tracking
    property real normX: 0.0
    property real normY: 0.0

    transform: [
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.normX * 5.0
            Behavior on angle { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: -root.normY * 5.0
            Behavior on angle { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        }
    ]

    Item {
        id: hexStage
        anchors.fill: parent

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real hexR: Math.min(width * 0.48, height * 0.46)

            // Vector Canvas: Pointy-Topped Hexagon with 3 Rhombic Sectors
            Canvas {
                id: hexCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image
                renderStrategy: Canvas.Immediate

                property int hovered: root.hoveredSector
                property int active: root.activeSector
                property real radius: hexStage.hexR

                onHoveredChanged: requestPaint()
                onActiveChanged: requestPaint()
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

                    // 1. Draw Sector Fills (Sector 0: Top, Sector 1: Bottom-Left, Sector 2: Bottom-Right)
                    // Sector 0: pts[5] (300°) -> pts[0] (0°) -> pts[1] (60°) -> center
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.lineTo(pts[5].x, pts[5].y);
                    ctx.lineTo(pts[0].x, pts[0].y);
                    ctx.lineTo(pts[1].x, pts[1].y);
                    ctx.closePath();
                    ctx.fillStyle = (hovered === 0 || active === 0)
                        ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.90);
                    ctx.fill();

                    // Sector 1: pts[3] (180°) -> pts[4] (240°) -> pts[5] (300°) -> center
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.lineTo(pts[3].x, pts[3].y);
                    ctx.lineTo(pts[4].x, pts[4].y);
                    ctx.lineTo(pts[5].x, pts[5].y);
                    ctx.closePath();
                    ctx.fillStyle = (hovered === 1 || active === 1)
                        ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.90);
                    ctx.fill();

                    // Sector 2: pts[1] (60°) -> pts[2] (120°) -> pts[3] (180°) -> center
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.lineTo(pts[1].x, pts[1].y);
                    ctx.lineTo(pts[2].x, pts[2].y);
                    ctx.lineTo(pts[3].x, pts[3].y);
                    ctx.closePath();
                    ctx.fillStyle = (hovered === 2 || active === 2)
                        ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        : Qt.rgba(1.0, 1.0, 1.0, 0.90);
                    ctx.fill();

                    // 2. Concentric Internal Guide Rings
                    var innerScales = [0.84, 0.62];
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
                        ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.14);
                        ctx.stroke();
                    }

                    // 3. Three 120° Dividing Spokes (to vertices 60°, 180°, 300°)
                    ctx.beginPath();
                    ctx.moveTo(cx, cy); ctx.lineTo(pts[1].x, pts[1].y); // 60°
                    ctx.moveTo(cx, cy); ctx.lineTo(pts[3].x, pts[3].y); // 180°
                    ctx.moveTo(cx, cy); ctx.lineTo(pts[5].x, pts[5].y); // 300°
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.40);
                    ctx.stroke();

                    // 4. Outer Hexagon Perimeter Border
                    ctx.beginPath();
                    ctx.moveTo(pts[0].x, pts[0].y);
                    for (var j = 1; j < 6; j++) {
                        ctx.lineTo(pts[j].x, pts[j].y);
                    }
                    ctx.closePath();
                    ctx.lineWidth = 1.8;
                    ctx.strokeStyle = root.primary;
                    ctx.stroke();

                    // Corner vertex tactical ticks
                    for (var v = 0; v < 6; v++) {
                        ctx.beginPath();
                        ctx.arc(pts[v].x, pts[v].y, 2.5, 0, Math.PI * 2);
                        ctx.fillStyle = root.primary;
                        ctx.fill();
                    }
                }
            }

            // Interactive Mouse Areas for the 3 Sectors
            // Sector 0 (Top / Chrono)
            MouseArea {
                id: s0Mouse
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.85
                height: hexStage.cy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredSector = 0
                onExited: if (root.hoveredSector === 0) root.hoveredSector = -1
                onClicked: {
                    root.activeSector = 0;
                    root.chronoFocusRequested();
                }
            }

            // Sector 1 (Bottom-Left / Weather)
            MouseArea {
                id: s1Mouse
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: hexStage.cx
                height: hexStage.cy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredSector = 1
                onExited: if (root.hoveredSector === 1) root.hoveredSector = -1
                onClicked: {
                    root.activeSector = 1;
                    root.weatherFocusRequested();
                }
            }

            // Sector 2 (Bottom-Right / Alerts)
            MouseArea {
                id: s2Mouse
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: hexStage.cx
                height: hexStage.cy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hoveredSector = 2
                onExited: if (root.hoveredSector === 2) root.hoveredSector = -1
                onClicked: {
                    root.activeSector = 2;
                    root.opsFocusRequested();
                }
            }

            // ========================================================
            // CONTENT: SECTOR 0 (TOP / CHRONO TELEMETRY)
            // Centered at exact centroid: (cx, cy - 0.50 * hexR)
            // ========================================================
            Item {
                id: s0Container
                x: hexStage.cx - width / 2
                y: (hexStage.cy - 0.50 * hexStage.hexR) - height / 2
                width: hexStage.hexR * 1.15
                height: 72

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 1
                    width: parent.width

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "▲ CHRONO // ATOMIC"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    // Digital Clock
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        Text {
                            text: root.localHours
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: ":"
                            color: root.colonBlink ? root.primary : "transparent"
                            font.family: root.hudFont
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            text: root.localMinutes
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Text {
                            text: ":"
                            color: root.colonBlink ? root.primary : "transparent"
                            font.family: root.hudFont
                            font.pixelSize: 22
                            font.bold: true
                        }

                        Text {
                            text: root.localSeconds
                            color: root.highlight
                            font.family: root.hudFont
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    // Date Readout
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.dateBanner
                        color: root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    // World Clocks Micro Strip
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 5

                        Text {
                            text: "JST: " + root.tokyoTime
                            color: root.fgDim
                            font.family: root.hudFont
                            font.pixelSize: 6
                            font.bold: true
                        }

                        Rectangle { width: 3; height: 3; radius: 1.5; color: root.primary }

                        Text {
                            text: "ZULU: " + root.utcTime
                            color: root.fgDim
                            font.family: root.hudFont
                            font.pixelSize: 6
                            font.bold: true
                        }
                    }
                }
            }

            // ========================================================
            // CONTENT: SECTOR 1 (BOTTOM-LEFT / METEOROLOGY)
            // Centered safely clear of the center hub: (cx - 0.54 * hexR, cy + 0.28 * hexR)
            // ========================================================
            Item {
                id: s1Container
                x: (hexStage.cx - 0.54 * hexStage.hexR) - width / 2
                y: (hexStage.cy + 0.28 * hexStage.hexR) - height / 2
                width: 96
                height: 64

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    width: parent.width

                    RowLayout {
                        spacing: 3
                        Rectangle { width: 4; height: 4; radius: 2; color: root.primary }
                        Text {
                            text: "◄ BIOSPHERE"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    RowLayout {
                        spacing: 5
                        Text {
                            text: root.weatherData && root.weatherData.icon ? root.weatherData.icon : "󰖙"
                            color: root.primary
                            font.pixelSize: 18
                        }
                        Text {
                            text: (root.weatherData && root.weatherData.temp !== undefined ? root.weatherData.temp : 28) + "°C"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }

                    Text {
                        text: root.weatherData && root.weatherData.condition ? root.weatherData.condition : "ATMOSPHERE"
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "TOKYO-3 RADAR"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 6
                        font.bold: true
                    }
                }
            }

            // ========================================================
            // CONTENT: SECTOR 2 (BOTTOM-RIGHT / OPERATIONS & ALERTS)
            // Centered safely clear of the center hub: (cx + 0.54 * hexR, cy + 0.28 * hexR)
            // ========================================================
            Item {
                id: s2Container
                x: (hexStage.cx + 0.54 * hexStage.hexR) - width / 2
                y: (hexStage.cy + 0.28 * hexStage.hexR) - height / 2
                width: 96
                height: 64

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    width: parent.width

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 3
                        Text {
                            text: "COMMS / ALERTS ►"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                        Rectangle { width: 4; height: 4; radius: 2; color: root.primary }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 4
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: root.storedNotifications && root.storedNotifications.length > 0 ? "#ff2222" : root.primary
                        }
                        Text {
                            text: root.storedNotifications && root.storedNotifications.length > 0
                                ? (root.storedNotifications.length + " ALERTS")
                                : "STANDBY"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "DAY " + root.dayOfYear + " OF 365"
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "DEFENSE PHASE"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 6
                        font.bold: true
                    }
                }
            }

            // ========================================================
            // CENTER HUB: PILOT ASUKA & SYNCHRONY PROGRESS RING
            // ========================================================
            Item {
                id: centerHub
                anchors.centerIn: parent
                width: 82
                height: 82

                // Solid Circular Plate Masking the dividing ray intersection
                Rectangle {
                    anchors.centerIn: parent
                    width: 78
                    height: 78
                    radius: 39
                    color: "#ffffff"
                    border.width: 1.5
                    border.color: root.primary

                    // Top Specular Lip
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.7
                        height: 1.5
                        color: "#ffffff"
                        opacity: 0.95
                    }

                    // Avatar Image clipped to circle
                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        anchors.margins: 3
                        source: "file://" + Quickshell.configPath("assets/asukapfp.jpg")
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }

                    Item {
                        id: avatarMask
                        anchors.fill: avatarImg
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#ffffff"
                        }
                    }

                    MultiEffect {
                        anchors.fill: avatarImg
                        source: avatarImg
                        maskEnabled: true
                        maskSource: avatarMask
                    }

                    // Tactical Status Dot
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.bottomMargin: 2
                        anchors.rightMargin: 2
                        width: 10
                        height: 10
                        radius: 5
                        color: root.primary
                        border.width: 1.5
                        border.color: "#ffffff"
                    }
                }

                // Pilot Tag Badge Below Avatar
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -6
                    width: 66
                    height: 14
                    radius: 7
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Rectangle { width: 3; height: 3; radius: 1.5; color: root.primary }
                        Text {
                            text: "PILOT-02"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }
            }
        }

        // Global Mouse Hover Tracking for 3D Tilt
        MouseArea {
            id: nexusMouse
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: (m) => {
                root.normX = (m.x - width / 2) / (width / 2);
                root.normY = (m.y - height / 2) / (height / 2);
            }
            onExited: {
                root.normX = 0;
                root.normY = 0;
            }
        }
}
