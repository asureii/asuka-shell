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

    property real masterVolume: 0.50
    property bool isMuted: false
    property real displayBrightness: 1.0

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
    implicitWidth: 215
    implicitHeight: Math.round(root.cardHeight * 1.06)

    mask: Region {
        item: popoutContainer
    }

    color: "transparent"
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

                var vitalsActive = (typeof vitalsPopout !== "undefined" && vitalsPopout && vitalsPopout.visible && vitalsPopout.isOpen);
                if (!vitalsActive && typeof networkPopout !== "undefined" && networkPopout && networkPopout.visible && networkPopout.isStackedBelow) {
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
        root.refreshAudioBri();
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

    function refreshAudioBri() {
        volProcess.running = true;
        briProcess.running = true;
    }

    onVisibleChanged: {
        if (root.visible) {
            root.refreshAudioBri();
        }
    }

    // Volume Poller
    Process {
        id: volProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim();
                root.isMuted = raw.indexOf("[MUTED]") !== -1;
                var match = raw.match(/Volume:\s*([0-9.]+)/);
                if (match) {
                    root.masterVolume = Math.max(0.0, Math.min(1.0, parseFloat(match[1])));
                }
            }
        }
    }

    // Brightness Poller
    Process {
        id: briProcess
        command: ["sh", "-c", "cur=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1); max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1); [ \"$max\" -gt 0 ] && echo $(( cur * 100 / max )) || echo 100"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(text.trim());
                if (!isNaN(v)) root.displayBrightness = Math.max(0.01, Math.min(1.0, v / 100.0));
            }
        }
    }

    function setVolume(pct) {
        var clamped = Math.max(0.0, Math.min(1.0, pct));
        root.masterVolume = clamped;
        var intPct = Math.round(clamped * 100);
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", intPct + "%"]);
        volProcess.running = true;
    }

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        volProcess.running = true;
    }

    function setBrightness(pct) {
        var clamped = Math.max(0.05, Math.min(1.0, pct));
        root.displayBrightness = clamped;
        var intPct = Math.round(clamped * 100);
        Quickshell.execDetached([Quickshell.configPath("scripts/set_brightness.sh"), intPct.toString()]);
        briProcess.running = true;
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: root.refreshAudioBri()
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

                ctx.fillStyle = "#ffffff";
                ctx.fill();

                ctx.clip();

                ctx.strokeStyle = root.gridColor;
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

        // Main Layout
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4

            // 1. HEADER
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
                    text: NervSettings.hudBranding + " // AUDIO & OPTICAL"
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
                    color: closeHover.containsMouse ? root.primary : "transparent"
                    border.width: 1
                    border.color: root.primary

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeHover.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 8
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

            // 2. DUAL VERTICAL WAVEFORM SLIDERS
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // ==================== VOLUME COLUMN ====================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.width: 1.5
                    border.color: root.primary

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            Text {
                                text: "󰕾 VOL"
                                color: root.textMain
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.isMuted ? "MUTED" : (Math.round(root.masterVolume * 100) + "%")
                                color: root.isMuted ? root.textDim : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }

                        // Vertical Waveform Canvas & Handle Area
                        Rectangle {
                            id: volWaveBox
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04)
                            border.width: 1
                            border.color: root.primary
                            clip: true

                            Canvas {
                                id: volWaveCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                renderStrategy: Canvas.Immediate

                                function getWaveX(yVal, w, h) {
                                    var midX = w / 2;
                                    var amp = Math.max(8, w * 0.35);
                                    return midX + Math.sin(yVal * (Math.PI * 4.0 / Math.max(1, h))) * amp;
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    var w = width;
                                    var h = height;
                                    if (w <= 0 || h <= 0) return;

                                    var midX = w / 2;
                                    var curY = Math.max(0, Math.min(h, (1.0 - root.masterVolume) * h));

                                    // Center Dotted Guide Line
                                    ctx.save();
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20);
                                    ctx.lineWidth = 1;
                                    ctx.beginPath();
                                    ctx.moveTo(midX, 0);
                                    ctx.lineTo(midX, h);
                                    ctx.stroke();

                                    // Horizontal Scale Ticks
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35);
                                    ctx.lineWidth = 1;
                                    for (var t = 0; t <= 4; t++) {
                                        var ty = (t / 4.0) * (h - 4) + 2;
                                        ctx.beginPath();
                                        ctx.moveTo(0, ty);
                                        ctx.lineTo(4, ty);
                                        ctx.moveTo(w - 4, ty);
                                        ctx.lineTo(w, ty);
                                        ctx.stroke();
                                    }

                                    // Inactive Guide Waveform
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20);
                                    ctx.lineWidth = 1.5;
                                    ctx.beginPath();
                                    for (var y = 0; y <= h; y += 2) {
                                        var x = getWaveX(y, w, h);
                                        if (y === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();

                                    // Active Filled Red Waveform
                                    if (curY < h) {
                                        ctx.beginPath();
                                        ctx.moveTo(midX, h);
                                        for (var ay1 = h; ay1 >= curY; ay1 -= 2) {
                                            ctx.lineTo(getWaveX(ay1, w, h), ay1);
                                        }
                                        ctx.lineTo(midX, curY);
                                        ctx.closePath();
                                        ctx.fillStyle = root.isMuted ? Qt.rgba(0.2, 0.2, 0.2, 0.10) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15);
                                        ctx.fill();

                                        ctx.strokeStyle = root.isMuted ? root.textDim : root.primary;
                                        ctx.lineWidth = 2.5;
                                        ctx.beginPath();
                                        for (var ay2 = h; ay2 >= curY; ay2 -= 2) {
                                            var ax2 = getWaveX(ay2, w, h);
                                            if (ay2 === h) ctx.moveTo(ax2, ay2);
                                            else ctx.lineTo(ax2, ay2);
                                        }
                                        ctx.stroke();
                                    }

                                    ctx.restore();
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }

                            Connections {
                                target: root
                                function onMasterVolumeChanged() { volWaveCanvas.requestPaint(); }
                                function onIsMutedChanged() { volWaveCanvas.requestPaint(); }
                            }

                            // Fully Opaque Accurate Diamond Knob
                            Item {
                                id: volKnob
                                readonly property real targetY: Math.max(0, Math.min(parent.height, (1.0 - root.masterVolume) * parent.height))
                                readonly property real targetX: {
                                    var w = parent.width;
                                    var h = parent.height;
                                    var midX = w / 2;
                                    var amp = Math.max(8, w * 0.35);
                                    return midX + Math.sin(targetY * (Math.PI * 4.0 / Math.max(1, h))) * amp;
                                }

                                x: targetX - width / 2
                                y: targetY - height / 2
                                width: 12
                                height: 12

                                Behavior on x {
                                    enabled: !volSliderMouse.pressed
                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }
                                Behavior on y {
                                    enabled: !volSliderMouse.pressed
                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    color: root.isMuted ? root.textDim : root.primary
                                    border.width: 1.5
                                    border.color: "#ffffff"
                                    rotation: 45
                                    antialiasing: true
                                }
                            }

                            MouseArea {
                                id: volSliderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                function applyPos(mouseY) {
                                    var pct = 1.0 - (mouseY / height);
                                    root.setVolume(pct);
                                }

                                onClicked: mouse => applyPos(mouse.y)
                                onPositionChanged: mouse => {
                                    if (pressed) applyPos(mouse.y);
                                }
                                onWheel: wheel => {
                                    if (wheel.angleDelta.y > 0) root.setVolume(root.masterVolume + 0.05);
                                    else if (wheel.angleDelta.y < 0) root.setVolume(root.masterVolume - 0.05);
                                }
                            }
                        }

                        // Mute Toggle Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            color: muteMouse.containsMouse ? root.primary : (root.isMuted ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06))
                            border.width: 1.5
                            border.color: root.primary

                            Text {
                                anchors.centerIn: parent
                                text: root.isMuted ? "UNMUTE" : "MUTE"
                                color: muteMouse.containsMouse ? "#ffffff" : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            MouseArea {
                                id: muteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMute()
                            }
                        }
                    }
                }

                // ==================== BRIGHTNESS COLUMN ====================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.width: 1.5
                    border.color: root.primary

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 3

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            Text {
                                text: "󰃠 BRI"
                                color: root.textMain
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(root.displayBrightness * 100) + "%"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }

                        // Vertical Waveform Canvas & Handle Area
                        Rectangle {
                            id: briWaveBox
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04)
                            border.width: 1
                            border.color: root.primary
                            clip: true

                            Canvas {
                                id: briWaveCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                renderStrategy: Canvas.Immediate

                                function getWaveX(yVal, w, h) {
                                    var midX = w / 2;
                                    var amp = Math.max(8, w * 0.35);
                                    return midX + Math.sin(yVal * (Math.PI * 4.0 / Math.max(1, h))) * amp;
                                }

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    var w = width;
                                    var h = height;
                                    if (w <= 0 || h <= 0) return;

                                    var midX = w / 2;
                                    var curY = Math.max(0, Math.min(h, (1.0 - root.displayBrightness) * h));

                                    // Center Dotted Guide Line
                                    ctx.save();
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20);
                                    ctx.lineWidth = 1;
                                    ctx.beginPath();
                                    ctx.moveTo(midX, 0);
                                    ctx.lineTo(midX, h);
                                    ctx.stroke();

                                    // Horizontal Scale Ticks
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35);
                                    ctx.lineWidth = 1;
                                    for (var t = 0; t <= 4; t++) {
                                        var ty = (t / 4.0) * (h - 4) + 2;
                                        ctx.beginPath();
                                        ctx.moveTo(0, ty);
                                        ctx.lineTo(4, ty);
                                        ctx.moveTo(w - 4, ty);
                                        ctx.lineTo(w, ty);
                                        ctx.stroke();
                                    }

                                    // Inactive Guide Waveform
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20);
                                    ctx.lineWidth = 1.5;
                                    ctx.beginPath();
                                    for (var y = 0; y <= h; y += 2) {
                                        var x = getWaveX(y, w, h);
                                        if (y === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();

                                    // Active Filled Red Waveform
                                    if (curY < h) {
                                        ctx.beginPath();
                                        ctx.moveTo(midX, h);
                                        for (var ay1 = h; ay1 >= curY; ay1 -= 2) {
                                            ctx.lineTo(getWaveX(ay1, w, h), ay1);
                                        }
                                        ctx.lineTo(midX, curY);
                                        ctx.closePath();
                                        ctx.fillStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15);
                                        ctx.fill();

                                        ctx.strokeStyle = root.primary;
                                        ctx.lineWidth = 2.5;
                                        ctx.beginPath();
                                        for (var ay2 = h; ay2 >= curY; ay2 -= 2) {
                                            var ax2 = getWaveX(ay2, w, h);
                                            if (ay2 === h) ctx.moveTo(ax2, ay2);
                                            else ctx.lineTo(ax2, ay2);
                                        }
                                        ctx.stroke();
                                    }

                                    ctx.restore();
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }

                            Connections {
                                target: root
                                function onDisplayBrightnessChanged() { briWaveCanvas.requestPaint(); }
                            }

                            // Fully Opaque Accurate Diamond Knob
                            Item {
                                id: briKnob
                                readonly property real targetY: Math.max(0, Math.min(parent.height, (1.0 - root.displayBrightness) * parent.height))
                                readonly property real targetX: {
                                    var w = parent.width;
                                    var h = parent.height;
                                    var midX = w / 2;
                                    var amp = Math.max(8, w * 0.35);
                                    return midX + Math.sin(targetY * (Math.PI * 4.0 / Math.max(1, h))) * amp;
                                }

                                x: targetX - width / 2
                                y: targetY - height / 2
                                width: 12
                                height: 12

                                Behavior on x {
                                    enabled: !brightSliderMouse.pressed
                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }
                                Behavior on y {
                                    enabled: !brightSliderMouse.pressed
                                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    color: root.primary
                                    border.width: 1.5
                                    border.color: "#ffffff"
                                    rotation: 45
                                    antialiasing: true
                                }
                            }

                            MouseArea {
                                id: brightSliderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                function applyPos(mouseY) {
                                    var pct = 1.0 - (mouseY / height);
                                    root.setBrightness(pct);
                                }

                                onClicked: mouse => applyPos(mouse.y)
                                onPositionChanged: mouse => {
                                    if (pressed) applyPos(mouse.y);
                                }
                                onWheel: wheel => {
                                    if (wheel.angleDelta.y > 0) root.setBrightness(root.displayBrightness + 0.05);
                                    else if (wheel.angleDelta.y < 0) root.setBrightness(root.displayBrightness - 0.05);
                                }
                            }
                        }

                        // Brightness Max/Dim Toggle Button
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            color: briBtnMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                            border.width: 1.5
                            border.color: root.primary

                            Text {
                                anchors.centerIn: parent
                                text: root.displayBrightness >= 0.95 ? "DIM" : "MAX"
                                color: briBtnMouse.containsMouse ? "#ffffff" : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            MouseArea {
                                id: briBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.displayBrightness >= 0.95) {
                                        root.setBrightness(0.40);
                                    } else {
                                        root.setBrightness(1.00);
                                    }
                                }
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

