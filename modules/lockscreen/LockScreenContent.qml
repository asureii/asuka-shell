import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "../../components"

Item {
    id: root

    property bool isLocked: true
    property bool isTestMode: false
    property string username: Quickshell.env("USER") || "camellia"
    property string avatarSource: Quickshell.configPath("assets/asukapfp.jpg")
    property string wallpaperSource: "/home/camellia/Pictures/asukagraphic.png"

    signal unlockRequested()

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    property string statusMessage: ""
    property bool isAuthenticating: false
    property bool capsLockActive: false

    // Clock properties
    property var currentTime: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    readonly property string timeString: {
        var h = root.currentTime.getHours();
        var m = root.currentTime.getMinutes();
        var hStr = (h < 10 ? "0" : "") + h;
        var mStr = (m < 10 ? "0" : "") + m;
        return hStr + ":" + mStr;
    }

    readonly property string secondsString: {
        var s = root.currentTime.getSeconds();
        return (s < 10 ? "0" : "") + s;
    }

    readonly property string dateString: {
        var days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        var months = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"];
        var d = root.currentTime;
        return days[d.getDay()] + " // " + d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear();
    }

    // ============================================================
    // PAM AUTHENTICATION BACKEND
    // ============================================================
    PamContext {
        id: pam
        user: root.username
        config: "system-auth"

        onResponseRequiredChanged: {
            if (pam.responseRequired && root.isAuthenticating) {
                pam.respond(passwordInput.text);
            }
        }

        onCompleted: (result) => {
            root.isAuthenticating = false;
            if (result === PamResult.Success) {
                root.statusMessage = "AUTHENTICATION ACCEPTED // UNLOCKING";
                unlockTimer.restart();
            } else {
                root.statusMessage = "ACCESS DENIED // INVALID CODE";
                shakeAnim.restart();
                passwordInput.text = "";
                passwordInput.forceActiveFocus();
            }
        }

        onError: (err) => {
            root.isAuthenticating = false;
            root.statusMessage = "AUTH ERROR: " + (pam.message || "FAILURE");
            shakeAnim.restart();
            passwordInput.text = "";
            passwordInput.forceActiveFocus();
        }
    }

    Timer {
        id: unlockTimer
        interval: 200
        repeat: false
        onTriggered: {
            root.unlockRequested();
        }
    }

    function submitPassword() {
        if (!passwordInput.text || passwordInput.text.length === 0) return;
        root.isAuthenticating = true;
        root.statusMessage = "VERIFYING CREDENTIALS...";

        if (root.isTestMode) {
            // In standalone test mode, accept password test
            testTimer.restart();
            return;
        }

        try {
            if (pam.active) {
                pam.abort();
            }
            pam.start();
        } catch (e) {
            root.isAuthenticating = false;
            root.statusMessage = "PAM INITIALIZATION ERROR";
            shakeAnim.restart();
        }
    }

    Timer {
        id: testTimer
        interval: 600
        repeat: false
        onTriggered: {
            root.isAuthenticating = false;
            root.statusMessage = "TEST MODE // ACCESS ACCEPTED";
            unlockTimer.restart();
        }
    }

    // Keyboard handling
    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_CapsLock) {
            root.capsLockActive = !root.capsLockActive;
        }
        if (!passwordInput.activeFocus) {
            passwordInput.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus();
    }

    // ============================================================
    // CLEAN WHITE WALLPAPER & BACKDROP
    // ============================================================
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"

        // Optional Subtle Wallpaper Graphic Layer
        Image {
            id: bgGraphic
            anchors.fill: parent
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            opacity: 0.85
            asynchronous: true
        }

        // Subtle Geometric Watermark Grid
        NervHudGrid {
            anchors.fill: parent
            gridColor: root.primary
            gridOpacity: 0.04
            hexRadius: 36
        }

        // Top & Bottom Tactical Hazard Borders
        NervHazardLines {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            stripeColor: root.primary
            bgColor: "#ffffff"
        }

        NervHazardLines {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            stripeColor: root.primary
            bgColor: "#ffffff"
        }

        // ============================================================
        // MAIN CENTER HERO COLUMN
        // ============================================================
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 24
            width: 440

            // 1. CLOCK & DATE BLOCK
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                // Large Time Display
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Text {
                        text: root.timeString
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 84
                        font.bold: true
                        font.letterSpacing: -3.0
                    }

                    // Blinking Seconds Pulse
                    Text {
                        text: ":" + root.secondsString
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 28
                        font.bold: true
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 14
                    }
                }

                // Full Date Readout
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.dateString
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2.0
                }

                // NERV Lockscreen Telemetry Tag
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Rectangle { width: 14; height: 1; color: root.primary }

                    Text {
                        text: "NERV // TERMINAL LOCK // PILOT-02"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Rectangle { width: 14; height: 1; color: root.primary }
                }
            }

            // 2. PROFILE PICTURE AVATAR
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                // Circular Avatar Frame
                Rectangle {
                    id: avatarFrame
                    Layout.alignment: Qt.AlignHCenter
                    width: 96
                    height: 96
                    radius: 48
                    color: "#ffffff"
                    border.width: 2
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
                        source: root.avatarSource
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

                    // Tactical Corner Marker
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 10
                        height: 10
                        radius: 5
                        color: root.primary
                        border.width: 1.5
                        border.color: "#ffffff"
                    }
                }

                // Pilot Name
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.username.toUpperCase()
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 1.8
                }
            }

            // 3. PASSWORD INPUT CAPSULE
            Item {
                id: inputPillContainer
                Layout.alignment: Qt.AlignHCenter
                width: 320
                height: 44

                property real xOffset: 0.0

                transform: Translate {
                    x: inputPillContainer.xOffset
                }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: inputPillContainer; property: "xOffset"; to: -14; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: inputPillContainer; property: "xOffset"; to: 14; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: inputPillContainer; property: "xOffset"; to: -10; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: inputPillContainer; property: "xOffset"; to: 10; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: inputPillContainer; property: "xOffset"; to: -4; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: inputPillContainer; property: "xOffset"; to: 0; duration: 40; easing.type: Easing.OutQuad }
                }

                Rectangle {
                    id: inputPill
                    anchors.fill: parent
                    radius: 22
                    color: "#ffffff"
                    border.width: 1.5
                    border.color: root.isAuthenticating ? root.highlight : (inputMouse.containsMouse ? root.primary : root.itemBorder)

                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    // Directional Top Specular Edge
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        height: 1
                        color: "#ffffff"
                        opacity: 0.95
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 6
                        spacing: 8

                        // Lock Icon
                        Text {
                            text: "󰌾"
                            color: root.primary
                            font.pixelSize: 14
                        }

                        // Text Input
                        TextInput {
                            id: passwordInput
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            font.family: root.hudFont
                            font.pixelSize: 12
                            color: root.fg
                            clip: true
                            selectByMouse: true
                            focus: true

                            onAccepted: root.submitPassword()

                            Text {
                                anchors.fill: parent
                                visible: !passwordInput.text && !passwordInput.activeFocus
                                text: "ENTER PASSCODE..."
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.letterSpacing: 1.0
                            }
                        }

                        // Unlock Submit Button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: submitMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                            border.width: 1
                            border.color: root.primary
                            scale: submitMouse.pressed ? 0.92 : (submitMouse.containsMouse ? 1.08 : 1.0)

                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: root.isAuthenticating ? "…" : "▶"
                                color: submitMouse.containsMouse ? "#ffffff" : root.primary
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                id: submitMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitPassword()
                            }
                        }
                    }

                    MouseArea {
                        id: inputMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }

            // 4. CAPS LOCK & STATUS MESSAGE
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                // Caps Lock Indicator
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.capsLockActive
                    height: 18
                    implicitWidth: capsRow.implicitWidth + 10
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        id: capsRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "󰘲"; color: root.primary; font.pixelSize: 9 }
                        Text { text: "CAPS LOCK ON"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    }
                }

                // Authentication Status Toast
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.statusMessage.length > 0
                    text: root.statusMessage
                    color: root.statusMessage.indexOf("DENIED") !== -1 ? root.primary : root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1.0
                }
            }
        }

        // ============================================================
        // BOTTOM TELEMETRY & POWER ACTIONS BAR
        // ============================================================
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 18
            spacing: 12

            // Power Actions: Shutdown, Reboot, Suspend
            RowLayout {
                spacing: 8

                Rectangle {
                    height: 24
                    implicitWidth: shutRow.implicitWidth + 10
                    color: shutMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        id: shutRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "󰐥"; color: shutMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 9 }
                        Text { text: "SHUTDOWN"; color: shutMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    }

                    MouseArea {
                        id: shutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
                }

                Rectangle {
                    height: 24
                    implicitWidth: rebRow.implicitWidth + 10
                    color: rebMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        id: rebRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "⟳"; color: rebMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 9; font.bold: true }
                        Text { text: "REBOOT"; color: rebMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    }

                    MouseArea {
                        id: rebMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }
                }

                Rectangle {
                    height: 24
                    implicitWidth: suspRow.implicitWidth + 10
                    color: suspMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        id: suspRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "󰒋"; color: suspMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 9 }
                        Text { text: "SUSPEND"; color: suspMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    }

                    MouseArea {
                        id: suspMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Status Telemetry: Tokyo-3 Geo & Sync
            RowLayout {
                spacing: 8

                Rectangle {
                    height: 20
                    implicitWidth: statusPillRow.implicitWidth + 10
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                    RowLayout {
                        id: statusPillRow
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle { width: 4; height: 4; radius: 2; color: root.primary }
                        Text { text: "NERV HQ // MAGI SYSTEM SECURE"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    }
                }
            }
        }
    }
}
