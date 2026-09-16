import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color textMain: "#111111"
    readonly property color textDim: Qt.rgba(0.1, 0.0, 0.0, 0.55)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    width: 1366
    height: 768

    property string currentUsername: (typeof userModel !== "undefined" && userModel && userModel.lastUser) ? userModel.lastUser : "camellia"
    property int currentSessionIndex: (typeof sessionModel !== "undefined" && sessionModel && sessionModel.lastIndex !== undefined) ? sessionModel.lastIndex : 0
    property string errorMessage: ""
    property bool isAuthenticating: false
    property bool loginRevealed: false
    property bool introAudioPlayed: false

    focus: true

    Keys.onPressed: (event) => {
        if (!root.loginRevealed) {
            root.revealLogin();
            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                passwordInput.text += event.text;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.hideLogin();
            event.accepted = true;
        }
    }

    function revealLogin() {
        root.loginRevealed = true;
        focusTimer.restart();
        if (!root.introAudioPlayed) {
            root.introAudioPlayed = true;
            introAudio.play();
        }
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
    // 1. FULLSCREEN VIDEO LAYER (SEAMLESS OSCILLOSCOPE LOOP)
    // ============================================================
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
    }

    MediaPlayer {
        id: bgVideoPlayer
        source: Qt.resolvedUrl("assets/evaintro.mp4")
        loops: MediaPlayer.Infinite
        videoOutput: bgVideoOutput
        audioOutput: null
        Component.onCompleted: bgVideoPlayer.play()
    }

    VideoOutput {
        id: bgVideoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    MediaPlayer {
        id: introAudio
        source: Qt.resolvedUrl("assets/asukaintro.mp3")
        audioOutput: AudioOutput {
            volume: 1.0
        }
    }

    // ============================================================
    // 2. STANDBY CLICK CAPTURE (FULLSCREEN)
    // ============================================================
    MouseArea {
        id: standbyClickArea
        anchors.fill: parent
        enabled: !root.loginRevealed
        cursorShape: Qt.PointingHandCursor
        onClicked: root.revealLogin()
    }

    // ============================================================
    // 3. DIM BACKDROP & CLICK-OUTSIDE DISMISSAL
    // ============================================================
    Rectangle {
        id: modalBackdrop
        anchors.fill: parent
        color: Qt.rgba(0.0, 0.0, 0.0, 0.22)
        opacity: root.loginRevealed ? 1.0 : 0.0
        visible: opacity > 0.001

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.InOutQuad }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.loginRevealed
            onClicked: root.hideLogin()
        }
    }

    // ============================================================
    // 4. FLOATING TACTICAL LOGIN PANEL (CENTERED MODAL)
    // ============================================================
    Item {
        id: floatingPanelContainer
        anchors.centerIn: parent
        width: 440
        height: 480
        opacity: root.loginRevealed ? 1.0 : 0.0
        visible: opacity > 0.001
        scale: root.loginRevealed ? 1.0 : 0.92

        Behavior on opacity {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack }
        }

        // Prevent clicks inside panel from dismissing the modal
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Main Card Body
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1.0, 1.0, 1.0, 0.96)
            border.width: 1.5
            border.color: root.primary

            // Inner Accent Border
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03)
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                // Header Row (Title, Live Clock, and Close Button)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle { width: 3; height: 16; color: root.primary }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        Text {
                            text: "NERV // PILOT AUTHENTICATION"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.5
                        }
                        Text {
                            text: "MAGI-01 SYSTEM ACCESS // EVA-02 SYNCHRONIZATION"
                            color: root.textDim
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    // Live Mini Clock
                    Rectangle {
                        Layout.preferredWidth: 85
                        Layout.preferredHeight: 22
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                        border.width: 1
                        border.color: root.primary

                        Text {
                            id: cardTimeText
                            anchors.centerIn: parent
                            text: Qt.formatTime(new Date(), "hh:mm:ss")
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                        }

                        Timer {
                            interval: 1000
                            running: root.loginRevealed
                            repeat: true
                            onTriggered: cardTimeText.text = Qt.formatTime(new Date(), "hh:mm:ss")
                        }
                    }

                    // Dismiss Button (Close Panel)
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        color: closeMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                        border.width: 1
                        border.color: root.primary

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: closeMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hideLogin()
                        }
                    }
                }

                // Telemetry / Status Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text { text: "HARMONIC SYNC"; color: root.textDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                            Text { text: "99.8% // STABLE"; color: root.primary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
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

                // Pilot Username Display Box
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            color: root.primary
                            Text {
                                anchors.centerIn: parent
                                text: "󰌀"
                                color: "#ffffff"
                                font.pixelSize: 12
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Text {
                                text: "DESIGNATED PILOT ID"
                                color: root.textDim
                                font.family: root.hudFont
                                font.pixelSize: 6
                                font.bold: true
                            }
                            Text {
                                text: root.currentUsername.toUpperCase()
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1.5
                            }
                        }

                        Rectangle {
                            width: 48
                            height: 16
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                            border.width: 1
                            border.color: root.primary
                            Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }

                // Password Input Field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "PILOT AUTHORIZATION CODE:"
                        color: root.textDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        color: "#ffffff"
                        border.width: 1.5
                        border.color: passwordInput.activeFocus ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

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
                                    if (event.key === Qt.Key_Escape) {
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

                // Session Selector
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "SESSION:"
                        color: root.textDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        color: sessionMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03)
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

                            Text {
                                text: "󰅂"
                                color: root.primary
                                font.pixelSize: 9
                            }
                        }

                        MouseArea {
                            id: sessionMouse
                            anchors.fill: parent
                            hoverEnabled: true
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

                Item { Layout.fillHeight: true }

                // Authenticate Button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
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

                // Tactical Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                }

                // Integrated Power Controls Deck
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    spacing: 6

                    // Suspend
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
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
                        Layout.preferredHeight: 20
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
                        Layout.preferredHeight: 20
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

            // Corner Tactical Accents (Red L-brackets)
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 10; height: 10; color: root.primary }
            Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 10; height: 10; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 10; height: 10; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 10; height: 10; color: root.primary }
        }
    }
}
