import QtQuick

Item {
    id: root

    property string assetPath: Qt.resolvedUrl("../assets/opening/asuka_believable.png")
    property real fogDensity: 0.50
    property color fogColor: "#cc0000"
    property real fogSpeed: 0.85
    property real shimmerIntensity: 0.008
    property real scanlineAlpha: 0.06
    property bool running: true

    Image {
        id: rawAsset
        anchors.fill: parent
        source: root.assetPath
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    NervFogEffect {
        anchors.fill: rawAsset
        sourceItem: rawAsset
        fogDensity: root.fogDensity
        fogColor: root.fogColor
        fogSpeed: root.fogSpeed
        shimmerIntensity: root.shimmerIntensity
        scanlineAlpha: root.scanlineAlpha
        running: root.running
    }
}
