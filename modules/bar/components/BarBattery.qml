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
    color: batMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.16) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
    border.width: 1
    border.color: batMouse.containsMouse ? "#ff2222" : root.itemBorder

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    // Tactile Spring Scale
    scale: batMouse.pressed ? 0.94 : (batMouse.containsMouse ? 1.05 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
    }

    // Directional 1px Top Specular Rim
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 2; anchors.rightMargin: 2
        height: 1
        color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
        visible: batMouse.containsMouse
    }

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

    MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (typeof vitalsPopout !== "undefined" && vitalsPopout) {
                vitalsPopout.toggle();
            }
        }
    }
}

