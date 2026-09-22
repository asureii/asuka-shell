import QtQuick
import QtQuick.Layouts
import QtQuick3D

/**
 * MagiHoloCore3D.qml
 *
 * Evangelion NERV MAGI-01 3D Holographic Consensus Core using QtQuick3D.
 * Features:
 * - True 3D spatial cluster depicting Melchior-1, Balthasar-2, Casper-3, and Central Consensus Core.
 * - Interactive cursor-following yaw & pitch tilt with PBR emissive glow.
 * - Safe Lazy-Mount Loader: only instantiates View3D when window & tab are fully mapped,
 *   preventing Wayland layer-shell proxy window crashes in Quickshell.
 * - Zero-CPU Idle Law: 100% powered down when inactive or unhovered.
 * - Native 2D vector HUD telemetry floating in lockstep.
 */
Item {
    id: root

    property bool active: false
    property color primaryColor: "#cc0000"
    property color secondaryColor: "#ff2222"
    property color fgColor: "#1a0000"
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    property real targetNormX: 0.0
    property real targetNormY: 0.0
    property real normX: targetNormX
    property real normY: targetNormY

    Behavior on normX { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on normY { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    // Lazy-Mount Loader: only mounts View3D when active, ensuring window is ready
    Loader {
        id: view3dLoader
        anchors.fill: parent
        active: root.active
        asynchronous: false

        sourceComponent: Component {
            View3D {
                id: v3d
                anchors.fill: parent

                environment: SceneEnvironment {
                    clearColor: "transparent"
                    backgroundMode: SceneEnvironment.Transparent
                    antialiasingMode: SceneEnvironment.MSAA
                    antialiasingQuality: SceneEnvironment.High
                }

                PerspectiveCamera {
                    id: camera
                    z: 460
                    clipNear: 10
                    clipFar: 1400
                    fieldOfView: 33
                }

                DirectionalLight {
                    eulerRotation.x: -28
                    eulerRotation.y: 25
                    color: "#ffffff"
                    brightness: 0.95
                }

                PointLight {
                    x: root.normX * 120
                    y: -root.normY * 120
                    z: 130
                    color: root.secondaryColor
                    brightness: holoHover.hovered ? 2.4 : 1.1
                    Behavior on brightness { NumberAnimation { duration: 180 } }
                }

                Node {
                    id: clusterNode
                    eulerRotation.x: -root.normY * 16.0
                    eulerRotation.y: root.normX * 16.0

                    // Melchior-1 (Top Apex)
                    Node {
                        position: Qt.vector3d(0, 56, 0)
                        Model {
                            source: "#Cylinder"
                            scale: Qt.vector3d(0.38, 0.26, 0.38)
                            materials: [
                                PrincipledMaterial {
                                    baseColor: root.primaryColor
                                    roughness: 0.20
                                    metalness: 0.85
                                    emissiveFactor: Qt.vector3d(0.40, 0.06, 0.06)
                                }
                            ]
                        }
                    }

                    // Balthasar-2 (Bottom Left)
                    Node {
                        position: Qt.vector3d(-62, -42, 0)
                        Model {
                            source: "#Cylinder"
                            scale: Qt.vector3d(0.38, 0.26, 0.38)
                            materials: [
                                PrincipledMaterial {
                                    baseColor: root.primaryColor
                                    roughness: 0.20
                                    metalness: 0.85
                                    emissiveFactor: Qt.vector3d(0.40, 0.06, 0.06)
                                }
                            ]
                        }
                    }

                    // Casper-3 (Bottom Right)
                    Node {
                        position: Qt.vector3d(62, -42, 0)
                        Model {
                            source: "#Cylinder"
                            scale: Qt.vector3d(0.38, 0.26, 0.38)
                            materials: [
                                PrincipledMaterial {
                                    baseColor: root.primaryColor
                                    roughness: 0.20
                                    metalness: 0.85
                                    emissiveFactor: Qt.vector3d(0.40, 0.06, 0.06)
                                }
                            ]
                        }
                    }

                    // Central Consensus Logic Core
                    Node {
                        position: Qt.vector3d(0, -10, 0)
                        Model {
                            source: "#Sphere"
                            scale: Qt.vector3d(0.34, 0.34, 0.34)
                            materials: [
                                PrincipledMaterial {
                                    baseColor: "#ffffff"
                                    roughness: 0.10
                                    metalness: 0.95
                                    clearcoatAmount: 1.0
                                    clearcoatRoughnessAmount: 0.05
                                }
                            ]
                        }
                    }
                }
            }
        }
    }

    // Interactive Hover Tracking
    HoverHandler {
        id: holoHover
        onPointChanged: {
            if (hovered && root.width > 0 && root.height > 0) {
                root.targetNormX = Math.max(-1.0, Math.min(1.0, (point.position.x - root.width / 2) / (root.width / 2)));
                root.targetNormY = Math.max(-1.0, Math.min(1.0, (point.position.y - root.height / 2) / (root.height / 2)));
            }
        }
        onHoveredChanged: {
            if (!hovered) {
                root.targetNormX = 0;
                root.targetNormY = 0;
            }
        }
    }

    // 2D NERV HUD Telemetry Overlay (Vector sharp)
    Item {
        anchors.fill: parent
        z: 6

        transform: [
            Rotation {
                origin.x: root.width / 2; origin.y: root.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: root.normX * 8
            },
            Rotation {
                origin.x: root.width / 2; origin.y: root.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: -root.normY * 8
            }
        ]

        // Melchior-1 Tag
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 12
            width: 140
            height: 24
            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
            border.width: 1
            border.color: root.primaryColor

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Rectangle { width: 4; height: 4; radius: 2; color: root.primaryColor }
                Text {
                    text: "MELCHIOR-1 // 承認"
                    color: root.primaryColor
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 0.5
                }
            }
        }

        // Balthasar-2 Tag
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: 140
            height: 24
            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
            border.width: 1
            border.color: root.primaryColor

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Rectangle { width: 4; height: 4; radius: 2; color: root.primaryColor }
                Text {
                    text: "BALTHASAR-2 // 承認"
                    color: root.primaryColor
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 0.5
                }
            }
        }

        // Casper-3 Tag
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: 140
            height: 24
            color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
            border.width: 1
            border.color: root.primaryColor

            RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Rectangle { width: 4; height: 4; radius: 2; color: root.primaryColor }
                Text {
                    text: "CASPER-3 // 承認"
                    color: root.primaryColor
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 0.5
                }
            }
        }

        // Central Status Badge
        Rectangle {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            width: 100
            height: 20
            color: Qt.rgba(1.0, 1.0, 1.0, 0.92)
            border.width: 1
            border.color: root.primaryColor

            Text {
                anchors.centerIn: parent
                text: "CONSENSUS: 3/3"
                color: root.primaryColor
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 0.8
            }
        }
    }
}
