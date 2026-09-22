import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property var statusData: ({})
    property color primary: "#cc0000"
    property color secondary: "#cc0000"
    property color highlight: "#ff2222"
    property color fg: "#1a0000"
    property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.94)
    property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    signal launchTuiRequested()
    signal downloadStreamRequested(string url, string format, string dest)
    signal openFolderRequested(string path)

    property string mediaUrl: ""
    property string selectedFormat: "video" // "video", "audio", "1080p"
    property string targetDest: "~/Videos"

    readonly property bool isAvailable: !!(root.statusData && root.statusData.tube && root.statusData.tube.available)

    color: root.panelBg
    border.width: 1
    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

    // Directional Top Specular Edge
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: "#ffffff"
        opacity: 0.85
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header Deck
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                text: "▶ EVATUBE // MEDIA STREAM EXTRACTION"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 18
                implicitWidth: tubeStatusRow.implicitWidth + 8
                color: root.isAvailable ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "#ffffff"
                border.width: 1
                border.color: root.isAvailable ? root.primary : root.itemBorder

                RowLayout {
                    id: tubeStatusRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle { width: 4; height: 4; radius: 2; color: root.isAvailable ? root.primary : root.fgDim }
                    Text {
                        text: root.isAvailable ? "READY" : "OFFLINE"
                        color: root.isAvailable ? root.primary : root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }
                }
            }
        }

        NervHazardLines {
            Layout.fillWidth: true
            height: 6
            stripeColor: root.primary
            bgColor: "#ffffff"
        }

        // Dedicated TUI App Launcher Banner
        Rectangle {
            Layout.fillWidth: true
            height: 38
            color: tuiLaunchMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : root.itemBg
            border.width: 1.5
            border.color: tuiLaunchMouse.containsMouse ? root.primary : root.secondary
            scale: tuiLaunchMouse.pressed ? 0.97 : (tuiLaunchMouse.containsMouse ? 1.01 : 1.0)

            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: root.primary
                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        color: "#ffffff"
                        font.pixelSize: 10
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "LAUNCH EVATUBE TUI APPLICATION"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Text {
                        text: "INTERACTIVE TERMINAL MEDIA DOWNLOADER & PLAYER"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                    }
                }

                Text {
                    text: "SPAWN ▶"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            MouseArea {
                id: tuiLaunchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchTuiRequested()
            }
        }

        // Section Label
        Text {
            text: "DIRECT MEDIA STREAM INGESTION // YT-DLP"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.8
        }

        // Stream URL Input Bar
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: "#ffffff"
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 4
                spacing: 4

                Text {
                    text: "󰎆 URL >"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                TextInput {
                    id: tubeUrlInput
                    Layout.fillWidth: true
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 8
                    selectByMouse: true
                    clip: true
                    text: root.mediaUrl
                    onTextChanged: root.mediaUrl = text

                    Text {
                        anchors.fill: parent
                        visible: !tubeUrlInput.text && !tubeUrlInput.activeFocus
                        text: "PASTE YOUTUBE / SOUNDCLOUD / MEDIA LINK..."
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                    }
                }
            }
        }

        // Format Selector Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Best Video
            Rectangle {
                Layout.fillWidth: true
                height: 24
                color: root.selectedFormat === "video" ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.secondary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰕧"; color: root.selectedFormat === "video" ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                    Text { text: "BEST VIDEO"; color: root.selectedFormat === "video" ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedFormat = "video";
                        root.targetDest = "~/Videos";
                    }
                }
            }

            // Audio Only
            Rectangle {
                Layout.fillWidth: true
                height: 24
                color: root.selectedFormat === "audio" ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.secondary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰝚"; color: root.selectedFormat === "audio" ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                    Text { text: "AUDIO (MP3)"; color: root.selectedFormat === "audio" ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedFormat = "audio";
                        root.targetDest = "~/Music";
                    }
                }
            }

            // 1080P Video
            Rectangle {
                Layout.fillWidth: true
                height: 24
                color: root.selectedFormat === "1080p" ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.secondary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰑋"; color: root.selectedFormat === "1080p" ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                    Text { text: "1080P HD"; color: root.selectedFormat === "1080p" ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedFormat = "1080p";
                        root.targetDest = "~/Videos";
                    }
                }
            }
        }

        // Destination folder chip & Pull Stream Action
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Dest Chip
            Rectangle {
                height: 28
                implicitWidth: destChipRow.implicitWidth + 10
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                RowLayout {
                    id: destChipRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "DEST:"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: root.targetDest; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openFolderRequested(root.targetDest)
                }
            }

            Item { Layout.fillWidth: true }

            // Pull Media Action
            Rectangle {
                height: 28
                implicitWidth: pullRow.implicitWidth + 14
                color: pullMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary

                RowLayout {
                    id: pullRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰇚"; color: pullMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 9 }
                    Text { text: "PULL MEDIA STREAM"; color: pullMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                }

                MouseArea {
                    id: pullMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tubeUrlInput.text.trim().length > 0) {
                            root.downloadStreamRequested(tubeUrlInput.text.trim(), root.selectedFormat, root.targetDest);
                            tubeUrlInput.text = "";
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Telemetry Footer
        Rectangle {
            Layout.fillWidth: true
            height: 26
            color: root.itemBg
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "SUPPORTED PROTOCOLS: YOUTUBE // SOUNDCLOUD // BILIBILI // TWITCH // RAW HTTP"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 6
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }
}
