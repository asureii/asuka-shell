import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "../../components"
import "tabs"

PanelWindow {
    id: root

    property int currentTabIndex: 6 // Defaults to Tab 07 (Eva Suite / Operations)

    readonly property color bg: "#fcfcfc"
    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color fg: "#ffffff"
    readonly property color textMain: "#1a0000"
    readonly property color textMuted: Qt.rgba(0.1, 0.0, 0.0, 0.65)
    readonly property string fontFamily: "Liberation Sans, JetBrainsMono Nerd Font"

    readonly property var tabs: [
        { id: "01", key: "1", icon: "󰕮", name: "DASHBOARD", subtitle: "TELEMETRY & ENV", title: "TACTICAL DASHBOARD // COMMAND & ENVIRONMENT", status: "ENVIRONMENT: ACTIVE" },
        { id: "02", key: "2", icon: "󰖩", name: "NETWORK RADAR", subtitle: "TRAFFIC & PACKETS", title: "NETWORK TRAFFIC & PACKET RADAR", status: "WIFI: CONNECTED" },
        { id: "03", key: "3", icon: "󰒋", name: "PROCESS MANAGER", subtitle: "MAGI DISPATCH", title: "PROTOCOL & SYSTEM THREADS", status: "SYS: NOMINAL" },
        { id: "04", key: "4", icon: "󰎆", name: "SOUND & MEDIA", subtitle: "AUDIO & EVATUBE", title: "TACTICAL AUDIO MATRIX & MEDIA DECK", status: "PIPEWIRE AUDIO: ONLINE" },
        { id: "05", key: "5", icon: "󰢮", name: "HARDWARE VITALS", subtitle: "NEURAL TELEMETRY", title: "HARDWARE ARCHITECTURE & NEURAL TELEMETRY", status: "SYSTEM: ARCH LINUX // NOMINAL" },
        { id: "06", key: "6", icon: "󰸉", name: "WALLPAPERS", subtitle: "RECON MATRIX", title: "WALLPAPERS & VISUAL RECON MATRIX", status: "15 RECON ASSETS LOADED" },
        { id: "07", key: "7", icon: "󰒋", name: "EVA SUITE", subtitle: "ECOSYSTEM & RPC", title: "ECOSYSTEM CONTROL & DOWNLINK MATRIX", status: "EVACORE: ONLINE" },
        { id: "08", key: "8", icon: "󰀻", name: "PROTOCOL LAUNCHER", subtitle: "APPLICATIONS", title: "TACTICAL PROTOCOL & APPS LAUNCHER", status: "DAEMON: READY" }
    ]

    // ============================================================
    // TACTICAL ROTARY WHEEL STATE & FUNCTIONS
    // ============================================================
    property bool isWheelCollapsed: false
    property real wheelStepCount: currentTabIndex
    property real animatedStep: wheelStepCount
    Behavior on animatedStep {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }
    readonly property real animatedWheelAngle: -animatedStep * 45
    property real scrollAccumulator: 0

    function getTabDiff(tabIndex) {
        var raw = (tabIndex - root.animatedStep) % root.tabs.length;
        while (raw < -4) raw += root.tabs.length;
        while (raw >= 4) raw -= root.tabs.length;
        return raw;
    }

    function advanceNextTab() {
        root.wheelStepCount += 1;
        root.currentTabIndex = ((Math.round(root.wheelStepCount) % root.tabs.length) + root.tabs.length) % root.tabs.length;
    }

    function advancePrevTab() {
        root.wheelStepCount -= 1;
        root.currentTabIndex = ((Math.round(root.wheelStepCount) % root.tabs.length) + root.tabs.length) % root.tabs.length;
    }

    function selectTabByWheelIndex(targetIdx) {
        var currentMod = ((Math.round(root.wheelStepCount) % root.tabs.length) + root.tabs.length) % root.tabs.length;
        var diff = targetIdx - currentMod;
        if (diff > root.tabs.length / 2) diff -= root.tabs.length;
        if (diff < -root.tabs.length / 2) diff += root.tabs.length;
        root.wheelStepCount += diff;
        root.currentTabIndex = targetIdx;
    }

    function handleWheel(wheel) {
        root.scrollAccumulator += wheel.angleDelta.y;
        if (root.scrollAccumulator >= 60) {
            root.advanceNextTab();
            root.scrollAccumulator = 0;
        } else if (root.scrollAccumulator <= -60) {
            root.advancePrevTab();
            root.scrollAccumulator = 0;
        }
    }

    onCurrentTabIndexChanged: {
        var currentMod = ((Math.round(root.wheelStepCount) % root.tabs.length) + root.tabs.length) % root.tabs.length;
        if (currentMod !== root.currentTabIndex) {
            var diff = root.currentTabIndex - currentMod;
            if (diff > root.tabs.length / 2) diff -= root.tabs.length;
            if (diff < -root.tabs.length / 2) diff += root.tabs.length;
            root.wheelStepCount += diff;
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (root.visible && !root.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Unanchored PanelWindow is centered on screen by layer-shell
    implicitWidth: 1220
    implicitHeight: 700
    color: "transparent"

    visible: false

    // ============================================================
    // SCANLINE WIPE & HOLOGRAM REVEAL ANIMATION STATE
    // ============================================================
    property real revealProgress: 0.0
    property real beamIgnition: 0.0
    property real beamOpacity: 0.0
    property real phosphorFlash: 0.0
    property real reticleDeploy: 0.0
    property real hudDeploy: 0.0
    property bool isClosing: false
    readonly property bool isAnimating: openAnim.running || closeAnim.running

    function open() {
        if (closeAnim.running) closeAnim.stop();
        isClosing = false;
        root.visible = true;
        beamOpacity = 1.0;
        openProgressAnim.from = root.revealProgress;
        openAnim.restart();
    }

    function close() {
        if (openAnim.running) openAnim.stop();
        isClosing = true;
        beamOpacity = 1.0;
        closeProgressAnim.from = root.revealProgress;
        closeAnim.restart();
    }

    function toggle() {
        if (root.visible && !isClosing && root.revealProgress > 0.1) {
            close();
        } else {
            open();
        }
    }

    onVisibleChanged: {
        if (root.visible) {
            overlayContainer.forceActiveFocus();
            if (!root.isAnimating && root.revealProgress < 0.99) {
                root.open();
            }
        } else {
            root.revealProgress = 0.0;
            root.beamIgnition = 0.0;
            root.beamOpacity = 0.0;
            root.phosphorFlash = 0.0;
            root.reticleDeploy = 0.0;
            root.hudDeploy = 0.0;
            root.isClosing = false;
        }
    }

    ParallelAnimation {
        id: openAnim
        onStarted: {
            root.visible = true;
            root.beamOpacity = 1.0;
            overlayContainer.forceActiveFocus();
        }
        onFinished: {
            root.revealProgress = 1.0;
            root.beamIgnition = 1.0;
            root.beamOpacity = 0.0;
            root.phosphorFlash = 0.0;
            root.reticleDeploy = 1.0;
            root.hudDeploy = 1.0;
            overlayContainer.forceActiveFocus();
        }

        // 1. Scissor wipe down
        NumberAnimation {
            id: openProgressAnim
            target: root
            property: "revealProgress"
            from: 0.0
            to: 1.0
            duration: 340
            easing.type: Easing.OutCubic
        }

        // 2. Beam horizontal ignition flare (expands from center out in 90ms)
        NumberAnimation {
            target: root
            property: "beamIgnition"
            from: 0.15
            to: 1.0
            duration: 90
            easing.type: Easing.OutQuad
        }

        // 3. CRT excitation flash (phosphor strike, 160ms)
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "phosphorFlash"
                from: 1.0
                to: 0.0
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        // 4. Tactical corner reticle brackets lock into position (310ms, OutBack)
        SequentialAnimation {
            PauseAnimation { duration: 30 }
            NumberAnimation {
                target: root
                property: "reticleDeploy"
                from: 0.0
                to: 1.0
                duration: 310
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
        }

        // 5. Staggered HUD spatial deployment (wheel + banner + content)
        SequentialAnimation {
            PauseAnimation { duration: 50 }
            NumberAnimation {
                target: root
                property: "hudDeploy"
                from: 0.0
                to: 1.0
                duration: 290
                easing.type: Easing.OutCubic
            }
        }

        // 6. Laser beam dissipation at the bottom
        SequentialAnimation {
            PauseAnimation { duration: 260 }
            NumberAnimation {
                target: root
                property: "beamOpacity"
                from: 1.0
                to: 0.0
                duration: 80
                easing.type: Easing.OutQuad
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        onStarted: {
            root.beamOpacity = 1.0;
            root.beamIgnition = 1.0;
        }
        onFinished: {
            root.revealProgress = 0.0;
            root.beamIgnition = 0.0;
            root.beamOpacity = 0.0;
            root.phosphorFlash = 0.0;
            root.reticleDeploy = 0.0;
            root.hudDeploy = 0.0;
            root.isClosing = false;
            root.visible = false;
        }

        NumberAnimation {
            id: closeProgressAnim
            target: root
            property: "revealProgress"
            from: 1.0
            to: 0.0
            duration: 200
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: root
            property: "hudDeploy"
            from: 1.0
            to: 0.0
            duration: 180
            easing.type: Easing.InQuad
        }

        NumberAnimation {
            target: root
            property: "reticleDeploy"
            from: 1.0
            to: 0.0
            duration: 150
            easing.type: Easing.InQuad
        }
    }

    // ============================================================
    // REVEAL CLIP MASK (Top-to-Bottom Scissor Reveal)
    // ============================================================
    Item {
        id: revealMask
        width: 1220
        height: Math.round(root.revealProgress * root.implicitHeight)
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        Rectangle {
            id: overlayContainer
            width: 1220
            height: root.implicitHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            focus: true
            radius: 0
            color: root.bg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.65)
            clip: true

            // Directional 1px Overhead Specular Highlight Rim
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.85)
                z: 97
            }

            // Keyboard handling: Keys 1 to 8 switch tabs, Arrow Up/Down cycles, C toggles wheel collapse, Escape closes overlay
            Keys.onPressed: function(event) {
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
                    var targetIdx = event.key - Qt.Key_1;
                    if (targetIdx >= 0 && targetIdx < root.tabs.length) {
                        root.selectTabByWheelIndex(targetIdx);
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Up) {
                    root.advancePrevTab();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    root.advanceNextTab();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab) {
                    root.advancePrevTab();
                    event.accepted = true;
                } else if (event.key === Qt.Key_C) {
                    root.isWheelCollapsed = !root.isWheelCollapsed;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }

        // ==========================================
        // CRT PHOSPHOR POWER SURGE / HOLOGRAPHIC STRIKE
        // ==========================================
        Rectangle {
            id: crtStrike
            anchors.fill: parent
            z: 98
            visible: root.phosphorFlash > 0.005
            opacity: root.phosphorFlash * 0.30
            gradient: Gradient {
                GradientStop { position: 0.00; color: "#ffffff" }
                GradientStop { position: 0.12; color: "#ff2222" }
                GradientStop { position: 0.40; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45) }
                GradientStop { position: 0.60; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45) }
                GradientStop { position: 0.88; color: "#ff2222" }
                GradientStop { position: 1.00; color: "#ffffff" }
            }
        }

        // Transient CRT raster sync line during phosphor strike
        Rectangle {
            id: strikeRasterLine
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            y: Math.round((1.0 - root.phosphorFlash) * parent.height)
            color: "#ffffff"
            z: 98
            visible: root.phosphorFlash > 0.05
            opacity: root.phosphorFlash * 0.70
        }

        // Honeycomb HUD Grid
        NervHudGrid {
            anchors.fill: parent
            anchors.topMargin: 14
            anchors.bottomMargin: 14
        }

        // Left side faint ambient glow
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            width: 160
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10) }
                GradientStop { position: 0.5; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Right side faint ambient glow
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            width: 140
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.6; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03) }
                GradientStop { position: 1.0; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10) }
            }
        }

        // Top Hazard Lines
        NervHazardLines {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 14
            stripeColor: root.primary
            bgColor: root.bg
        }

        // Bottom Hazard Lines
        NervHazardLines {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 14
            stripeColor: root.primary
            bgColor: root.bg
            scrollLeft: true
        }

        // Left Tactical Gridded Border Strip
        NervGrid {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            width: 14
            primaryColor: root.primary
            secondaryColor: root.secondary
            isRight: false
        }

        // Right Tactical Gridded Border Strip
        NervGrid {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            width: 14
            primaryColor: root.primary
            secondaryColor: root.secondary
            isRight: true
        }

        // ============================================================
        // TACTICAL FLOATING SEMI-OCTAGON ROTARY WHEEL (LEFT EDGE)
        // ============================================================
        Item {
            id: tacticalSemiOctagonWheel
            z: 60
            width: 316
            height: 440
            anchors.verticalCenter: parent.verticalCenter
            x: root.isWheelCollapsed ? (-width + 48) : 0

            transform: Translate {
                x: Math.round(-36 * (1.0 - root.hudDeploy))
            }

            Behavior on x {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            // Semi-Octagon Tactical Canvas (Beveled Facets, Concentric Tracks, Graduation Ticks & Hub)
            Canvas {
                id: semiOctagonCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image
                renderStrategy: Canvas.Immediate

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var cy = height / 2; // 220
                    var cx = 68;
                    var rOuter = 210;
                    var rGrad = 186;
                    var rOrbit = 140;
                    var rHub = 56;

                    var c22 = 0.92388;
                    var s22 = 0.38268;
                    var c67 = 0.38268;
                    var s67 = 0.92388;

                    // Helper to generate 6 vertices of outer semi-octagon anchored to left edge (x=0)
                    function getSemiOctagonPts(r) {
                        return [
                            { x: 0,            y: cy - r * s67 },
                            { x: cx + r * c67, y: cy - r * s67 },
                            { x: cx + r * c22, y: cy - r * s22 },
                            { x: cx + r * c22, y: cy + r * s22 },
                            { x: cx + r * c67, y: cy + r * s67 },
                            { x: 0,            y: cy + r * s67 }
                        ];
                    }

                    // Helper to generate 8 vertices of a full regular octagon centered at (cx, cy)
                    function getFullOctagonPts(r) {
                        return [
                            { x: cx - r * c67, y: cy - r * s67 },
                            { x: cx + r * c67, y: cy - r * s67 },
                            { x: cx + r * c22, y: cy - r * s22 },
                            { x: cx + r * c22, y: cy + r * s22 },
                            { x: cx + r * c67, y: cy + r * s67 },
                            { x: cx - r * c67, y: cy + r * s67 },
                            { x: cx - r * c22, y: cy + r * s22 },
                            { x: cx - r * c22, y: cy - r * s22 }
                        ];
                    }

                    // 1. Outer Halo Semi-Octagon (thin glow)
                    var haloPts = getSemiOctagonPts(rOuter + 4);
                    ctx.beginPath();
                    ctx.moveTo(haloPts[0].x, haloPts[0].y);
                    for (var h = 1; h < haloPts.length; h++) {
                        ctx.lineTo(haloPts[h].x, haloPts[h].y);
                    }
                    ctx.lineTo(0, haloPts[0].y);
                    ctx.closePath();
                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    // 2. Main Semi-Octagon Body (Cream Fill & Crimson Perimeter)
                    var outerPts = getSemiOctagonPts(rOuter);
                    ctx.beginPath();
                    ctx.moveTo(outerPts[0].x, outerPts[0].y);
                    for (var o = 1; o < outerPts.length; o++) {
                        ctx.lineTo(outerPts[o].x, outerPts[o].y);
                    }
                    ctx.lineTo(0, outerPts[0].y);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.96);
                    ctx.fill();
                    ctx.strokeStyle = "#cc0000";
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    // 3. Inner Graduation Track Semi-Octagon
                    var gradPts = getSemiOctagonPts(rGrad);
                    ctx.beginPath();
                    ctx.moveTo(gradPts[0].x, gradPts[0].y);
                    for (var g = 1; g < gradPts.length; g++) {
                        ctx.lineTo(gradPts[g].x, gradPts[g].y);
                    }
                    ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.35);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    // 4. Orbit Guide Semi-Octagon
                    var orbitPts = getSemiOctagonPts(rOrbit);
                    ctx.beginPath();
                    ctx.moveTo(orbitPts[0].x, orbitPts[0].y);
                    for (var ob = 1; ob < orbitPts.length; ob++) {
                        ctx.lineTo(orbitPts[ob].x, orbitPts[ob].y);
                    }
                    ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.15);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    // 5. Inner Hub Regular Octagon Base (Centered at cx, cy)
                    var hubPts = getFullOctagonPts(rHub);
                    ctx.beginPath();
                    ctx.moveTo(hubPts[0].x, hubPts[0].y);
                    for (var hp = 1; hp < hubPts.length; hp++) {
                        ctx.lineTo(hubPts[hp].x, hubPts[hp].y);
                    }
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.96);
                    ctx.fill();
                    ctx.strokeStyle = "#cc0000";
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    // Hub Accent Inner Chamfer (Concentric Regular Octagon)
                    var hubAccentPts = getFullOctagonPts(rHub - 5);
                    ctx.beginPath();
                    ctx.moveTo(hubAccentPts[0].x, hubAccentPts[0].y);
                    for (var ha = 1; ha < hubAccentPts.length; ha++) {
                        ctx.lineTo(hubAccentPts[ha].x, hubAccentPts[ha].y);
                    }
                    ctx.closePath();
                    ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.22);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    // 6. Radial Spokes from Hub Corners to Outer Facets
                    for (var sp = 1; sp <= 4; sp++) {
                        ctx.beginPath();
                        ctx.moveTo(hubPts[sp].x, hubPts[sp].y);
                        ctx.lineTo(outerPts[sp].x, outerPts[sp].y);
                        ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.20);
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }
                    // Left spoke ties from hub corners to left border
                    ctx.beginPath();
                    ctx.moveTo(hubPts[0].x, hubPts[0].y);
                    ctx.lineTo(hubPts[0].x, outerPts[0].y);
                    ctx.moveTo(hubPts[5].x, hubPts[5].y);
                    ctx.lineTo(hubPts[5].x, outerPts[5].y);
                    ctx.moveTo(hubPts[6].x, hubPts[6].y);
                    ctx.lineTo(0, hubPts[6].y);
                    ctx.moveTo(hubPts[7].x, hubPts[7].y);
                    ctx.lineTo(0, hubPts[7].y);
                    ctx.strokeStyle = Qt.rgba(0.8, 0.0, 0.0, 0.20);
                    ctx.lineWidth = 1;
                    ctx.stroke();

                    // 7. Tactical Graduation Ticks along each outer facet
                    for (var f = 0; f < outerPts.length - 1; f++) {
                        var pA = outerPts[f];
                        var pB = outerPts[f + 1];
                        var pGradA = gradPts[f];
                        var pGradB = gradPts[f + 1];

                        var numTicks = (f === 2) ? 12 : 7;
                        for (var t = 1; t < numTicks; t++) {
                            var frac = t / numTicks;
                            var tx1 = pA.x + (pB.x - pA.x) * frac;
                            var ty1 = pA.y + (pB.y - pA.y) * frac;
                            var tx2 = pGradA.x + (pGradB.x - pGradA.x) * frac;
                            var ty2 = pGradA.y + (pGradB.y - pGradA.y) * frac;

                            var isMaj = (t % 3 === 0);
                            var tlen = isMaj ? 1.0 : 0.45;
                            ctx.beginPath();
                            ctx.moveTo(tx1, ty1);
                            ctx.lineTo(tx1 + (tx2 - tx1) * tlen, ty1 + (ty2 - ty1) * tlen);
                            ctx.strokeStyle = isMaj ? "#cc0000" : Qt.rgba(0.8, 0.0, 0.0, 0.35);
                            ctx.lineWidth = isMaj ? 1.5 : 1;
                            ctx.stroke();
                        }
                    }

                    // 8. Active Facet Right Edge Bracket (Highlighted Crimson on Vertical Face)
                    ctx.beginPath();
                    ctx.moveTo(outerPts[2].x, outerPts[2].y);
                    ctx.lineTo(outerPts[3].x, outerPts[3].y);
                    ctx.strokeStyle = "#ff2222";
                    ctx.lineWidth = 3.5;
                    ctx.stroke();
                }
            }

            Connections {
                target: root
                function onCurrentTabIndexChanged() {
                    if (semiOctagonCanvas.available) semiOctagonCanvas.requestPaint();
                }
            }

            // 8 Orbiting Tab Badges along the Semi-Octagon Perimeter
            Repeater {
                model: root.tabs

                Item {
                    id: tabNode
                    readonly property int tabIndex: index
                    readonly property real diff: root.getTabDiff(tabIndex)
                    readonly property real angleDeg: diff * 32
                    readonly property real angleRad: angleDeg * Math.PI / 180
                    readonly property bool isSelected: root.currentTabIndex === tabIndex
                    readonly property real orbitRadius: 140
                    readonly property real cx: 68

                    width: isSelected ? 44 : 36
                    height: isSelected ? 44 : 36

                    // Position along semi-octagon arc centered at (cx, 220)
                    x: Math.round(cx + Math.cos(angleRad) * orbitRadius - width / 2)
                    y: Math.round(220 + Math.sin(angleRad) * orbitRadius - height / 2)

                    // Smooth scale & fade towards edges
                    scale: Math.max(0.65, Math.min(1.0, 0.65 + 0.35 * Math.max(0.0, Math.cos(angleRad)))) * (0.85 + 0.15 * root.hudDeploy)
                    opacity: {
                        var c = Math.cos(angleRad);
                        if (c <= 0.05) return 0.0;
                        return Math.max(0.0, Math.min(1.0, c * 2.2 - 0.35));
                    }
                    visible: opacity > 0.02
                    z: isSelected ? 25 : Math.round(20 - Math.abs(diff) * 3)

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: tabNode.isSelected ? root.primary : (nodeMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15) : Qt.rgba(1.0, 1.0, 1.0, 0.95))
                        border.width: tabNode.isSelected ? 2 : 1
                        border.color: tabNode.isSelected ? "#ff2222" : (nodeMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.40))

                        // Tactile spring scale & smooth color feedback
                        scale: nodeMouse.pressed ? 0.93 : (tabNode.isSelected ? 1.08 : (nodeMouse.containsMouse ? 1.06 : 1.0))
                        Behavior on scale {
                            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Magnetic Cursor Pull
                        property real targetX: 0
                        property real targetY: 0
                        transform: Translate {
                            x: parent.targetX
                            y: parent.targetY
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        }

                        // Top Specular Highlight Edge
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.leftMargin: 2; anchors.rightMargin: 2
                            height: 1
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.6)
                            visible: tabNode.isSelected || nodeMouse.containsMouse
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                color: tabNode.isSelected ? "#ffffff" : root.primary
                                font.family: root.fontFamily
                                font.pixelSize: tabNode.isSelected ? 14 : 11
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.key
                                color: tabNode.isSelected ? "#ffffff" : root.primary
                                font.family: root.fontFamily
                                font.pixelSize: tabNode.isSelected ? 8 : 7
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: nodeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPositionChanged: (m) => {
                                parent.targetX = Math.max(-4, Math.min(4, (m.x - width / 2) * 0.22));
                                parent.targetY = Math.max(-4, Math.min(4, (m.y - height / 2) * 0.22));
                            }
                            onExited: {
                                parent.targetX = 0;
                                parent.targetY = 0;
                            }

                            onClicked: {
                                root.selectTabByWheelIndex(tabNode.tabIndex);
                            }
                            onWheel: wheel => root.handleWheel(wheel)
                        }
                    }

                }
            }

            // Fixed Center Hub (Mounted & Centered in Full Octagon)
            Item {
                id: centerHub
                x: Math.round(68 - width / 2)
                anchors.verticalCenter: parent.verticalCenter
                width: 96
                height: 96
                visible: !root.isWheelCollapsed
                z: 28

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    // EVA Badge
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 48
                        height: 14
                        color: root.primary
                        radius: 2

                        Text {
                            anchors.centerIn: parent
                            text: NervSettings.hudBranding
                            color: "#ffffff"
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }

                    // Tab ID
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "TAB " + root.tabs[root.currentTabIndex].id
                        color: root.primary
                        font.family: root.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 0.6
                    }

                    // Tab Name
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 64
                        text: root.tabs[root.currentTabIndex].name
                        color: root.primary
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.3
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        lineHeight: 1.05
                    }

                    Item { height: 1; width: 1 }

                    // Collapse Toggle Button
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 50
                        height: 15
                        color: hubCollapseMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                        border.width: 1
                        border.color: root.primary
                        radius: 2

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                text: "◀"
                                color: hubCollapseMouse.containsMouse ? "#ffffff" : root.primary
                                font.pixelSize: 7
                                font.bold: true
                            }
                            Text {
                                text: "HIDE"
                                color: hubCollapseMouse.containsMouse ? "#ffffff" : root.primary
                                font.family: root.fontFamily
                                font.pixelSize: 6
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: hubCollapseMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.isWheelCollapsed = true
                        }
                    }
                }
            } // end centerHub

            // Fixed Reticle Pointer at Apex (Points from active side of semi-octagon into panels)
            Item {
                id: focusReticle
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 264
                width: 48
                height: 24
                z: 30
                visible: !root.isWheelCollapsed

                // Red Pointer Arrow
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#cc0000";
                        ctx.beginPath();
                        ctx.moveTo(2, 6);
                        ctx.lineTo(12, 12);
                        ctx.lineTo(2, 18);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                // HUD Tag
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    height: 16
                    width: 32
                    color: root.primary
                    border.width: 1
                    border.color: root.primary

                    Text {
                        anchors.centerIn: parent
                        text: "FOCUS"
                        color: "#ffffff"
                        font.family: root.fontFamily
                        font.pixelSize: 7
                        font.bold: true
                        font.letterSpacing: 0.6
                    }
                }
            }

            // Collapsed Handle Edge Indicator (Visible when collapsed)
            Rectangle {
                id: collapsedHandle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 180
                color: Qt.rgba(1.0, 1.0, 1.0, 0.96)
                border.width: 1.5
                border.color: root.primary
                radius: 4
                visible: root.isWheelCollapsed
                z: 35

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "▲"
                        color: root.primary
                        font.pixelSize: 8
                        opacity: 0.7
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 34
                        height: 34
                        radius: 4
                        color: root.primary
                        border.width: 1
                        border.color: "#ff2222"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.tabs[root.currentTabIndex].icon
                                color: "#ffffff"
                                font.family: root.fontFamily
                                font.pixelSize: 11
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.tabs[root.currentTabIndex].key
                                color: "#ffffff"
                                font.family: root.fontFamily
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "▼"
                        color: root.primary
                        font.pixelSize: 8
                        opacity: 0.7
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 28
                        height: 18
                        color: handleExpandMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15)
                        border.width: 1
                        border.color: root.primary

                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: handleExpandMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 8
                            font.bold: true
                        }

                        MouseArea {
                            id: handleExpandMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.isWheelCollapsed = false
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.isWheelCollapsed = false
                    onWheel: wheel => root.handleWheel(wheel)
                }
            }

            // Global Wheel Area across the Semi-Octagon Widget
            MouseArea {
                id: wheelInteractionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.isWheelCollapsed ? Qt.PointingHandCursor : Qt.ArrowCursor
                z: -1 // Behind buttons & nodes

                onClicked: {
                    if (root.isWheelCollapsed) {
                        root.isWheelCollapsed = false;
                    }
                }

                onWheel: wheel => {
                    root.handleWheel(wheel);
                }
            }
        }

        // ==========================================
        // MAIN TACTICAL DECK (FULL WIDTH)
        // ==========================================
        Item {
            id: mainDeck
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 60
            anchors.rightMargin: 20
            anchors.topMargin: 20
            anchors.bottomMargin: 20

            // Top Subheader / Active Tab Breadcrumb Banner
            Rectangle {
                id: subHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32
                radius: 0
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                border.width: 1
                border.color: root.primary
                opacity: Math.min(1.0, root.hudDeploy * 1.5)
                transform: Translate {
                    y: Math.round(-12 * (1.0 - root.hudDeploy))
                }

                // Left Inner Tactical Badge Box
                Rectangle {
                    id: innerBadge
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 8
                    width: tabTitleText.implicitWidth + 20
                    radius: 0
                    color: root.primary
                    border.width: 1
                    border.color: root.primary

                    Text {
                        id: tabTitleText
                        anchors.centerIn: parent
                        text: "[ TAB " + root.tabs[root.currentTabIndex].id + " // " + NervSettings.hudBranding + " // " + root.tabs[root.currentTabIndex].title + " ]"
                        color: "#ffffff"
                        font.family: root.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                }

                // Tactical End Bracket Ticks
                Rectangle {
                    id: tick1
                    anchors.left: innerBadge.right
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 8
                    width: 2
                    color: root.primary
                }

                Rectangle {
                    id: tick2
                    anchors.left: tick1.right
                    anchors.leftMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 8
                    width: 1
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.5)
                }

                // Right-aligned status text
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tabs[root.currentTabIndex].status
                    color: root.secondary
                    font.family: root.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.0
                }
            }

            // Main Content Area
            Item {
                id: contentArea
                anchors.top: subHeader.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                opacity: Math.min(1.0, Math.max(0.0, (root.hudDeploy - 0.15) * 1.18))
                transform: Translate {
                    y: Math.round(16 * (1.0 - root.hudDeploy))
                }

                DashboardTab {
                    opacity: (root.visible && root.currentTabIndex === 0) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                NetworkRadarTab {
                    opacity: (root.visible && root.currentTabIndex === 1) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                EvaProtocolTab {
                    opacity: (root.visible && root.currentTabIndex === 2) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                SoundMediaTab {
                    opacity: (root.visible && root.currentTabIndex === 3) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                HardwareVitalsTab {
                    opacity: (root.visible && root.currentTabIndex === 4) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                WallpapersTab {
                    opacity: (root.visible && root.currentTabIndex === 5) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                EvaSuiteTab {
                    opacity: (root.visible && root.currentTabIndex === 6) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                ProtocolLauncherTab {
                    opacity: (root.visible && root.currentTabIndex === 7) ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }
            }
        }

        // ==========================================
        // CRT RADAR SWEEP OVERLAY (VERY FRONT)
        // ==========================================
        NervScanlines {
            z: 99
            anchors.fill: parent
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            sweepDuration: 4000
            glowIntensity: 1.0
        }
    } // end overlayContainer
} // end revealMask

    // ============================================================
    // TACTICAL RETICLE CORNER LOCKING FRAME (⌜ ⌝ ⌞ ⌟)
    // ============================================================
    Item {
        id: tacticalReticleFrame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 1220
        height: root.implicitHeight
        z: 90
        visible: (root.reticleDeploy > 0.01 || root.revealProgress > 0.01) && root.visible
        opacity: Math.min(1.0, root.reticleDeploy * 1.8)

        // Top-Left Reticle ⌜
        Item {
            id: reticleTL
            x: Math.round((1.0 - root.reticleDeploy) * 16)
            y: Math.round((1.0 - root.reticleDeploy) * 16)
            width: 80
            height: 32

            Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 24; height: 2; color: root.primary }
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 2; height: 24; color: root.primary }
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; width: 4; height: 4; color: "#ff2222" }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 4
                text: "LOC // NERV-01"
                color: root.primary
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 0.5
            }
        }

        // Top-Right Reticle ⌝
        Item {
            id: reticleTR
            x: parent.width - width - Math.round((1.0 - root.reticleDeploy) * 16)
            y: Math.round((1.0 - root.reticleDeploy) * 16)
            width: 80
            height: 32

            Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 24; height: 2; color: root.primary }
            Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 2; height: 24; color: root.primary }
            Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 4; height: 4; color: "#ff2222" }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 4
                text: "SYS // NOMINAL"
                color: root.primary
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 0.5
            }
        }

        // Bottom-Left Reticle ⌞
        Item {
            id: reticleBL
            x: Math.round((1.0 - root.reticleDeploy) * 16)
            y: parent.height - height - Math.round((1.0 - root.reticleDeploy) * 16)
            width: 80
            height: 32

            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 24; height: 2; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 2; height: 24; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; width: 4; height: 4; color: "#ff2222" }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: "MAGI // 01-MEL"
                color: root.primary
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 0.5
            }
        }

        // Bottom-Right Reticle ⌟
        Item {
            id: reticleBR
            x: parent.width - width - Math.round((1.0 - root.reticleDeploy) * 16)
            y: parent.height - height - Math.round((1.0 - root.reticleDeploy) * 16)
            width: 80
            height: 32

            Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 24; height: 2; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 2; height: 24; color: root.primary }
            Rectangle { anchors.bottom: parent.bottom; anchors.right: parent.right; width: 4; height: 4; color: "#ff2222" }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                text: "SYNC // 100%"
                color: root.primary
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
                font.letterSpacing: 0.5
            }
        }
    }

    // ============================================================
    // TACTICAL LASER SCANLINE REVEAL BEAM
    // ============================================================
    Item {
        id: scanlineBeam
        anchors.horizontalCenter: parent.horizontalCenter
        width: 1220
        height: 36
        y: Math.round(root.revealProgress * root.implicitHeight) - 34
        z: 100
        visible: (root.isAnimating || root.revealProgress < 1.0) && root.beamOpacity > 0.0
        opacity: root.beamOpacity

        transform: Scale {
            origin.x: scanlineBeam.width / 2
            origin.y: scanlineBeam.height / 2
            xScale: root.beamIgnition
        }

        // 1. Phosphor Trail (trailing glow behind the scanline, fading upward)
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: laserCore.top
            anchors.left: parent.left
            anchors.right: parent.right
            gradient: Gradient {
                GradientStop { position: 0.00; color: "transparent" }
                GradientStop { position: 0.50; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12) }
                GradientStop { position: 0.85; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.30) }
                GradientStop { position: 1.00; color: Qt.rgba(1.0, 0.25, 0.25, 0.60) }
            }
        }

        // 2. High-intensity Laser Beam (horizontal razor-sharp cutting edge)
        Rectangle {
            id: laserCore
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: "#ffffff" // Blinding white-hot energy core
            border.width: 1
            border.color: "#ff2222"
        }

        // 3. Central Ignition Flare Core (Intense white spark during opening)
        Rectangle {
            anchors.centerIn: laserCore
            width: Math.max(32, Math.round(180 * (1.0 - root.revealProgress)))
            height: 6
            radius: 3
            color: "#ffffff"
            border.width: 1
            border.color: "#ff2222"
            opacity: Math.max(0.0, 1.0 - root.revealProgress * 2.0)
            visible: opacity > 0.01
        }

        // 4. Laser Bloom Flare (ambient luminous glow)
        Rectangle {
            anchors.centerIn: laserCore
            width: parent.width
            height: 6
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1.0, 0.2, 0.2, 0.40)
        }

        // 5. Tactical Left & Right HUD Reticle Brackets
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.bottom: laserCore.top
            anchors.bottomMargin: 3
            spacing: 4

            Rectangle {
                width: 4
                height: 4
                color: "#ff2222"
            }

            Text {
                text: "◄ " + NervSettings.hudBranding + " REVEAL SCAN"
                color: "#ff2222"
                font.family: root.fontFamily
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1.0
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.bottom: laserCore.top
            anchors.bottomMargin: 3
            spacing: 4

            Text {
                text: "RADAR ACTIVE ►"
                color: "#ff2222"
                font.family: root.fontFamily
                font.pixelSize: 8
                font.bold: true
                font.letterSpacing: 1.0
            }

            Rectangle {
                width: 4
                height: 4
                color: "#ff2222"
            }
        }
    }
}
