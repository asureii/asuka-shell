import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color primary: "#cc0000"
    property color fg: "#cc0000"
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"
    property string title: "EVA-02 // STANDBY"

    // Active Window Query
    Process {
        id: winProcess
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data && data.title) {
                        root.title = data.title;
                    } else {
                        root.title = "EVA-02 // STANDBY";
                    }
                } catch (e) {
                    root.title = "EVA-02 // STANDBY";
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: winProcess.running = true
    }

    Layout.fillWidth: true
    Layout.preferredHeight: 26
    clip: true

    RowLayout {
        anchors.fill: parent
        spacing: 4

        Text {
            text: "•"
            color: root.primary
            font.pixelSize: 10
        }

        Text {
            text: root.title
            color: root.fg
            font.family: root.hudFont
            font.pixelSize: 10
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
