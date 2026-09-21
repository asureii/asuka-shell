import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../../components"

PanelWindow {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color fg: "#cc0000"
    readonly property color fgMuted: Qt.rgba(0.8, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.8, 0.0, 0.0, 0.50)
    readonly property color bg: "#ffffff"
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.45)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"
    readonly property string monoFont: "JetBrainsMono Nerd Font, Liberation Sans, monospace"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.isFocused && (root.revealed || root.pinned)) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
    }

    margins {
        bottom: 0
    }

    readonly property real fullHeight: 42
    readonly property real wingHeight: 34

    // ============================================================
    // STATE & AUTO-HIDE
    // ============================================================
    property bool revealed: false
    property bool pinned: false
    property bool isAnimating: false
    property bool isFocused: false
    property bool isExecuting: false
    property string statusText: ""
    property bool statusIsError: false

    // Ollama / Model State
    property bool qwenOnline: false
    property string qwenModelName: "qwen2.5:0.5b"
    property bool hasModelLoaded: false

    // History Buffer
    property var commandHistory: []
    property int historyIndex: -1

    implicitWidth: 1280
    implicitHeight: (root.revealed || root.pinned || root.isAnimating) ? root.fullHeight : 2
    color: "transparent"

    // ============================================================
    // OLLAMA STATUS CHECK PROCESS
    // ============================================================
    Process {
        id: statusProcess
        command: ["python3", Quickshell.configPath("scripts/qwen_bridge.py"), "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    root.qwenOnline = !!data.online;
                    if (data.model) root.qwenModelName = data.model;
                    root.hasModelLoaded = !!data.has_model;
                } catch (e) {
                    root.qwenOnline = false;
                }
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProcess.running = true
    }

    // ============================================================
    // COMMAND EXECUTION PROCESS
    // ============================================================
    property string pendingCommand: ""

    Process {
        id: execProcess
        command: ["python3", Quickshell.configPath("scripts/qwen_bridge.py"), "--exec", root.pendingCommand]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isExecuting = false;
                try {
                    var data = JSON.parse(text.trim());
                    root.statusIsError = !data.success;
                    root.statusText = data.message || (data.success ? "Command executed" : "Error executing command");

                    // Handle internal IPC actions requested by bridge
                    if (data.action === "ipc" && data.target && data.call) {
                        handleIpcAction(data.target, data.call);
                    } else if (data.action === "cmd" && data.cmd) {
                        Quickshell.execDetached(data.cmd);
                    }
                } catch (e) {
                    root.statusIsError = false;
                    root.statusText = text.trim() || "Executed";
                }
                statusClearTimer.restart();
                if (!root.pinned && !bottomHoverArea.containsMouse) {
                    postExecAutoHideTimer.restart();
                }
            }
        }
    }

    Timer {
        id: statusClearTimer
        interval: 4500
        repeat: false
        onTriggered: {
            root.statusText = "";
            root.statusIsError = false;
        }
    }

    Timer {
        id: hideDebounceTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!bottomHoverArea.containsMouse && !root.pinned) {
                cmdInput.focus = false;
                root.isFocused = false;
                root.revealed = false;
            }
        }
    }

    Timer {
        id: idleAutoHideTimer
        interval: 6000
        repeat: false
        onTriggered: {
            if (!bottomHoverArea.containsMouse && !root.pinned && !root.isExecuting) {
                cmdInput.focus = false;
                root.isFocused = false;
                root.revealed = false;
            }
        }
    }

    Timer {
        id: postExecAutoHideTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (!root.pinned && !bottomHoverArea.containsMouse) {
                cmdInput.focus = false;
                root.isFocused = false;
                root.revealed = false;
            }
        }
    }

    function handleIpcAction(target, call) {
        if (target === "vitals" && typeof vitalsPopout !== "undefined") vitalsPopout.toggle();
        else if (target === "controlcenter" && typeof controlCenter !== "undefined") controlCenter.toggle();
        else if (target === "launcher" && typeof nervLauncher !== "undefined") nervLauncher.toggle();
        else if (target === "lockscreen" && typeof lockScreen !== "undefined") lockScreen.lock();
        else if (target === "audiobri" && typeof audioBriPopout !== "undefined") audioBriPopout.toggle();
        else if (target === "network" && typeof networkPopout !== "undefined") networkPopout.toggle();
        else if (target === "areapicker" && typeof areaPicker !== "undefined") {
            if (call === "openClip") areaPicker.openClip();
            else areaPicker.open();
        } else if (target === "background" && typeof background !== "undefined") {
            background.openFileDialog();
        } else if (target === "workspace_preview" && typeof activeWorkspacePopout !== "undefined") {
            activeWorkspacePopout.toggle();
        }
    }

    function executeCommand(query) {
        var q = query.trim();
        if (!q) return;

        // Push to history
        if (root.commandHistory.length === 0 || root.commandHistory[root.commandHistory.length - 1] !== q) {
            root.commandHistory.push(q);
        }
        root.historyIndex = -1;

        // Quick internal direct command intercept
        var lower = q.toLowerCase();
        if (lower === "clear" || lower === "cls") {
            cmdInput.text = "";
            root.statusText = "";
            return;
        }
        if (lower === "exit" || lower === "quit" || lower === "close") {
            cmdInput.text = "";
            cmdInput.focus = false;
            root.isFocused = false;
            root.revealed = false;
            return;
        }

        root.isExecuting = true;
        root.statusText = "PROCESSING // QWEN 2.5...";
        root.statusIsError = false;
        root.pendingCommand = q;
        cmdInput.text = "";
        cmdInput.focus = false;
        root.isFocused = false;
        execProcess.running = true;
    }

    function toggle() {
        if (root.revealed || root.pinned) {
            root.revealed = false;
            root.pinned = false;
            root.isFocused = false;
            cmdInput.focus = false;
        } else {
            root.revealed = true;
            focusInput();
        }
    }

    function open() {
        root.revealed = true;
        focusInput();
    }

    function close() {
        root.revealed = false;
        root.pinned = false;
        root.isFocused = false;
        cmdInput.focus = false;
    }

    function focusInput() {
        root.revealed = true;
        root.isFocused = true;
        cmdInput.forceActiveFocus();
        idleAutoHideTimer.restart();
    }

    // ============================================================
    // HOVER DETECTION & MAIN HUD BAR CONTAINER
    // ============================================================
    MouseArea {
        id: bottomHoverArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: (root.revealed || root.pinned || root.isAnimating) ? root.fullHeight : 4
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        clip: true

        onEntered: {
            hideDebounceTimer.stop();
            postExecAutoHideTimer.stop();
            root.revealed = true;
        }

        onExited: {
            if (!root.pinned) {
                hideDebounceTimer.restart();
            }
        }

        Item {
            id: barContainer
            width: parent.width
            height: root.fullHeight
            y: (root.revealed || root.pinned) ? 0 : (root.fullHeight - 2)
            opacity: (root.revealed || root.pinned) ? 1.0 : 0.0

            Behavior on y {
                SequentialAnimation {
                    ScriptAction { script: root.isAnimating = true }
                    NumberAnimation {
                        duration: (root.revealed || root.pinned) ? 220 : 160
                        easing.type: (root.revealed || root.pinned) ? Easing.OutCubic : Easing.InQuad
                    }
                    ScriptAction { script: root.isAnimating = false }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Polygonal NERV HUD Vector Background (Inverted geometry matching top bar)
            BottomBarBackground {
                id: bottomBg
                anchors.fill: parent
                fillColor: root.bg
                hexFillColor: root.primary
                hexBorderColor: "#ffffff"
                strokeColor: root.primary
                accentColor: root.accent
                strokeWidth: 1.5
                wingHeight: root.wingHeight
                leftChamferWidth: 34
                rightChamferWidth: 34
                centerTopWidth: 560
                centerMidWidth: 620
            }

            // Directional 1px Bottom Highlight Line
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: bottomBg.leftChamferWidth
                anchors.rightMargin: bottomBg.rightChamferWidth
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.55)
                z: 10
            }

            // ============================================================
            // LEFT WING (NERV Identity & Qwen 2.5 0.5B Model Status)
            // ============================================================
            Item {
                id: leftWing
                x: bottomBg.leftChamferWidth + 8
                y: bottomBg.height - bottomBg.wingHeight
                width: bottomBg.centerMidLeftX - x - 8
                height: bottomBg.wingHeight

                RowLayout {
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    spacing: 6

                    // Identity Tag
                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 16
                        color: root.primary
                        radius: 2

                        Text {
                            anchors.centerIn: parent
                            text: NervSettings.hudBranding
                            color: "#ffffff"
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }

                    // Qwen Model Status Badge
                    Rectangle {
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: 140
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        border.width: 1
                        border.color: root.qwenOnline ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35) : Qt.rgba(0.5, 0.5, 0.5, 0.3)
                        radius: 2

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            // Pulse / Status Dot
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: root.isExecuting ? "#ffaa00" : (root.qwenOnline ? "#00cc44" : "#ff3333")

                                SequentialAnimation on opacity {
                                    running: root.isExecuting || !root.qwenOnline
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.3; duration: 400; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 0.3; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                                }
                            }

                            Text {
                                text: "QWEN 2.5 // 0.5B"
                                color: root.primary
                                font.family: root.monoFont
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 0.6
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: statusProcess.running = true
                        }
                    }

                    Text {
                        text: "// AI CMD"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // ============================================================
            // CENTER COMMAND POD (Compact Monospace Command Line)
            // ============================================================
            Item {
                id: centerPod
                x: bottomBg.centerMidLeftX
                y: 0
                width: bottomBg.centerMidWidth
                height: root.fullHeight

                // Command Line Input Container
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    height: 26
                    color: "#ffffff"
                    border.width: 1.5
                    border.color: root.isExecuting ? "#ffaa00" : (cmdInput.activeFocus ? "#ff2222" : root.primary)
                    radius: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 6

                        // Terminal Prompt Badge
                        Rectangle {
                            Layout.preferredWidth: 54
                            Layout.preferredHeight: 16
                            color: root.primary
                            radius: 2

                            Text {
                                anchors.centerIn: parent
                                text: "NERV ❯"
                                color: "#ffffff"
                                font.family: root.monoFont
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 0.4
                            }
                        }

                        // Text Input
                        TextInput {
                            id: cmdInput
                            Layout.fillWidth: true
                            color: "#1a0000"
                            font.family: root.monoFont
                            font.pixelSize: 10
                            font.bold: true
                            clip: true
                            selectByMouse: true
                            cursorVisible: cmdInput.activeFocus

                            Text {
                                text: root.statusText ? root.statusText : "ENTER COMMAND OR QUERY (e.g. 'open firefox', 'terminal', 'vitals')..."
                                color: root.statusText ? (root.statusIsError ? "#cc0000" : "#008822") : root.fgDim
                                font.family: root.monoFont
                                font.pixelSize: 9
                                font.bold: true
                                visible: !cmdInput.text && !cmdInput.inputMethodComposing
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            onTextChanged: {
                                if (cmdInput.activeFocus) {
                                    idleAutoHideTimer.restart();
                                }
                            }

                            Keys.onPressed: function(event) {
                                idleAutoHideTimer.restart();
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.executeCommand(cmdInput.text);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    cmdInput.text = "";
                                    cmdInput.focus = false;
                                    root.isFocused = false;
                                    if (!root.pinned) root.revealed = false;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    if (root.commandHistory.length > 0) {
                                        if (root.historyIndex === -1) {
                                            root.historyIndex = root.commandHistory.length - 1;
                                        } else if (root.historyIndex > 0) {
                                            root.historyIndex -= 1;
                                        }
                                        cmdInput.text = root.commandHistory[root.historyIndex];
                                        cmdInput.cursorPosition = cmdInput.text.length;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (root.historyIndex !== -1) {
                                        if (root.historyIndex < root.commandHistory.length - 1) {
                                            root.historyIndex += 1;
                                            cmdInput.text = root.commandHistory[root.historyIndex];
                                        } else {
                                            root.historyIndex = -1;
                                            cmdInput.text = "";
                                        }
                                        cmdInput.cursorPosition = cmdInput.text.length;
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                        // Execution / Send Button
                        Rectangle {
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 18
                            color: execMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                            border.width: 1
                            border.color: root.primary
                            radius: 2

                            Text {
                                anchors.centerIn: parent
                                text: root.isExecuting ? "•••" : "↵ RUN"
                                color: execMouse.containsMouse ? "#ffffff" : root.primary
                                font.family: root.monoFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            MouseArea {
                                id: execMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.executeCommand(cmdInput.text)
                            }
                        }

                        // Clear Button [X] (visible when text is present)
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            color: clearMouse.containsMouse ? root.primary : "transparent"
                            border.width: 1
                            border.color: root.primary
                            radius: 2
                            visible: cmdInput.text.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: clearMouse.containsMouse ? "#ffffff" : root.primary
                                font.pixelSize: 8
                                font.bold: true
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cmdInput.text = "";
                                    cmdInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // ============================================================
            // RIGHT WING (Shortcuts, Quick App Launchers, and Pin Toggle)
            // ============================================================
            Item {
                id: rightWing
                x: bottomBg.centerMidRightX + 8
                y: bottomBg.height - bottomBg.wingHeight
                width: root.width - x - bottomBg.rightChamferWidth - 6
                height: bottomBg.wingHeight

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    spacing: 6

                    Item { Layout.fillWidth: true }

                    // Quick App Shortcuts
                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 18
                        color: termMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        border.width: 1
                        border.color: root.primary
                        radius: 2

                        Text {
                            anchors.centerIn: parent
                            text: "TERM"
                            color: termMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.monoFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: termMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["evaterm"])
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 18
                        color: fileMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        border.width: 1
                        border.color: root.primary
                        radius: 2

                        Text {
                            anchors.centerIn: parent
                            text: "FILE"
                            color: fileMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.monoFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: fileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["evafile"])
                        }
                    }

                    // Key Guide
                    Text {
                        text: "[↵] EXEC [ESC] HIDE"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        font.letterSpacing: 0.5
                    }

                    // Pin Toggle Button
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 18
                        color: root.pinned ? root.primary : (pinMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08))
                        border.width: 1
                        border.color: root.primary
                        radius: 2

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                text: root.pinned ? "🔒" : "🔓"
                                font.pixelSize: 7
                            }

                            Text {
                                text: root.pinned ? "PIN" : "AUTO"
                                color: root.pinned ? "#ffffff" : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: pinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pinned = !root.pinned
                        }
                    }
                }
            }
        }
    }
}
