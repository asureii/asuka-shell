import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
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

    component FormatBtn: Rectangle {
        id: fb
        property string label: ""
        property bool selected: false
        signal clicked()
        Layout.fillWidth: true
        height: 20
        color: selected ? root.primary : "#ffffff"
        border.width: 1
        border.color: selected ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)
        scale: fbMouse.pressed ? 0.94 : (fbMouse.containsMouse ? 1.05 : 1.0)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

        // Top Specular Highlight Rim
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#ffffff"
            opacity: fb.selected ? 0.9 : 0.35
        }

        Text {
            anchors.centerIn: parent
            text: fb.label
            color: fb.selected ? "#ffffff" : root.fgMuted
            font.family: root.hudFont
            font.pixelSize: 7
            font.bold: true
        }
        MouseArea {
            id: fbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.clicked()
        }
    }

    component WaveSlider: Rectangle {
        id: ws
        property string title: ""
        property real value: 0.0
        property bool isOscillating: false
        signal sliderMoved(real val)

        Layout.fillWidth: true
        height: 76
        color: root.itemBg
        border.width: 1
        border.color: wsMouse.containsMouse ? root.primary : root.itemBorder

        Behavior on border.color { ColorAnimation { duration: 120 } }

        // Top Specular Highlight Rim
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#ffffff"
            opacity: wsMouse.containsMouse ? 0.85 : 0.3
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        function getWaveY(xPx, h) {
            if (isOscillating) return h / 2 + Math.sin(xPx * 0.035) * 12 + Math.cos(xPx * 0.07) * 4;
            return h / 2 + Math.sin(xPx * 0.025 + 0.5) * 14;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text { text: ws.title; color: root.fg; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { text: Math.round(ws.value * 100) + "%"; color: root.secondary; font.family: root.hudFont; font.pixelSize: 10; font.bold: true }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Canvas {
                    anchors.fill: parent
                    renderTarget: Canvas.Image
                    renderStrategy: Canvas.Immediate

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        ctx.beginPath();
                        ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, ws.isOscillating ? 0.15 : 0.2);
                        ctx.lineWidth = 1;
                        for (var x = 0; x <= width; x += 2) {
                            var gy = height / 2 + Math.sin(x * (ws.isOscillating ? 0.04 : 0.03)) * (ws.isOscillating ? 4 : 6);
                            if (x === 0) ctx.moveTo(x, gy); else ctx.lineTo(x, gy);
                        }
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.strokeStyle = root.primary;
                        ctx.lineWidth = 2;
                        for (var x2 = 0; x2 <= width; x2 += 2) {
                            var my = ws.getWaveY(x2, height);
                            if (x2 === 0) ctx.moveTo(x2, my); else ctx.lineTo(x2, my);
                        }
                        ctx.stroke();
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                Item {
                    x: Math.max(0, Math.min(parent.width - 12, parent.width * ws.value - 6))
                    y: ws.getWaveY(parent.width * ws.value, parent.height) - 6
                    width: 12
                    height: 12

                    Behavior on x { enabled: !wsMouse.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !wsMouse.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12; radius: 6
                        color: "transparent"; border.width: 2; border.color: root.accent
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 4; height: 4; radius: 2
                        color: root.secondary
                    }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => ws.sliderMoved(mouse.x / width)
                    onPositionChanged: mouse => { if (pressed) ws.sliderMoved(mouse.x / width); }
                }
            }
        }
    }

    // ============================================================
    // MPRIS MEDIA PLAYER BACKEND
    // ============================================================
    readonly property var activePlayer: {
        var p = Mpris.players.values;
        return (p && p.length > 0) ? (p.find(function(x) { return x.isPlaying; }) || p[0]) : null;
    }

    readonly property bool hasMedia: activePlayer !== null && activePlayer.trackTitle !== undefined && activePlayer.trackTitle.length > 0
    readonly property string currentTitle: hasMedia ? activePlayer.trackTitle : "UNKNOWN TITLE"
    readonly property string currentArtist: hasMedia ? (Array.isArray(activePlayer.trackArtists) ? activePlayer.trackArtists.join(", ") : (activePlayer.trackArtists ? activePlayer.trackArtists.toString() : "UNKNOWN ARTIST")) : "UNKNOWN ARTIST // " + NervSettings.hudBranding
    readonly property string currentAlbum: hasMedia ? (activePlayer.trackAlbum || "STANDBY") : "NO MEDIA DETECTED"
    readonly property string currentArtUrl: hasMedia ? (activePlayer.artUrl || "") : ""
    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false

    // ============================================================
    // EVATUBE MEDIA EXTRACTION BACKEND
    // ============================================================
    property string evatubeUrl: ""
    property string evatubeMode: "mp3" // "mp3" or "mp4"
    property string evatubeQuality: "best" // "best", "1080p", "720p", "4k"
    property bool evatubeEmbedThumb: true
    property bool evatubeLoading: false
    property string evatubeStatus: "READY"
    property var evatubeInfo: null

    Process {
        id: evatubeInfoProcess
        command: [Quickshell.configPath("scripts/evatube_bridge.py"), "info", root.evatubeUrl]
        stdout: StdioCollector {
            onStreamFinished: {
                root.evatubeLoading = false;
                try {
                    var data = JSON.parse(text.trim());
                    if (data.error) {
                        root.evatubeStatus = "ERROR: " + data.error;
                        root.evatubeInfo = null;
                    } else {
                        root.evatubeInfo = data;
                        root.evatubeStatus = "METADATA EXTRACTED";
                    }
                } catch (e) {
                    root.evatubeStatus = "PARSE FAILED";
                    root.evatubeInfo = null;
                }
            }
        }
    }

    Process {
        id: evatubeDlProcess
        command: [Quickshell.configPath("scripts/evatube_bridge.py"), "download", root.evatubeUrl, root.evatubeMode, root.evatubeQuality, root.evatubeEmbedThumb ? "true" : "false"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.evatubeLoading = false;
                try {
                    var data = JSON.parse(text.trim());
                    if (data.success) {
                        root.evatubeStatus = "EXTRACTION DISPATCHED";
                    } else if (data.error) {
                        root.evatubeStatus = "FAIL: " + data.error;
                    }
                } catch (e) {
                    root.evatubeStatus = "DOWNLOAD INITIALIZED";
                }
            }
        }
    }

    function inspectEvaTube(url) {
        if (!url || url.trim().length === 0) return;
        root.evatubeUrl = url.trim();
        root.evatubeLoading = true;
        root.evatubeStatus = "INSPECTING URL...";
        evatubeInfoProcess.command = [Quickshell.configPath("scripts/evatube_bridge.py"), "info", root.evatubeUrl];
        evatubeInfoProcess.running = true;
    }

    function startEvaTubeDownload() {
        if (!root.evatubeUrl || root.evatubeUrl.trim().length === 0) return;
        root.evatubeLoading = true;
        root.evatubeStatus = "DISPATCHING EXTRACTION...";
        evatubeDlProcess.command = [Quickshell.configPath("scripts/evatube_bridge.py"), "download", root.evatubeUrl.trim(), root.evatubeMode, root.evatubeQuality, root.evatubeEmbedThumb ? "true" : "false"];
        evatubeDlProcess.running = true;
    }

    function launchEvaFile(path) {
        Quickshell.execDetached([Quickshell.configPath("scripts/evacore_bridge.py"), "launch_file", path || (Quickshell.env("HOME") + "/Downloads")]);
    }

    // ============================================================
    // AUDIO BACKEND (WPCTL & PACTL)
    // ============================================================
    property real masterVolume: 0.52
    property real micVolume: 0.94

    Process {
        id: volSetter
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.50"]
    }

    Process {
        id: volGetter
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/Volume:\s+([0-9.]+)/);
                if (m) root.masterVolume = parseFloat(m[1]);
            }
        }
    }

    Process {
        id: micGetter
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/Volume:\s+([0-9.]+)/);
                if (m) root.micVolume = parseFloat(m[1]);
            }
        }
    }

    function setMasterVolume(pct) {
        pct = Math.max(0.0, Math.min(1.0, pct));
        masterVolume = pct;
        volSetter.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct.toFixed(2)];
        volSetter.running = true;
    }

    function setMicVolume(pct) {
        pct = Math.max(0.0, Math.min(1.0, pct));
        micVolume = pct;
        volSetter.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", pct.toFixed(2)];
        volSetter.running = true;
    }

    function getWaveY(type, x, h) {
        if (type === "zigzag") {
            var tri = Math.abs((x % 30) - 15) - 7.5;
            return h / 2 + tri * 0.9;
        } else if (type === "smooth") {
            return h / 2 + Math.sin(x * 0.04) * 4;
        } else if (type === "undulate") {
            return h / 2 + Math.sin(x * 0.03) * 5 + Math.cos(x * 0.06) * 2;
        } else if (type === "plateau") {
            var s = Math.sin(x * 0.04) * 6;
            return h / 2 + Math.max(-4, Math.min(4, s));
        } else {
            return h / 2 + Math.sin(x * 0.05) * 6;
        }
    }

    // Application Streams Backend
    property var appStreams: []

    Process {
        id: streamVolSetter
        command: ["pactl", "set-sink-input-volume", "0", "100%"]
    }

    Process {
        id: streamFetcher
        command: ["pactl", "--format=json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (Array.isArray(parsed)) {
                        var list = [];
                        var waveTypes = ["undulate", "smooth", "zigzag", "plateau", "sine"];
                        for (var i = 0; i < parsed.length; i++) {
                            var item = parsed[i];
                            var appName = (item.properties && (item.properties["application.name"] || item.properties["node.name"] || item.properties["application.process.binary"])) || ("Stream #" + item.index);
                            var volPct = 1.0;
                            if (item.volume && item.volume["front-left"]) {
                                volPct = item.volume["front-left"].value / 65536.0;
                            }
                            list.push({
                                index: item.index,
                                app: appName,
                                pct: Math.min(1.0, Math.max(0.0, volPct)),
                                pctText: Math.round(volPct * 100) + "%",
                                type: waveTypes[i % waveTypes.length]
                            });
                        }
                        root.appStreams = list;
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
            if (!streamFetcher.running) streamFetcher.running = true;
            if (!volGetter.running) volGetter.running = true;
            if (!micGetter.running) micGetter.running = true;
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            if (!streamFetcher.running) streamFetcher.running = true;
            if (!volGetter.running) volGetter.running = true;
            if (!micGetter.running) micGetter.running = true;
        }
    }

    function setStreamVolume(streamIndex, pct) {
        pct = Math.max(0.0, Math.min(1.0, pct));
        var pctInt = Math.round(pct * 100);
        for (var i = 0; i < appStreams.length; i++) {
            if (appStreams[i].index === streamIndex) {
                appStreams[i].pct = pct;
                appStreams[i].pctText = pctInt + "%";
                break;
            }
        }
        streamVolSetter.command = ["pactl", "set-sink-input-volume", streamIndex.toString(), pctInt + "%"];
        streamVolSetter.running = true;
    }

    Component.onCompleted: {
        volGetter.running = true;
        micGetter.running = true;
        streamFetcher.running = true;
    }

    anchors.fill: parent

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ============================================================
        // COLUMN 1: TACTICAL MEDIA DECK & EVATUBE PROTOCOL
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 460
            Layout.minimumWidth: 420
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            // Top Directional Specular Highlight Rim
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#ffffff"
                opacity: 0.7
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ TACTICAL MEDIA DECK // MPRIS & EVATUBE"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 70
                        height: 16
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.isPlaying ? root.secondary : root.itemBorder

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle { width: 4; height: 4; radius: 2; color: root.isPlaying ? root.primary : root.fgDim }
                            Text {
                                text: root.isPlaying ? "PLAYING" : "STANDBY"
                                color: root.isPlaying ? root.secondary : root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }

                // Media Info Card with 2.5D Perspective Tilt & Specular Glare
                Rectangle {
                    id: mediaCard
                    Layout.fillWidth: true
                    implicitHeight: mediaRow.implicitHeight + 16
                    color: root.itemBg
                    border.width: 1
                    border.color: mediaHover.hovered ? root.primary : root.itemBorder

                    scale: mediaHover.hovered ? 1.025 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    transform: [
                        Rotation {
                            id: mediaRotX
                            axis.x: 1; axis.y: 0; axis.z: 0
                            origin.x: mediaCard.width / 2; origin.y: mediaCard.height / 2
                            angle: 0
                            Behavior on angle { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        },
                        Rotation {
                            id: mediaRotY
                            axis.x: 0; axis.y: 1; axis.z: 0
                            origin.x: mediaCard.width / 2; origin.y: mediaCard.height / 2
                            angle: 0
                            Behavior on angle { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        }
                    ]

                    HoverHandler {
                        id: mediaHover
                        onPointChanged: {
                            if (hovered && mediaCard.width > 0 && mediaCard.height > 0) {
                                var nx = (point.position.x / mediaCard.width) - 0.5;
                                var ny = (point.position.y / mediaCard.height) - 0.5;
                                mediaRotY.angle = Math.max(-14.0, Math.min(14.0, nx * 18.0));
                                mediaRotX.angle = Math.max(-14.0, Math.min(14.0, -ny * 18.0));
                            }
                        }
                        onHoveredChanged: {
                            if (!hovered) {
                                mediaRotX.angle = 0;
                                mediaRotY.angle = 0;
                            }
                        }
                    }

                    // Top Specular Highlight Rim
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#ffffff"
                        opacity: mediaHover.hovered ? 0.95 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    RowLayout {
                        id: mediaRow
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // Album Art Box with Z-Parallax
                        Rectangle {
                            width: 54
                            height: 54
                            color: "#ffffff"
                            border.width: 1
                            border.color: root.primary
                            clip: true

                            transform: Translate {
                                x: mediaHover.hovered ? (mediaHover.point.position.x / mediaCard.width - 0.5) * 5 : 0
                                y: mediaHover.hovered ? (mediaHover.point.position.y / mediaCard.height - 0.5) * 5 : 0
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }

                            Image {
                                anchors.fill: parent
                                source: root.currentArtUrl
                                visible: root.currentArtUrl !== ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            Canvas {
                                anchors.fill: parent
                                visible: root.currentArtUrl === ""
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.fillStyle = "#ffffff";
                                    ctx.fillRect(0, 0, width, height);
                                    
                                    // Stylized NERV EVA silhouette
                                    ctx.fillStyle = "#cf2824";
                                    ctx.beginPath();
                                    ctx.arc(27, 20, 11, 0, Math.PI * 2);
                                    ctx.fill();
                                    
                                    ctx.beginPath();
                                    ctx.arc(27, 52, 20, Math.PI, 0);
                                    ctx.fill();
                                    
                                    ctx.fillStyle = "#e32a10";
                                    ctx.fillRect(23, 18, 8, 4);
                                }
                            }
                        }

                        // Track Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: root.currentTitle
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.currentArtist
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.currentAlbum
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Playback Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // PREV
                    Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        color: prevMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) : root.itemBg
                        border.width: 1
                        border.color: prevMouse.containsMouse ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.5)
                        scale: prevMouse.pressed ? 0.96 : (prevMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                        // Top Specular Highlight Rim
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: "#ffffff"
                            opacity: prevMouse.containsMouse ? 0.9 : 0.35
                        }

                        Text { anchors.centerIn: parent; text: "« PREV"; color: root.fg; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canGoPrevious) {
                                    root.activePlayer.previous();
                                }
                            }
                        }
                    }

                    // PLAY / PAUSE
                    Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        color: pauseMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                        border.width: 1
                        border.color: root.primary
                        scale: pauseMouse.pressed ? 0.96 : (pauseMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                        // Top Specular Highlight Rim
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: "#ffffff"
                            opacity: pauseMouse.containsMouse ? 0.95 : 0.4
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "❚❚ PAUSE" : "▶ PLAY"
                            color: root.accent
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                        }

                        MouseArea {
                            id: pauseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer) {
                                    root.activePlayer.playPause();
                                }
                            }
                        }
                    }

                    // NEXT
                    Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        color: nextMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) : root.itemBg
                        border.width: 1
                        border.color: nextMouse.containsMouse ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.5)
                        scale: nextMouse.pressed ? 0.96 : (nextMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                        // Top Specular Highlight Rim
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: "#ffffff"
                            opacity: nextMouse.containsMouse ? 0.9 : 0.35
                        }

                        Text { anchors.centerIn: parent; text: "NEXT »"; color: root.fg; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activePlayer && root.activePlayer.canGoNext) {
                                    root.activePlayer.next();
                                }
                            }
                        }
                    }
                }

                // Equalizer Visualizer Bars
                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 3

                    Repeater {
                        model: 32

                        Rectangle {
                            readonly property var idlePattern: [6, 10, 14, 8, 6, 4, 3, 6, 9, 12, 16, 14, 11, 7, 5, 8, 11, 15, 12, 9, 6, 4, 7, 10, 8, 6, 9, 12, 10, 7, 5, 8]
                            readonly property var playPattern: [14, 24, 30, 20, 16, 12, 8, 16, 22, 28, 34, 32, 26, 18, 14, 20, 26, 32, 28, 22, 16, 12, 18, 24, 28, 32, 26, 20, 16, 12, 18, 22]
                            width: (parent.width - 31 * 3) / 32
                            height: root.isPlaying ? playPattern[index % playPattern.length] : idlePattern[index % idlePattern.length]
                            anchors.bottom: parent.bottom
                            color: root.primary

                            Behavior on height {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                // EVATUBE MEDIA EXTRACTION PROTOCOL Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.itemBg
                    border.width: 1
                    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        // Header with Mode Badges
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "▶ EVATUBE MEDIA EXTRACTION PROTOCOL"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 56
                                height: 16
                                color: "#ffffff"
                                border.width: 1
                                border.color: root.secondary

                                Text {
                                    anchors.centerIn: parent
                                    text: root.evatubeLoading ? "• BUSY" : "• READY"
                                    color: root.evatubeLoading ? root.accent : root.secondary
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }
                        }

                        // URL Input and Inspect Button
                        Rectangle {
                            Layout.fillWidth: true
                            height: 24
                            color: "#ffffff"
                            border.width: 1
                            border.color: root.itemBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 4
                                spacing: 4

                                TextInput {
                                    id: tubeUrlInput
                                    Layout.fillWidth: true
                                    color: root.fg
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    clip: true
                                    selectByMouse: true
                                    text: root.evatubeUrl
                                    onTextChanged: root.evatubeUrl = text
                                    onAccepted: root.inspectEvaTube(text)

                                    Text {
                                        anchors.fill: parent
                                        visible: !tubeUrlInput.text && !tubeUrlInput.activeFocus
                                        text: "INPUT YOUTUBE / SOUNDCLOUD URL >"
                                        color: root.fgDim
                                        font.family: root.hudFont
                                        font.pixelSize: 8
                                    }
                                }

                                Rectangle {
                                    width: 60
                                    height: 16
                                    color: inspectMouse.containsMouse ? root.primary : "#ffffff"
                                    border.width: 1
                                    border.color: root.secondary

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🔍 INSPECT"
                                        color: inspectMouse.containsMouse ? "#ffffff" : root.secondary
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: inspectMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.inspectEvaTube(tubeUrlInput.text)
                                    }
                                }
                            }
                        }

                        // Media Inspection Details Card (Thumbnail + Info)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.4)
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                            clip: true

                            // If no media inspected yet
                            Item {
                                anchors.fill: parent
                                visible: !root.evatubeInfo

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: root.evatubeLoading ? "󰇚 SCANNING MEDIA STREAM..." : "󰎆 AWAITING TARGET URL"
                                        color: root.fgDim
                                        font.family: root.hudFont
                                        font.pixelSize: 8
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "EXTRACTS HIGH-QUALITY AUDIO & VIDEO METADATA"
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                    }
                                }
                            }

                            // If media info is available
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4
                                visible: !!root.evatubeInfo

                                // 16:9 Thumbnail Box
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "#ffffff"
                                    border.width: 1
                                    border.color: root.secondary
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        source: root.evatubeInfo ? root.evatubeInfo.thumbnail : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }

                                    // Extractor Tag (Top Left)
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 4
                                        width: extractorText.implicitWidth + 8
                                        height: 14
                                        color: Qt.rgba(0, 0, 0, 0.75)
                                        border.width: 1
                                        border.color: root.secondary

                                        Text {
                                            id: extractorText
                                            anchors.centerIn: parent
                                            text: root.evatubeInfo ? root.evatubeInfo.extractor.toUpperCase() : ""
                                            color: root.secondary
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            font.bold: true
                                        }
                                    }

                                    // Duration Tag (Bottom Right)
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 4
                                        width: durText.implicitWidth + 8
                                        height: 14
                                        color: Qt.rgba(0, 0, 0, 0.75)
                                        border.width: 1
                                        border.color: root.primary

                                        Text {
                                            id: durText
                                            anchors.centerIn: parent
                                            text: root.evatubeInfo ? root.evatubeInfo.duration : ""
                                            color: root.accent
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            font.bold: true
                                        }
                                    }
                                }

                                // Metadata Details Column
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: root.evatubeInfo ? root.evatubeInfo.title : ""
                                        color: root.accent
                                        font.family: root.hudFont
                                        font.pixelSize: 8
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: root.evatubeInfo ? ("UPLOADER: " + root.evatubeInfo.uploader) : ""
                                        color: root.fgMuted
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        // Format & Options Selector Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Mode Selector Buttons
                            FormatBtn {
                                label: "󰎆 MP3 AUDIO"
                                selected: root.evatubeMode === "mp3"
                                onClicked: root.evatubeMode = "mp3"
                            }

                            FormatBtn {
                                label: "󰕧 MP4 VIDEO"
                                selected: root.evatubeMode === "mp4"
                                onClicked: root.evatubeMode = "mp4"
                            }


                            // Embed Thumbnail Checkbox Button
                            Rectangle {
                                width: 78
                                height: 20
                                color: root.evatubeEmbedThumb ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.evatubeEmbedThumb ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.evatubeEmbedThumb ? "✓ EMBED ART" : "✕ EMBED ART"
                                    color: root.evatubeEmbedThumb ? "#ffffff" : root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.evatubeEmbedThumb = !root.evatubeEmbedThumb
                                }
                            }
                        }

                        // Bottom Download Action Button & Status
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Trigger Download Button
                            Rectangle {
                                Layout.fillWidth: true
                                height: 22
                                color: dlMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "󰇚"
                                        color: dlMouse.containsMouse ? "#ffffff" : root.secondary
                                        font.pixelSize: 9
                                    }

                                    Text {
                                        text: "INITIALIZE EXTRACTION"
                                        color: dlMouse.containsMouse ? "#ffffff" : root.secondary
                                        font.family: root.hudFont
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }
                                }

                                MouseArea {
                                    id: dlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.startEvaTubeDownload()
                                }
                            }

                            // Open in EvaFile Button
                            Rectangle {
                                width: 28
                                height: 22
                                color: efTubeMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰝰"
                                    color: efTubeMouse.containsMouse ? "#ffffff" : root.secondary
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: efTubeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launchEvaFile("~/Downloads")
                                }
                            }

                            // Status Tag
                            Rectangle {
                                width: 90
                                height: 22
                                color: "#ffffff"
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.evatubeStatus
                                    color: root.secondary
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width - 6
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // ============================================================
        // COLUMN 2: PIPEWIRE AUDIO MIXER & APPLICATION STREAMS
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            // Top Directional Specular Highlight Rim
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#ffffff"
                opacity: 0.7
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "▶ PIPEWIRE AUDIO MIXER // HARDWARE & APPLICATION STREAMS"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.5
                }

                // 1. Master Output Sink Card
                WaveSlider {
                    title: "MASTER OUTPUT SINK (SPEAKERS / HEADPHONES)"
                    value: root.masterVolume
                    isOscillating: false
                    onSliderMoved: val => root.setMasterVolume(val)
                }

                // 2. Microphone Input Card
                WaveSlider {
                    title: "MICROPHONE INPUT SOURCE"
                    value: root.micVolume
                    isOscillating: true
                    onSliderMoved: val => root.setMicVolume(val)
                }


                // 3. Active Application Streams Header
                Text {
                    text: "ACTIVE APPLICATION AUDIO STREAMS:"
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                }

                // 4. Stream Items
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: streamsColumn.implicitHeight

                    ColumnLayout {
                        id: streamsColumn
                        width: parent.width
                        spacing: 5

                        Text {
                            visible: root.appStreams.length === 0
                            text: "[ NO ACTIVE APPLICATION AUDIO STREAMS ]"
                            color: root.fgDim
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Repeater {
                            model: root.appStreams

                            Rectangle {
                                Layout.fillWidth: true
                                height: 34
                                color: root.itemBg
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: modelData.app
                                        color: root.fg
                                        font.family: root.hudFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        Layout.preferredWidth: 120
                                        elide: Text.ElideRight
                                    }

                                    // Stream Waveform Canvas
                                    Item {
                                        id: streamSliderArea
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        Canvas {
                                            anchors.fill: parent
                                            renderTarget: Canvas.Image
                                            renderStrategy: Canvas.Immediate

                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);
                                                ctx.beginPath();
                                                ctx.strokeStyle = root.primary;
                                                ctx.lineWidth = 1.8;

                                                var type = modelData.type;
                                                for (var x = 0; x <= width; x += 2) {
                                                    var y = height / 2;
                                                    if (type === "zigzag") {
                                                        var tri = Math.abs((x % 30) - 15) - 7.5;
                                                        y = height / 2 + tri * 0.9;
                                                    } else if (type === "smooth") {
                                                        y = height / 2 + Math.sin(x * 0.04) * 4;
                                                    } else if (type === "undulate") {
                                                        y = height / 2 + Math.sin(x * 0.03) * 5 + Math.cos(x * 0.06) * 2;
                                                    } else if (type === "plateau") {
                                                        var s = Math.sin(x * 0.04) * 6;
                                                        y = height / 2 + Math.max(-4, Math.min(4, s));
                                                    } else {
                                                        y = height / 2 + Math.sin(x * 0.05) * 6;
                                                    }

                                                    if (x === 0) ctx.moveTo(x, y);
                                                    else ctx.lineTo(x, y);
                                                }
                                                ctx.stroke();
                                            }
                                            onWidthChanged: requestPaint()
                                            onHeightChanged: requestPaint()
                                        }

                                        // Knob Handle
                                        Item {
                                            readonly property real knobTargetX: Math.max(0, Math.min(parent.width - 12, parent.width * modelData.pct - 6))
                                            readonly property real knobTargetY: root.getWaveY(modelData.type, parent.width * modelData.pct, parent.height) - 6
                                            x: knobTargetX
                                            y: knobTargetY
                                            width: 12
                                            height: 12

                                            Behavior on x {
                                                enabled: !streamMouse.pressed
                                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                            }
                                            Behavior on y {
                                                enabled: !streamMouse.pressed
                                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 10
                                                height: 10
                                                radius: 5
                                                color: "transparent"
                                                border.width: 1.5
                                                border.color: root.accent
                                            }

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 3
                                                height: 3
                                                radius: 1.5
                                                color: root.secondary
                                            }
                                        }

                                        MouseArea {
                                            id: streamMouse
                                            anchors.fill: parent
                                            cursorShape: modelData.index >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: mouse => {
                                                if (modelData.index >= 0) {
                                                    root.setStreamVolume(modelData.index, mouse.x / width);
                                                }
                                            }
                                            onPositionChanged: mouse => {
                                                if (pressed && modelData.index >= 0) {
                                                    root.setStreamVolume(modelData.index, mouse.x / width);
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: modelData.pctText
                                        color: root.secondary
                                        font.family: root.hudFont
                                        font.pixelSize: 9
                                        font.bold: true
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
