import QtQuick

Item {
    id: root

    property color stripeColor: "#cc0000"
    property color bgColor: "#ffffff"
    property real stripeWidth: 14
    property real stripeGap: 14
    property bool reverse: false      // Invert slant angle
    property bool scrollLeft: false   // Scroll direction: false = right, true = left
    property bool animated: true
    property int duration: 1000       // Milliseconds per stride
    property real offset: 0

    implicitHeight: 14
    implicitWidth: 100
    clip: true

    readonly property real step: stripeWidth + stripeGap
    readonly property bool animating: root.animated && root.visible && (root.opacity > 0.01)

    NumberAnimation on offset {
        from: 0
        to: root.step
        duration: root.duration
        loops: Animation.Infinite
        running: root.animating
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
    }

    Canvas {
        id: canvas
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: -root.step * 2
        anchors.rightMargin: -root.step * 2

        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        transform: Translate {
            x: (root.scrollLeft ? -1 : 1) * (root.offset % root.step)
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var w = root.stripeWidth;
            var gap = root.stripeGap;
            var s = w + gap;
            var slant = height; // 45 degree angle

            ctx.fillStyle = root.stripeColor;
            ctx.beginPath();

            if (!root.reverse) {
                for (var x = -slant - s * 2; x < width + slant + s * 2; x += s) {
                    ctx.moveTo(x + slant, 0);
                    ctx.lineTo(x + slant + w, 0);
                    ctx.lineTo(x + w, height);
                    ctx.lineTo(x, height);
                    ctx.closePath();
                }
            } else {
                for (var x = -slant - s * 2; x < width + slant + s * 2; x += s) {
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x + w, 0);
                    ctx.lineTo(x + w + slant, height);
                    ctx.lineTo(x + slant, height);
                    ctx.closePath();
                }
            }
            ctx.fill();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onStripeColorChanged: canvas.requestPaint()
    onBgColorChanged: canvas.requestPaint()
    onStripeWidthChanged: canvas.requestPaint()
    onStripeGapChanged: canvas.requestPaint()
    onReverseChanged: canvas.requestPaint()
}
