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

    signal launchRequested(string path)

    property string customPath: "~/Downloads"

    readonly property bool isRunning: !!(root.statusData && root.statusData.file && root.statusData.file.running)
    readonly property int instanceCount: (root.statusData && root.statusData.file) ? (root.statusData.file.count || 0) : 0
    readonly property var activePids: (root.statusData && root.statusData.file) ? (root.statusData.file.pids || []) : []

    readonly property var quickDirs: [
        { name: "DOWNLOADS", path: "~/Downloads", icon: "󰇚" },
        { name: "DOCUMENTS", path: "~/Documents", icon: "󰈙" },
        { name: "PICTURES", path: "~/Pictures", icon: "󰋩" },
        { name: "VIDEOS", path: "~/Videos", icon: "󰕧" },
        { name: "MUSIC", path: "~/Music", icon: "󰝚" },
        { name: "HOME", path: "~", icon: "󰋜" },
        { name: "ROOT FS", path: "/", icon: "󰋊" },
        { name: "CONFIG", path: "~/.config/quickshell/evangelion", icon: "󰒋" }
    ]

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
                text: "▶ EVAFILE // VFS SPATIAL BROWSER"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 18
                implicitWidth: statusRow.implicitWidth + 8
                color: root.isRunning ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "#ffffff"
                border.width: 1
                border.color: root.isRunning ? root.primary : root.itemBorder

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle { width: 4; height: 4; radius: 2; color: root.isRunning ? root.primary : root.fgDim }
                    Text {
                        text: root.isRunning ? (root.instanceCount + " ACTIVE") : "STANDBY"
                        color: root.isRunning ? root.primary : root.fgDim
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

        // Tactical Path Input Bar
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
                    text: "󰝰 PATH:"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                TextInput {
                    id: pathInput
                    Layout.fillWidth: true
                    text: root.customPath
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 8
                    selectByMouse: true
                    clip: true
                    onAccepted: root.launchRequested(text)
                    onTextChanged: root.customPath = text
                }

                Rectangle {
                    width: 58
                    height: 18
                    color: openMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.secondary

                    Text {
                        anchors.centerIn: parent
                        text: "▶ OPEN"
                        color: openMouse.containsMouse ? "#ffffff" : root.secondary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    MouseArea {
                        id: openMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchRequested(pathInput.text)
                    }
                }
            }
        }

        // Section Label: Quick Navigation
        Text {
            text: "DIRECTORY TARGET MATRIX // RAPID ACCESS"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.8
        }

        // Quick Navigation Grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: root.quickDirs

                Rectangle {
                    id: dirCard
                    required property var modelData
                    Layout.fillWidth: true
                    height: 38
                    color: dirMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : root.itemBg
                    border.width: 1
                    border.color: dirMouse.containsMouse ? root.primary : root.itemBorder
                    scale: dirMouse.pressed ? 0.96 : (dirMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    // Top Specular Highlight
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#ffffff"
                        opacity: dirMouse.containsMouse ? 0.9 : 0.35
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Text {
                            text: dirCard.modelData.icon
                            color: root.primary
                            font.pixelSize: 12
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: dirCard.modelData.name
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Text {
                                text: dirCard.modelData.path
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 6
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: "▶"
                            color: dirMouse.containsMouse ? root.primary : root.fgDim
                            font.pixelSize: 7
                        }
                    }

                    MouseArea {
                        id: dirMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchRequested(dirCard.modelData.path)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Bottom Telemetry & Launch Action
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: launchAllMouse.containsMouse ? root.primary : "#ffffff"
            border.width: 1.5
            border.color: root.primary

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰝰"
                    color: launchAllMouse.containsMouse ? "#ffffff" : root.primary
                    font.pixelSize: 12
                }

                Text {
                    text: "SPAWN EVAFILE EXPLORER"
                    color: launchAllMouse.containsMouse ? "#ffffff" : root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.0
                }
            }

            MouseArea {
                id: launchAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchRequested(root.customPath)
            }
        }
    }
}
