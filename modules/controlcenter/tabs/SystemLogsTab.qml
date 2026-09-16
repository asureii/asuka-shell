import QtQuick
import "../../../components"

Item {
    id: root

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Text {
            anchors.centerIn: parent
            text: NervSettings.hudBranding + " // TAB 04 - SYSTEM LOGS & EVENT STREAM"
            color: "#cc0000"
            font.family: "Liberation Sans, JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.bold: true
            font.letterSpacing: 2
        }
    }
}
