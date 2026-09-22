import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property var statusData: ({})
    property bool evalinkOnline: false
    property string dlSpeed: "0 B/s"
    property string ulSpeed: "0 B/s"
    property int activeDownloads: 0
    property string sortSourceDir: "~/Downloads"
    property bool sortWatcherRunning: false

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

    signal appSelectRequested(int index)
    signal cleanDownloadsRequested()
    signal openFolderRequested(string path)

    readonly property var servicesSummary: [
        { idx: 0, id: "file", name: "EVAFILE", icon: "󰝰", desc: "FILE BROWSER", status: (root.statusData && root.statusData.file && root.statusData.file.running) ? (root.statusData.file.count + " ACTIVE") : "STANDBY", active: !!(root.statusData && root.statusData.file && root.statusData.file.running) },
        { idx: 1, id: "term", name: "EVATERM", icon: "󰆍", desc: "GPU TERMINAL", status: (root.statusData && root.statusData.term && root.statusData.term.running) ? (root.statusData.term.count + " SESSIONS") : "STANDBY", active: !!(root.statusData && root.statusData.term && root.statusData.term.running) },
        { idx: 2, id: "sort", name: "EVASORT", icon: "󰒋", desc: "AUTO PIPELINE", status: root.sortWatcherRunning ? "WATCHER ON" : "STANDBY", active: root.sortWatcherRunning },
        { idx: 3, id: "link", name: "EVALINK", icon: "󰇚", desc: "DOWNLINK RPC", status: root.evalinkOnline ? ("DL: " + root.dlSpeed) : "OFFLINE", active: root.evalinkOnline },
        { idx: 4, id: "tube", name: "EVATUBE", icon: "󰎆", desc: "MEDIA STREAM", status: (root.statusData && root.statusData.tube && root.statusData.tube.available) ? "READY" : "OFFLINE", active: !!(root.statusData && root.statusData.tube && root.statusData.tube.available) },
        { idx: 5, id: "shell", name: "QUICKSHELL", icon: "󰵆", desc: "SHELL RUNTIME", status: "ONLINE", active: true }
    ]

    color: root.panelBg
    border.width: 1
    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

    // Top Specular Highlight Edge
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
                text: "▶ EVA-02 // ECOSYSTEM TELEMETRY HUD"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 18
                implicitWidth: syncRow.implicitWidth + 8
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                border.width: 1
                border.color: root.primary

                RowLayout {
                    id: syncRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle { width: 4; height: 4; radius: 2; color: root.primary }
                    Text {
                        text: "SYNC: 100%"
                        color: root.primary
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

        // Section Label
        Text {
            text: "6-POINT SERVICE CONSENSUS STATUS"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.8
        }

        // 6 Services Quick Summary Stack
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.servicesSummary

                Rectangle {
                    id: sRowCard
                    required property var modelData
                    Layout.fillWidth: true
                    height: 32
                    color: sMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : root.itemBg
                    border.width: 1
                    border.color: sMouse.containsMouse ? root.primary : (sRowCard.modelData.active ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3) : root.itemBorder)
                    scale: sMouse.pressed ? 0.97 : (sMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: sRowCard.modelData.icon
                            color: sRowCard.modelData.active ? root.primary : root.fgDim
                            font.pixelSize: 11
                        }

                        Text {
                            text: sRowCard.modelData.name
                            color: sRowCard.modelData.active ? root.primary : root.fg
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                        }

                        Text {
                            text: sRowCard.modelData.desc
                            color: root.fgDim
                            font.family: root.hudFont
                            font.pixelSize: 6
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: sRowCard.modelData.status
                            color: sRowCard.modelData.active ? root.primary : root.fgMuted
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: sRowCard.modelData.active ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                            border.width: 0.5
                            border.color: sRowCard.modelData.active ? "#ffffff" : "transparent"
                        }
                    }

                    MouseArea {
                        id: sMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.appSelectRequested(sRowCard.modelData.idx)
                    }
                }
            }
        }

        // Section Label
        Text {
            text: "NERV COMMAND RAPID TELEMETRY"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.8
        }

        // Rapid Status Telemetry Tiles
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            // Tile 1: Downlink RPC Bandwidth
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
                    Text { text: "󰇚 ARIA2 DOWNLINK"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: root.dlSpeed; color: root.secondary; font.family: root.hudFont; font.pixelSize: 10; font.bold: true }
                    Text { text: "ACT: " + root.activeDownloads + " TRANSFERS"; color: root.primary; font.family: root.hudFont; font.pixelSize: 6 }
                }
            }

            // Tile 2: Sorter Watcher
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
                    Text { text: "󰒋 PIPELINE WATCHER"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: root.sortWatcherRunning ? "DAEMON ON" : "STANDBY"; color: root.primary; font.family: root.hudFont; font.pixelSize: 10; font.bold: true }
                    Text { text: "SRC: " + root.sortSourceDir; color: root.fgMuted; font.family: root.hudFont; font.pixelSize: 6; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Rapid Operations Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: cleanDlMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.secondary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰒋"; color: cleanDlMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                    Text { text: "CLEAN DOWNLOADS"; color: cleanDlMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }

                MouseArea {
                    id: cleanDlMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cleanDownloadsRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: openDlFolderMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰝰"; color: openDlFolderMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 8 }
                    Text { text: "OPEN DOWNLOADS"; color: openDlFolderMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }

                MouseArea {
                    id: openDlFolderMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openFolderRequested("~/Downloads")
                }
            }
        }
    }
}
