import QtQuick
import QtQuick.Layouts
import "../../../components"

Rectangle {
    id: root

    property color primary: "#cc0000"
    property color secondary: "#cc0000"
    property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.45)
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    readonly property int batteryCap: NervVitals.batteryCap
    readonly property string batteryStatus: NervVitals.batteryStatus

    Layout.preferredWidth: 62
    Layout.preferredHeight: 26
    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
    border.width: 1
    border.color: root.itemBorder

    RowLayout {
        anchors.centerIn: parent
        spacing: 3
        Text {
            text: root.batteryStatus === "Charging" ? "󰂄" : "󰁹"
            color: root.secondary
            font.pixelSize: 11
        }
        Text {
            text: root.batteryCap + "%";
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 10
            font.bold: true
        }
    }
}
