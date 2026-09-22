import QtQuick

/**
 * StudioParallaxLayer.qml
 *
 * Multi-Plane Virtual Depth (Z-Parallax) Container.
 * Decouples child elements from the base surface plane based on normalized coordinates.
 */
Item {
    id: root

    default property alias content: root.data

    property real depth: 8.0 // Virtual depth factor
    property real normX: {
        var p = root.parent;
        while (p) {
            if (p.normX !== undefined) return p.normX;
            p = p.parent;
        }
        return 0.0;
    }
    property real normY: {
        var p = root.parent;
        while (p) {
            if (p.normY !== undefined) return p.normY;
            p = p.parent;
        }
        return 0.0;
    }

    transform: Translate {
        x: root.normX * root.depth
        y: root.normY * root.depth
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    }
}
