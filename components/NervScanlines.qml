import QtQuick

// NervScanlines — High-Visibility Front-Layered Continuous Vertical CRT Sweep
//
// 1. Positioned at top z-index (z: 99) in the very front above all elements
// 2. High-visibility multi-stop gradient wash with intense amber-red luminescence
// 3. 1px CRT scanline raster and phosphor micro-flicker

Item {
    id: root

    z: 99
    visible: NervSettings.crtEnabled

    property int duration: 4000
    property real glowIntensity: 1.0
    property color glowColor: "#cc0000"
    property color edgeColor: "#990000"

    // Alias for backwards compatibility
    property alias sweepDuration: root.duration

    clip: true

    // ============================================================
    // HIGH-VISIBILITY MOVING GRADIENT SWEEP
    // ============================================================
    Rectangle {
        id: scanGlow
        width: parent.width
        height: Math.max(220, parent.height * 0.45)

        gradient: Gradient {
            GradientStop { position: 0.00; color: "transparent" }
            GradientStop { position: 0.20; color: Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, 0.10 * root.glowIntensity) }
            GradientStop { position: 0.38; color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.25 * root.glowIntensity) }
            GradientStop { position: 0.50; color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.38 * root.glowIntensity) }
            GradientStop { position: 0.62; color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.25 * root.glowIntensity) }
            GradientStop { position: 0.80; color: Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, 0.10 * root.glowIntensity) }
            GradientStop { position: 1.00; color: "transparent" }
        }

        NumberAnimation on y {
            from: -scanGlow.height
            to: root.height
            duration: root.duration
            loops: Animation.Infinite
            running: root.visible && (root.opacity > 0.01)
            easing.type: Easing.Linear
        }
    }
}
