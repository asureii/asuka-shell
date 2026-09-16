import QtQuick

Item {
    id: root

    visible: NervSettings.hexHudEnabled

    property color gridColor: "#cc0000"
    property real gridOpacity: 0.12
    property real lineWidth: 1.0
    property real hexRadius: 24
    property color cellFillColor: "transparent"

    implicitWidth: 300
    implicitHeight: 200
    clip: true

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var r = root.hexRadius;
            var h = Math.sqrt(3) * r;
            var wStep = 1.5 * r;
            var hStep = h;

            ctx.lineWidth = root.lineWidth;
            ctx.strokeStyle = Qt.rgba(root.gridColor.r, root.gridColor.g, root.gridColor.b, root.gridOpacity);

            var hasFill = root.cellFillColor !== "transparent" && root.cellFillColor.a > 0;
            if (hasFill) {
                ctx.fillStyle = root.cellFillColor;
            }

            var cols = Math.ceil(width / wStep) + 2;
            var rows = Math.ceil(height / hStep) + 2;

            ctx.beginPath();
            for (var c = -1; c < cols; c++) {
                for (var row = -1; row < rows; row++) {
                    var cx = c * wStep;
                    var cy = row * hStep + ((Math.abs(c) % 2 !== 0) ? (h / 2) : 0);

                    for (var i = 0; i < 6; i++) {
                        var angle = (i * 60) * Math.PI / 180;
                        var vx = cx + r * Math.cos(angle);
                        var vy = cy + r * Math.sin(angle);
                        if (i === 0) {
                            ctx.moveTo(vx, vy);
                        } else {
                            ctx.lineTo(vx, vy);
                        }
                    }
                    ctx.closePath();
                }
            }
            if (hasFill) {
                ctx.fill();
            }
            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onGridColorChanged: canvas.requestPaint()
    onGridOpacityChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onHexRadiusChanged: canvas.requestPaint()
    onCellFillColorChanged: canvas.requestPaint()
}
