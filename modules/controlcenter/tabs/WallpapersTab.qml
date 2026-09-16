import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
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

    property string activePath: ""
    property string activeName: ""
    property bool nightLightOn: false
    property real colorTemp: 6000
    property real colorTempSlider: 0.88 // 0.0 = 2500K, 1.0 = 6500K
    property real displayBrightness: 1.0

    // Read display brightness
    Process {
        id: brightnessGetter
        command: ["sh", "-c", "cur=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1); max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1); echo \"$cur $max\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(/\s+/);
                if (parts.length >= 2) {
                    var cur = parseFloat(parts[0]);
                    var max = parseFloat(parts[1]);
                    if (max > 0) root.displayBrightness = Math.max(0.01, Math.min(1.0, cur / max));
                }
            }
        }
    }

    // Set display brightness process
    Process {
        id: brightnessSetter
        command: [Quickshell.configPath("scripts/set_brightness.sh"), "100"]
    }

    function setBrightness(pct) {
        pct = Math.max(0.01, Math.min(1.0, pct));
        root.displayBrightness = pct;
        var pctInt = Math.round(pct * 100);
        brightnessSetter.command = [Quickshell.configPath("scripts/set_brightness.sh"), pctInt.toString()];
        brightnessSetter.running = true;
    }

    // Real Wallpaper Assets List (Populated strictly from disk scan)
    property var wallpapers: []

    // Read current saved wallpaper
    Process {
        id: readSavedProcess
        command: ["sh", "-c", "cat '" + Quickshell.configPath("wallpaper.txt") + "' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim();
                if (p.length > 0) {
                    if (p.startsWith("~/")) {
                        p = (Quickshell.env("HOME") || "") + p.substring(1);
                    } else if (!p.startsWith("/")) {
                        p = Quickshell.configPath(p);
                    }
                    root.activePath = p;
                    root.activeName = p.split("/").pop();
                }
            }
        }
    }

    // Set wallpaper process
    Process {
        id: setWallProcess
        command: ["sh", "-c", "true"]
    }

    // Rescan Wallpapers directory (Strictly ~/Pictures/Wallpapers only)
    Process {
        id: scanProcess
        command: ["sh", "-c", "mkdir -p ~/Pictures/Wallpapers && find ~/Pictures/Wallpapers -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' -o -name '*.webp' \\) 2>/dev/null | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapers = text.trim().split("\n")
                    .map(l => l.trim())
                    .filter(l => l.length > 0)
                    .map(l => ({ name: l.split("/").pop(), path: l }));
            }
        }
    }

    function selectWallpaper(path, name) {
        if (!path) return;
        root.activePath = path;
        root.activeName = name || path.split("/").pop();

        setWallProcess.command = ["sh", "-c", "echo -n '" + path + "' > '" + Quickshell.configPath("wallpaper.txt") + "'; quickshell -p '" + Quickshell.configPath("") + "' ipc call background setWallpaper '" + path + "' 2>/dev/null || true"];
        setWallProcess.running = true;
    }

    function setNightLight(enabled) {
        root.nightLightOn = enabled;
        var temp = Math.round(root.colorTemp);
        nightLightProcess.command = [Quickshell.configPath("scripts/set_hyprsunset.sh"), enabled ? temp.toString() : "off"];
        nightLightProcess.running = true;
    }

    function updateColorTemp(pct) {
        pct = Math.max(0.0, Math.min(1.0, pct));
        root.colorTempSlider = pct;
        root.colorTemp = Math.round(2500 + pct * 4000);
        if (root.nightLightOn) {
            nightLightProcess.command = [Quickshell.configPath("scripts/set_hyprsunset.sh"), root.colorTemp.toString()];
            nightLightProcess.running = true;
        }
    }

    Process {
        id: nightLightProcess
        command: [Quickshell.configPath("scripts/set_hyprsunset.sh"), "off"]
    }

    Process {
        id: checkSunsetProcess
        command: ["sh", "-c", "pgrep -x hyprsunset >/dev/null && echo 'ON' || echo 'OFF'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var st = text.trim();
                root.nightLightOn = (st === "ON");
            }
        }
    }

    Component.onCompleted: {
        readSavedProcess.running = true;
        scanProcess.running = true;
        brightnessGetter.running = true;
        checkSunsetProcess.running = true;
    }

    anchors.fill: parent

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ============================================================
        // LEFT: VISUAL BUFFER MATRIX (WALLPAPERS GRID)
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
                spacing: 8

                // Header Row
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ VISUAL BUFFER MATRIX (WALLPAPERS)"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Item { Layout.fillWidth: true }

                    // Open in EvaFile Button
                    Rectangle {
                        width: 82
                        height: 18
                        color: efWallMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary

                        Text {
                            anchors.centerIn: parent
                            text: "󰝰 EVAFILE"
                            color: efWallMouse.containsMouse ? "#ffffff" : root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: efWallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["evafile", (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"])
                        }
                    }

                    // Open in EvaTerm Button
                    Rectangle {
                        width: 82
                        height: 18
                        color: etWallMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary

                        Text {
                            anchors.centerIn: parent
                            text: "󰆍 EVATERM"
                            color: etWallMouse.containsMouse ? "#ffffff" : root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: etWallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["evaterm", "-e", "bash", "-c", "cd '" + (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers' && exec $SHELL"])
                        }
                    }

                    // Rescan Button
                    Rectangle {
                        width: 76
                        height: 18
                        color: rescanMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.secondary

                        Text {
                            anchors.centerIn: parent
                            text: "[ RESCAN ]"
                            color: rescanMouse.containsMouse ? "#ffffff" : root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                        }

                        MouseArea {
                            id: rescanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!scanProcess.running) scanProcess.running = true;
                                if (!readSavedProcess.running) readSavedProcess.running = true;
                            }
                        }
                    }
                }

                // 3-Column Wallpaper Grid (Thumbnails)
                Item {
                    Layout.fillWidth: true
                    height: Math.min(220, Math.max(105, Math.ceil(root.wallpapers.length / 3) * 106))

                    Flickable {
                        id: gridFlickable
                        anchors.fill: parent
                        anchors.rightMargin: 6
                        clip: true
                        contentWidth: width
                        contentHeight: gridFlow.implicitHeight

                        Flow {
                            id: gridFlow
                            width: gridFlickable.width
                            spacing: 6

                            Repeater {
                                model: root.wallpapers

                                Rectangle {
                                    id: card
                                    width: Math.floor((gridFlow.width - 12) / 3)
                                    height: 100
                                    color: "#ffffff"

                                    readonly property bool isCurrent: root.activeName === modelData.name || root.activePath === modelData.path

                                    border.width: isCurrent ? 1.5 : (cardMouse.containsMouse ? 1 : 1)
                                    border.color: isCurrent ? root.accent : (cardMouse.containsMouse ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35))

                                    // Subtle Grid Canvas inside Card
                                    Canvas {
                                        anchors.fill: parent
                                        renderTarget: Canvas.Image
                                        renderStrategy: Canvas.Immediate
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);
                                            ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15);
                                            ctx.lineWidth = 0.6;
                                            for (var x = 0; x < width; x += 16) {
                                                ctx.beginPath();
                                                ctx.moveTo(x, 0);
                                                ctx.lineTo(x, height);
                                                ctx.stroke();
                                            }
                                            for (var y = 0; y < height; y += 16) {
                                                ctx.beginPath();
                                                ctx.moveTo(0, y);
                                                ctx.lineTo(width, y);
                                                ctx.stroke();
                                            }
                                        }
                                    }

                                    // Thumbnail Image
                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        source: modelData.path ? (modelData.path.startsWith("/") ? "file://" + modelData.path : modelData.path) : ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        opacity: isCurrent ? 1.0 : (cardMouse.containsMouse ? 0.9 : 0.7)
                                    }

                                    // Active Corner Highlight Ticks
                                    Rectangle {
                                        visible: card.isCurrent
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        width: 8
                                        height: 8
                                        color: root.accent
                                    }

                                    // Filename Label Overlay
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 18
                                        color: Qt.rgba(1.0, 1.0, 1.0, 0.85)

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.name
                                            color: card.isCurrent ? root.accent : root.fg
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: card.isCurrent
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectWallpaper(modelData.path, modelData.name);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Pure QtQuick ScrollBar Track
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15)
                        visible: gridFlickable.contentHeight > gridFlickable.height

                        Rectangle {
                            width: parent.width
                            height: Math.max(16, (gridFlickable.height / Math.max(1, gridFlickable.contentHeight)) * parent.height)
                            y: (gridFlickable.contentY / Math.max(1, (gridFlickable.contentHeight - gridFlickable.height))) * (parent.height - height)
                            color: root.primary
                        }
                    }
                }

                // ============================================================
                // LARGE TACTICAL WALLPAPER SHOWCASE (Fills the big empty space)
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder
                    clip: true

                    // Large Background Image of Active Target
                    Image {
                        id: largePreviewImg
                        anchors.fill: parent
                        source: root.activePath.length > 0 ? (root.activePath.startsWith("/") ? "file://" + root.activePath : root.activePath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: 0.9

                        Behavior on opacity {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }

                    // Faint HUD Grid Overlay
                    Canvas {
                        anchors.fill: parent
                        renderTarget: Canvas.Image
                        renderStrategy: Canvas.Immediate
                        opacity: 0.45
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15);
                            ctx.lineWidth = 0.6;
                            for (var x = 0; x <= width; x += 32) {
                                ctx.beginPath();
                                ctx.moveTo(x, 0);
                                ctx.lineTo(x, height);
                                ctx.stroke();
                            }
                            for (var y = 0; y <= height; y += 32) {
                                ctx.beginPath();
                                ctx.moveTo(0, y);
                                ctx.lineTo(width, y);
                                ctx.stroke();
                            }
                        }
                    }

                    // Tactical Corner Reticles
                    Repeater {
                        model: ["⌜", "⌝", "⌞", "⌟"]
                        Text {
                            anchors.top: index < 2 ? parent.top : undefined
                            anchors.bottom: index >= 2 ? parent.bottom : undefined
                            anchors.left: (index % 2 === 0) ? parent.left : undefined
                            anchors.right: (index % 2 === 1) ? parent.right : undefined
                            anchors.margins: 8
                            text: modelData
                            color: root.accent
                            font.family: root.hudFont
                            font.pixelSize: 18
                            font.bold: true
                        }
                    }

                    // Center Targeting Reticle
                    Text {
                        anchors.centerIn: parent
                        text: "┼"
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.6)
                        font.family: root.hudFont
                        font.pixelSize: 22
                    }

                    // Top Left Header Strip
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 12
                        width: targetTitleCol.implicitWidth + 16
                        height: targetTitleCol.implicitHeight + 10
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                        border.width: 1
                        border.color: root.itemBorder

                        ColumnLayout {
                            id: targetTitleCol
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                text: "ACTIVE RECON TARGET:"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            Text {
                                text: root.activeName.length > 0 ? root.activeName : "NO SOURCE LOADED"
                                color: root.accent
                                font.family: root.hudFont
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    // Top Right Telemetry Badge
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 12
                        width: 130
                        height: 22
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                        border.width: 1
                        border.color: root.secondary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "• LIVE BUFFER SYNC"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }
                    }

                    // Bottom Telemetry Bar
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 24
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.92)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Text {
                                text: "URI: " + root.activePath
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 8
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "LAYER: WLR_LAYER_BACKGROUND • ADAPTER: eDP-1"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        // ============================================================
        // RIGHT: ATMOSPHERE & SPECTRAL FILTER + ACTIVE RECON TARGET
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 350
            Layout.minimumWidth: 320
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 16

                // Section 1 Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ ATMOSPHERE & SPECTRAL FILTER"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                }

                // Hypr-Sunset Night Light / Color Temperature Waveform Slider Card
                Rectangle {
                    Layout.fillWidth: true
                    height: 76
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "HYPR-SUNSET NIGHT LIGHT"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(root.colorTemp) + " K"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 10
                                font.bold: true
                            }
                            Item { Layout.preferredWidth: 6 }
                            // Toggle Badge Button
                            Rectangle {
                                width: 44
                                height: 16
                                color: root.nightLightOn ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.nightLightOn ? root.accent : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.nightLightOn ? "[ ON ]" : "[ OFF ]"
                                    color: root.nightLightOn ? "#ffffff" : root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    id: nightLightMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setNightLight(!root.nightLightOn)
                                }
                            }
                        }

                        // Waveform Canvas with Interactive Slider Handle
                        Item {
                            id: tempWaveArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Canvas {
                                id: tempWaveCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                renderStrategy: Canvas.Immediate

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    // Faint guide wave
                                    ctx.beginPath();
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.2);
                                    ctx.lineWidth = 1;
                                    for (var x = 0; x <= width; x += 2) {
                                        var y = height / 2 + Math.sin(x * 0.035) * 5;
                                        if (x === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();

                                    // Main smooth sine waveform
                                    ctx.beginPath();
                                    ctx.strokeStyle = root.primary;
                                    ctx.lineWidth = 2;
                                    for (var x = 0; x <= width; x += 2) {
                                        var y = height / 2 + Math.sin(x * 0.03 + 0.3) * 12;
                                        if (x === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }

                            // Interactive / Positioned Knob Handle
                            Item {
                                x: Math.max(0, Math.min(parent.width - 12, parent.width * root.colorTempSlider - 6))
                                y: parent.height / 2 + Math.sin((parent.width * root.colorTempSlider) * 0.03 + 0.3) * 12 - 6
                                width: 12
                                height: 12

                                Behavior on x {
                                    enabled: !tempWaveMouse.pressed
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                                Behavior on y {
                                    enabled: !tempWaveMouse.pressed
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "transparent"
                                    border.width: 2
                                    border.color: root.accent
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: root.secondary
                                }
                            }

                            MouseArea {
                                id: tempWaveMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => root.updateColorTemp(mouse.x / width)
                                onPositionChanged: mouse => {
                                    if (pressed) root.updateColorTemp(mouse.x / width);
                                }
                            }
                        }
                    }
                }

                // Section 1.2: Display Luminance (Brightness) Slider — Styled Identically to Tab 07 Volume Slider
                Rectangle {
                    Layout.fillWidth: true
                    height: 76
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "DISPLAY LUMINANCE LEVEL"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(root.displayBrightness * 100) + "%"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        // Waveform Canvas with Interactive Slider Handle
                        Item {
                            id: brightnessWaveArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Canvas {
                                id: brightnessWaveCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                renderStrategy: Canvas.Immediate

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    // Faint guide wave
                                    ctx.beginPath();
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.2);
                                    ctx.lineWidth = 1;
                                    for (var x = 0; x <= width; x += 2) {
                                        var y = height / 2 + Math.sin(x * 0.03) * 6;
                                        if (x === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();

                                    // Main smooth sine waveform
                                    ctx.beginPath();
                                    ctx.strokeStyle = root.primary;
                                    ctx.lineWidth = 2;
                                    for (var x = 0; x <= width; x += 2) {
                                        var y = height / 2 + Math.sin(x * 0.025 + 0.5) * 14;
                                        if (x === 0) ctx.moveTo(x, y);
                                        else ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();
                                }
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }

                            // Interactive / Positioned Knob Handle
                            Item {
                                x: Math.max(0, Math.min(parent.width - 12, parent.width * root.displayBrightness - 6))
                                y: parent.height / 2 + Math.sin((parent.width * root.displayBrightness) * 0.025 + 0.5) * 14 - 6
                                width: 12
                                height: 12

                                Behavior on x {
                                    enabled: !brightnessWaveMouse.pressed
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                                Behavior on y {
                                    enabled: !brightnessWaveMouse.pressed
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "transparent"
                                    border.width: 2
                                    border.color: root.accent
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: root.secondary
                                }
                            }

                            MouseArea {
                                id: brightnessWaveMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => root.setBrightness(mouse.x / width)
                                onPositionChanged: mouse => {
                                    if (pressed) root.setBrightness(mouse.x / width);
                                }
                            }
                        }
                    }
                }

                // Section 2: Active Recon Target Card & Preview
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "ACTIVE RECON TARGET:"
                        color: root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    Text {
                        text: root.activeName
                        color: root.accent
                        font.family: root.hudFont
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.activePath
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    // Action Buttons Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // Browse Button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 24
                            color: browseMouse.containsMouse ? root.primary : "#ffffff"
                            border.width: 1
                            border.color: root.secondary

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                Text { text: ""; color: browseMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 9 }
                                Text { text: "BROWSE FILE"; color: browseMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                            }

                            MouseArea {
                                id: browseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: externalDialog.open()
                            }
                        }

                        // Unset / Clear Button
                        Rectangle {
                            width: 80
                            height: 24
                            color: clearMouse.containsMouse ? root.primary : "#ffffff"
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)

                            Text {
                                anchors.centerIn: parent
                                text: "✕ UNSET"
                                color: clearMouse.containsMouse ? "#ffffff" : root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectWallpaper("", "NONE")
                            }
                        }
                    }
                }

                // Section 3: Visual Protocol Shaders Matrix
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "▶ VISUAL PROTOCOL SHADERS"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    // 1. CRT PHOSPHOR SCANLINES
                    Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        color: root.itemBg
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Text {
                                text: "CRT PHOSPHOR SCANLINES"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 44
                                height: 16
                                color: NervSettings.crtEnabled ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: NervSettings.crtEnabled ? root.accent : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)

                                Text {
                                    anchors.centerIn: parent
                                    text: NervSettings.crtEnabled ? "[ ON ]" : "[ OFF ]"
                                    color: NervSettings.crtEnabled ? "#ffffff" : root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NervSettings.crtEnabled = !NervSettings.crtEnabled
                                }
                            }
                        }
                    }

                    // 2. SPECTRAL RGB ABERRATION
                    Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        color: root.itemBg
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Text {
                                text: "SPECTRAL RGB ABERRATION"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 44
                                height: 16
                                color: NervSettings.rgbAberrationEnabled ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: NervSettings.rgbAberrationEnabled ? root.accent : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)

                                Text {
                                    anchors.centerIn: parent
                                    text: NervSettings.rgbAberrationEnabled ? "[ ON ]" : "[ OFF ]"
                                    color: NervSettings.rgbAberrationEnabled ? "#ffffff" : root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NervSettings.rgbAberrationEnabled = !NervSettings.rgbAberrationEnabled
                                }
                            }
                        }
                    }

                    // 3. HEXAGONAL MATRIX HUD
                    Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        color: root.itemBg
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Text {
                                text: "HEXAGONAL MATRIX HUD"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 44
                                height: 16
                                color: NervSettings.hexHudEnabled ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: NervSettings.hexHudEnabled ? root.accent : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)

                                Text {
                                    anchors.centerIn: parent
                                    text: NervSettings.hexHudEnabled ? "[ ON ]" : "[ OFF ]"
                                    color: NervSettings.hexHudEnabled ? "#ffffff" : root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NervSettings.hexHudEnabled = !NervSettings.hexHudEnabled
                                }
                            }
                        }
                    }
                }

                // Section 5: Display Output Status
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: root.itemBg
                    border.width: 1
                    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Text {
                            text: "󰍹 eDP-1 // 1920x1080 @ 60Hz"
                            color: root.fg
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "• ONLINE"
                            color: root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        FileDialog {
            id: externalDialog
            title: "Select External " + NervSettings.hudBranding + " Wallpaper"
            nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.svg)", "All files (*)"]
            onAccepted: {
                root.selectWallpaper(selectedFile.toString().replace(/^file:\/\//, ""));
            }
        }
    }
}
