import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../components"

PanelWindow {
    id: root

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color bg: "#ffffff"
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.96)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property color textMain: "#1a0000"
    readonly property color textMuted: Qt.rgba(0.1, 0.0, 0.0, 0.65)
    readonly property color textDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Model State
    property var allApps: []
    property var filteredApps: []
    property string filterQuery: ""
    property string selectedCategory: "ALL"
    property int selectedIndex: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }

    margins {
        top: 46
        left: (root.screen ? Math.round((root.screen.width - root.implicitWidth) / 2) : 0)
    }

    readonly property real cardHeight: 560
    implicitWidth: 500
    implicitHeight: Math.round(root.cardHeight * 1.06)

    mask: Region {
        item: popoutContainer
    }

    color: "transparent"
    visible: false

    property bool isOpen: false
    property real revealProgress: 0.0
    property real beamOpacity: 0.0

    ParallelAnimation {
        id: openAnim
        onStarted: {
            root.beamOpacity = 1.0;
        }
        onFinished: {
            root.revealProgress = 1.0;
            root.beamOpacity = 0.0;
            root.refreshApps();
        }
        NumberAnimation {
            id: openProgressAnim
            target: root
            property: "revealProgress"
            from: 0.0
            to: 1.0
            duration: 260
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: 160 }
            NumberAnimation {
                target: root
                property: "beamOpacity"
                from: 1.0
                to: 0.0
                duration: 100
                easing.type: Easing.OutQuad
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        onStarted: {
            root.beamOpacity = 1.0;
        }
        onFinished: {
            root.revealProgress = 0.0;
            root.beamOpacity = 0.0;
            if (!root.isOpen) {
                root.visible = false;
            }
        }
        NumberAnimation {
            id: closeProgressAnim
            target: root
            property: "revealProgress"
            from: 1.0
            to: 0.0
            duration: 180
            easing.type: Easing.InCubic
        }
    }

    function toggle() {
        if (!root.isOpen) root.open();
        else root.close();
    }

    function open() {
        if (typeof activeWorkspacePopout !== "undefined" && activeWorkspacePopout && activeWorkspacePopout.visible) {
            activeWorkspacePopout.close();
        }
        root.isOpen = true;
        root.visible = true;
        root.beamOpacity = 1.0;
        openProgressAnim.from = root.revealProgress;
        closeAnim.stop();
        openAnim.restart();
        searchInput.forceActiveFocus();
    }

    function close() {
        if (!root.visible || !root.isOpen) {
            root.isOpen = false;
            root.visible = false;
            return;
        }
        root.isOpen = false;
        root.beamOpacity = 1.0;
        closeProgressAnim.from = root.revealProgress;
        openAnim.stop();
        closeAnim.restart();
    }

    function refreshApps() {
        appScanner.running = true;
    }

    function setSearchQuery(text) {
        root.filterQuery = text;
        searchInput.text = text;
        root.updateFilteredApps();
    }

    function launchApp(app) {
        if (!app || !app.exec) return;
        NervAppSearch.incrementFrequency(app.id);
        Quickshell.execDetached(["bash", "-c", app.exec + " &"]);
        root.close();
    }

    function launchSelected() {
        if (root.filteredApps.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredApps.length) {
            root.launchApp(root.filteredApps[root.selectedIndex]);
        }
    }

    function updateFilteredApps() {
        root.filteredApps = NervAppSearch.search(root.filterQuery, root.allApps, root.selectedCategory);
        root.selectedIndex = 0;
    }

    Connections {
        target: NervAppSearch
        function onFrequenciesChanged() {
            root.updateFilteredApps();
        }
    }

    Component.onCompleted: {
        root.refreshApps();
    }

    onVisibleChanged: {
        if (root.visible) {
            root.filterQuery = "";
            root.selectedCategory = "ALL";
            searchInput.text = "";
            root.updateFilteredApps();
            searchInput.forceActiveFocus();
        }
    }

    // App Scanner Process
    Process {
        id: appScanner
        command: [Quickshell.shellPath("scripts/get_applications")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (Array.isArray(data)) {
                        root.allApps = data;
                        root.updateFilteredApps();
                    }
                } catch (e) {}
            }
        }
    }

    // Popout Container with Scanline Reveal Animation
    Item {
        id: popoutContainer
        width: parent.width
        height: Math.round(root.revealProgress * root.cardHeight)
        clip: true
        layer.enabled: openAnim.running || closeAnim.running
        layer.smooth: true

        Item {
            id: animContent
            width: parent.width
            height: root.cardHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            // Tactical Chamfered Frame Canvas with Trapezoid Cutout for Top Bar Pod
            Canvas {
                id: frameCanvas
                anchors.fill: parent
                renderTarget: Canvas.Image
                renderStrategy: Canvas.Immediate

                property real chamfer: 8
                property real strokeWidth: 2

                // Trapezoid Cutout Geometry
                // Mirrors center pod in BarBackground (centerMidWidth=260, centerBottomWidth=190, depth 41px)
                // With uniform ~7.4px lateral clearance and 5px bottom clearance
                property real cutoutTopW: 268
                property real cutoutBotW: 196
                property real cutoutDepth: 42

                // Bottom Trapezoid Base Geometry
                property real botSlopeW: 46
                property real botSlopeH: 36

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var w = width;
                    var h = height;
                    var cx = w / 2;
                    var c = chamfer;
                    var sw = strokeWidth;
                    var p = sw / 2;

                    var cth = cutoutTopW / 2;
                    var cbh = cutoutBotW / 2;
                    var cd = cutoutDepth;
                    var bsw = botSlopeW;
                    var bsh = botSlopeH;

                    function buildPath(offset) {
                        ctx.beginPath();
                        // 1. Top-left shoulder chamfer
                        ctx.moveTo(c + offset * 0.4, offset);
                        // 2. Left shoulder to cutout
                        ctx.lineTo(cx - cth - offset * 0.3, offset);
                        // 3. Cutout left slope (down-inward)
                        ctx.lineTo(cx - cbh - offset * 0.3, cd + offset);
                        // 4. Cutout bottom horizontal edge
                        ctx.lineTo(cx + cbh + offset * 0.3, cd + offset);
                        // 5. Cutout right slope (up-outward)
                        ctx.lineTo(cx + cth + offset * 0.3, offset);
                        // 6. Right shoulder
                        ctx.lineTo(w - c - offset * 0.4, offset);
                        // 7. Top-right chamfer
                        ctx.lineTo(w - offset, c + offset * 0.4);
                        // 8. Right vertical edge down to bottom slope
                        ctx.lineTo(w - offset, h - bsh - offset * 0.3);
                        // 9. Bottom-right trapezoid slope (down-inward)
                        ctx.lineTo(w - bsw - offset * 0.3, h - offset);
                        // 10. Bottom horizontal base
                        ctx.lineTo(bsw + offset * 0.3, h - offset);
                        // 11. Bottom-left trapezoid slope (up-outward)
                        ctx.lineTo(offset, h - bsh - offset * 0.3);
                        // 12. Left vertical edge up to top-left chamfer
                        ctx.lineTo(offset, c + offset * 0.4);
                        ctx.closePath();
                    }

                    // 1. Solid Background Fill
                    buildPath(0);
                    ctx.fillStyle = root.bg;
                    ctx.fill();

                    // 2. Tactical Grid Pattern (clipped strictly within polygon)
                    ctx.save();
                    buildPath(0);
                    ctx.clip();
                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06);
                    ctx.lineWidth = 1;
                    for (var gy = 10; gy < h; gy += 10) {
                        ctx.beginPath();
                        ctx.moveTo(0, gy);
                        ctx.lineTo(w, gy);
                        ctx.stroke();
                    }
                    for (var gx = 10; gx < w; gx += 10) {
                        ctx.beginPath();
                        ctx.moveTo(gx, 0);
                        ctx.lineTo(gx, h);
                        ctx.stroke();
                    }
                    ctx.restore();

                    // 3. Clear Inset Crimson Outer Border (2px, No Edge Clipping)
                    ctx.save();
                    buildPath(p);
                    ctx.strokeStyle = root.primary;
                    ctx.lineWidth = sw;
                    ctx.lineJoin = "miter";
                    ctx.miterLimit = 4;
                    ctx.stroke();
                    ctx.restore();

                    // 4. Tactical Shoulder & Notch Corner Accent Marks
                    ctx.save();
                    ctx.strokeStyle = root.primary;
                    ctx.lineWidth = 1.5;

                    // Left shoulder notch corner tick
                    ctx.beginPath();
                    ctx.moveTo(cx - cth - 10, p);
                    ctx.lineTo(cx - cth, p);
                    ctx.stroke();

                    // Right shoulder notch corner tick
                    ctx.beginPath();
                    ctx.moveTo(cx + cth, p);
                    ctx.lineTo(cx + cth + 10, p);
                    ctx.stroke();

                    // Bottom notch corner ticks
                    ctx.beginPath();
                    ctx.moveTo(cx - cbh, cd + p);
                    ctx.lineTo(cx - cbh + 8, cd + p);
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(cx + cbh - 8, cd + p);
                    ctx.lineTo(cx + cbh, cd + p);
                    ctx.stroke();

                    // Bottom Trapezoid Left & Right Transition Ticks
                    ctx.beginPath();
                    ctx.moveTo(p, h - bsh);
                    ctx.lineTo(p + 8, h - bsh);
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(w - p - 8, h - bsh);
                    ctx.lineTo(w - p, h - bsh);
                    ctx.stroke();

                    // Bottom Base Horizontal Notch Ticks
                    ctx.beginPath();
                    ctx.moveTo(bsw, h - p);
                    ctx.lineTo(bsw + 8, h - p);
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.moveTo(w - bsw - 8, h - p);
                    ctx.lineTo(w - bsw, h - p);
                    ctx.stroke();

                    ctx.restore();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            // Left Shoulder Tactical Header
            Item {
                x: 12
                y: 6
                width: Math.max(60, (parent.width / 2) - (frameCanvas.cutoutTopW / 2) - 18)
                height: 32

                RowLayout {
                    anchors.fill: parent
                    spacing: 5

                    Rectangle {
                        width: 3
                        height: 16
                        color: root.primary
                    }

                    ColumnLayout {
                        spacing: 0
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: NervSettings.hudBranding
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }

                        Text {
                            text: "// DISPATCH"
                            color: root.textDim
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.6
                        }
                    }
                }
            }

            // Right Shoulder Close Button [ESC]
            Item {
                x: (parent.width / 2) + (frameCanvas.cutoutTopW / 2) + 6
                y: 6
                width: Math.max(60, parent.width - x - 12)
                height: 32

                RowLayout {
                    anchors.fill: parent
                    spacing: 4

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 20
                        color: closeMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                        border.width: 1
                        border.color: root.primary

                        Text {
                            anchors.centerIn: parent
                            text: "ESC ✕"
                            color: closeMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }
            }

            // Sub-cutout tactical separator line
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.topMargin: 48
                height: 1
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
            }

            // Inner Main Layout (Sits cleanly below the trapezoid cutout)
            ColumnLayout {
                anchors.top: parent.top
                anchors.topMargin: 56
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                spacing: 8

            // 2. SEARCH INPUT BOX
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "#ffffff"
                border.width: 1.5
                border.color: searchInput.activeFocus ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    Text {
                        text: "▶"
                        color: root.primary
                        font.pixelSize: 9
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: root.textMain
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        clip: true
                        selectByMouse: true

                        Text {
                            text: "SEARCH PROTOCOLS OR APPS..."
                            color: root.textDim
                            font.family: root.hudFont
                            font.pixelSize: 10
                            font.bold: true
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            root.filterQuery = text;
                            root.updateFilteredApps();
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.close();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launchSelected();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                if (root.filteredApps.length > 0) {
                                    root.selectedIndex = (root.selectedIndex + 1) % root.filteredApps.length;
                                    appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                if (root.filteredApps.length > 0) {
                                    root.selectedIndex = (root.selectedIndex - 1 + root.filteredApps.length) % root.filteredApps.length;
                                    appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    // Clear button when typing
                    Text {
                        text: "✕"
                        color: root.primary
                        font.pixelSize: 10
                        font.bold: true
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // 3. CATEGORY FILTER RAIL
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                readonly property var categories: ["ALL", "EVA SUITE"]

                Repeater {
                    model: parent.categories

                    Rectangle {
                        readonly property bool isSelected: root.selectedCategory === modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        color: isSelected ? root.primary : (catMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12) : "transparent")
                        border.width: 1.5
                        border.color: isSelected ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

                        scale: catMouse.pressed ? 0.93 : (catMouse.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                        }

                        // Top Specular Highlight
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.leftMargin: 2; anchors.rightMargin: 2
                            height: 1
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
                            visible: parent.isSelected || catMouse.containsMouse
                        }

                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: modelData
                            color: parent.isSelected ? "#ffffff" : (catMouse.containsMouse ? root.primary : root.textMuted)
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            id: catMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedCategory = modelData;
                                root.updateFilteredApps();
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // 4. SCROLLABLE APPLICATION LIST
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#ffffff"
                border.width: 1.5
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)
                clip: true

                ListView {
                    id: appListView
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 3
                    model: root.filteredApps
                    boundsBehavior: Flickable.DragOverBounds

                    delegate: Rectangle {
                        id: appDelegate
                        width: appListView.width
                        height: 34
                        color: (index === root.selectedIndex) ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.14) : (itemMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06) : "transparent")
                        border.width: (index === root.selectedIndex) ? 1 : 0
                        border.color: root.primary

                        // Tactile Spring Scale
                        scale: itemMouse.pressed ? 0.98 : (itemMouse.containsMouse ? 1.015 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                        }

                        // Top Specular Highlight Edge on Selected
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.leftMargin: 4; anchors.rightMargin: 4
                            height: 1
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
                            visible: index === root.selectedIndex || itemMouse.containsMouse
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            spacing: 8

                            // Application Icon
                            Rectangle {
                                width: 24
                                height: 24
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                                border.width: 1
                                border.color: root.itemBorder

                                Image {
                                    id: appIconImg
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    source: (modelData.iconPath && modelData.iconPath.length > 0) ? ("file://" + modelData.iconPath) : (modelData.icon ? Quickshell.iconPath(modelData.icon) : "")
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    visible: (modelData.iconPath && modelData.iconPath.length > 0) || (modelData.icon && modelData.icon.length > 0)
                                    layer.enabled: true
                                    layer.effect: NervIconEffect {
                                        tintColor: (index === root.selectedIndex || itemMouse.containsMouse) ? root.secondary : (modelData.isRunning ? root.secondary : root.primary)
                                        bgColor: "#ffffff"
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name.length > 0 ? modelData.name.charAt(0).toUpperCase() : "󰀻"
                                    color: (index === root.selectedIndex || itemMouse.containsMouse) ? root.secondary : root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    visible: !appIconImg.visible
                                }
                            }

                            // Application Name
                            Text {
                                text: modelData.name
                                color: (index === root.selectedIndex || itemMouse.containsMouse) ? root.primary : root.textMain
                                font.family: root.hudFont
                                font.pixelSize: 10
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Running Beacon
                            Rectangle {
                                visible: modelData.isRunning
                                Layout.preferredWidth: 62
                                Layout.preferredHeight: 16
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                                border.width: 1
                                border.color: root.primary

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Rectangle { width: 4; height: 4; radius: 2; color: root.primary }
                                    Text {
                                        text: "RUNNING"
                                        color: root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        // Divider Line Between Items
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            height: 1
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)
                            visible: index < root.filteredApps.length - 1 && index !== root.selectedIndex && (index + 1) !== root.selectedIndex
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchApp(modelData)
                            onEntered: root.selectedIndex = index
                        }
                    }
                }

                // Empty Placeholder
                Text {
                    anchors.centerIn: parent
                    text: "NO MATCHING PROTOCOLS FOUND"
                    color: root.textDim
                    font.family: root.hudFont
                    font.pixelSize: 10
                    font.bold: true
                    visible: root.filteredApps.length === 0
                }
            }

            // 5. Tactical Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.fillHeight: false
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
            }

            // 6. BOTTOM POWER & SESSION CONTROL DECK (Fixed 26px height footer)
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 26
                Layout.minimumHeight: 26
                Layout.maximumHeight: 26
                Layout.leftMargin: 36
                Layout.rightMargin: 36
                spacing: 6

                // LOG OUT BUTTON
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 26
                    color: logoutMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰍃"
                            color: logoutMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 10
                        }
                        Text {
                            text: "LOG OUT"
                            color: logoutMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: logoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.close();
                            Quickshell.execDetached(["sh", "-c", "uwsm stop || swaymsg exit || hyprctl dispatch exit || loginctl terminate-session self || loginctl terminate-user $USER"]);
                        }
                    }
                }

                // REBOOT BUTTON
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 26
                    color: rebootMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰑓"
                            color: rebootMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 10
                        }
                        Text {
                            text: "REBOOT"
                            color: rebootMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: rebootMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.close();
                            Quickshell.execDetached(["systemctl", "reboot"]);
                        }
                    }
                }

                // POWER OFF BUTTON
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 26
                    color: powerMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                    border.width: 1
                    border.color: root.primary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰐥"
                            color: powerMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 10
                        }
                        Text {
                            text: "POWER OFF"
                            color: powerMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.5
                        }
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.close();
                            Quickshell.execDetached(["systemctl", "poweroff"]);
                        }
                    }
                }
            }
        }
        }
    } // end popoutContainer

    // Tactical Laser Scanline Beam
    NervScanlineBeam {
        revealProgress: root.revealProgress
        beamOpacity: root.beamOpacity
        running: openAnim.running || closeAnim.running
        targetHeight: root.cardHeight
        primaryColor: root.primary
        hudFont: root.hudFont
    }
}

