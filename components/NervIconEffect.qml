import QtQuick

ShaderEffect {
    id: root

    property color tintColor: "#cc0000"
    property color bgColor: "#ffffff"
    property real contrast: 1.2

    fragmentShader: Qt.resolvedUrl("shaders/icon_tint.frag.qsb")
}
