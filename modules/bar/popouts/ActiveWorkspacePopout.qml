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
    readonly property color panelBg: "#ffffff"
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property color textMain: "#1a0000"
    readonly property color textMuted: Qt.rgba(0.1, 0.0, 0.0, 0.65)
    readonly property color textDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Target Workspace State
    property int targetWorkspaceId: 1
    readonly property var kanjiNumerals: ["壱", "弐", "参", "肆", "伍", "陸", "漆", "捌"]
    readonly property string targetKanji: (targetWorkspaceId >= 1 && targetWorkspaceId <= 8) ? kanjiNumerals[targetWorkspaceId - 1] : "壱"

    // Telemetry State
    property var allClients: []
    property var workspaceClients: []
    property real monitorWidth: 1366
    property real monitorHeight: 768
    property int activeMonitorWs: 1

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }

    margins {
        top: 46
        left: (root.screen ? Math.max(20, Math.round((root.screen.width - 1280) / 2) + 76) : 119)
    }

    readonly property real cardHeight: 520
    implicitWidth: 420
    implicitHeight: Math.round(root.cardHeight * 1.06)

    mask: Region {
        item: popoutContainer
    }

    color: "transparent"
    visible: false

    property real snapshotVersion: Date.now()
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

    function openForWorkspace(wsId) {
        if (wsId >= 1 && wsId <= 8) {
            root.targetWorkspaceId = wsId;
        }
        root.snapshotVersion = Date.now();
        root.open();
    }

    function toggle() {
        if (!root.isOpen) root.open();
        else root.close();
    }

    function open() {
        if (typeof nervLauncher !== "undefined" && nervLauncher && nervLauncher.visible) {
            nervLauncher.close();
        }
        root.isOpen = true;
        root.snapshotVersion = Date.now();
        root.visible = true;
        root.beamOpacity = 1.0;
        root.refresh();
        openProgressAnim.from = root.revealProgress;
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        if (!root.visible || !root.isOpen) {
            root.isOpen = false;
            root.visible = false;
            return;
        }
        root.isOpen = false;
        root.beamOpacity = 1.0;
        closeProgressAnim.from = root.revealProgress;
        openAnim.stop();
        closeAnim.restart();
    }

    function triggerSnapshot() {
        Quickshell.execDetached([Quickshell.configPath("scripts/nerv_workspace_clients.py"), "--snapshot", "" + root.targetWorkspaceId]);
        snapshotDelayTimer.restart();
    }

    Timer {
        id: snapshotDelayTimer
        interval: 180
        repeat: false
        onTriggered: {
            root.snapshotVersion = Date.now();
        }
    }

    function refresh() {
        clientsProcess.running = true;
    }

    function focusWindow(address) {
        if (!address) return;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + address + "' })"]);
        root.close();
    }

    function closeWindow(address) {
        if (!address) return;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ window = 'address:" + address + "' })"]);
        refreshTimer.restart();
    }

    function switchToWorkspace(wsId) {
        if (wsId < 1 || wsId > 8) return;
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsId + " })"]);
        root.close();
    }

    function getAppIcon(className) {
        var c = (className || "").toLowerCase();
        if (c.indexOf("firefox") !== -1 || c.indexOf("browser") !== -1 || c.indexOf("zen") !== -1) return "󰈹";
        if (c.indexOf("term") !== -1 || c.indexOf("kitty") !== -1 || c.indexOf("alacritty") !== -1) return "󰞷";
        if (c.indexOf("code") !== -1 || c.indexOf("nvim") !== -1 || c.indexOf("dev") !== -1) return "󰨞";
        if (c.indexOf("discord") !== -1 || c.indexOf("vesktop") !== -1 || c.indexOf("chat") !== -1) return "󰍡";
        if (c.indexOf("file") !== -1 || c.indexOf("thunar") !== -1 || c.indexOf("nautilus") !== -1) return "󰉋";
        if (c.indexOf("music") !== -1 || c.indexOf("spotify") !== -1) return "󰓇";
        if (c.indexOf("image") !== -1 || c.indexOf("gimp") !== -1 || c.indexOf("inkscape") !== -1) return "󰋩";
        return "󰆍";
    }

    function filterClients() {
        var filtered = [];
        for (var i = 0; i < root.allClients.length; i++) {
            var cl = root.allClients[i];
            if (cl.ws === root.targetWorkspaceId) {
                filtered.push(cl);
            }
        }
        root.workspaceClients = filtered;
    }

    onTargetWorkspaceIdChanged: filterClients()

    onVisibleChanged: {
        if (root.visible) {
            root.refresh();
            popoutContainer.forceActiveFocus();
        }
    }

    Timer {
        id: refreshTimer
        interval: 180
        repeat: false
        onTriggered: root.refresh()
    }

    // Telemetry Poller Process
    Process {
        id: clientsProcess
        command: [Quickshell.configPath("scripts/nerv_workspace_clients.py")]

        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data);
                    if (parsed.monitor) {
                        root.monitorWidth = parsed.monitor.width || 1366;
                        root.monitorHeight = parsed.monitor.height || 768;
                        root.activeMonitorWs = parsed.monitor.activeWs || 1;
                    }
                    if (parsed.clients) {
                        root.allClients = parsed.clients;
                        root.filterClients();
                    }
                } catch (e) {
                    console.log("Error parsing workspace telemetry:", e);
                }
            }
        }
    }

    // ============================================================
    // MAIN POPOUT CARD CONTAINER
    // ============================================================
    Item {
        id: popoutContainer
        width: parent.width
        height: Math.round(root.revealProgress * root.cardHeight)
        clip: true

        // Keyboard navigation
        Keys.onEscapePressed: root.close()

        // Background Outer Card with 2.5D Perspective Tilt
        Rectangle {
            id: cardRect
            width: parent.width
            height: root.cardHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            property real normX: 0.0
            property real normY: 0.0

            transform: [
                Scale {
                    origin.x: cardRect.width / 2
                    origin.y: 0
                    yScale: Math.max(1.0, root.revealProgress)
                },
                Rotation {
                    origin.x: cardRect.width / 2; origin.y: cardRect.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: cardRect.normX * 14.0
                    Behavior on angle { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                },
                Rotation {
                    origin.x: cardRect.width / 2; origin.y: cardRect.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: -cardRect.normY * 14.0
                    Behavior on angle { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                }
            ]

            color: root.panelBg
            border.width: 1.5
            border.color: root.primary

            // Directional 1px Overhead Specular Highlight Rim
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.70)
                z: 4
            }

            // Dynamic Roving Specular Glare
            Item {
                anchors.fill: parent
                clip: true
                z: 2
                opacity: cardHover.hovered ? 0.30 : 0.0
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: parent.width * 1.4
                    height: parent.height * 1.4
                    x: (parent.width - width) / 2 + (cardRect.normX * parent.width * 0.3)
                    y: (parent.height - height) / 2 + (cardRect.normY * parent.height * 0.3)
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.45) }
                        GradientStop { position: 0.45; color: Qt.rgba(1.0, 1.0, 1.0, 0.05) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            HoverHandler {
                id: cardHover
                onPointChanged: {
                    if (hovered && cardRect.width > 0 && cardRect.height > 0) {
                        cardRect.normX = Math.max(-1.0, Math.min(1.0, (point.position.x - cardRect.width / 2) / (cardRect.width / 2)));
                        cardRect.normY = Math.max(-1.0, Math.min(1.0, (point.position.y - cardRect.height / 2) / (cardRect.height / 2)));
                    }
                }
                onHoveredChanged: {
                    if (!hovered) {
                        cardRect.normX = 0.0;
                        cardRect.normY = 0.0;
                    }
                }
            }

            // Inner Accent Glow
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                z: 5

                // 1. TOP HEADER (Sector Kanji, ID, Close Button)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 4
                        height: 18
                        color: root.primary
                    }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 6
                            Text {
                                text: NervSettings.hudBranding + " // WORKSPACE RECON"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1.2
                            }

                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 14
                                color: (root.targetWorkspaceId === root.activeMonitorWs) ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                                border.width: 1
                                border.color: root.primary

                                Text {
                                    anchors.centerIn: parent
                                    text: root.targetKanji
                                    color: (root.targetWorkspaceId === root.activeMonitorWs) ? "#ffffff" : root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }

                        Text {
                            text: "SECTOR " + root.targetKanji + " [" + root.targetWorkspaceId + "] • " + root.workspaceClients.length + " ACTIVE SIGNAL" + (root.workspaceClients.length === 1 ? "" : "S")
                            color: root.textDim
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }

                    // Quick Close Button
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        color: closeMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        border.width: 1
                        border.color: root.primary

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 10
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

                // 2. MINI-DESKTOP VIEWPORT ("What it looks like")
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "TACTICAL VIEWPORT // LIVE TOPOLOGY"
                            color: root.textDim
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.monitorWidth + "x" + root.monitorHeight
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }

                    // Scaled Monitor Stage (16:9 Aspect Frame)
                    Rectangle {
                        id: miniMapStage
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03)
                        border.width: 1.5
                        border.color: root.primary
                        clip: true

                        // 1. ACTUAL LIVE SCREENSHOT OF WORKSPACE
                        Image {
                            id: realPreviewImage
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: "file:///dev/shm/quickshell_evangelion/ws_" + root.targetWorkspaceId + ".jpg?v=" + root.snapshotVersion
                            cache: false
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                        }

                        // Coordinate Crosshairs & Grid Lines
                        Canvas {
                            anchors.fill: parent
                            renderTarget: Canvas.Image
                            renderStrategy: Canvas.Immediate
                            opacity: realPreviewImage.visible ? 0.15 : 1.0

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.08);
                                ctx.lineWidth = 1;

                                // Sub-grid
                                for (var x = 20; x < width; x += 20) {
                                    ctx.beginPath();
                                    ctx.moveTo(x, 0);
                                    ctx.lineTo(x, height);
                                    ctx.stroke();
                                }
                                for (var y = 20; y < height; y += 20) {
                                    ctx.beginPath();
                                    ctx.moveTo(0, y);
                                    ctx.lineTo(width, y);
                                    ctx.stroke();
                                }

                                // Center Crosshair
                                ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.20);
                                ctx.beginPath();
                                ctx.moveTo(width / 2, 0);
                                ctx.lineTo(width / 2, height);
                                ctx.moveTo(0, height / 2);
                                ctx.lineTo(width, height / 2);
                                ctx.stroke();
                            }
                        }

                        // Status Tag (OPTICAL FEED or TOPOLOGY)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: realPreviewImage.visible ? 80 : 70
                            height: 16
                            color: Qt.rgba(0.0, 0.0, 0.0, 0.70)
                            border.width: 1
                            border.color: root.primary
                            z: 10

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    text: realPreviewImage.visible ? "󰄬" : "󰑓"
                                    color: root.primary
                                    font.pixelSize: 8
                                }
                                Text {
                                    text: realPreviewImage.visible ? "OPTICAL FEED" : "TOPOLOGY"
                                    color: "#ffffff"
                                    font.family: root.hudFont
                                    font.pixelSize: 6
                                    font.bold: true
                                }
                            }
                        }

                        // Rendered Window Blocks (Scaled Coordinates)
                        Repeater {
                            model: root.workspaceClients

                            Rectangle {
                                id: winBlock
                                readonly property var cl: modelData
                                readonly property real scaleX: miniMapStage.width / Math.max(1, root.monitorWidth)
                                readonly property real scaleY: miniMapStage.height / Math.max(1, root.monitorHeight)

                                x: Math.max(2, Math.min(miniMapStage.width - width - 2, cl.at[0] * scaleX))
                                y: Math.max(2, Math.min(miniMapStage.height - height - 2, cl.at[1] * scaleY))
                                width: Math.max(34, Math.min(miniMapStage.width - 4, cl.size[0] * scaleX))
                                height: Math.max(22, Math.min(miniMapStage.height - 4, cl.size[1] * scaleY))

                                color: realPreviewImage.visible ?
                                       (winHover.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18) : (cl.focused ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "transparent")) :
                                       (cl.focused ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.24) :
                                       (winHover.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.09)))
                                border.width: cl.focused ? 2 : 1
                                border.color: cl.focused ? root.primary : (realPreviewImage.visible ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50) : root.primary)

                                Behavior on color { ColorAnimation { duration: 100 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    width: parent.width - 4

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 3
                                        Text {
                                            text: root.getAppIcon(cl.class)
                                            color: root.primary
                                            font.pixelSize: 9
                                        }
                                        Text {
                                            text: (cl.class || "WINDOW").toUpperCase()
                                            color: root.primary
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: winBlock.width - 16
                                        }
                                    }

                                    Text {
                                        text: cl.title || ""
                                        color: root.textDim
                                        font.family: root.hudFont
                                        font.pixelSize: 6
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.maximumWidth: winBlock.width - 6
                                        visible: winBlock.height >= 32
                                    }
                                }

                                MouseArea {
                                    id: winHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.focusWindow(cl.address)
                                }
                            }
                        }

                        // Inert Sector Overlay when Empty
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: root.workspaceClients.length === 0

                            Text {
                                text: "󰮇"
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
                                font.pixelSize: 22
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "// NO SIGNALS IN SECTOR // INERT WORKSPACE"
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50)
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 1.0
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        // Corner Tactical Ticks
                        Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 6; height: 6; color: root.primary }
                        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 6; height: 6; color: root.primary }
                        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 6; height: 6; color: root.primary }
                        Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 6; height: 6; color: root.primary }
                    }
                }

                // 3. RUNNING PROCESS & WINDOW INSPECTOR ("What is running")
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    Text {
                        text: "DETECTED APPLICATIONS & PROCESSES (" + root.workspaceClients.length + ")"
                        color: root.textDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.itemBorder

                        ListView {
                            id: processList
                            anchors.fill: parent
                            anchors.margins: 4
                            clip: true
                            spacing: 4
                            model: root.workspaceClients

                            delegate: Rectangle {
                                id: clientCard
                                width: processList.width
                                height: 42
                                color: itemHover.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10) :
                                       (modelData.focused ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05) : "transparent")
                                border.width: 1
                                border.color: modelData.focused ? root.primary : (itemHover.containsMouse ? "#ff2222" : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20))

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                // Orchestrated Staggered Cascade
                                opacity: 0.0
                                transform: Translate { id: transY; y: 12 }
                                Component.onCompleted: clientCascadeAnim.start()

                                SequentialAnimation {
                                    id: clientCascadeAnim
                                    PauseAnimation { duration: Math.min(index * 30, 240) }
                                    ParallelAnimation {
                                        NumberAnimation { target: clientCard; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: transY; property: "y"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                                    }
                                }

                                // Tactile Spring Scale
                                scale: itemHover.containsMouse ? 1.015 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                                }

                                // Directional Specular Lip
                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.leftMargin: 2; anchors.rightMargin: 2
                                    height: 1
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
                                    visible: modelData.focused || itemHover.containsMouse
                                }

                                MouseArea {
                                    id: itemHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.focusWindow(modelData.address)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    // Class Badge
                                    Rectangle {
                                        Layout.preferredWidth: 26
                                        Layout.preferredHeight: 26
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                                        border.width: 1
                                        border.color: root.primary

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.getAppIcon(modelData.class)
                                            color: root.primary
                                            font.pixelSize: 13
                                        }
                                    }

                                    // Window Title & Process Info
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        RowLayout {
                                            spacing: 6
                                            Text {
                                                text: (modelData.class || "WINDOW").toUpperCase()
                                                color: root.primary
                                                font.family: root.hudFont
                                                font.pixelSize: 8
                                                font.bold: true
                                            }

                                            Text {
                                                text: "PID: " + modelData.pid
                                                color: root.textDim
                                                font.family: root.hudFont
                                                font.pixelSize: 7
                                                font.bold: true
                                            }

                                            Item { Layout.fillWidth: true }
                                        }

                                        Text {
                                            text: modelData.title || "Untitled"
                                            color: root.textMain
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Action Controls (Focus / Close)
                                    RowLayout {
                                        spacing: 4

                                        // Focus Window Button
                                        Rectangle {
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 22
                                            color: focusMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                            border.width: 1
                                            border.color: root.primary

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 2
                                                Text { text: "󰆍"; color: focusMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 8 }
                                                Text { text: "FOCUS"; color: focusMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                            }

                                            MouseArea {
                                                id: focusMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.focusWindow(modelData.address)
                                            }
                                        }

                                        // Close Window Button
                                        Rectangle {
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            color: closeWinMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                            border.width: 1
                                            border.color: root.primary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: closeWinMouse.containsMouse ? "#ffffff" : root.primary
                                                font.pixelSize: 9
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: closeWinMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.closeWindow(modelData.address)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Empty List Message
                        Text {
                            anchors.centerIn: parent
                            text: "NO PROCESSES RUNNING"
                            color: root.textDim
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            visible: root.workspaceClients.length === 0
                        }
                    }
                }

                // 4. BOTTOM ACTION DECK
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 28
                    Layout.minimumHeight: 28
                    Layout.maximumHeight: 28
                    spacing: 6

                    // Switch to Workspace Button
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 28
                        color: jumpMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                        border.width: 1.5
                        border.color: root.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰌑"
                                color: jumpMouse.containsMouse ? "#ffffff" : root.primary
                                font.pixelSize: 11
                            }
                            Text {
                                text: "SWITCH TO WORKSPACE " + root.targetKanji + " [" + root.targetWorkspaceId + "]"
                                color: jumpMouse.containsMouse ? "#ffffff" : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1.0
                            }
                        }

                        MouseArea {
                            id: jumpMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchToWorkspace(root.targetWorkspaceId)
                        }
                    }

                    // Rescan Button
                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.fillHeight: false
                        Layout.preferredHeight: 28
                        color: rescanMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        border.width: 1
                        border.color: root.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰑓"
                                color: rescanMouse.containsMouse ? "#ffffff" : root.primary
                                font.pixelSize: 10
                            }
                            Text {
                                text: "RESCAN"
                                color: rescanMouse.containsMouse ? "#ffffff" : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: rescanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refresh()
                        }
                    }
                }
            }

            // Outer Corner Tactical Brackets
            Repeater {
                model: 4
                Rectangle {
                    anchors.top: index < 2 ? parent.top : undefined
                    anchors.bottom: index >= 2 ? parent.bottom : undefined
                    anchors.left: (index % 2 === 0) ? parent.left : undefined
                    anchors.right: (index % 2 === 1) ? parent.right : undefined
                    width: 10; height: 10; color: root.primary
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

