import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property color primary: "#cc0000"
    property color secondary: "#cc0000"

    signal screenshotClicked()

    spacing: 6

    // Area Screenshot Button
    Rectangle {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 26
        color: shotMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
        border.width: 1
        border.color: root.primary

        Text {
            anchors.centerIn: parent
            text: "󰄀"
            color: root.secondary
            font.pixelSize: 13
        }

        MouseArea {
            id: shotMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (areaPicker) areaPicker.open();
                root.screenshotClicked();
            }
        }
    }
}
