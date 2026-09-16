import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root

    property real revealProgress: 0.0
    property real beamOpacity: 0.0
    property real targetHeight: parent ? parent.implicitHeight : 500
    property bool running: false
    property color primaryColor: "#cc0000"
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    width: parent ? parent.width : 0
    height: 28
    y: Math.round(revealProgress * targetHeight) - 26
    z: 100
    visible: (running || revealProgress !== 1.0) && beamOpacity > 0.0
    opacity: beamOpacity

    // Phosphor Trail
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: laserCore.top
        anchors.left: parent.left
        anchors.right: parent.right
        gradient: Gradient {
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.60; color: Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.18) }
            GradientStop { position: 1.00; color: Qt.rgba(1.0, 0.25, 0.25, 0.55) }
        }
    }

    // Razor Laser Core Line
    Rectangle {
        id: laserCore
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: "#ffffff"
        border.width: 1
        border.color: "#ff2222"
    }

    // Laser Bloom Flare
    Rectangle {
        anchors.centerIn: laserCore
        width: parent.width
        height: 6
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1.0, 0.2, 0.2, 0.40)
    }

    // Tactical Left & Right HUD Reticle Brackets
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.bottom: laserCore.top
        anchors.bottomMargin: 2
        spacing: 3

        Rectangle { width: 3; height: 3; color: "#ff2222" }
        Text {
            text: "◄ " + NervSettings.hudBranding
            color: "#ff2222"
            font.family: root.hudFont
            font.pixelSize: 7
            font.bold: true
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.bottom: laserCore.top
        anchors.bottomMargin: 2
        spacing: 3

        Text {
            text: "SCAN ►"
            color: "#ff2222"
            font.family: root.hudFont
            font.pixelSize: 7
            font.bold: true
        }
        Rectangle { width: 3; height: 3; color: "#ff2222" }
    }
}
