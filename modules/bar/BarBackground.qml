import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color fillColor: "#ffffff"
    property color hexFillColor: "#cc0000"
    property color hexBorderColor: "#ffffff"
    property color strokeColor: "#cc0000"
    property color accentColor: "#cc0000"
    property color gridColor: Qt.rgba(0.8, 0.0, 0.0, 0.08)
    property real strokeWidth: 1.5

    // Geometric proportions
    property real wingHeight: 34
    property real leftChamferWidth: 34
    property real rightChamferWidth: 34

    property real centerTopWidth: 170
    property real centerMidWidth: 230
    property real centerBottomWidth: 170
    property real centerBottomY: height - 1

    readonly property real midX: width / 2
    readonly property real centerMidLeftX: midX - centerMidWidth / 2
    readonly property real centerMidRightX: midX + centerMidWidth / 2
    readonly property real centerBottomLeftX: midX - centerBottomWidth / 2
    readonly property real centerBottomRightX: midX + centerBottomWidth / 2
    readonly property real centerTopLeftX: midX - centerTopWidth / 2
    readonly property real centerTopRightX: midX + centerTopWidth / 2

    // Main Vector Canvas for Crisp HUD Outlines
    Canvas {
        id: bgCanvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var w = width;
            var h = height;
            var wh = root.wingHeight;
            var lc = root.leftChamferWidth;
            var rc = root.rightChamferWidth;

            var cmlX = root.centerMidLeftX;
            var cmrX = root.centerMidRightX;
            var cblX = root.centerBottomLeftX;
            var cbrX = root.centerBottomRightX;
            var cby = root.centerBottomY;

            var ctlX = root.centerTopLeftX;
            var ctrX = root.centerTopRightX;

            // 1. LEFT & RIGHT WINGS BACKGROUND FILL (WHITE WITH GRID)
            ctx.save();
            ctx.beginPath();
            // Left wing path
            ctx.moveTo(0, 0);
            ctx.lineTo(ctlX, 0);
            ctx.lineTo(cmlX, wh);
            ctx.lineTo(lc, wh);
            ctx.closePath();

            // Right wing path
            ctx.moveTo(ctrX, 0);
            ctx.lineTo(w, 0);
            ctx.lineTo(w - rc, wh);
            ctx.lineTo(cmrX, wh);
            ctx.closePath();

            // Solid Background for wings only
            ctx.fillStyle = root.fillColor;
            ctx.fill();

            // Clip to draw subtle tactical grid pattern inside wings only
            ctx.clip();

            // Subtle Scanline / Grid Effect
            ctx.strokeStyle = root.gridColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (var gy = 4; gy < wh; gy += 4) {
                ctx.moveTo(0, gy);
                ctx.lineTo(w, gy);
            }
            ctx.stroke();

            // Faint vertical guide ticks
            ctx.beginPath();
            for (var gx = 20; gx < w; gx += 20) {
                ctx.moveTo(gx, 0);
                ctx.lineTo(gx, wh);
            }
            ctx.stroke();

            ctx.restore();

            // 2. CENTER HEXAGON FILL (SOLID RED POD)
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(ctlX, 0);
            ctx.lineTo(ctrX, 0);
            ctx.lineTo(cmrX, wh);
            ctx.lineTo(cbrX, cby);
            ctx.lineTo(cblX, cby);
            ctx.lineTo(cmlX, wh);
            ctx.closePath();

            ctx.fillStyle = root.hexFillColor;
            ctx.fill();

            // Subtle dark tactical grid inside the red hex pod
            ctx.clip();
            ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.18);
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (var hgy = 4; hgy < h; hgy += 4) {
                ctx.moveTo(cmlX - 10, hgy);
                ctx.lineTo(cmrX + 10, hgy);
            }
            ctx.stroke();

            ctx.beginPath();
            for (var hgx = cmlX; hgx <= cmrX; hgx += 16) {
                ctx.moveTo(hgx, 0);
                ctx.lineTo(hgx, h);
            }
            ctx.stroke();

            ctx.restore();

            // 3. WINGS RED BORDER OUTLINES
            ctx.save();
            ctx.strokeStyle = root.strokeColor;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineJoin = "miter";
            ctx.miterLimit = 4;

            // Left wing bottom outline
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(lc, wh);
            ctx.lineTo(cmlX, wh);
            ctx.stroke();

            // Right wing bottom outline
            ctx.beginPath();
            ctx.moveTo(cmrX, wh);
            ctx.lineTo(w - rc, wh);
            ctx.lineTo(w, 0);
            ctx.stroke();

            // Top screen baseline for left & right wings
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(ctlX, 0);
            ctx.moveTo(ctrX, 0);
            ctx.lineTo(w, 0);
            ctx.stroke();

            // Wing hazard notches
            ctx.strokeStyle = root.accentColor;
            ctx.lineWidth = 2;

            // Left wing start notch
            ctx.beginPath();
            ctx.moveTo(lc + 4, wh - 3);
            ctx.lineTo(lc + 14, wh - 3);
            ctx.stroke();

            // Right wing end notch
            ctx.beginPath();
            ctx.moveTo(w - rc - 14, wh - 3);
            ctx.lineTo(w - rc - 4, wh - 3);
            ctx.stroke();

            ctx.restore();

            // 4. CENTER HEXAGON WHITE BORDER OUTLINE
            ctx.save();
            ctx.strokeStyle = root.hexBorderColor;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineJoin = "miter";
            ctx.miterLimit = 4;

            ctx.beginPath();
            ctx.moveTo(ctlX, 0);
            ctx.lineTo(ctrX, 0);
            ctx.lineTo(cmrX, wh);
            ctx.lineTo(cbrX, cby);
            ctx.lineTo(cblX, cby);
            ctx.lineTo(cmlX, wh);
            ctx.closePath();
            ctx.stroke();

            ctx.restore();

            // 5. CENTER WHITE TACTICAL CROSSHAIR (+) AS IN REFERENCE
            var crossX = w / 2;
            var crossY = wh;
            var crossSize = 5;

            ctx.save();
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            // Horizontal bar
            ctx.moveTo(crossX - crossSize, crossY);
            ctx.lineTo(crossX + crossSize, crossY);
            // Vertical bar
            ctx.moveTo(crossX, crossY - crossSize);
            ctx.lineTo(crossX, crossY + crossSize);
            ctx.stroke();

            ctx.restore();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onFillColorChanged: bgCanvas.requestPaint()
    onHexFillColorChanged: bgCanvas.requestPaint()
    onHexBorderColorChanged: bgCanvas.requestPaint()
    onStrokeColorChanged: bgCanvas.requestPaint()
    onAccentColorChanged: bgCanvas.requestPaint()
}
