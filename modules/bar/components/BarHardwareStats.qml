import QtQuick
import QtQuick.Layouts
import "../../../components"

Rectangle {
    id: root

    property color primary: "#cc0000"
    property color secondary: "#cc0000"
    property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.45)
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    readonly property int cpuLoad: NervVitals.cpuLoad
    readonly property string ramUsedGb: NervVitals.ramUsedGb

    readonly property bool isPopoutOpen: (typeof vitalsPopout !== "undefined" && vitalsPopout && vitalsPopout.visible)

    Layout.preferredWidth: 136
    Layout.preferredHeight: 26
    color: root.isPopoutOpen ? root.primary : (statsMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08))
    border.width: root.isPopoutOpen ? 1.5 : 1
    border.color: root.isPopoutOpen ? "#ff2222" : (statsMouse.containsMouse ? root.primary : root.itemBorder)

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    // Tactile Spring Scale
    scale: statsMouse.pressed ? 0.94 : (statsMouse.containsMouse ? 1.04 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
    }

    // Directional 1px Top Specular Rim
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 2; anchors.rightMargin: 2
        height: 1
        color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
        visible: statsMouse.containsMouse || root.isPopoutOpen
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 6

        RowLayout {
            spacing: 3
            Text {
                text: "CPU"
                color: root.isPopoutOpen ? "#ffffff" : root.fgDim
                font.family: root.hudFont
                font.pixelSize: 9
                font.bold: true
            }
            Text {
                text: root.cpuLoad + "%"
                color: root.isPopoutOpen ? "#ffffff" : root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
            }
        }

        Text {
            text: "//"
            color: root.isPopoutOpen ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
            font.family: root.hudFont
            font.pixelSize: 9
            font.bold: true
        }

        RowLayout {
            spacing: 3
            Text {
                text: "RAM"
                color: root.isPopoutOpen ? "#ffffff" : root.fgDim
                font.family: root.hudFont
                font.pixelSize: 9
                font.bold: true
            }
            Text {
                text: root.ramUsedGb + "G"
                color: root.isPopoutOpen ? "#ffffff" : root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    MouseArea {
        id: statsMouse
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
