import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property color primary: "#cc0000"
    property color secondary: "#cc0000"
    property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.45)
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    property int volumeLevel: 50
    property bool isMuted: false
    property int brightnessLevel: 100

    // Volume Query
    Process {
        id: volProcess
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim();
                root.isMuted = raw.indexOf("[MUTED]") !== -1;
                var match = raw.match(/Volume:\s*([0-9.]+)/);
                if (match) {
                    root.volumeLevel = Math.round(parseFloat(match[1]) * 100);
                }
            }
        }
    }

    // Brightness Query
    Process {
        id: briProcess
        command: ["sh", "-c", "cur=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -n1); max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -n1); [ \"$max\" -gt 0 ] && echo $(( cur * 100 / max )) || echo 100"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(text.trim());
                if (!isNaN(v)) root.brightnessLevel = Math.max(1, Math.min(100, v));
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            volProcess.running = true;
            briProcess.running = true;
        }
    }

    function adjustVolume(delta) {
        var step = delta > 0 ? "5%+" : "5%-";
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", step]);
        volProcess.running = true;
    }

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        volProcess.running = true;
    }

    function adjustBrightness(delta) {
        var newBri = Math.max(5, Math.min(100, root.brightnessLevel + delta));
        root.brightnessLevel = newBri;
        Quickshell.execDetached([Quickshell.configPath("scripts/set_brightness.sh"), newBri.toString()]);
        briProcess.running = true;
    }

    readonly property bool isPopoutActive: (typeof audioBriPopout !== "undefined" && audioBriPopout && audioBriPopout.visible)

    Layout.preferredWidth: 140
    Layout.preferredHeight: 26
    color: root.isPopoutActive ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22) : ((volAreaMouse.containsMouse || briAreaMouse.containsMouse) ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.16) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08))
    border.width: root.isPopoutActive ? 1.5 : 1
    border.color: (volAreaMouse.containsMouse || briAreaMouse.containsMouse) ? "#ff2222" : root.primary

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    // Tactile Spring Scale
    scale: (volAreaMouse.pressed || briAreaMouse.pressed) ? 0.94 : ((volAreaMouse.containsMouse || briAreaMouse.containsMouse) ? 1.04 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
    }

    // Directional 1px Top Specular Rim
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 2; anchors.rightMargin: 2
        height: 1
        color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
        visible: volAreaMouse.containsMouse || briAreaMouse.containsMouse || root.isPopoutActive
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 6

        // Volume Indicator
        Item {
            implicitWidth: volContent.implicitWidth
            implicitHeight: 20

            RowLayout {
                id: volContent
                anchors.centerIn: parent
                spacing: 3
                Text {
                    text: root.isMuted ? "󰝟" : (root.volumeLevel === 0 ? "󰕿" : (root.volumeLevel < 50 ? "󰖀" : "󰕾"))
                    color: root.isMuted ? root.fgDim : root.secondary
                    font.pixelSize: 11
                }
                Text {
                    text: root.isMuted ? "MUTE" : (root.volumeLevel + "%")
                    color: root.isMuted ? root.fgDim : root.primary
                    font.family: root.hudFont
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            MouseArea {
                id: volAreaMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) root.adjustVolume(5);
                    else if (wheel.angleDelta.y < 0) root.adjustVolume(-5);
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.toggleMute();
                    } else {
                        if (typeof audioBriPopout !== "undefined" && audioBriPopout) {
                            audioBriPopout.toggle();
                        }
                    }
                }
            }
        }

        // Separator
        Text {
            text: "//"
            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
            font.family: root.hudFont
            font.pixelSize: 9
            font.bold: true
        }

        // Brightness Indicator
        Item {
            implicitWidth: briContent.implicitWidth
            implicitHeight: 20

            RowLayout {
                id: briContent
                anchors.centerIn: parent
                spacing: 3
                Text {
                    text: root.brightnessLevel < 35 ? "󰃞" : (root.brightnessLevel < 70 ? "󰃟" : "󰃠")
                    color: root.secondary
                    font.pixelSize: 11
                }
                Text {
                    text: root.brightnessLevel + "%"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            MouseArea {
                id: briAreaMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) root.adjustBrightness(5);
                    else if (wheel.angleDelta.y < 0) root.adjustBrightness(-5);
                }
                onClicked: {
                    if (typeof audioBriPopout !== "undefined" && audioBriPopout) {
                        audioBriPopout.toggle();
                    }
                }
            }
        }
    }
}
