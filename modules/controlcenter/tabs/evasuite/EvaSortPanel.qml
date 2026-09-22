import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property var statusData: ({})
    property var sortCategories: []
    property string sortSourceDir: "~/Downloads"
    property string sortStrategy: "rename"
    property string sortFeedback: ""

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

    signal runSortRequested(string path)
    signal toggleDaemonRequested()
    signal openFolderRequested(string path)

    readonly property bool isWatcherActive: !!(root.statusData && root.statusData.sort && root.statusData.sort.running)

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
                text: "▶ EVASORT // DIRECTORY INGESTION PIPELINE"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 18
                implicitWidth: watcherRow.implicitWidth + 8
                color: root.isWatcherActive ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "#ffffff"
                border.width: 1
                border.color: root.isWatcherActive ? root.primary : root.itemBorder

                RowLayout {
                    id: watcherRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle { width: 4; height: 4; radius: 2; color: root.isWatcherActive ? root.primary : root.fgDim }
                    Text {
                        text: root.isWatcherActive ? "WATCHER ON" : "STANDBY"
                        color: root.isWatcherActive ? root.primary : root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDaemonRequested()
                }
            }
        }

        NervHazardLines {
            Layout.fillWidth: true
            height: 6
            stripeColor: root.primary
            bgColor: "#ffffff"
        }

        // Source Meta & Action Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Meta Chip: Source Directory
            Rectangle {
                height: 22
                implicitWidth: srcRow.implicitWidth + 10
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)

                RowLayout {
                    id: srcRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "SRC:"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: root.sortSourceDir; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }
            }

            // Meta Chip: Conflict Strategy
            Rectangle {
                height: 22
                implicitWidth: stratRow.implicitWidth + 10
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)

                RowLayout {
                    id: stratRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "STRAT:"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: root.sortStrategy.toUpperCase(); color: root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }
            }

            Item { Layout.fillWidth: true }

            // Toggle Watcher Button
            Rectangle {
                height: 22
                implicitWidth: toggleWatcherRow.implicitWidth + 10
                color: toggleWatcherMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary

                RowLayout {
                    id: toggleWatcherRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "󰈈"; color: toggleWatcherMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 8 }
                    Text { text: root.isWatcherActive ? "STOP WATCHER" : "START WATCHER"; color: toggleWatcherMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                }

                MouseArea {
                    id: toggleWatcherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleDaemonRequested()
                }
            }
        }

        // Action Trigger Button: Clean Downloads Now
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: cleanNowMouse.containsMouse ? root.primary : "#ffffff"
            border.width: 1
            border.color: root.secondary

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰒋"; color: cleanNowMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 10 }
                Text { text: "EXECUTE DIRECTORY SORT // CLEAN DOWNLOADS"; color: cleanNowMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.8 }
            }

            MouseArea {
                id: cleanNowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.runSortRequested(root.sortSourceDir)
            }
        }

        // Live Feedback Toast
        Text {
            visible: root.sortFeedback.length > 0
            text: root.sortFeedback
            color: root.secondary
            font.family: root.hudFont
            font.pixelSize: 7
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        // Section Label
        Text {
            text: "CATEGORY ROUTING PIPELINE // " + root.sortCategories.length + " DESTINATIONS"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.8
        }

        // Scrollable Category Pipeline List
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: catCol.implicitHeight

            Column {
                id: catCol
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.sortCategories

                    Rectangle {
                        id: catCard
                        required property var modelData
                        width: catCol.width
                        height: 38
                        color: catMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05) : "#ffffff"
                        border.width: 1
                        border.color: catMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18)
                        scale: catMouse.pressed ? 0.98 : (catMouse.containsMouse ? 1.01 : 1.0)

                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                        // Specular Rim
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: "#ffffff"
                            opacity: catMouse.containsMouse ? 0.9 : 0.35
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: catCard.modelData.icon || "󰒋"
                                color: root.primary
                                font.pixelSize: 10
                            }

                            Text {
                                text: (catCard.modelData.name || "CATEGORY").toUpperCase()
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Text { text: "▶"; color: root.fgDim; font.pixelSize: 6 }

                            // Destination Chip (Clickable to open in EvaFile)
                            Rectangle {
                                height: 18
                                implicitWidth: destRow.implicitWidth + 8
                                color: destMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                                border.width: 0.5
                                border.color: destMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.3)

                                RowLayout {
                                    id: destRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text { text: "󰝰"; color: destMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 7 }
                                    Text { text: catCard.modelData.dest || ""; color: destMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                }

                                MouseArea {
                                    id: destMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openFolderRequested(catCard.modelData.dest_full || catCard.modelData.dest)
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: {
                                    var exts = catCard.modelData.exts || [];
                                    var sample = exts.slice(0, 3).join(", ");
                                    return (catCard.modelData.count || exts.length) + " fmts (" + sample + (exts.length > 3 ? ", …" : "") + ")";
                                }
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                            }
                        }

                        MouseArea {
                            id: catMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }
        }
    }
}
