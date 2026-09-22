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
    readonly property color textMain: "#111111"
    readonly property color textMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color textDim: Qt.rgba(0.1, 0.0, 0.0, 0.50)
    readonly property color gridColor: Qt.rgba(0.8, 0.0, 0.0, 0.06)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Network Telemetry State
    property string netType: "DISCONNECTED"
    property string activeIface: "wlo1"
    property string activeSsid: "OFFLINE"
    property string activeBssid: "--:--:--:--:--:--"
    property int activeSignal: 0
    property string activeSecurity: "NONE"
    property string activeFreq: ""
    property string localIp: "127.0.0.1"
    property string gatewayIp: "0.0.0.0"
    property var scannedNetworks: []
    property bool isScanning: false

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
        right: (root.screen ? Math.max(20, Math.round((root.screen.width - 1280) / 2) + 48) : 91)
    }

    readonly property real cardHeight: 280
    implicitWidth: 443
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

                if (typeof vitalsPopout !== "undefined" && vitalsPopout && vitalsPopout.visible && vitalsPopout.isStackedBelow) {
                    vitalsPopout.isStackedBelow = false;
                }
                if (typeof audioBriPopout !== "undefined" && audioBriPopout && audioBriPopout.visible && audioBriPopout.isStackedBelow) {
                    audioBriPopout.isStackedBelow = false;
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
        if (!root.isOpen) {
            root.open();
        } else {
            root.close();
        }
    }

    function open() {
        var vitalsActive = (typeof vitalsPopout !== "undefined" && vitalsPopout && vitalsPopout.visible && vitalsPopout.isOpen && !vitalsPopout.isStackedBelow);
        var audioBriActive = (typeof audioBriPopout !== "undefined" && audioBriPopout && audioBriPopout.visible && audioBriPopout.isOpen && !audioBriPopout.isStackedBelow);

        root.isStackedBelow = (vitalsActive || audioBriActive);
        root.isOpen = true;
        root.visible = true;
        root.beamOpacity = 1.0;
        openProgressAnim.from = root.revealProgress;
        root.refreshNetwork();
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

    function triggerRescan() {
        root.isScanning = true;
        wifiScanPoller.running = true;
    }

    function refreshNetwork() {
        netPoller.running = true;
        routePoller.running = true;
        wifiScanPoller.running = true;
    }

    // Network Poller Process
    Process {
        id: netPoller
        command: ["sh", "-c", "wf=$(nmcli -t -f active,ssid,bssid,signal,security,freq dev wifi 2>/dev/null | grep '^yes' | head -n1); if [ -n \"$wf\" ]; then echo \"WIFI:$wf\"; exit 0; fi; eth=$(nmcli -t -f TYPE,STATE,DEVICE dev 2>/dev/null | grep '^ethernet:connected'); if [ -n \"$eth\" ]; then dev=$(echo \"$eth\" | cut -d: -f3); echo \"ETH:ETHERNET:CONNECTED:100:WIRED:--:$dev\"; exit 0; fi; echo \"DISCONNECTED:::::::\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim();
                var parts = raw.split(":");
                if (parts[0] === "WIFI" && parts.length >= 7) {
                    root.netType = "WIFI";
                    root.activeSsid = parts[2] || "UNKNOWN";
                    root.activeBssid = parts[3] || "";
                    var s = parseInt(parts[4]);
                    root.activeSignal = !isNaN(s) ? s : 0;
                    root.activeSecurity = parts[5] || "WPA2";
                    root.activeFreq = parts[6] || "";
                } else if (parts[0] === "ETH") {
                    root.netType = "ETH";
                    root.activeSsid = "WIRED ETHERNET";
                    root.activeSignal = 100;
                    root.activeSecurity = "DIRECT";
                    if (parts[6]) root.activeIface = parts[6];
                } else {
                    root.netType = "DISCONNECTED";
                    root.activeSsid = "OFFLINE";
                    root.activeSignal = 0;
                }
            }
        }
    }

    // IP Route Poller Process
    Process {
        id: routePoller
        command: ["sh", "-c", "ip -j route get 1.1.1.1 2>/dev/null | grep -o '\"gateway\":\"[^\"]*\"' | cut -d'\"' -f4; ip -j route get 1.1.1.1 2>/dev/null | grep -o '\"prefsrc\":\"[^\"]*\"' | cut -d'\"' -f4; ip -j route get 1.1.1.1 2>/dev/null | grep -o '\"dev\":\"[^\"]*\"' | cut -d'\"' -f4"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                if (lines.length >= 1 && lines[0]) root.gatewayIp = lines[0];
                if (lines.length >= 2 && lines[1]) root.localIp = lines[1];
                if (lines.length >= 3 && lines[2]) root.activeIface = lines[2];
            }
        }
    }

    // Wi-Fi Access Points Full Scanner Process
    Process {
        id: wifiScanPoller
        command: ["sh", "-c", "nmcli dev wifi rescan 2>/dev/null || true; nmcli -t -f in-use,ssid,bssid,signal,security dev wifi 2>/dev/null | grep -v '^:[[:space:]]*$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var list = [];
                var seen = {};
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim();
                    if (!l) continue;
                    var p = l.split(":");
                    if (p.length >= 5) {
                        var inUse = (p[0].indexOf("*") !== -1 || p[0].indexOf("yes") !== -1);
                        var sName = p[1].replace(/\\/g, "").trim();
                        if (!sName) continue;
                        var sig = parseInt(p[3]);
                        var sec = p[4].replace(/\\/g, "").trim();
                        
                        // Keep or update highest signal entry per SSID
                        if (seen[sName]) {
                            if (inUse || sig > seen[sName].signal) {
                                seen[sName].signal = sig;
                                seen[sName].inUse = inUse;
                                seen[sName].security = sec || "OPEN";
                            }
                        } else {
                            var item = {
                                inUse: inUse,
                                ssid: sName,
                                signal: !isNaN(sig) ? sig : 0,
                                security: sec || "OPEN"
                            };
                            seen[sName] = item;
                            list.push(item);
                        }
                    }
                }

                // Sort: in-use first, then descending signal strength
                list.sort(function(a, b) {
                    if (a.inUse && !b.inUse) return -1;
                    if (!a.inUse && b.inUse) return 1;
                    return b.signal - a.signal;
                });

                root.scannedNetworks = list;
                root.isScanning = false;
            }
        }
    }

    Timer {
        interval: 4000
        running: root.visible
        repeat: true
        onTriggered: root.refreshNetwork()
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

            // Top Directional Specular Highlight Rim
            Rectangle {
                z: 20
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#ffffff"
                opacity: 0.85
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

                ctx.fillStyle = "#ffffff";
                ctx.fill();

                ctx.clip();

                // Scanline grid
                ctx.strokeStyle = root.gridColor;
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (var gy = 4; gy < h; gy += 4) {
                    ctx.moveTo(0, gy);
                    ctx.lineTo(w, gy);
                }
                ctx.stroke();

                ctx.restore();

                // Outer border
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

        // Main Layout
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 5

            // 1. HEADER ROW
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: 4

                Rectangle {
                    width: 3
                    height: 12
                    color: root.primary
                }

                Text {
                    text: NervSettings.hudBranding + " // NETWORK RADAR"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                }

                Text {
                    text: "• IFACE: " + root.activeIface.toUpperCase()
                    color: root.textDim
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 16
                    color: closeHover.containsMouse ? root.primary : "transparent"
                    border.width: 1
                    border.color: root.primary
                    scale: closeHover.pressed ? 0.90 : (closeHover.containsMouse ? 1.08 : 1.0)

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeHover.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                    }

                    MouseArea {
                        id: closeHover
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

            // 2. DUAL DECK MAIN BODY
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                // ==================== LEFT DECK: ACTIVE LINK & RADAR (210px) ====================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.width: 1.5
                    border.color: root.primary

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        // Active SSID & Signal Status
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 14
                            Text {
                                text: (root.netType === "WIFI" ? "󰤨 " : (root.netType === "ETH" ? "󰌘 " : "󰤭 ")) + "ACTIVE LINK"
                                color: root.textMain
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.netType === "DISCONNECTED" ? "OFFLINE" : (root.activeSignal + "%")
                                color: root.netType === "DISCONNECTED" ? root.textDim : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        // SSID Name Pill
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.30)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 4
                                Text {
                                    text: "SSID:"
                                    color: root.textDim
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                                Text {
                                    text: root.activeSsid
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // IP & Gateway Matrix
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04)
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text { text: "IPv4 ADDRESS"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                                    Text { text: root.localIp; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04)
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text { text: "GATEWAY ROUTE"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                                    Text { text: root.gatewayIp; color: root.textMain; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                }
                            }
                        }

                        // Tactical Evangelion Radar Canvas
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03)
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)
                            clip: true

                            Canvas {
                                id: radarCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                renderStrategy: Canvas.Immediate

                                property real sweepAngle: 0.0

                                NumberAnimation on sweepAngle {
                                    from: 0
                                    to: Math.PI * 2
                                    duration: 3000
                                    loops: Animation.Infinite
                                    running: root.visible
                                }

                                onSweepAngleChanged: requestPaint()

                                function shortenName(name) {
                                    if (!name) return "";
                                    var clean = name.replace(/[^a-zA-Z0-9]/g, "");
                                    if (clean.length > 5) return clean.substring(0, 5) + "..";
                                    return clean;
                                }

                                function getNetAngle(ssid, idx) {
                                    var hash = 0;
                                    for (var c = 0; c < ssid.length; c++) {
                                        hash = ((hash << 5) - hash) + ssid.charCodeAt(c);
                                        hash |= 0;
                                    }
                                    var base = (idx / 5.0) * Math.PI * 2 + 0.35;
                                    var jitter = ((Math.abs(hash) % 50) / 50.0) * 0.4 - 0.2;
                                    return base + jitter;
                                }

                                function getNetRadius(sig, maxRadius) {
                                    var norm = Math.max(0.1, Math.min(1.0, sig / 100.0));
                                    return maxRadius * (0.85 - norm * 0.45);
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    var cx = width / 2;
                                    var cy = height / 2;
                                    var maxR = Math.min(cx, cy) - 6;
                                    if (maxR <= 0) return;

                                    // Concentric Radar Rings
                                    ctx.save();
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18);
                                    ctx.lineWidth = 1;
                                    for (var r = 1; r <= 3; r++) {
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, (maxR / 3) * r, 0, Math.PI * 2);
                                        ctx.stroke();
                                    }

                                    // Crosshairs
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22);
                                    ctx.beginPath();
                                    ctx.moveTo(cx - maxR, cy);
                                    ctx.lineTo(cx + maxR, cy);
                                    ctx.moveTo(cx, cy - maxR);
                                    ctx.lineTo(cx, cy + maxR);
                                    ctx.stroke();

                                    // Rotating Sweep Beam
                                    if (root.netType !== "DISCONNECTED") {
                                        ctx.beginPath();
                                        ctx.moveTo(cx, cy);
                                        ctx.arc(cx, cy, maxR, sweepAngle - 0.45, sweepAngle);
                                        ctx.closePath();
                                        ctx.fillStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15);
                                        ctx.fill();

                                        ctx.strokeStyle = root.primary;
                                        ctx.lineWidth = 1.5;
                                        ctx.beginPath();
                                        ctx.moveTo(cx, cy);
                                        ctx.lineTo(cx + Math.cos(sweepAngle) * maxR, cy + Math.sin(sweepAngle) * maxR);
                                        ctx.stroke();

                                        // Center beacon dot
                                        ctx.fillStyle = root.primary;
                                        ctx.beginPath();
                                        ctx.arc(cx, cy, 2.5, 0, Math.PI * 2);
                                        ctx.fill();
                                    }

                                    // Render Top 5 Best Networks on the Radar Screen
                                    var topCount = Math.min(5, root.scannedNetworks.length);
                                    for (var i = 0; i < topCount; i++) {
                                        var net = root.scannedNetworks[i];
                                        var theta = getNetAngle(net.ssid, i);
                                        var rad = getNetRadius(net.signal, maxR);
                                        var nx = cx + Math.cos(theta) * rad;
                                        var ny = cy + Math.sin(theta) * rad;

                                        var angleDiff = (sweepAngle - theta) % (Math.PI * 2);
                                        if (angleDiff < 0) angleDiff += Math.PI * 2;
                                        var isPinged = (angleDiff < 0.55);
                                        var pingIntensity = isPinged ? (1.0 - angleDiff / 0.55) : 0.0;

                                        // 1. Radar Blip Ping Pulse
                                        if (isPinged && pingIntensity > 0.05) {
                                            ctx.beginPath();
                                            ctx.arc(nx, ny, 3 + pingIntensity * 5, 0, Math.PI * 2);
                                            ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, pingIntensity * 0.8);
                                            ctx.lineWidth = 1;
                                            ctx.stroke();
                                        }

                                        // 2. Radar Blip Point
                                        ctx.beginPath();
                                        if (net.inUse) {
                                            ctx.arc(nx, ny, 3.5, 0, Math.PI * 2);
                                            ctx.fillStyle = root.primary;
                                            ctx.fill();
                                            ctx.strokeStyle = "#ffffff";
                                            ctx.lineWidth = 1;
                                            ctx.stroke();
                                        } else {
                                            ctx.arc(nx, ny, 2.2, 0, Math.PI * 2);
                                            ctx.fillStyle = isPinged ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.70);
                                            ctx.fill();
                                        }

                                        // 3. Shortened SSID Label
                                        var label = shortenName(net.ssid);
                                        if (label) {
                                            ctx.fillStyle = net.inUse ? root.primary : (isPinged ? root.primary : root.textDim);
                                            ctx.font = "bold 6px " + root.hudFont;
                                            ctx.textAlign = (nx >= cx) ? "left" : "right";
                                            ctx.textBaseline = "middle";
                                            var lx = (nx >= cx) ? (nx + 4) : (nx - 4);
                                            ctx.fillText(label, lx, ny);
                                        }
                                    }

                                    ctx.restore();
                                }
                            }
                        }

                        // Disconnect / Reconnect Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            color: discMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                            border.width: 1
                            border.color: root.primary

                            Text {
                                anchors.centerIn: parent
                                text: root.netType === "DISCONNECTED" ? "󰖩 RECONNECT" : "󰖪 DISCONNECT"
                                color: discMouse.containsMouse ? "#ffffff" : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            MouseArea {
                                id: discMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.netType !== "DISCONNECTED") {
                                        Quickshell.execDetached(["nmcli", "dev", "disconnect", root.activeIface]);
                                    } else {
                                        Quickshell.execDetached(["nmcli", "dev", "connect", root.activeIface]);
                                    }
                                    root.refreshNetwork();
                                }
                            }
                        }
                    }
                }

                // ==================== RIGHT DECK: ALL AVAILABLE NETWORKS & RESCAN ====================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.width: 1.5
                    border.color: root.primary

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        // Header with Live Network Count
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 14
                            Text {
                                text: "AVAILABLE NETWORKS"
                                color: root.textMain
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.isScanning ? "SCANNING..." : (root.scannedNetworks.length + " FOUND")
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        // Full Scrollable List of All Available Wi-Fi Networks
                        ListView {
                            id: wifiList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3
                            model: root.scannedNetworks
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                active: true
                                width: 4
                                policy: ScrollBar.AsNeeded
                                background: Rectangle {
                                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                }
                                contentItem: Rectangle {
                                    color: root.primary
                                }
                            }

                            delegate: Rectangle {
                                width: wifiList.width - (wifiList.contentHeight > wifiList.height ? 6 : 0)
                                height: 24
                                color: modelData.inUse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.16) : (stationHover.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03))
                                border.width: 1
                                border.color: modelData.inUse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 4

                                    Text {
                                        text: modelData.inUse ? "󰄬" : (modelData.signal >= 60 ? "󰤨" : (modelData.signal >= 35 ? "󰤥" : "󰤢"))
                                        color: modelData.inUse ? root.primary : (modelData.signal >= 40 ? root.textMain : root.textDim)
                                        font.pixelSize: 9
                                    }

                                    Text {
                                        text: modelData.ssid
                                        color: modelData.inUse ? root.primary : root.textMain
                                        font.family: root.hudFont
                                        font.pixelSize: 8
                                        font.bold: modelData.inUse
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.signal + "%"
                                        color: modelData.inUse ? root.primary : root.textDim
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                    }

                                    Text {
                                        text: modelData.security.indexOf("WPA") !== -1 ? "󰌾" : (modelData.security === "OPEN" || !modelData.security ? "󰌿" : "󰌾")
                                        color: root.textDim
                                        font.pixelSize: 8
                                    }
                                }

                                MouseArea {
                                    id: stationHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!modelData.inUse) {
                                            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid]);
                                            root.triggerRescan();
                                        }
                                    }
                                }
                            }
                        }

                        // Dedicated Full-Width RESCAN Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            color: rescanBtnMouse.containsMouse ? root.primary : (root.isScanning ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.16) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06))
                            border.width: 1.5
                            border.color: root.primary

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "󰑓"
                                    color: rescanBtnMouse.containsMouse ? "#ffffff" : root.primary
                                    font.pixelSize: 9

                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: root.isScanning && root.visible && (root.opacity > 0.01)
                                    }
                                }

                                Text {
                                    text: root.isScanning ? "SCANNING WIRELESS SPECTRUM..." : "RESCAN WIRELESS NETWORKS"
                                    color: rescanBtnMouse.containsMouse ? "#ffffff" : root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                }
                            }

                            MouseArea {
                                id: rescanBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.triggerRescan()
                            }
                        }
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

