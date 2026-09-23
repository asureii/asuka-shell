import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../components"

Item {
    id: root

    property color primary: "#cc0000"
    property color fg: "#cc0000"
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"
    readonly property string title: NervCompositor.activeTitle

    Layout.fillWidth: true
    Layout.preferredHeight: 26
    clip: true

    RowLayout {
        anchors.fill: parent
        spacing: 5

        Text {
            text: "•"
            color: root.primary
            font.pixelSize: 10
            scale: 1.1
        }

        Text {
            text: root.title
            color: root.fg
            font.family: root.hudFont
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.4
            elide: Text.ElideRight
            Layout.fillWidth: true

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }
    }

}
