import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../components"

Item {
    id: root

    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"
    property string timeStr: "00:00:00"
    property string powerStr: "INTERNAL // 00:00:00"

    // Power / Battery Telemetry State bound to centralized NervVitals
    readonly property bool isAcOnline: NervVitals.isAcOnline
    readonly property int batteryCap: NervVitals.batteryCap
    property int secondsRemaining: NervVitals.secondsRemaining

    Connections {
        target: NervVitals
        function onSecondsRemainingChanged() {
            if (NervVitals.secondsRemaining > 0) {
                root.secondsRemaining = NervVitals.secondsRemaining;
            }
        }
    }

    // 1-Second Precision Tactical Clock & Countdown Ticking
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            var h = String(d.getHours()).padStart(2, "0");
            var m = String(d.getMinutes()).padStart(2, "0");
            var s = String(d.getSeconds()).padStart(2, "0");
            root.timeStr = h + ":" + m + ":" + s;

            if (!root.isAcOnline) {
                if (root.secondsRemaining > 0) {
                    root.secondsRemaining -= 1;
                }
                var rem = root.secondsRemaining;
                var rh = String(Math.floor(rem / 3600)).padStart(2, "0");
                var rm = String(Math.floor((rem % 3600) / 60)).padStart(2, "0");
                var rs = String(rem % 60).padStart(2, "0");
                root.powerStr = "INTERNAL // " + rh + ":" + rm + ":" + rs;
            } else {
                root.powerStr = "EXTERNAL // " + (root.batteryCap >= 100 ? "100%" : (root.batteryCap + "%"));
            }
        }
    }

    // Studio Tactile Hover and Spring Scale
    scale: clockMouse.pressed ? 0.95 : (clockMouse.containsMouse ? 1.03 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
    }

    // Dynamic Specular Glare across Central Pod
    Item {
        anchors.fill: parent
        clip: true
        opacity: clockMouse.containsMouse ? 0.25 : 0.0
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Rectangle {
            id: podSpecular
            width: parent.width * 1.4
            height: parent.height * 1.4
            property real normX: 0
            x: (parent.width - width) / 2 + (normX * parent.width * 0.3)
            y: (parent.height - height) / 2
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1.0, 1.0, 1.0, 0.45) }
                GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, 0.05) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 3

        // Tactical Time
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.timeStr
            color: "#ffffff"
            font.family: root.hudFont
            font.pixelSize: 22
            font.bold: true
            font.letterSpacing: 2
        }

        // Eva Power Telemetry (Internal Countdown vs External Power)
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.powerStr
            color: (!root.isAcOnline && root.secondsRemaining > 0 && root.secondsRemaining < 300) ? "#ffcc00" : "#ffffff"
            font.family: root.hudFont
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.2
        }
    }

    // Interactive Click toggles Control Center
    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: (mouse) => {
            podSpecular.normX = Math.max(-1.0, Math.min(1.0, (mouse.x - width / 2) / (width / 2)));
        }
        onExited: {
            podSpecular.normX = 0;
        }
        onClicked: {
            if (controlCenter) (typeof controlCenter.toggle === "function" ? controlCenter.toggle() : (controlCenter.visible = !controlCenter.visible));
        }
    }
}

