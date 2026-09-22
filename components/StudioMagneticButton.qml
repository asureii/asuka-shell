import QtQuick
import QtQuick.Layouts

/**
 * StudioMagneticButton.qml
 *
 * Evangelion Studio-grade Magnetic Button with proximity cursor attraction.
 * Features:
 * - Extended invisible proximity zone drawing visual core toward cursor.
 * - Tactile spring press feedback (OutBack easing).
 * - Directional 1px specular lighting edge bevel.
 * - Full aesthetic compatibility with Evangelion crimson/white HUD design.
 * - Zero CPU idle overhead when mouse is outside the proximity zone.
 */
Item {
    id: root

    property string label: ""
    property string icon: ""
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"
    property int fontPixelSize: 8

    property color btnColor: Qt.rgba(0.8, 0.0, 0.0, 0.08)
    property color btnHoverColor: Qt.rgba(0.8, 0.0, 0.0, 0.22)
    property color btnPressedColor: "#cc0000"
    property color btnBorder: "#cc0000"
    property color btnHoverBorder: "#ff2222"
    property real borderWidth: 1.0
    property real radius: 0.0

    property color textColor: "#cc0000"
    property color textHoverColor: "#ffffff"

    property real magnetRadius: 24.0
    property real pullStrength: 0.28 // Subtle physical magnetic pull (0.0 to 1.0)
    property bool magneticEnabled: true

    signal clicked()

    implicitWidth: 32
    implicitHeight: 28

    // Invisible Proximity Detection Zone
    MouseArea {
        id: magnetZone
        anchors.centerIn: parent
        width: parent.width + (root.magneticEnabled ? (root.magnetRadius * 2) : 0)
        height: parent.height + (root.magneticEnabled ? (root.magnetRadius * 2) : 0)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: (mouse) => {
            if (!root.magneticEnabled) return;
            var centerX = width / 2;
            var centerY = height / 2;
            var deltaX = (mouse.x - centerX);
            var deltaY = (mouse.y - centerY);

            visualCore.targetX = Math.max(-6, Math.min(6, deltaX * root.pullStrength));
            visualCore.targetY = Math.max(-5, Math.min(5, deltaY * root.pullStrength));
        }

        onExited: {
            visualCore.targetX = 0;
            visualCore.targetY = 0;
        }

        onClicked: root.clicked()
    }

    // Visual Core Container (Moves magnetically)
    Rectangle {
        id: visualCore
        anchors.centerIn: parent
        width: root.width
        height: root.height
        radius: root.radius

        color: magnetZone.pressed ? root.btnPressedColor : (magnetZone.containsMouse ? root.btnHoverColor : root.btnColor)
        border.width: root.borderWidth
        border.color: magnetZone.containsMouse ? root.btnHoverBorder : root.btnBorder

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        property real targetX: 0
        property real targetY: 0

        transform: Translate {
            x: visualCore.targetX
            y: visualCore.targetY
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        }

        // Tactile Press Scale (Spring overshoot)
        scale: magnetZone.pressed ? 0.93 : (magnetZone.containsMouse ? 1.06 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        // Top Specular Highlight Edge
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.radius > 0 ? root.radius : 2
            anchors.rightMargin: root.radius > 0 ? root.radius : 2
            height: 1
            color: Qt.rgba(1.0, 1.0, 1.0, 0.45)
            visible: magnetZone.containsMouse
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
                visible: root.icon.length > 0
                text: root.icon
                color: magnetZone.pressed ? "#ffffff" : (magnetZone.containsMouse ? root.textHoverColor : root.textColor)
                font.family: root.hudFont
                font.pixelSize: root.fontPixelSize + 2
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                visible: root.label.length > 0
                text: root.label
                color: magnetZone.pressed ? "#ffffff" : (magnetZone.containsMouse ? root.textHoverColor : root.textColor)
                font.family: root.hudFont
                font.pixelSize: root.fontPixelSize
                font.bold: true
                font.letterSpacing: 0.6
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
