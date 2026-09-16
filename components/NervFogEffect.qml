import QtQuick

Item {
    id: root

    property alias sourceItem: shaderSource.sourceItem
    property real fogDensity: 0.50
    property real fogSpeed: 0.85
    property color fogColor: "#cc0000"
    property real shimmerIntensity: 0.008
    property real scanlineAlpha: 0.06
    property bool running: true

    readonly property bool animating: root.running && root.visible && (root.opacity > 0.01)

    ShaderEffectSource {
        id: shaderSource
        visible: false
        hideSource: true
        live: root.animating
        recursive: false
    }

    ShaderEffect {
        anchors.fill: parent

        property real uTime: 0.0
        property real fogDensity: root.fogDensity
        property real fogSpeed: root.fogSpeed
        property color fogColor: root.fogColor
        property real shimmerIntensity: root.shimmerIntensity
        property real scanlineAlpha: root.scanlineAlpha
        property var source: shaderSource

        fragmentShader: Qt.resolvedUrl("shaders/moving_fog.frag.qsb")

        NumberAnimation on uTime {
            from: 0.0
            to: 1000.0
            duration: 1000000
            loops: Animation.Infinite
            running: root.animating
        }
    }
}
