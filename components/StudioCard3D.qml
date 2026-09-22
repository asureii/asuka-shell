import QtQuick
import QtQuick.Layouts

/**
 * StudioCard3D.qml
 *
 * Safe 2.5D Evangelion Studio Perspective Card wrapper.
 * Directly inherits StudioCard without QtQuick3D to eliminate
 * Wayland layer-shell proxy window SIGSEGV crashes in Quickshell while
 * maintaining 100% aesthetic fidelity to the Evangelion HUD design.
 */
StudioCard {
    id: root

    // Inherits all properties, transforms, specular lighting, and hover states from StudioCard.
}

