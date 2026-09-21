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

    property real centerTopWidth: 560
    property real centerMidWidth: 620

    readonly property real midX: width / 2
    readonly property real centerMidLeftX: midX - centerMidWidth / 2
    readonly property real centerMidRightX: midX + centerMidWidth / 2
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
            var wy = h - wh; // Top Y of wings
            var lc = root.leftChamferWidth;
            var rc = root.rightChamferWidth;

            var cmlX = root.centerMidLeftX;
            var cmrX = root.centerMidRightX;
            var ctlX = root.centerTopLeftX;
            var ctrX = root.centerTopRightX;

            // 1. LEFT & RIGHT WINGS BACKGROUND FILL (WHITE WITH GRID)
            ctx.save();
            ctx.beginPath();
            // Left wing path
            ctx.moveTo(0, h);
            ctx.lineTo(lc, wy);
            ctx.lineTo(cmlX, wy);
            ctx.lineTo(cmlX, h);
            ctx.closePath();

            // Right wing path
            ctx.moveTo(cmrX, h);
            ctx.lineTo(cmrX, wy);
            ctx.lineTo(w - rc, wy);
            ctx.lineTo(w, h);
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
            for (var gy = wy + 4; gy < h; gy += 4) {
                ctx.moveTo(0, gy);
                ctx.lineTo(w, gy);
            }
            ctx.stroke();

            // Faint vertical guide ticks
            ctx.beginPath();
            for (var gx = 20; gx < w; gx += 20) {
                ctx.moveTo(gx, wy);
                ctx.lineTo(gx, h);
            }
            ctx.stroke();

            ctx.restore();

            // 2. CENTER HEXAGON / TRAPEZOID POD FILL (SOLID RED POD)
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(cmlX, h);
            ctx.lineTo(cmlX, wy);
            ctx.lineTo(ctlX, 0);
            ctx.lineTo(ctrX, 0);
            ctx.lineTo(cmrX, wy);
            ctx.lineTo(cmrX, h);
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

            // Left wing top outline
            ctx.beginPath();
            ctx.moveTo(0, h);
            ctx.lineTo(lc, wy);
            ctx.lineTo(cmlX, wy);
            ctx.stroke();

            // Right wing top outline
            ctx.beginPath();
            ctx.moveTo(cmrX, wy);
            ctx.lineTo(w - rc, wy);
            ctx.lineTo(w, h);
            ctx.stroke();

            // Bottom screen baseline
            ctx.beginPath();
            ctx.moveTo(0, h);
            ctx.lineTo(w, h);
            ctx.stroke();

            // Wing hazard notches
            ctx.strokeStyle = root.accentColor;
            ctx.lineWidth = 2;

            // Left wing start notch
            ctx.beginPath();
            ctx.moveTo(lc + 4, wy + 3);
            ctx.lineTo(lc + 14, wy + 3);
            ctx.stroke();

            // Right wing end notch
            ctx.beginPath();
            ctx.moveTo(w - rc - 14, wy + 3);
            ctx.lineTo(w - rc - 4, wy + 3);
            ctx.stroke();

            ctx.restore();

            // 4. CENTER POD WHITE BORDER OUTLINE
            ctx.save();
            ctx.strokeStyle = root.hexBorderColor;
            ctx.lineWidth = root.strokeWidth;
            ctx.lineJoin = "miter";
            ctx.miterLimit = 4;

            ctx.beginPath();
            ctx.moveTo(cmlX, h);
            ctx.lineTo(cmlX, wy);
            ctx.lineTo(ctlX, 0);
            ctx.lineTo(ctrX, 0);
            ctx.lineTo(cmrX, wy);
            ctx.lineTo(cmrX, h);
            ctx.stroke();

            ctx.restore();

            // 5. CENTER WHITE TACTICAL CROSSHAIR (+)
            var crossX = w / 2;
            var crossY = 6;
            var crossSize = 3.5;

            ctx.save();
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 1.2;
            ctx.beginPath();
            ctx.moveTo(crossX - crossSize, crossY);
            ctx.lineTo(crossX + crossSize, crossY);
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
