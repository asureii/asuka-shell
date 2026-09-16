import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../../components"

Scope {
    id: root

    property string wallpaperPath: ""
    property bool completed: false
    property var activeImages: ({})

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // Load saved wallpaper path on startup
    Process {
        id: loadProcess
        command: ["sh", "-c", "cat '" + Quickshell.configPath("wallpaper.txt") + "' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var saved = text.trim();
                if (saved.length > 0) {
                    if (saved.startsWith("~/")) {
                        saved = (Quickshell.env("HOME") || "") + saved.substring(1);
                    } else if (!saved.startsWith("/")) {
                        saved = Quickshell.configPath(saved);
                    }
                    root.wallpaperPath = saved;
                }
                root.completed = true;
            }
        }
    }

    Component.onCompleted: {
        loadProcess.running = true;
    }

    function setWallpaper(path: string) {
        if (!path || path.length === 0) return;
        var cleanPath = path.replace(/^file:\/\//, "");
        root.wallpaperPath = cleanPath;

        // Save to config file for persistence
        saveProcess.command = ["sh", "-c", "echo -n '" + cleanPath + "' > '" + Quickshell.configPath("wallpaper.txt") + "'"];
        saveProcess.running = true;
    }

    Process {
        id: saveProcess
        command: ["sh", "-c", "true"]
    }

    FileDialog {
        id: fileDialog
        title: "Select Desktop Wallpaper"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp *.svg)", "All files (*)"]
        onAccepted: {
            root.setWallpaper(selectedFile.toString());
        }
    }

    function openFileDialog() {
        fileDialog.open();
    }

    // ============================================================
    // PANEL WINDOW PER MONITOR (BACKGROUND LAYER)
    // ============================================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bgWin

            required property ShellScreen modelData

            screen: modelData
            visible: true

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "#ffffff"

            Item {
                id: wallpaperContainer
                anchors.fill: parent

                property Item currentImageItem: null

                function loadNewWallpaper(src) {
                    if (!src || src.length === 0) {
                        if (currentImageItem) {
                            currentImageItem.destroy();
                            currentImageItem = null;
                        }
                        return;
                    }

                    var oldItem = currentImageItem;
                    var newItem = imgComponent.createObject(wallpaperContainer, {
                        sourcePath: src,
                        oldItemRef: oldItem
                    });
                    currentImageItem = newItem;
                }

                Connections {
                    target: root
                    function onWallpaperPathChanged() {
                        wallpaperContainer.loadNewWallpaper(root.wallpaperPath);
                    }
                }

                Component.onCompleted: {
                    if (root.wallpaperPath && root.wallpaperPath.length > 0) {
                        wallpaperContainer.loadNewWallpaper(root.wallpaperPath);
                    }
                }

                // ============================================================
                // FALLBACK / EMPTY WALLPAPER UI (NERV TACTICAL HUD)
                // ============================================================
                Rectangle {
                    anchors.fill: parent
                    visible: root.completed && (!root.wallpaperPath || root.wallpaperPath.length === 0)
                    color: "#ffffff"

                    NervHudGrid {
                        anchors.fill: parent
                        gridColor: "#cc0000"
                        gridOpacity: 0.12
                    }

                    NervHazardLines {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 6
                    }

                    NervHazardLines {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 6
                    }

                    // Centered Tactical Banner
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(620, parent.width - 40)
                        height: 280
                        color: Qt.rgba(0.06, 0.015, 0.015, 0.75)
                        border.width: 1
                        border.color: root.primary

                        NervHazardLines {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 4
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 14

                            // Top Header & Alert Code
                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "NERV // DESKTOP VISUAL ENGINE"
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 2
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 80
                                    height: 16
                                    color: "#ffffff"
                                    border.width: 1
                                    border.color: root.secondary

                                    Text {
                                        anchors.centerIn: parent
                                        text: "NO SOURCE"
                                        color: root.secondary
                                        font.family: root.hudFont
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                            }

                            // Large Center Alert Icon & Text
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 18

                                Text {
                                    text: "󰀦"
                                    color: root.secondary
                                    font.family: root.hudFont
                                    font.pixelSize: 48
                                }

                                ColumnLayout {
                                    spacing: 4

                                    Text {
                                        text: "WALLPAPER MISSING // STANDBY"
                                        color: root.accent
                                        font.family: root.hudFont
                                        font.pixelSize: 16
                                        font.bold: true
                                        font.letterSpacing: 1.5
                                    }

                                    Text {
                                        text: "No active desktop image signal detected. Select a tactical background to initialize visual layer."
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.7)
                                        font.family: root.hudFont
                                        font.pixelSize: 10
                                        Layout.maximumWidth: 440
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            // Action Button
                            RowLayout {
                                Layout.fillWidth: true

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: 210
                                    height: 36
                                    color: fileBtnMouse.containsMouse ? root.primary : "#ffffff"
                                    border.width: 1
                                    border.color: root.secondary

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: ""
                                            color: fileBtnMouse.containsMouse ? "#ffffff" : root.secondary
                                            font.family: root.hudFont
                                            font.pixelSize: 12
                                        }

                                        Text {
                                            text: "SELECT WALLPAPER"
                                            color: fileBtnMouse.containsMouse ? "#ffffff" : root.secondary
                                            font.family: root.hudFont
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.letterSpacing: 1.2
                                        }
                                    }

                                    MouseArea {
                                        id: fileBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openFileDialog()
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }

                        NervHazardLines {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 4
                        }
                    }

                    NervScanlines {
                        anchors.fill: parent
                    }
                }

                // ============================================================
                // DYNAMIC WALLPAPER IMAGE COMPONENT (CROSSFADE TRANSITION)
                // ============================================================
                Component {
                    id: imgComponent

                    Image {
                        id: wallpaperImg

                        property string sourcePath: ""
                        property Item oldItemRef: null

                        anchors.fill: parent
                        source: sourcePath.length > 0 ? (sourcePath.startsWith("/") ? "file://" + sourcePath : sourcePath) : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: 0.0

                        onStatusChanged: {
                            if (status === Image.Ready) {
                                fadeInAnim.start();
                            }
                        }

                        NumberAnimation on opacity {
                            id: fadeInAnim
                            running: false
                            from: 0.0
                            to: 1.0
                            duration: 500
                            easing.type: Easing.InOutQuad
                            onFinished: {
                                if (wallpaperImg.oldItemRef) {
                                    wallpaperImg.oldItemRef.destroy();
                                    wallpaperImg.oldItemRef = null;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
