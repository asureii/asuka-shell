import QtQuick
import QtQuick.Layouts

/**
 * StudioCard.qml
 *
 * Evangelion Studio-grade 2.5D interactive perspective tilt card.
 * Features:
 * - Real-time 3D cursor-reactive pitch and yaw tilt around center origin.
 * - Dynamic roving specular glare tracking cursor displacement.
 * - Directional 1px specular lighting rim simulating overhead key-light.
 * - Multi-plane virtual depth (Z-parallax) normalized coordinates (normX, normY).
 * - Non-blocking HoverHandler: preserves 100% clickability of nested child buttons/inputs.
 * - Strict Zero-CPU idle law: powers down completely when mouse is resting or off-screen.
 * - Full aesthetic compatibility with Evangelion crimson/white HUD design.
 */
Item {
    id: root

    default property alias content: contentHost.data

    property color cardBg: Qt.rgba(1.0, 1.0, 1.0, 0.92)
    property color strokeColor: Qt.rgba(0.8, 0.0, 0.0, 0.45)
    property real strokeWidth: 1.0
    property real radius: 0.0

    property bool isChamfered: false
    property real chamfer: 8.0

    property bool tiltEnabled: true
    property real maxTilt: 16.0 // Prominent, tactile 3D perspective tilt (in degrees)

    property bool specularEnabled: true
    property color specularColor: Qt.rgba(1.0, 1.0, 1.0, 0.55)
    property real specularOpacity: 0.45

    property bool rimEnabled: true
    property color rimColor: Qt.rgba(1.0, 1.0, 1.0, 0.70)

    property bool tactileScale: true
    property real hoverScale: 1.035
    property real pressScale: 0.98

    property int cursorShape: Qt.ArrowCursor

    // Compatibility properties for drop-in 3D replacements
    property real slabThickness: 12.0
    property real specularBrightness: 1.5
    property color slabEdgeColor: "#1a0000"

    // Target & animated normalized tilt values (-1.0 to 1.0)
    property real targetNormX: 0.0
    property real targetNormY: 0.0
    property real normX: targetNormX
    property real normY: targetNormY

    Behavior on normX {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
    Behavior on normY {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    readonly property bool isHovered: cardHover.hovered

    // 3D Perspective Rotation Compound
    transform: [
        Rotation {
            id: rotY
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.tiltEnabled ? (root.normX * root.maxTilt) : 0.0
        },
        Rotation {
            id: rotX
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: root.tiltEnabled ? (-root.normY * root.maxTilt) : 0.0
        }
    ]

    // Tactile Scale on hover (3D elevation lift)
    scale: (root.tactileScale && root.isHovered) ? root.hoverScale : 1.0
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
    }

    // Perspective Drop Ambient Shadow / Depth Cast
    Rectangle {
        id: perspectiveShadow
        anchors.fill: parent
        z: -1
        radius: root.radius
        color: Qt.rgba(root.strokeColor.r, root.strokeColor.g, root.strokeColor.b, 0.28)
        visible: root.isHovered || opacity > 0.01
        opacity: root.isHovered ? 0.65 : 0.0
        transform: Translate {
            x: -root.normX * 12
            y: -root.normY * 12 + 6
        }
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    // Base Frame (Rectangle or Chamfered Canvas)
    Rectangle {
        id: rectBase
        visible: !root.isChamfered
        anchors.fill: parent
        radius: root.radius
        color: root.cardBg
        border.width: root.strokeWidth
        border.color: root.isHovered ? Qt.rgba(0.9, 0.1, 0.1, 0.85) : root.strokeColor

        Behavior on border.color {
            ColorAnimation { duration: 160 }
        }
    }

    Canvas {
        id: chamferBase
        visible: root.isChamfered
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var w = width;
            var h = height;
            var c = root.chamfer;

            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(w - c, 0);
            ctx.lineTo(w, c);
            ctx.lineTo(w, h);
            ctx.lineTo(c, h);
            ctx.lineTo(0, h - c);
            ctx.closePath();

            ctx.fillStyle = root.cardBg;
            ctx.fill();

            ctx.strokeStyle = root.isHovered ? Qt.rgba(0.9, 0.1, 0.1, 0.85) : root.strokeColor;
            ctx.lineWidth = root.strokeWidth;
            ctx.stroke();
        }

        Connections {
            target: root
            function onIsHoveredChanged() { if (root.isChamfered) chamferBase.requestPaint(); }
            function onCardBgChanged() { if (root.isChamfered) chamferBase.requestPaint(); }
            function onStrokeColorChanged() { if (root.isChamfered) chamferBase.requestPaint(); }
        }
    }

    // Directional 1px Overhead Specular Highlight Rim
    Rectangle {
        id: topRim
        visible: root.rimEnabled
        z: 4
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.radius > 0 ? root.radius : (root.isChamfered ? root.chamfer : 4)
        anchors.rightMargin: root.radius > 0 ? root.radius : (root.isChamfered ? root.chamfer : 4)
        height: 1
        color: root.rimColor
        opacity: root.isHovered ? 0.90 : 0.45

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }

    // Dynamic Roving Specular Glare (tracks cursor position)
    Item {
        id: specularContainer
        anchors.fill: parent
        clip: true
        z: 3
        visible: root.specularEnabled && (root.isHovered || opacity > 0.01)
        opacity: root.isHovered ? root.specularOpacity : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            width: parent.width * 1.5
            height: parent.height * 1.5
            x: (parent.width - width) / 2 + (root.normX * parent.width * 0.35)
            y: (parent.height - height) / 2 + (root.normY * parent.height * 0.35)
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.00; color: root.specularColor }
                GradientStop { position: 0.45; color: Qt.rgba(1.0, 1.0, 1.0, 0.05) }
                GradientStop { position: 1.00; color: "transparent" }
            }
        }
    }

    // Interactive HoverHandler (Non-blocking: child elements receive clicks)
    HoverHandler {
        id: cardHover
        cursorShape: root.cursorShape
        onPointChanged: {
            if (hovered && root.width > 0 && root.height > 0) {
                root.targetNormX = Math.max(-1.0, Math.min(1.0, (point.position.x - root.width / 2) / (root.width / 2)));
                root.targetNormY = Math.max(-1.0, Math.min(1.0, (point.position.y - root.height / 2) / (root.height / 2)));
            }
        }
        onHoveredChanged: {
            if (!hovered) {
                root.targetNormX = 0.0;
                root.targetNormY = 0.0;
            }
        }
    }

    // Content Layer
    Item {
        id: contentHost
        anchors.fill: parent
        z: 6
    }
}
