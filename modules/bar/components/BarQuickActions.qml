import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property color primary: "#cc0000"
    property color secondary: "#cc0000"

    signal screenshotClicked()

    spacing: 6

    // Area Screenshot Button (Studio Magnetic Interaction)
    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 26

        Rectangle {
            id: shotVisualCore
            anchors.fill: parent
            color: shotMouse.pressed ? root.primary : (shotMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.24) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08))
            border.width: 1
            border.color: shotMouse.containsMouse ? "#ff2222" : root.primary

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // Tactile Spring Scale
            scale: shotMouse.pressed ? 0.92 : (shotMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }

            // Magnetic Translation
            property real targetX: 0
            property real targetY: 0
            transform: Translate {
                x: shotVisualCore.targetX
                y: shotVisualCore.targetY
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }

            // Directional Specular Lip
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.leftMargin: 2; anchors.rightMargin: 2
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
                visible: shotMouse.containsMouse
            }

            Text {
                anchors.centerIn: parent
                text: "󰄀"
                color: shotMouse.pressed ? "#ffffff" : root.secondary
                font.pixelSize: 13
            }
        }

        MouseArea {
            id: shotMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPositionChanged: (mouse) => {
                var cx = width / 2;
                var cy = height / 2;
                shotVisualCore.targetX = Math.max(-3, Math.min(3, (mouse.x - cx) * 0.25));
                shotVisualCore.targetY = Math.max(-3, Math.min(3, (mouse.y - cy) * 0.25));
            }

            onExited: {
                shotVisualCore.targetX = 0;
                shotVisualCore.targetY = 0;
            }

            onClicked: {
                if (areaPicker) areaPicker.open();
                root.screenshotClicked();
            }
        }
    }
}

