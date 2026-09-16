import QtQuick

Item {
    id: root

    property string framePath: Qt.resolvedUrl("../../../assets/vfx/wifi_glow_frames/frame_")
    property int fps: 30
    property int currentFrame: 1
    property bool running: true
    property bool connected: false

    // Frame ranges based on After Effects composition:
    // Frames 1-60: Searching wave loop (dot -> arc1 -> arc2 -> arc3), clean lines with no glow or pulse
    readonly property int loopStartFrame: 1
    readonly property int loopEndFrame: 60

    // Frames 121-136: Connection pulse rising to peak glow
    // Frame 136: Peak red glow aura with all 3 arcs + dot illuminated
    readonly property int pulseStartFrame: 121
    readonly property int glowFrame: 136

    property bool isPulsing: false

    readonly property bool animating: running && root.visible && (root.opacity > 0.01) && (!connected || isPulsing)

    width: 44
    height: 44

    function pad3(n) {
        if (n < 10) return "00" + n;
        if (n < 100) return "0" + n;
        return "" + n;
    }

    function triggerPulse() {
        isPulsing = true;
        currentFrame = pulseStartFrame;
    }

    onConnectedChanged: {
        if (connected) {
            // When connecting to WiFi: trigger pulse and stay glowing
            triggerPulse();
        } else {
            // When disconnected: loop searching waves without pulse or glow
            isPulsing = false;
            currentFrame = loopStartFrame;
        }
    }

    Component.onCompleted: {
        if (connected) {
            currentFrame = glowFrame;
            isPulsing = false;
        } else {
            currentFrame = loopStartFrame;
        }
    }

    Image {
        id: spriteImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        source: root.framePath + root.pad3(root.currentFrame) + ".png"
        cache: true
        smooth: true
        asynchronous: false
    }

    Timer {
        id: animTimer
        interval: Math.max(16, Math.round(1000 / Math.max(1, root.fps)))
        running: root.animating
        repeat: true
        onTriggered: {
            if (root.connected) {
                if (root.isPulsing) {
                    if (root.currentFrame < root.glowFrame) {
                        root.currentFrame += 1;
                    } else {
                        root.currentFrame = root.glowFrame;
                        root.isPulsing = false; // Pulse complete; stays glowing!
                    }
                } else {
                    root.currentFrame = root.glowFrame;
                }
            } else {
                // Loop searching wave animation (frames 1 to 60)
                if (root.currentFrame < root.loopEndFrame && root.currentFrame >= root.loopStartFrame) {
                    root.currentFrame += 1;
                } else {
                    root.currentFrame = root.loopStartFrame;
                }
            }
        }
    }
}
