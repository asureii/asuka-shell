import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Item {
    id: root

    // Selection & Deliberation Properties
    property string selectedPid: ""
    property string selectedProcName: ""
    property bool isDeliberating: false
    property bool consensusPassed: true
    property string consensusText: "3-0 UNANIMOUS"
    property string consensusStatus: "APPROVED // 承認"

    // Node Telemetry & Votes
    property var melchiorData: ({ name: "MELCHIOR • 01", role: "SCIENTIST // 科学者", vote: "AGREE", thought: "Logical consistency and computational efficiency validated." })
    property var balthasarData: ({ name: "BALTHASAR • 02", role: "MOTHER // 母親", vote: "AGREE", thought: "System safety and critical fail-safe protocols verified." })
    property var casperData: ({ name: "CASPER • 03", role: "WOMAN // 女性", vote: "AGREE", thought: "User intent and operational necessity approved." })

    signal terminateProcessRequested(string pid)
    signal reDeliberateRequested()

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color passColor: "#00aa44"
    readonly property color denyColor: "#ff1100"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.95)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Multi-plane tilt tracking
    property real normX: 0.0
    property real normY: 0.0

    transform: [
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root.normX * 4.0
            Behavior on angle { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        },
        Rotation {
            origin.x: root.width / 2
            origin.y: root.height / 2
            axis { x: 1; y: 0; z: 0 }
            angle: -root.normY * 4.0
            Behavior on angle { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        }
    ]

    // ============================================================
    // 1. TOP HEADER: PROJECT EVANGELION & TACTICAL SCAN EFFECT
    // ============================================================
    Item {
        id: titleBlock
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: baseTitleText.implicitWidth
        height: baseTitleText.implicitHeight + 14

        Text {
            id: baseTitleText
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: "PROJECT EVANGELION"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 22
            font.bold: true
            font.letterSpacing: 6
        }

        // Tactical Laser Scan Band
        Item {
            id: scanBand
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: baseTitleText.width
            height: 12
            clip: true

            property real scanY: -height
            y: scanY

            NumberAnimation on scanY {
                from: -scanBand.height
                to: baseTitleText.height + 4
                duration: 2400
                loops: Animation.Infinite
                running: root.visible
                easing.type: Easing.InOutSine
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -scanBand.y
                text: "PROJECT EVANGELION"
                color: root.highlight
                font.family: root.hudFont
                font.pixelSize: 22
                font.bold: true
                font.letterSpacing: 6
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: "MAGI-01 // TRI-CORE CONSENSUS DELIBERATION ENGINE"
            color: root.fgDim
            font.family: root.hudFont
            font.pixelSize: 7
            font.bold: true
            font.letterSpacing: 1.5
        }
    }

    // ============================================================
    // 2. MAIN 2D VECTOR CANVAS: THE 3 MAGI POLYGONS
    // ============================================================
    Item {
        id: magiStage
        anchors.top: titleBlock.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: authCapsule.top
        anchors.bottomMargin: 8

        readonly property real cx: width / 2
        readonly property real pad: 14
        readonly property real leftEdge: pad
        readonly property real rightEdge: width - pad
        readonly property real yBase: 26

        readonly property real balW: width * 0.44
        readonly property real balLeft: cx - balW / 2
        readonly property real balRight: cx + balW / 2
        readonly property real balStraightH: height * 0.22
        readonly property real balTaperY: yBase + height * 0.35
        readonly property real balBottomHalfW: balW * 0.20

        readonly property real nodeTop: balTaperY + 22
        readonly property real nodeBot: height - 16
        readonly property real centerGap: 24

        readonly property real taperSlope: (balTaperY - yBase - balStraightH) / (balW / 2 - balBottomHalfW)
        readonly property real cChamferDx: (cx - centerGap - leftEdge) * 0.38
        readonly property real chamferH: taperSlope * cChamferDx

        Canvas {
            id: triadCanvas
            anchors.fill: parent
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            property bool balHov: balMouse.containsMouse
            property bool casperHov: casperMouse.containsMouse
            property bool melchiorHov: melchiorMouse.containsMouse
            property bool isDelib: root.isDeliberating

            onBalHovChanged: requestPaint()
            onCasperHovChanged: requestPaint()
            onMelchiorHovChanged: requestPaint()
            onIsDelibChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = magiStage.cx;
                var leftEdge = magiStage.leftEdge;
                var rightEdge = magiStage.rightEdge;
                var yBase = magiStage.yBase;

                var balLeft = magiStage.balLeft;
                var balRight = magiStage.balRight;
                var balStraightH = magiStage.balStraightH;
                var balTaperY = magiStage.balTaperY;
                var balBottomHalfW = magiStage.balBottomHalfW;

                var nodeTop = magiStage.nodeTop;
                var nodeBot = magiStage.nodeBot;
                var centerGap = magiStage.centerGap;
                var chamferH = magiStage.chamferH;

                var normalStroke = root.primary;
                var normalFill = Qt.rgba(1.0, 1.0, 1.0, 0.95);
                var hoverFill = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08);

                ctx.lineWidth = 1.5;

                // --------------------------------------------------
                // 1. TOP-LEFT: 質 問 BOX
                // --------------------------------------------------
                var qBoxW = balLeft - leftEdge;
                var qBoxH = 34;
                ctx.beginPath();
                ctx.moveTo(leftEdge, yBase);
                ctx.lineTo(balLeft, yBase);
                ctx.strokeStyle = normalStroke;
                ctx.stroke();
                ctx.fillStyle = normalFill;
                ctx.fillRect(leftEdge, yBase, qBoxW, qBoxH);
                ctx.strokeRect(leftEdge, yBase, qBoxW, qBoxH);

                // --------------------------------------------------
                // 2. TOP-RIGHT: 解 決 BOX & 合 意 BOX
                // --------------------------------------------------
                var rBoxW = rightEdge - balRight;
                var rBoxH = 34;
                ctx.beginPath();
                ctx.moveTo(balRight, yBase);
                ctx.lineTo(rightEdge, yBase);
                ctx.stroke();
                ctx.fillStyle = normalFill;
                ctx.fillRect(balRight, yBase, rBoxW, rBoxH);
                ctx.strokeRect(balRight, yBase, rBoxW, rBoxH);

                var gBoxW = Math.min(100, rBoxW * 0.78);
                var gBoxH = 28;
                var gBoxX = balRight + (rBoxW - gBoxW) / 2;
                var gBoxY = yBase + rBoxH + 10;
                ctx.fillStyle = normalFill;
                ctx.fillRect(gBoxX, gBoxY, gBoxW, gBoxH);
                ctx.strokeRect(gBoxX, gBoxY, gBoxW, gBoxH);

                // --------------------------------------------------
                // 3. BALTHASAR • 02 (Top Trapezoid)
                // --------------------------------------------------
                ctx.strokeStyle = balHov ? root.highlight : normalStroke;
                ctx.fillStyle = balHov ? hoverFill : normalFill;
                ctx.lineWidth = balHov ? 2.0 : 1.5;
                ctx.beginPath();
                ctx.moveTo(balLeft, yBase);
                ctx.lineTo(balRight, yBase);
                ctx.lineTo(balRight, yBase + balStraightH);
                ctx.lineTo(cx + balBottomHalfW, balTaperY);
                ctx.lineTo(cx - balBottomHalfW, balTaperY);
                ctx.lineTo(balLeft, yBase + balStraightH);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();

                // --------------------------------------------------
                // 4. CASPER • 03 (Bottom-Left Chamfered Polygon)
                // --------------------------------------------------
                var cL = leftEdge;
                var cR = cx - centerGap;
                var cTop = nodeTop;
                var cBot = nodeBot;
                var cChamferStartX = cL + (cR - cL) * 0.62;

                ctx.strokeStyle = casperHov ? root.highlight : normalStroke;
                ctx.fillStyle = casperHov ? hoverFill : normalFill;
                ctx.lineWidth = casperHov ? 2.0 : 1.5;
                ctx.beginPath();
                ctx.moveTo(cL, cTop);
                ctx.lineTo(cChamferStartX, cTop);
                ctx.lineTo(cR, cTop + chamferH);
                ctx.lineTo(cR, cBot);
                ctx.lineTo(cL, cBot);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();

                // --------------------------------------------------
                // 5. MELCHIOR • 01 (Bottom-Right Chamfered Polygon)
                // --------------------------------------------------
                var mL = cx + centerGap;
                var mR = rightEdge;
                var mTop = nodeTop;
                var mBot = nodeBot;
                var mChamferStartX = mR - (mR - mL) * 0.62;

                ctx.strokeStyle = melchiorHov ? root.highlight : normalStroke;
                ctx.fillStyle = melchiorHov ? hoverFill : normalFill;
                ctx.lineWidth = melchiorHov ? 2.0 : 1.5;
                ctx.beginPath();
                ctx.moveTo(mChamferStartX, mTop);
                ctx.lineTo(mR, mTop);
                ctx.lineTo(mR, mBot);
                ctx.lineTo(mR, mBot);
                ctx.lineTo(mL, mBot);
                ctx.lineTo(mL, mTop + chamferH);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();

                // --------------------------------------------------
                // 6. Central Crosshair & Connecting Laser Conduits
                // --------------------------------------------------
                ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.50);
                ctx.lineWidth = 1.0;
                var crossY = (nodeTop + nodeBot) / 2 - 4;
                ctx.beginPath();
                ctx.moveTo(cx - 8, crossY); ctx.lineTo(cx + 8, crossY);
                ctx.moveTo(cx, crossY - 8); ctx.lineTo(cx, crossY + 8);
                ctx.stroke();
            }
        }

        // ========================================================
        // AUXILIARY BOXES CONTENT: 質問, 解決, 合意
        // ========================================================
        // 質問 Box
        Text {
            x: magiStage.leftEdge
            y: magiStage.yBase
            width: magiStage.balLeft - magiStage.leftEdge
            height: 34
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "質 問"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 15
            font.bold: true
            font.letterSpacing: 6
        }

        // Telemetry under 質問
        ColumnLayout {
            x: magiStage.leftEdge + 4
            y: magiStage.yBase + 40
            spacing: 2

            Text { text: "CODE: 473"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
            Text { text: "FILE: MAGI_SYS"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
            Text { text: "EXTENTION: 3023"; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
            Text { text: "EX_MODE: ON"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
            Text { text: "PRIORITY: AAA"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
        }

        // 解決 Box
        Text {
            x: magiStage.balRight
            y: magiStage.yBase
            width: magiStage.rightEdge - magiStage.balRight
            height: 34
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "解 決"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 15
            font.bold: true
            font.letterSpacing: 6
        }

        // 合意 Box
        Rectangle {
            readonly property real rBoxW: magiStage.rightEdge - magiStage.balRight
            readonly property real gBW: Math.min(100, rBoxW * 0.78)
            x: magiStage.balRight + (rBoxW - gBW) / 2
            y: magiStage.yBase + 34 + 10
            width: gBW
            height: 28
            color: "transparent"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "合 意"
                    color: root.consensusPassed ? root.primary : root.denyColor
                    font.family: root.hudFont
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 3
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.consensusText
                    color: root.consensusPassed ? root.primary : root.denyColor
                    font.family: root.hudFont
                    font.pixelSize: 6
                    font.bold: true
                }
            }
        }

        // ========================================================
        // NODE 2: BALTHASAR • 02 (TOP TRAPEZOID CONTENT)
        // ========================================================
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: magiStage.yBase + 6
            width: magiStage.balW * 0.82
            height: magiStage.balTaperY - magiStage.yBase - 12

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2
                width: parent.width

                // Header & Persona
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Text {
                        text: "BALTHASAR • 02"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Text {
                        text: "母親"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "マギ・バルタザール // MOTHER CORE"
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                // Dynamic Vote Pill
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 120
                    height: 16
                    radius: 2
                    color: root.isDeliberating
                        ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                        : (root.balthasarData.vote === "AGREE"
                            ? Qt.rgba(0.0, 0.65, 0.25, 0.15)
                            : Qt.rgba(0.9, 0.1, 0.0, 0.15))
                    border.width: 1
                    border.color: root.isDeliberating
                        ? root.primary
                        : (root.balthasarData.vote === "AGREE" ? root.passColor : root.denyColor)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: root.isDeliberating ? root.highlight : (root.balthasarData.vote === "AGREE" ? root.passColor : root.denyColor)
                        }
                        Text {
                            text: root.isDeliberating
                                ? "DELIBERATING..."
                                : (root.balthasarData.vote === "AGREE" ? "AGREE // 承認" : "DENY // 否認")
                            color: root.isDeliberating ? root.primary : (root.balthasarData.vote === "AGREE" ? root.passColor : root.denyColor)
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }

                // Thought snippet
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isDeliberating ? "Analyzing system fail-safe protocols..." : root.balthasarData.thought
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
            }

            MouseArea {
                id: balMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Subtitle under Balthasar taper
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: magiStage.balTaperY + 3
            text: "MAGI"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 2.5
        }

        // ========================================================
        // NODE 3: CASPER • 03 (BOTTOM-LEFT CONTENT)
        // ========================================================
        Item {
            x: magiStage.leftEdge + 6
            y: magiStage.nodeTop + 6
            width: magiStage.cx - magiStage.centerGap - magiStage.leftEdge - 12
            height: magiStage.nodeBot - magiStage.nodeTop - 12

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3
                width: parent.width * 0.92

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Text {
                        text: "CASPER • 03"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Text {
                        text: "女性"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "マギ・カスパー // WOMAN CORE"
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                // Dynamic Vote Pill
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 110
                    height: 16
                    radius: 2
                    color: root.isDeliberating
                        ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                        : (root.casperData.vote === "AGREE"
                            ? Qt.rgba(0.0, 0.65, 0.25, 0.15)
                            : Qt.rgba(0.9, 0.1, 0.0, 0.15))
                    border.width: 1
                    border.color: root.isDeliberating
                        ? root.primary
                        : (root.casperData.vote === "AGREE" ? root.passColor : root.denyColor)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: root.isDeliberating ? root.highlight : (root.casperData.vote === "AGREE" ? root.passColor : root.denyColor)
                        }
                        Text {
                            text: root.isDeliberating
                                ? "DELIBERATING..."
                                : (root.casperData.vote === "AGREE" ? "AGREE // 承認" : "DENY // 否認")
                            color: root.isDeliberating ? root.primary : (root.casperData.vote === "AGREE" ? root.passColor : root.denyColor)
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }

                // Thought snippet
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isDeliberating ? "Assessing intent and risk trade-off..." : root.casperData.thought
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                // Memory / Telemetry Readout
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "SECURITY THREAT: 0.02% // PRAGMATIC PASS"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 6
                    font.bold: true
                }
            }

            MouseArea {
                id: casperMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }

        // Central Telemetry between Casper & Melchior
        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: (magiStage.nodeTop + magiStage.nodeBot) / 2 + 10
            spacing: 1

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.consensusStatus
                color: root.consensusPassed ? root.primary : root.denyColor
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1.0
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "DELIBERATION CORE"
                color: root.fgDim
                font.family: root.hudFont
                font.pixelSize: 6
                font.bold: true
            }
        }

        // ========================================================
        // NODE 1: MELCHIOR • 01 (BOTTOM-RIGHT CONTENT)
        // ========================================================
        Item {
            x: magiStage.cx + magiStage.centerGap + 6
            y: magiStage.nodeTop + 6
            width: magiStage.rightEdge - (magiStage.cx + magiStage.centerGap) - 12
            height: magiStage.nodeBot - magiStage.nodeTop - 12

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 3
                width: parent.width * 0.92

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4

                    Text {
                        text: "MELCHIOR • 01"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Text {
                        text: "科学者"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "マギ・メルキオール // SCIENTIST CORE"
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                // Dynamic Vote Pill
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 110
                    height: 16
                    radius: 2
                    color: root.isDeliberating
                        ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                        : (root.melchiorData.vote === "AGREE"
                            ? Qt.rgba(0.0, 0.65, 0.25, 0.15)
                            : Qt.rgba(0.9, 0.1, 0.0, 0.15))
                    border.width: 1
                    border.color: root.isDeliberating
                        ? root.primary
                        : (root.melchiorData.vote === "AGREE" ? root.passColor : root.denyColor)

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: root.isDeliberating ? root.highlight : (root.melchiorData.vote === "AGREE" ? root.passColor : root.denyColor)
                        }
                        Text {
                            text: root.isDeliberating
                                ? "DELIBERATING..."
                                : (root.melchiorData.vote === "AGREE" ? "AGREE // 承認" : "DENY // 否認")
                            color: root.isDeliberating ? root.primary : (root.melchiorData.vote === "AGREE" ? root.passColor : root.denyColor)
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }

                // Thought snippet
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isDeliberating ? "Validating execution and load efficiency..." : root.melchiorData.thought
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                // Computation / Load Telemetry
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "EFFICIENCY: 99.8% // LOGIC NOMINAL"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 6
                    font.bold: true
                }
            }

            MouseArea {
                id: melchiorMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }

    // ============================================================
    // 3. BOTTOM AUTHORIZATION & QUESTION CAPSULE
    // ============================================================
    Rectangle {
        id: authCapsule
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        height: 46
        color: "#ffffff"
        border.width: 1
        border.color: root.selectedPid.length > 0 ? root.primary : root.itemBorder

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "ACCESS CODE: [ " + (root.selectedPid ? "PID: " + root.selectedPid : "READY // AWAITING TARGET") + " ]"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                Text {
                    text: root.selectedPid
                        ? ("QUESTION: terminate process '" + root.selectedProcName + "'?")
                        : "QUESTION: select a process in Task Monitor or dispatch a command"
                    color: root.selectedPid ? root.highlight : root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            // Re-deliberate query button
            Rectangle {
                visible: root.selectedPid.length > 0
                Layout.preferredWidth: 80
                Layout.preferredHeight: 22
                color: reDelibMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary

                Text {
                    anchors.centerIn: parent
                    text: root.isDeliberating ? "VOTING..." : "RE-VOTE"
                    color: reDelibMouse.containsMouse ? "#ffffff" : root.primary
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                MouseArea {
                    id: reDelibMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reDeliberateRequested()
                }
            }

            // Tactical Terminate Button (Unlocked on MAGI Consensus)
            Rectangle {
                visible: root.selectedPid.length > 0
                Layout.preferredWidth: 100
                Layout.preferredHeight: 24
                color: !root.consensusPassed
                    ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15)
                    : (killMouse.containsMouse ? root.highlight : root.primary)
                border.width: 1
                border.color: root.primary

                Text {
                    anchors.centerIn: parent
                    text: root.consensusPassed ? "[ TERMINATE ]" : "[ DENIED ]"
                    color: !root.consensusPassed ? root.fgDim : "#ffffff"
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                MouseArea {
                    id: killMouse
                    anchors.fill: parent
                    hoverEnabled: root.consensusPassed
                    cursorShape: root.consensusPassed ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        if (root.consensusPassed && root.selectedPid.length > 0) {
                            root.terminateProcessRequested(root.selectedPid);
                        }
                    }
                }
            }
        }
    }

    // Global Mouse Area for 3D Tilt Tracking
    MouseArea {
        id: stageMouse
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: (m) => {
            root.normX = (m.x - width / 2) / (width / 2);
            root.normY = (m.y - height / 2) / (height / 2);
        }
        onExited: {
            root.normX = 0;
            root.normY = 0;
        }
    }
}
