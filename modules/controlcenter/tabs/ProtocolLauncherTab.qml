import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../../components"

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.92)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.85)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Model State
    property var allApps: []
    property var filteredApps: []
    property string filterQuery: ""
    property string selectedCategory: "ALL"
    property var selectedApp: null
    property int runningCount: 0

    // Live Minigraph Rolling History (30 samples)
    property var cpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var gpuHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property real currentCpuVal: 0
    property real currentGpuVal: 0
    property real currentRssVal: 0

    onSelectedAppChanged: {
        root.sampleTelemetry();
    }

    function sampleTelemetry() {
        var cpu = 0;
        var gpu = 0;
        var rss = 0;
        if (root.selectedApp && root.selectedApp.isRunning) {
            cpu = Math.min(100, Math.max(0, root.selectedApp.cpuPct || 0));
            gpu = Math.min(100, Math.max(0, root.selectedApp.gpuPct || 0));
            rss = Math.round(root.selectedApp.rssMb || 0);
        }
        root.currentCpuVal = cpu;
        root.currentGpuVal = gpu;
        root.currentRssVal = rss;

        var ch = root.cpuHistory.slice();
        var gh = root.gpuHistory.slice();
        ch.shift();
        ch.push(cpu);
        gh.shift();
        gh.push(gpu);
        root.cpuHistory = ch;
        root.gpuHistory = gh;
        if (typeof telemetryCanvas !== "undefined" && telemetryCanvas) {
            telemetryCanvas.requestPaint();
        }
    }

    function updateFilteredApps() {
        var query = root.filterQuery.trim().toLowerCase();
        var cat = root.selectedCategory.toUpperCase();
        var list = [];
        var activeCount = 0;

        for (var i = 0; i < root.allApps.length; i++) {
            var app = root.allApps[i];
            if (app.isRunning) activeCount++;

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

        root.runningCount = activeCount;
        root.filteredApps = list;

        // Auto-select first app if none selected or current selection no longer present
        if (list.length > 0) {
            if (!root.selectedApp) {
                root.selectedApp = list[0];
            } else {
                var found = false;
                for (var j = 0; j < list.length; j++) {
                    if (list[j].id === root.selectedApp.id) {
                        root.selectedApp = list[j];
                        found = true;
                        break;
                    }
                }
                if (!found) root.selectedApp = list[0];
            }
        }
    }

    function launchApp(app) {
        if (!app || !app.exec) return;
        Quickshell.execDetached(["bash", "-c", app.exec + " &"]);
        refreshTimer.restart();
    }

    function terminateApp(app) {
        if (!app) return;
        if (app.pid && app.pid.length > 0) {
            Quickshell.execDetached(["kill", app.pid]);
        } else if (app.execBinary && app.execBinary.length > 0) {
            Quickshell.execDetached(["killall", app.execBinary]);
        }
        refreshTimer.restart();
    }

    // Dynamic C++ App Discovery Process
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
                        root.sampleTelemetry();
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (!appScanner.running) appScanner.running = true;
        }
    }

    Timer {
        interval: 1500
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!appScanner.running) appScanner.running = true;
            else root.sampleTelemetry();
        }
    }

    Component.onCompleted: {
        appScanner.running = true;
    }

    onVisibleChanged: {
        if (root.visible) {
            appScanner.running = true;
        }
    }

    anchors.fill: parent

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // ============================================================
        // LEFT PANEL: APPLICATION PROTOCOL DIRECTORY (SCROLLABLE LIST)
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 400
            Layout.minimumWidth: 360
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            // Top Specular Highlight Rim
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#ffffff"
                opacity: 0.7
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Top Hazard Line Strip
                NervHazardLines {
                    Layout.fillWidth: true
                    height: 10
                    stripeColor: root.primary
                    bgColor: "#ffffff"
                }

                // Directory Header & Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    spacing: 6

                    // Title Bar
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "[ PROTOCOL DIRECTORY ]"
                            color: root.fg
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: appScanner.running ? root.secondary : root.primary
                        }
                    }

                    // Search Filter Input Box
                    Rectangle {
                        Layout.fillWidth: true
                        height: 22
                        color: "#ffffff"
                        border.width: 1
                        border.color: appSearchInput.activeFocus ? root.secondary : root.itemBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            Text {
                                text: "FILTER PROTOCOL >"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            TextInput {
                                id: appSearchInput
                                Layout.fillWidth: true
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                clip: true
                                selectByMouse: true

                                onTextChanged: {
                                    root.filterQuery = text;
                                    root.updateFilteredApps();
                                }
                            }

                            Text {
                                visible: appSearchInput.text.length > 0
                                text: "󰅖"
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 10
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: appSearchInput.text = ""
                                }
                            }
                        }
                    }

                    // Category Filter Pills
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: ["ALL", "EVA SUITE", "SYSTEM", "NETWORK", "DEV", "UTILITY", "MEDIA"]

                            Rectangle {
                                id: catPill
                                readonly property bool isSelected: root.selectedCategory === modelData
                                height: 16
                                Layout.fillWidth: true
                                color: isSelected ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: isSelected ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)
                                scale: pillMouse.pressed ? 0.94 : (pillMouse.containsMouse ? 1.05 : 1.0)

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                                // Top Specular Highlight Rim
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#ffffff"
                                    opacity: catPill.isSelected ? 0.9 : 0.35
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.isSelected ? "#ffffff" : root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    id: pillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedCategory = modelData;
                                        root.updateFilteredApps();
                                    }
                                }
                            }
                        }
                    }

                    // Directory Telemetry
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "TOTAL: " + root.allApps.length + " | MATCHED: " + root.filteredApps.length
                            color: root.fgMuted
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "ACTIVE: " + root.runningCount
                            color: root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }
                }

                // Scrollable Application List
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: appListColumn.implicitHeight

                    Column {
                        id: appListColumn
                        width: parent.width

                        Repeater {
                            model: root.filteredApps

                            Rectangle {
                                id: appRow
                                width: appListColumn.width
                                height: 42
                                readonly property bool isSelected: root.selectedApp && root.selectedApp.id === modelData.id
                                color: isSelected ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.28)
                                                  : (rowMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                                                                            : (index % 2 === 0 ? Qt.rgba(0, 0, 0, 0.4) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)))
                                border.width: isSelected ? 1 : 0
                                border.color: root.secondary
                                scale: rowMouse.pressed ? 0.98 : (rowMouse.containsMouse ? 1.01 : 1.0)

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                                // Top Specular Highlight Rim
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: "#ffffff"
                                    opacity: appRow.isSelected ? 0.95 : (rowMouse.containsMouse ? 0.6 : 0.2)
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }

                                opacity: root.visible ? 1.0 : 0.0
                                transform: Translate {
                                    x: root.visible ? 0 : -8
                                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }
                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    // App Icon Container
                                    Rectangle {
                                        width: 28
                                        height: 28
                                        color: "#ffffff"
                                        border.width: 1
                                        border.color: appRow.isSelected ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)

                                        Image {
                                            id: rowIconImg
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            source: modelData.iconPath.length > 0 ? ("file://" + modelData.iconPath) : ""
                                            fillMode: Image.PreserveAspectFit
                                            visible: modelData.iconPath.length > 0
                                            asynchronous: true
                                            layer.enabled: true
                                            layer.effect: NervIconEffect {
                                                tintColor: appRow.isSelected ? root.secondary : (modelData.isRunning ? root.secondary : root.primary)
                                                bgColor: "#ffffff"
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: modelData.iconPath.length === 0
                                            text: modelData.name.length > 0 ? modelData.name.charAt(0).toUpperCase() : "󰵆"
                                            color: appRow.isSelected ? root.secondary : root.primary
                                            font.family: root.hudFont
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }

                                    // Name & Exec Subtitle
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            text: modelData.name
                                            color: appRow.isSelected ? root.secondary : root.fg
                                            font.family: root.hudFont
                                            font.pixelSize: 9
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.genericName.length > 0 ? modelData.genericName : modelData.exec
                                            color: appRow.isSelected ? root.secondary : root.fgDim
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    // Running State Badge
                                    Rectangle {
                                        Layout.preferredWidth: 54
                                        Layout.preferredHeight: 16
                                        color: modelData.isRunning ? root.primary : "#ffffff"
                                        border.width: 1
                                        border.color: modelData.isRunning ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 3

                                            Rectangle {
                                                width: 4
                                                height: 4
                                                radius: 2
                                                color: modelData.isRunning ? "#ffffff" : root.fgDim
                                            }

                                            Text {
                                                text: modelData.isRunning ? "RUNNING" : "STANDBY"
                                                color: modelData.isRunning ? "#ffffff" : root.fgDim
                                                font.family: root.hudFont
                                                font.pixelSize: 6
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedApp = modelData;
                                    }
                                    onDoubleClicked: {
                                        root.launchApp(modelData);
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom Hazard Line Strip
                NervHazardLines {
                    Layout.fillWidth: true
                    height: 10
                    stripeColor: root.primary
                    bgColor: "#ffffff"
                    scrollLeft: true
                }
            }
        }

        // ============================================================
        // RIGHT PANEL: PROTOCOL INSPECTION, PREVIEW & EXECUTION UNIT
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            // Top Specular Highlight Rim
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#ffffff"
                opacity: 0.7
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header Banner
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "▶ PROTOCOL SPECIFICATION // EXECUTION UNIT"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 20
                        width: 130
                        color: "#ffffff"
                        border.width: 1
                        border.color: (root.selectedApp && root.selectedApp.isRunning) ? root.secondary : root.itemBorder

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: (root.selectedApp && root.selectedApp.isRunning) ? root.primary : root.fgDim
                            }

                            Text {
                                text: (root.selectedApp && root.selectedApp.isRunning) ? ("ACTIVE // PID " + root.selectedApp.pid) : "STATUS // STANDBY"
                                color: (root.selectedApp && root.selectedApp.isRunning) ? root.secondary : root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }

                // Main App Preview Card (Thumbnail & Info) (StudioCard 2.5D Perspective Card)
                StudioCard {
                    id: previewCard
                    Layout.fillWidth: true
                    height: 190
                    cardBg: root.itemBg
                    strokeColor: root.primary
                    maxTilt: 16.0

                    // Hex HUD background inside preview card
                    NervHudGrid {
                        anchors.fill: parent
                        gridOpacity: 0.15
                        gridColor: "#cc0000"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 16

                        // Big Tactical App Thumbnail Icon Frame with Z-Parallax
                        Rectangle {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 100
                            color: "#ffffff"
                            border.width: 2
                            border.color: root.secondary

                            transform: Translate {
                                x: previewCard.normX * 8
                                y: previewCard.normY * 8
                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }

                            // Top-Left Corner Bracket
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                width: 8
                                height: 2
                                color: root.secondary
                            }
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                width: 2
                                height: 8
                                color: root.secondary
                            }

                            // Bottom-Right Corner Bracket
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                width: 8
                                height: 2
                                color: root.secondary
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                width: 2
                                height: 8
                                color: root.secondary
                            }

                            Image {
                                id: previewIconImg
                                anchors.centerIn: parent
                                width: 64
                                height: 64
                                source: (root.selectedApp && root.selectedApp.iconPath.length > 0) ? ("file://" + root.selectedApp.iconPath) : ""
                                fillMode: Image.PreserveAspectFit
                                visible: (root.selectedApp && root.selectedApp.iconPath.length > 0)
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: NervIconEffect {
                                    tintColor: (root.selectedApp && root.selectedApp.isRunning) ? root.secondary : root.accent
                                    bgColor: "#ffffff"
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !root.selectedApp || root.selectedApp.iconPath.length === 0
                                text: (root.selectedApp && root.selectedApp.name.length > 0) ? root.selectedApp.name.charAt(0).toUpperCase() : "󰵆"
                                color: (root.selectedApp && root.selectedApp.isRunning) ? root.secondary : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 36
                                font.bold: true
                            }
                        }

                        // App Details Column
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            Text {
                                text: root.selectedApp ? root.selectedApp.name.toUpperCase() : "NO PROTOCOL SELECTED"
                                color: root.accent
                                font.family: root.hudFont
                                font.pixelSize: 18
                                font.bold: true
                                font.letterSpacing: 2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: (root.selectedApp && root.selectedApp.genericName.length > 0) ? ("GENERIC: " + root.selectedApp.genericName.toUpperCase()) : "SYSTEM PROTOCOL EXECUTABLE"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)
                                Layout.topMargin: 2
                                Layout.bottomMargin: 2
                            }

                            Text {
                                text: (root.selectedApp && root.selectedApp.comment.length > 0) ? root.selectedApp.comment : "No extended protocol description provided in desktop specification."
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 9
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }
                        }
                    }
                }

                // Technical Metadata Matrix (4 Tiles)
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    // Tile 1: Executable Command
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        color: root.itemBg
                        border.width: 1
                        border.color: root.itemBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2
                            Text { text: "EXECUTION BINARY PATH"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                            Text { text: root.selectedApp ? root.selectedApp.exec : "N/A"; color: root.fg; font.family: root.hudFont; font.pixelSize: 8; font.bold: true; elide: Text.ElideMiddle; Layout.fillWidth: true }
                        }
                    }

                    // Tile 2: Desktop ID
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        color: root.itemBg
                        border.width: 1
                        border.color: root.itemBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2
                            Text { text: "DESKTOP PROTOCOL SPEC"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                            Text { text: root.selectedApp ? (root.selectedApp.id + ".desktop") : "N/A"; color: root.fg; font.family: root.hudFont; font.pixelSize: 8; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }

                    // Tile 3: Category Classification
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        color: root.itemBg
                        border.width: 1
                        border.color: root.itemBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2
                            Text { text: "CATEGORIES"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                            Text { text: (root.selectedApp && root.selectedApp.categories.length > 0) ? root.selectedApp.categories : "System;Utility;"; color: root.secondary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                    }

                    // Tile 4: Process Telemetry
                    Rectangle {
                        Layout.fillWidth: true
                        height: 48
                        color: root.itemBg
                        border.width: 1
                        border.color: (root.selectedApp && root.selectedApp.isRunning) ? root.secondary : root.itemBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2
                            Text { text: "PROCESS INSTANCE TELEMETRY"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                            Text {
                                text: (root.selectedApp && root.selectedApp.isRunning) ? ("ACTIVE (PID: " + root.selectedApp.pid + ")") : "INACTIVE (STANDBY)"
                                color: (root.selectedApp && root.selectedApp.isRunning) ? root.secondary : root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }
                    }
                }

                // Live Telemetry Oscilloscope Card (CPU & GPU Minigraph)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 120
                    color: root.itemBg
                    border.width: 1
                    border.color: (root.selectedApp && root.selectedApp.isRunning) ? root.secondary : root.itemBorder
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Minigraph Header & Live Badges
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "▶ LIVE TELEMETRY OSCILLOSCOPE // TARGET"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            Item { Layout.fillWidth: true }

                            // Orange CPU Badge
                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: root.secondary
                            }
                            Text {
                                text: "CPU: " + Math.round(root.currentCpuVal) + "%"
                                color: root.secondary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Item { Layout.preferredWidth: 6 }

                            // Red GPU / Memory Badge
                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: root.primary
                            }
                            Text {
                                text: "GPU/MEM: " + Math.round(root.currentGpuVal) + "% (" + Math.round(root.currentRssVal) + " MB)"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }

                        // Canvas Minigraph Track
                        Item {
                            id: telemetryCanvasContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Canvas {
                                id: telemetryCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                renderStrategy: Canvas.Immediate

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    // Background 20px Grid lines
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12);
                                    ctx.lineWidth = 0.6;
                                    for (var gx = 0; gx <= width; gx += 25) {
                                        ctx.beginPath();
                                        ctx.moveTo(gx, 0);
                                        ctx.lineTo(gx, height);
                                        ctx.stroke();
                                    }
                                    for (var gy = 0; gy <= height; gy += 18) {
                                        ctx.beginPath();
                                        ctx.moveTo(0, gy);
                                        ctx.lineTo(width, gy);
                                        ctx.stroke();
                                    }

                                    // Center Crosshair (+)
                                    var cx = width / 2;
                                    var cy = height / 2;
                                    ctx.strokeStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3);
                                    ctx.lineWidth = 1;
                                    ctx.beginPath();
                                    ctx.moveTo(cx - 6, cy);
                                    ctx.lineTo(cx + 6, cy);
                                    ctx.moveTo(cx, cy - 6);
                                    ctx.lineTo(cx, cy + 6);
                                    ctx.stroke();

                                    var ch = root.cpuHistory;
                                    var gh = root.gpuHistory;
                                    var n = ch.length;
                                    if (n < 2) return;

                                    var stepX = width / (n - 1);
                                    var bottomY = height - 4;
                                    var topY = 6;
                                    var usableH = bottomY - topY;

                                    var isRunning = root.selectedApp && root.selectedApp.isRunning;

                                    // 1. RED TRACE (GPU / MEMORY)
                                    ctx.beginPath();
                                    for (var i = 0; i < n; i++) {
                                        var gxPos = i * stepX;
                                        var gVal = isRunning ? (gh[i] || 0) : 0;
                                        var gyPos = bottomY - (gVal / 100.0) * usableH;
                                        if (i === 0) ctx.moveTo(gxPos, gyPos);
                                        else ctx.lineTo(gxPos, gyPos);
                                    }
                                    ctx.strokeStyle = root.primary;
                                    ctx.lineWidth = 1.8;
                                    ctx.stroke();

                                    // Fill under Red curve
                                    if (isRunning) {
                                        ctx.lineTo((n - 1) * stepX, bottomY);
                                        ctx.lineTo(0, bottomY);
                                        ctx.closePath();
                                        ctx.fillStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12);
                                        ctx.fill();
                                    }

                                    // 2. ORANGE TRACE (CPU)
                                    ctx.beginPath();
                                    for (var j = 0; j < n; j++) {
                                        var cxPos = j * stepX;
                                        var cVal = isRunning ? (ch[j] || 0) : 0;
                                        var cyPos = bottomY - (cVal / 100.0) * usableH;
                                        if (j === 0) ctx.moveTo(cxPos, cyPos);
                                        else ctx.lineTo(cxPos, cyPos);
                                    }
                                    ctx.strokeStyle = root.secondary;
                                    ctx.lineWidth = 1.8;
                                    ctx.stroke();

                                    // Fill under Orange curve
                                    if (isRunning) {
                                        ctx.lineTo((n - 1) * stepX, bottomY);
                                        ctx.lineTo(0, bottomY);
                                        ctx.closePath();
                                        ctx.fillStyle = Qt.rgba(root.secondary.r, root.secondary.g, root.secondary.b, 0.16);
                                        ctx.fill();
                                    }
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }

                            // Standby Indicator Overlay
                            Text {
                                anchors.centerIn: parent
                                visible: !root.selectedApp || !root.selectedApp.isRunning
                                text: "[ TARGET PROCESS INACTIVE // STANDBY RADAR ]"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 1
                            }
                        }

                        // Time Axis Legend
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "T -30s"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "T -15s"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text { text: "T 0s (NOW)"; color: root.secondary; font.family: root.hudFont; font.pixelSize: 6; font.bold: true }
                        }
                    }
                }

                // Eva Suite Specialized Quick-Action Bar
                Rectangle {
                    visible: root.selectedApp && (root.selectedApp.id.toLowerCase().indexOf("eva") !== -1 || root.selectedApp.name.toLowerCase().indexOf("eva") !== -1)
                    Layout.fillWidth: true
                    height: 28
                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
                    border.width: 1
                    border.color: root.secondary

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        Text {
                            text: "EVA SUITE SHORTCUTS >"
                            color: root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            Layout.leftMargin: 4
                        }

                        // EvaFile Shortcuts
                        RowLayout {
                            visible: root.selectedApp && root.selectedApp.id.toLowerCase().indexOf("evafile") !== -1
                            spacing: 4

                            Rectangle {
                                width: 95
                                height: 20
                                color: efDownMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰝰 ~/Downloads"; color: efDownMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: efDownMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evafile", (Quickshell.env("HOME") || "") + "/Downloads"]) }
                            }

                            Rectangle {
                                width: 85
                                height: 20
                                color: efPicMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰝰 ~/Pictures"; color: efPicMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: efPicMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evafile", (Quickshell.env("HOME") || "") + "/Pictures"]) }
                            }

                            Rectangle {
                                width: 65
                                height: 20
                                color: efHomeMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰝰 ~/"; color: efHomeMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: efHomeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evafile", Quickshell.env("HOME") || ""]) }
                            }
                        }

                        // EvaTerm Shortcuts
                        RowLayout {
                            visible: root.selectedApp && root.selectedApp.id.toLowerCase().indexOf("evaterm") !== -1
                            spacing: 4

                            Rectangle {
                                width: 95
                                height: 20
                                color: etNewMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰆍 NEW SESSION"; color: etNewMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: etNewMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evaterm"]) }
                            }

                            Rectangle {
                                width: 115
                                height: 20
                                color: etStatMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰒋 EVACORE STATUS"; color: etStatMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: etStatMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evaterm", "-e", "evacore", "status"]) }
                            }
                        }

                        // EvaSort Shortcuts
                        RowLayout {
                            visible: root.selectedApp && root.selectedApp.id.toLowerCase().indexOf("evasort") !== -1
                            spacing: 4

                            Rectangle {
                                width: 105
                                height: 20
                                color: esRunMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰒋 SORT DOWNLOADS"; color: esRunMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: esRunMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evacore", "sort"]) }
                            }

                            Rectangle {
                                width: 110
                                height: 20
                                color: esWatchMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰈈 TOGGLE WATCHER"; color: esWatchMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: esWatchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["python3", Quickshell.configPath("scripts/evacore_bridge.py"), "sort_toggle_daemon"]) }
                            }
                        }

                        // EvaCore Shortcuts
                        RowLayout {
                            visible: root.selectedApp && root.selectedApp.id.toLowerCase().indexOf("evacore") !== -1
                            spacing: 4

                            Rectangle {
                                width: 110
                                height: 20
                                color: ecStatMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary
                                Text { anchors.centerIn: parent; text: "󰒋 SYSTEM STATUS"; color: ecStatMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: ecStatMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evaterm", "-e", "evacore", "status"]) }
                            }

                            Rectangle {
                                width: 110
                                height: 20
                                color: ecShellMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.primary
                                Text { anchors.centerIn: parent; text: "󰑓 RESTART SHELL"; color: ecShellMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                MouseArea { id: ecShellMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["evacore", "shell", "-r", "-d"]) }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // Action Controls Bar (Bottom)
                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // Launch Protocol Button
                        Rectangle {
                            id: launchBtn
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: launchMouse.containsMouse ? root.primary : "#ffffff"
                            border.width: 1
                            border.color: root.secondary
                            scale: launchMouse.pressed ? 0.96 : (launchMouse.containsMouse ? 1.02 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                            // Top Specular Highlight Rim
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: "#ffffff"
                                opacity: launchMouse.containsMouse ? 0.95 : 0.4
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "▶"
                                    color: launchMouse.containsMouse ? "#ffffff" : root.secondary
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: "LAUNCH PROTOCOL"
                                    color: launchMouse.containsMouse ? "#ffffff" : root.secondary
                                    font.family: root.hudFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.letterSpacing: 1.5
                                }
                            }

                            MouseArea {
                                id: launchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchApp(root.selectedApp)
                            }
                        }

                        // Terminate Instance Button
                        Rectangle {
                            id: termBtn
                            readonly property bool canTerminate: root.selectedApp && root.selectedApp.isRunning
                            Layout.preferredWidth: 160
                            Layout.fillHeight: true
                            color: canTerminate ? (termMouse.containsMouse ? root.primary : "#ffffff") : "#ffffff"
                            border.width: 1
                            border.color: canTerminate ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                            opacity: canTerminate ? 1.0 : 0.45
                            scale: termMouse.pressed ? 0.96 : (termMouse.containsMouse && canTerminate ? 1.02 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                            // Top Specular Highlight Rim
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: "#ffffff"
                                opacity: termMouse.containsMouse ? 0.95 : 0.35
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "󰓛"
                                    color: parent.parent.canTerminate ? (termMouse.containsMouse ? "#ffffff" : root.primary) : root.fgDim
                                    font.pixelSize: 10
                                }

                                Text {
                                    text: "TERMINATE"
                                    color: parent.parent.canTerminate ? (termMouse.containsMouse ? "#ffffff" : root.primary) : root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 1
                                }
                            }

                            MouseArea {
                                id: termMouse
                                anchors.fill: parent
                                enabled: parent.canTerminate
                                hoverEnabled: true
                                cursorShape: parent.canTerminate ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.terminateApp(root.selectedApp)
                            }
                        }
                    }
                }
            }
        }
    }
}
