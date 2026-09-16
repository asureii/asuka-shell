import QtQuick

Item {
    id: root

    property color primaryColor: "#cc0000"
    property color secondaryColor: "#cc0000"
    property color bgColor: "#ffffff"
    property real lineWidth: 1.0
    property real cellHeight: 14
    property bool isRight: false // false = left side, true = right side

    implicitWidth: 14
    implicitHeight: 300
    clip: true

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // Background
            ctx.fillStyle = root.bgColor;
            ctx.fillRect(0, 0, width, height);

            var w = width;
            var h = height;
            var step = root.cellHeight;

            // Outer thick accent border line
            ctx.strokeStyle = root.secondaryColor;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            if (!root.isRight) {
                ctx.moveTo(0.5, 0);
                ctx.lineTo(0.5, h);
            } else {
                ctx.moveTo(w - 0.5, 0);
                ctx.lineTo(w - 0.5, h);
            }
            ctx.stroke();

            // Inner boundary line
            ctx.strokeStyle = Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.4);
            ctx.lineWidth = 1.0;
            ctx.beginPath();
            if (!root.isRight) {
                ctx.moveTo(w - 0.5, 0);
                ctx.lineTo(w - 0.5, h);
            } else {
                ctx.moveTo(0.5, 0);
                ctx.lineTo(0.5, h);
            }
            ctx.stroke();

            // Uniform horizontal grid dividers & diagonal tactical ticks
            ctx.lineWidth = 0.8;
            for (var y = 0; y < h; y += step) {
                // Horizontal divider line
                ctx.strokeStyle = Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.45);
                ctx.beginPath();
                ctx.moveTo(0, y + 0.5);
                ctx.lineTo(w, y + 0.5);
                ctx.stroke();

                // Subtle diagonal tick inside cell
                var cellIndex = Math.floor(y / step);
                ctx.strokeStyle = Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.22);
                ctx.beginPath();
                if ((cellIndex % 2 === 0) ^ root.isRight) {
                    ctx.moveTo(1.5, y + 1.5);
                    ctx.lineTo(w - 1.5, y + step - 1.5);
                } else {
                    ctx.moveTo(w - 1.5, y + 1.5);
                    ctx.lineTo(1.5, y + step - 1.5);
                }
                ctx.stroke();
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onPrimaryColorChanged: canvas.requestPaint()
    onSecondaryColorChanged: canvas.requestPaint()
    onBgColorChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onCellHeightChanged: canvas.requestPaint()
    onIsRightChanged: canvas.requestPaint()
}
