import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../components"

PanelWindow {
    id: root

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
        left: (root.screen ? Math.max(20, Math.round((root.screen.width - 1280) / 2) + 48) : 91)
    }

    readonly property real cardHeight: 560
    implicitWidth: 440
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
        }
        NumberAnimation {
            id: openProgressAnim
            target: root
            property: "revealProgress"
            from: 0.0
            to: 1.0
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.165
        }
        SequentialAnimation {
            PauseAnimation { duration: 220 }
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

    function launchApp(app) {
        if (!app || !app.exec) return;
        Quickshell.execDetached(["bash", "-c", app.exec + " &"]);
        root.close();
    }

    function launchSelected() {
        if (root.filteredApps.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredApps.length) {
            root.launchApp(root.filteredApps[root.selectedIndex]);
        }
    }

    function updateFilteredApps() {
        var query = root.filterQuery.trim().toLowerCase();
        var cat = root.selectedCategory.toUpperCase();
        var list = [];

        for (var i = 0; i < root.allApps.length; i++) {
            var app = root.allApps[i];

            // Category match
            var catMatch = (cat === "ALL");
            if (!catMatch) {
                if (cat === "EVA SUITE" || cat === "EVA") {
                    if (app.name.toUpperCase().indexOf("EVA") !== -1 ||
                        app.id.toUpperCase().indexOf("EVA") !== -1 ||
                        (app.categories && (app.categories.toUpperCase().indexOf("EVA") !== -1 || app.categories.toUpperCase().indexOf("X-EVA") !== -1)) ||
                        (app.keywords && app.keywords.toUpperCase().indexOf("EVA") !== -1)) {
                        catMatch = true;
                    }
                } else if (app.categories) {
                    var appCats = app.categories.toUpperCase();
                    if (cat === "SYSTEM" && (appCats.indexOf("SYSTEM") !== -1 || appCats.indexOf("SETTINGS") !== -1 || appCats.indexOf("MONITOR") !== -1 || appCats.indexOf("TERMINAL") !== -1)) catMatch = true;
                    else if (cat === "NETWORK" && (appCats.indexOf("NETWORK") !== -1 || appCats.indexOf("WEBBROWSER") !== -1 || appCats.indexOf("FILETRANSFER") !== -1)) catMatch = true;
                    else if (cat === "DEV" && (appCats.indexOf("DEVELOPMENT") !== -1 || appCats.indexOf("BUILDING") !== -1 || appCats.indexOf("IDE") !== -1 || appCats.indexOf("TEXTEDITOR") !== -1)) catMatch = true;
                    else if (cat === "UTILITY" && (appCats.indexOf("UTILITY") !== -1 || appCats.indexOf("FILETOOLS") !== -1 || appCats.indexOf("FILEMANAGER") !== -1)) catMatch = true;
                    else if (cat === "MEDIA" && (appCats.indexOf("AUDIO") !== -1 || appCats.indexOf("VIDEO") !== -1 || appCats.indexOf("GRAPHICS") !== -1 || appCats.indexOf("VIEWER") !== -1)) catMatch = true;
                }
            }

            if (!catMatch) continue;

            // Search query match
            if (query) {
                var nameMatch = app.name.toLowerCase().indexOf(query) !== -1;
                var execMatch = app.exec.toLowerCase().indexOf(query) !== -1;
                var commentMatch = app.comment && app.comment.toLowerCase().indexOf(query) !== -1;
                var genMatch = app.genericName && app.genericName.toLowerCase().indexOf(query) !== -1;
                var keyMatch = app.keywords && app.keywords.toLowerCase().indexOf(query) !== -1;
                var catStrMatch = app.categories && app.categories.toLowerCase().indexOf(query) !== -1;
                if (!nameMatch && !execMatch && !commentMatch && !genMatch && !keyMatch && !catStrMatch) continue;
            }

            list.push(app);
        }

        root.filteredApps = list;
        root.selectedIndex = 0;
    }

    onVisibleChanged: {
        if (root.visible) {
            root.filterQuery = "";
            root.selectedCategory = "ALL";
            searchInput.text = "";
            root.refreshApps();
            searchInput.forceActiveFocus();
        }
    }

    // App Scanner Process
    Process {
        id: appScanner
        command: [Quickshell.configPath("scripts/get_applications")]
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

        Item {
            id: animContent
            width: parent.width
            height: root.cardHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            transform: Scale {
                origin.x: animContent.width / 2
                origin.y: 0
                yScale: Math.max(1.0, root.revealProgress)
            }

            // Tactical Chamfered Frame Canvas (Cut Top-Right & Bottom-Left)
            Canvas {
                id: frameCanvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            property real chamfer: 8
            property real strokeWidth: 2

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var w = width;
                var h = height;
                var c = chamfer;
                var sw = strokeWidth;
                var p = sw / 2;

                // 1. Solid Background Fill
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(w - c, 0);
                ctx.lineTo(w, c);
                ctx.lineTo(w, h);
                ctx.lineTo(c, h);
                ctx.lineTo(0, h - c);
                ctx.closePath();

                ctx.fillStyle = root.bg;
                ctx.fill();

                // 2. Tactical Grid Pattern
                ctx.save();
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
                ctx.beginPath();
                ctx.moveTo(p, p);
                ctx.lineTo(w - c - p * 0.4, p);
                ctx.lineTo(w - p, c + p * 0.4);
                ctx.lineTo(w - p, h - p);
                ctx.lineTo(c + p * 0.4, h - p);
                ctx.lineTo(p, h - c - p * 0.4);
                ctx.closePath();

                ctx.strokeStyle = root.primary;
                ctx.lineWidth = sw;
                ctx.stroke();
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // Inner Main Layout
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // 1. TACTICAL HEADER ROW
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 6

                Rectangle {
                    width: 4
                    height: 14
                    color: root.primary
                }

                Text {
                    text: NervSettings.hudBranding
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.5
                }

                Text {
                    text: "// PROTOCOL DISPATCH"
                    color: root.textDim
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Close Button [ESC]
                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 18
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

            // Header Separator Line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
            }

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
                        id: cascadeDelegate
                        width: appListView.width
                        height: 34
                        color: (index === root.selectedIndex) ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.14) : (itemMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06) : "transparent")
                        border.width: (index === root.selectedIndex) ? 1 : 0
                        border.color: root.primary

                        // Orchestrated Staggered Cascade Entrance
                        opacity: 0.0
                        transform: Translate { id: transX; x: -14 }
                        Component.onCompleted: cascadeAnim.start()

                        SequentialAnimation {
                            id: cascadeAnim
                            PauseAnimation { duration: Math.min(index * 25, 250) }
                            ParallelAnimation {
                                NumberAnimation { target: cascadeDelegate; property: "opacity"; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
                                NumberAnimation { target: transX; property: "x"; to: 0; duration: 240; easing.type: Easing.OutCubic }
                            }
                        }

                        // Tactile Spring Scale
                        scale: itemMouse.pressed ? 0.98 : (itemMouse.containsMouse ? 1.015 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
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
                            Quickshell.execDetached(["sh", "-c", "uwsm stop || hyprctl dispatch exit || loginctl terminate-session self || loginctl terminate-user $USER"]);
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

