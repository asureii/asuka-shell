import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../../../../components"

Item {
    id: root

    property bool colonBlink: true
    property string localHours: "12"
    property string localMinutes: "00"
    property string localSeconds: "00"
    property string dateBanner: ""
    property string tokyoTime: "--:--"
    property string utcTime: "--:--"
    property int dayOfYear: 1
    property int daysInYear: 365

    property var weatherData: ({})
    property int alertCount: 0
    property int criticalCount: 0

    property int hoveredSector: -1
    property int activeSector: 0 // 0: Chrono/Calendar, 1: Weather, 2: Alerts

    signal sectorClicked(int sector)

    readonly property color primary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color critical: "#ff1a10"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.50)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    readonly property var sectorHints: ["OPEN CALENDAR", "FOCUS WEATHER", "OPEN ALERTS"]

    // Subtle parallax tilt
    property real normX: 0.0
    property real normY: 0.0

    transform: [
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.normX * 3.0
            Behavior on angle { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: -root.normY * 3.0
            Behavior on angle { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        }
    ]

    Item {
        id: hexStage
        anchors.fill: parent

        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real hexR: Math.min(width * 0.48 / 0.866, height * 0.46)

        // Returns 0/1/2 for a sector, -1 for outside hex or on the center hub
        function sectorAt(px, py) {
            var dx = px - cx, dy = py - cy;
            var adx = Math.abs(dx), ady = Math.abs(dy);
            if (adx > hexR * 0.866 || ady > hexR - adx / 1.732) return -1;
            if (Math.sqrt(dx * dx + dy * dy) < 42) return -1;
            var deg = Math.atan2(dx, -dy) * 180 / Math.PI;
            if (deg < 0) deg += 360;
            if (deg >= 300 || deg < 60) return 0;
            if (deg < 180) return 2;
            return 1;
        }

        Canvas {
            id: hexCanvas
            anchors.fill: parent
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            property int hovered: root.hoveredSector
            property int active: root.activeSector
            property bool alarm: root.criticalCount > 0

            onHoveredChanged: requestPaint()
            onActiveChanged: requestPaint()
            onAlarmChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2, cy = height / 2;
                var R = hexStage.hexR;
                if (R <= 10) return;

                var pts = [];
                for (var i = 0; i < 6; i++) {
                    var rad = i * 60 * Math.PI / 180;
                    pts.push({ x: cx + R * Math.sin(rad), y: cy - R * Math.cos(rad) });
                }

                // Sector polygons: 0 top, 1 bottom-left, 2 bottom-right
                var sectors = [[5, 0, 1], [3, 4, 5], [1, 2, 3]];
                for (var s = 0; s < 3; s++) {
                    var p = sectors[s];
                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.lineTo(pts[p[0]].x, pts[p[0]].y);
                    ctx.lineTo(pts[p[1]].x, pts[p[1]].y);
                    ctx.lineTo(pts[p[2]].x, pts[p[2]].y);
                    ctx.closePath();
                    var a = 0.0;
                    if (active === s) a = 0.10;
                    if (hovered === s) a = Math.max(a, 0.06) + 0.04;
                    ctx.fillStyle = a > 0 ? Qt.rgba(0.8, 0.0, 0.0, a) : Qt.rgba(1.0, 1.0, 1.0, 0.92);
                    ctx.fill();
                }

                // Concentric guide rings
                var scales = [0.84, 0.62];
                for (var k = 0; k < scales.length; k++) {
                    ctx.beginPath();
                    for (var j = 0; j < 6; j++) {
                        var r2 = j * 60 * Math.PI / 180;
                        var ix = cx + R * scales[k] * Math.sin(r2);
                        var iy = cy - R * scales[k] * Math.cos(r2);
                        if (j === 0) ctx.moveTo(ix, iy); else ctx.lineTo(ix, iy);
                    }
                    ctx.closePath();
                    ctx.lineWidth = 1.0;
                    ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.14);
                    ctx.stroke();
                }

                // Dividing spokes
                ctx.beginPath();
                ctx.moveTo(cx, cy); ctx.lineTo(pts[1].x, pts[1].y);
                ctx.moveTo(cx, cy); ctx.lineTo(pts[3].x, pts[3].y);
                ctx.moveTo(cx, cy); ctx.lineTo(pts[5].x, pts[5].y);
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.40);
                ctx.stroke();

                // Perimeter
                ctx.beginPath();
                ctx.moveTo(pts[0].x, pts[0].y);
                for (var v = 1; v < 6; v++) ctx.lineTo(pts[v].x, pts[v].y);
                ctx.closePath();
                ctx.lineWidth = 1.8;
                ctx.strokeStyle = "#cc0000";
                ctx.stroke();

                // Active sector outer edge accent
                var ap = sectors[active] || sectors[0];
                ctx.beginPath();
                ctx.moveTo(pts[ap[0]].x, pts[ap[0]].y);
                ctx.lineTo(pts[ap[1]].x, pts[ap[1]].y);
                ctx.lineTo(pts[ap[2]].x, pts[ap[2]].y);
                ctx.lineWidth = 3.5;
                ctx.strokeStyle = (active === 2 && alarm) ? "#ff1a10" : "#ff2222";
                ctx.stroke();

                for (var t = 0; t < 6; t++) {
                    ctx.beginPath();
                    ctx.arc(pts[t].x, pts[t].y, 2.5, 0, Math.PI * 2);
                    ctx.fillStyle = "#cc0000";
                    ctx.fill();
                }
            }
        }

        // Single hit-tested input layer: exact hexagon sectors + parallax tilt
        MouseArea {
            id: sectorMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.hoveredSector >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPositionChanged: (m) => {
                root.hoveredSector = hexStage.sectorAt(m.x, m.y);
                root.normX = (m.x - width / 2) / (width / 2);
                root.normY = (m.y - height / 2) / (height / 2);
            }
            onExited: {
                root.hoveredSector = -1;
                root.normX = 0;
                root.normY = 0;
            }
            onClicked: (m) => {
                var s = hexStage.sectorAt(m.x, m.y);
                if (s >= 0) root.sectorClicked(s);
            }
        }

        // ========================================================
        // SECTOR 0 (TOP): CLOCK
        // ========================================================
        ColumnLayout {
            x: hexStage.cx - width / 2
            y: (hexStage.cy - 0.52 * hexStage.hexR) - height / 2
            width: hexStage.hexR * 1.2
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "▲ CHRONO"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1.5
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 1
                Text { text: root.localHours; color: root.primary; font.family: root.hudFont; font.pixelSize: 30; font.bold: true }
                Text { text: ":"; color: root.primary; opacity: root.colonBlink ? 1 : 0.15; font.family: root.hudFont; font.pixelSize: 26; font.bold: true }
                Text { text: root.localMinutes; color: root.primary; font.family: root.hudFont; font.pixelSize: 30; font.bold: true }
                Text {
                    text: root.localSeconds
                    color: root.highlight
                    font.family: root.hudFont
                    font.pixelSize: 14
                    font.bold: true
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 5
                    Layout.leftMargin: 3
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.dateBanner
                color: root.fgMuted
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 0.5
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "JST " + root.tokyoTime + "   ·   UTC " + root.utcTime
                color: root.fgDim
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
            }

            // Year progress
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 5
                implicitWidth: hexStage.hexR * 0.8
                implicitHeight: 3
                Rectangle { anchors.fill: parent; color: Qt.rgba(0.8, 0.0, 0.0, 0.12) }
                Rectangle { height: parent.height; width: parent.width * root.dayOfYear / root.daysInYear; color: root.primary }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "DAY " + root.dayOfYear + " / " + root.daysInYear
                color: root.fgDim
                font.family: root.hudFont
                font.pixelSize: 7
                font.bold: true
            }
        }

        // ========================================================
        // SECTOR 1 (BOTTOM-LEFT): WEATHER SUMMARY
        // ========================================================
        ColumnLayout {
            x: (hexStage.cx - 0.50 * hexStage.hexR) - width / 2
            y: (hexStage.cy + 0.30 * hexStage.hexR) - height / 2
            width: 104
            spacing: 2

            Text {
                text: "◄ WEATHER"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 0.8
            }
            RowLayout {
                spacing: 5
                Text {
                    text: root.weatherData && root.weatherData.icon ? root.weatherData.icon : "󰖙"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 20
                }
                Text {
                    text: (root.weatherData && root.weatherData.temp !== undefined ? root.weatherData.temp : "--") + "°C"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 18
                    font.bold: true
                }
            }
            Text {
                text: root.weatherData && root.weatherData.condition ? root.weatherData.condition : "—"
                color: root.fg
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // ========================================================
        // SECTOR 2 (BOTTOM-RIGHT): ALERTS SUMMARY
        // ========================================================
        ColumnLayout {
            x: (hexStage.cx + 0.50 * hexStage.hexR) - width / 2
            y: (hexStage.cy + 0.30 * hexStage.hexR) - height / 2
            width: 104
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignRight
                text: "ALERTS ►"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 0.8
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 5
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.criticalCount > 0 ? root.critical : (root.alertCount > 0 ? root.highlight : Qt.rgba(0.8, 0.0, 0.0, 0.3))
                    SequentialAnimation on opacity {
                        running: root.visible && root.criticalCount > 0
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.2; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }
                Text {
                    text: root.alertCount > 0 ? root.alertCount : "0"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 20
                    font.bold: true
                }
            }
            Text {
                Layout.alignment: Qt.AlignRight
                text: root.criticalCount > 0 ? (root.criticalCount + " CRITICAL")
                     : (root.alertCount > 0 ? "UNREAD" : "ALL CLEAR")
                color: root.criticalCount > 0 ? root.critical : root.fg
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
            }
        }

        // ========================================================
        // CENTER HUB: PILOT AVATAR
        // ========================================================
        Item {
            id: centerHub
            anchors.centerIn: parent
            width: 82
            height: 82

            Rectangle {
                anchors.centerIn: parent
                width: 78
                height: 78
                radius: 39
                color: "#ffffff"
                border.width: 1.5
                border.color: root.primary

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    anchors.margins: 3
                    source: "file://" + Quickshell.shellPath("assets/asukapfp.jpg")
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                Item {
                    id: avatarMask
                    anchors.fill: avatarImg
                    visible: false
                    layer.enabled: true
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "#ffffff" }
                }
                MultiEffect {
                    anchors.fill: avatarImg
                    source: avatarImg
                    maskEnabled: true
                    maskSource: avatarMask
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.bottomMargin: 2
                    anchors.rightMargin: 2
                    width: 10; height: 10; radius: 5
                    color: root.primary
                    border.width: 1.5
                    border.color: "#ffffff"
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -6
                width: 66
                height: 15
                radius: 7.5
                color: "#ffffff"
                border.width: 1
                border.color: root.primary
                Text {
                    anchors.centerIn: parent
                    text: "PILOT-02"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }
            }
        }

        // Hover hint chip (tells the user what a click does)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(2, hexStage.cy - hexStage.hexR - 22)
            implicitWidth: hintText.implicitWidth + 16
            implicitHeight: 18
            color: root.primary
            opacity: root.hoveredSector >= 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Text {
                id: hintText
                anchors.centerIn: parent
                text: "CLICK ▸ " + (root.hoveredSector >= 0 ? root.sectorHints[root.hoveredSector] : "")
                color: "#ffffff"
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1.0
            }
        }
    }
}
