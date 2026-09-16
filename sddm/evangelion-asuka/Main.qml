import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color textMain: "#111111"
    readonly property color textDim: Qt.rgba(0.1, 0.0, 0.0, 0.50)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    width: 1366
    height: 768

    property string currentUsername: (typeof userModel !== "undefined" && userModel && userModel.lastUser) ? userModel.lastUser : "camellia"
    property int currentSessionIndex: (typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex !== undefined) ? sessionModel.lastIndex : 0
    property string errorMessage: ""
    property bool isAuthenticating: false
    property bool loginRevealed: false
    property bool showWallpaperOnLogin: true

    focus: true

    Keys.onPressed: (event) => {
        if (!root.loginRevealed) {
            root.revealLogin();
            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                passwordInput.text += event.text;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && passwordInput.text.length === 0) {
            root.hideLogin();
            event.accepted = true;
        }
    }

    function revealLogin() {
        root.loginRevealed = true;
        focusTimer.restart();
    }

    function hideLogin() {
        root.loginRevealed = false;
        passwordInput.text = "";
        root.errorMessage = "";
        root.forceActiveFocus();
    }

    Timer {
        id: focusTimer
        interval: 60
        repeat: false
        onTriggered: {
            passwordInput.forceActiveFocus();
            passwordInput.cursorPosition = passwordInput.text.length;
        }
    }

    Timer {
        id: idleTimer
        interval: 60000
        repeat: false
        running: root.loginRevealed && !root.isAuthenticating && (passwordInput.text.length === 0)
        onTriggered: root.hideLogin()
    }

    function login() {
        if (!passwordInput.text && passwordInput.text.length === 0) return;
        root.isAuthenticating = true;
        root.errorMessage = "";
        if (typeof sddm !== "undefined" && sddm) {
            sddm.login(root.currentUsername, passwordInput.text, root.currentSessionIndex);
        } else {
            console.log("Mock SDDM Login:", root.currentUsername, "Session Index:", root.currentSessionIndex);
            mockTimer.restart();
        }
    }

    Timer {
        id: mockTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.isAuthenticating = false;
            root.errorMessage = "AUTHORIZATION ACCEPTED (TEST MODE)";
        }
    }

    Connections {
        target: (typeof sddm !== "undefined") ? sddm : null
        function onLoginFailed() {
            root.isAuthenticating = false;
            root.errorMessage = "ACCESS DENIED // INVALID PILOT CODE";
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.isAuthenticating = false;
            root.errorMessage = "AUTHENTICATION SUCCESSFUL";
        }
    }

    // ============================================================
    // STANDBY INTRO VIDEO LOOP LAYER (EVANGELION OSCILLOSCOPE)
    // ============================================================
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
    }

    MediaPlayer {
        id: introPlayer
        source: Qt.resolvedUrl("assets/evaintro.mp4")
        loops: MediaPlayer.Infinite
        videoOutput: introVideoOutput
        audioOutput: null
        Component.onCompleted: introPlayer.play()
    }

    VideoOutput {
        id: introVideoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    // ============================================================
    // FULLSCREEN WALLPAPER LAYER (ASUKA BELIEVABLE + GLSL FOG)
    // ============================================================
    Item {
        id: wallpaperLayer
        anchors.fill: parent
        opacity: (root.loginRevealed && root.showWallpaperOnLogin) ? 1.0 : 0.0
        visible: opacity > 0.001
        Behavior on opacity {
            NumberAnimation { duration: 550; easing.type: Easing.InOutQuad }
        }

        Image {
            id: bgImage
            anchors.fill: parent
            source: "assets/asuka_believable.png"
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            visible: false
        }

        ShaderEffectSource {
            id: bgSource
            sourceItem: bgImage
            hideSource: true
            live: true
            visible: false
        }

        ShaderEffect {
            anchors.fill: parent

            property real uTime: 0.0
            property real fogDensity: 0.35
            property real fogSpeed: 0.85
            property color fogColor: "#cc0000"
            property real shimmerIntensity: 0.0012
            property real scanlineAlpha: 0.04
            property var source: bgSource

            fragmentShader: Qt.resolvedUrl("shaders/moving_fog.frag.qsb")

            NumberAnimation on uTime {
                from: 0.0
                to: 1000.0
                duration: 1000000
                loops: Animation.Infinite
                running: true
            }
        }

        // RED BUTTERFLY ANIMATED GLSL SHADER EFFECT
        ShaderEffect {
            anchors.fill: parent

            property real uTime: 0.0
            property color butterflyColor: root.primary
            property color glowColor: root.primary
            property real wingBeatSpeed: 11.5
            property var uResolution: Qt.vector2d(root.width, root.height)

            fragmentShader: Qt.resolvedUrl("shaders/red_butterfly.frag.qsb")

            NumberAnimation on uTime {
                from: 0.0
                to: 1000.0
                duration: 1000000
                loops: Animation.Infinite
                running: true
            }
        }
    }

    // ============================================================
    // STANDBY INTERACTION & HUD PROMPT OVERLAY
    // ============================================================
    MouseArea {
        id: standbyMouse
        anchors.fill: parent
        enabled: !root.loginRevealed
        cursorShape: Qt.PointingHandCursor
        onClicked: root.revealLogin()
    }



    // ============================================================
    // ACTIVE LOGIN UI CONTAINER (REVEALED ON INTERACTION)
    // ============================================================
    Item {
        id: loginUIContainer
        anchors.fill: parent
        opacity: root.loginRevealed ? 1.0 : 0.0
        visible: opacity > 0.001
        transform: Translate {
            y: root.loginRevealed ? 0 : 20
            Behavior on y {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
        }

        // Left Vignette Gradient Overlay (Ensures Login Card & Text Contrast)
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: Math.max(580, parent.width * 0.48)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.94) }
                GradientStop { position: 0.70; color: Qt.rgba(1.0, 1.0, 1.0, 0.70) }
                GradientStop { position: 1.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.0) }
            }
        }

        // Tactical Scanline Canvas
        Canvas {
            anchors.fill: parent
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.04);
                ctx.lineWidth = 1;

                ctx.beginPath();
                for (var y = 0; y < height; y += 4) {
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                }
                ctx.stroke();
            }
        }

        // Top & Bottom Hazard Bars
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 6
            color: root.primary
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 6
            color: root.primary
        }

        // Top Tactical Header Deck & Quick Controls
        RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 28
            anchors.topMargin: 20
            spacing: 8

            Rectangle {
                width: 4
                height: 20
                color: root.primary
            }

            ColumnLayout {
                spacing: 1
                Text {
                    text: "NERV // LOGIN"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 2
                }
                Text {
                    text: "PILOT AUTHORIZATION // EVA-02 SYSTEM SYNCHRONIZATION"
                    color: root.textDim
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 1
                }
            }

            Item { Layout.fillWidth: true }

            // Switch Wallpaper / Live Wave Background
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: 125
                radius: 2
                color: bgToggleMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) : Qt.rgba(1.0, 1.0, 1.0, 0.85)
                border.width: 1
                border.color: root.primary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰄀"; color: root.primary; font.pixelSize: 9 }
                    Text {
                        text: root.showWallpaperOnLogin ? "BG: ASUKA ART" : "BG: LIVE WAVE"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                MouseArea {
                    id: bgToggleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showWallpaperOnLogin = !root.showWallpaperOnLogin
                }
            }

            // Standby Return Button
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: 95
                radius: 2
                color: standbyBtnMouse.containsMouse ? root.primary : Qt.rgba(1.0, 1.0, 1.0, 0.85)
                border.width: 1
                border.color: root.primary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "󰌍"
                        color: standbyBtnMouse.containsMouse ? "#ffffff" : root.primary
                        font.pixelSize: 9
                    }
                    Text {
                        text: "STANDBY"
                        color: standbyBtnMouse.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 1
                    }
                }

                MouseArea {
                    id: standbyBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.hideLogin()
                }
            }
        }

    // ============================================================
    // ALL-IN-ONE TACTICAL NERV LOGIN PANEL (WITH CLOCK & POWER)
    // ============================================================
    Item {
        anchors.left: parent.left
        anchors.leftMargin: 60
        anchors.verticalCenter: parent.verticalCenter
        width: 460
        height: 550

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1.0, 1.0, 1.0, 0.96)
            border.width: 2
            border.color: root.primary

            // Inner Inset Glow
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03)
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                // 1. Header Row (Title + Integrated Digital Clock)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle { width: 3; height: 14; color: root.primary }

                    Text {
                        text: "TERMINAL ACCESS // ASUKA LANGLEY SORYU"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.0
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Integrated Live Clock HUD in Card Header
                    Rectangle {
                        Layout.preferredWidth: 105
                        Layout.preferredHeight: 24
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                        border.width: 1
                        border.color: root.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                id: cardTimeText
                                text: Qt.formatTime(new Date(), "hh:mm:ss")
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                            }

                            Text {
                                id: cardDateText
                                text: Qt.formatDate(new Date(), "MM.dd")
                                color: root.textDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }

                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: {
                                cardTimeText.text = Qt.formatTime(new Date(), "hh:mm:ss");
                                cardDateText.text = Qt.formatDate(new Date(), "MM.dd");
                            }
                        }
                    }
                }

                // 2. Tactical Telemetry Matrix
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { text: "SYNCHRONIZATION"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                            Text { text: "99.8% // NORMAL"; color: root.primary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { text: "CLEARANCE LEVEL"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                            Text { text: "CLASS-A PILOT"; color: root.textMain; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                        }
                    }
                }

                // 3. Pilot Username Display Box
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            color: root.primary

                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                color: "#ffffff"
                                font.pixelSize: 11
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Text { text: "IDENTIFIED PILOT // EVA-02"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                            Text {
                                text: root.currentUsername.toUpperCase()
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1
                            }
                        }

                        Text { text: "READY"; color: root.primary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                    }
                }

                // 4. Password Field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "PILOT AUTHORIZATION CODE:"
                        color: root.textDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 1
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: "#ffffff"
                        border.width: 1.5
                        border.color: passwordInput.activeFocus ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.40)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Text {
                                text: "󰌾"
                                color: passwordInput.activeFocus ? root.primary : root.textDim
                                font.pixelSize: 12
                            }

                            TextInput {
                                id: passwordInput
                                Layout.fillWidth: true
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.bold: true
                                color: root.textMain
                                echoMode: TextInput.Password
                                focus: true
                                clip: true
                                onAccepted: root.login()
                                onTextChanged: idleTimer.restart()

                                Keys.onPressed: (event) => {
                                    idleTimer.restart();
                                    if (event.key === Qt.Key_Escape && passwordInput.text.length === 0) {
                                        root.hideLogin();
                                        event.accepted = true;
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "ENTER PILOT CODE //"
                                    color: root.textDim
                                    font.family: root.hudFont
                                    font.pixelSize: 10
                                    visible: !passwordInput.text && !passwordInput.inputMethodComposing
                                }
                            }
                        }
                    }
                }

                // 5. Session Selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "SESSION:"
                        color: root.textDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.30)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            Text {
                                text: {
                                    if (typeof sessionModel !== "undefined" && sessionModel && sessionModel.rowCount() > 0) {
                                        var val = sessionModel.data(sessionModel.index(root.currentSessionIndex, 0), Qt.DisplayRole);
                                        if (val) return val;
                                    }
                                    return "Hyprland (Wayland)";
                                }
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text { text: "󰍜"; color: root.primary; font.pixelSize: 9 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof sessionModel !== "undefined" && sessionModel && sessionModel.rowCount() > 1) {
                                    root.currentSessionIndex = (root.currentSessionIndex + 1) % sessionModel.rowCount();
                                }
                            }
                        }
                    }
                }

                // Error Message
                Text {
                    text: root.errorMessage
                    color: root.errorMessage.indexOf("DENIED") !== -1 ? root.primary : Qt.rgba(0.0, 0.5, 0.0, 1.0)
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                    visible: root.errorMessage.length > 0
                    Layout.alignment: Qt.AlignHCenter
                }

                // Generous Spacer between Session Selector and Authenticate Access
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 20
                }

                // 6. Authenticate Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: authMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                    border.width: 1.5
                    border.color: root.primary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: root.isAuthenticating ? "󰑓" : "󰌑"
                            color: authMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 11
                        }
                        Text {
                            text: root.isAuthenticating ? "SYNCHRONIZING..." : "AUTHENTICATE ACCESS"
                            color: authMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                    }

                    MouseArea {
                        id: authMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.login()
                    }
                }

                // 7. Tactical Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.30)
                }

                // 8. INTEGRATED POWER CONTROLS DECK (IN CARD FOOTER - ULTRA COMPACT)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 18
                    Layout.minimumHeight: 18
                    Layout.maximumHeight: 18
                    spacing: 6

                    // Suspend
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 18
                        radius: 2
                        color: suspMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                        border.width: 1
                        border.color: root.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text { text: "󰤄"; color: suspMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 8 }
                            Text { text: "SUSPEND"; color: suspMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        }

                        MouseArea {
                            id: suspMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof sddm !== "undefined" && sddm) sddm.suspend();
                            }
                        }
                    }

                    // Reboot
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 18
                        radius: 2
                        color: rebootMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                        border.width: 1
                        border.color: root.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text { text: "󰑓"; color: rebootMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 8 }
                            Text { text: "REBOOT"; color: rebootMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        }

                        MouseArea {
                            id: rebootMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof sddm !== "undefined" && sddm) sddm.reboot();
                            }
                        }
                    }

                    // Shutdown
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 18
                        radius: 2
                        color: powerMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                        border.width: 1
                        border.color: root.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text { text: "󰐥"; color: powerMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 8 }
                            Text { text: "SHUTDOWN"; color: powerMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof sddm !== "undefined" && sddm) sddm.powerOff();
                            }
                        }
                    }
                }
            }

            // Corner Tactical Accents
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 12; height: 12; color: root.primary }
            Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 12; height: 12; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 12; height: 12; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 12; height: 12; color: root.primary }
        }
    }
}
}
