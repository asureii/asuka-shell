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

    signal launchRequested(string cwd, string cmd)

    property string customCmd: ""
    property string customCwd: "~"

    readonly property bool isRunning: !!(root.statusData && root.statusData.term && root.statusData.term.running)
    readonly property int sessionCount: (root.statusData && root.statusData.term) ? (root.statusData.term.count || 0) : 0
    readonly property var sessionPids: (root.statusData && root.statusData.term) ? (root.statusData.term.pids || []) : []

    readonly property var presetCommands: [
        { label: "BTOPSYS", cmd: "btop", desc: "RESOURCE MONITOR", icon: "󰒋" },
        { label: "FASTFETCH", cmd: "fastfetch", desc: "SYSTEM TELEMETRY", icon: "󰋜" },
        { label: "NVIM RICE", cmd: "nvim ~/.config/quickshell/evangelion", desc: "QML CONFIG", icon: "" },
        { label: "GIT STATUS", cmd: "git status", desc: "REPO REVISION", icon: "󰊢" },
        { label: "EVACORE CLI", cmd: "evacore", desc: "SYSTEM BRIDGE", icon: "󰝰" },
        { label: "HTOP PROCS", cmd: "htop", desc: "PROCESS TREE", icon: "󰆍" }
    ]

    color: root.panelBg
    border.width: 1
    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

    // Top Specular Highlight
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
                text: "▶ EVATERM // GPU TACTICAL SHELL CLUSTER"
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
                        text: root.isRunning ? (root.sessionCount + " SESSIONS ACTIVE") : "STANDBY"
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

        // Active Session PID Telemetry Bar
        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "SESSIONS:"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                Text {
                    text: root.sessionPids.length > 0 ? ("PIDS: [" + root.sessionPids.join(", ") + "]") : "NO ACTIVE SESSIONS (READY TO SPAWN)"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Custom Command Dispatch Bar
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
                    text: "CMD >"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                TextInput {
                    id: cmdInput
                    Layout.fillWidth: true
                    text: root.customCmd
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 8
                    selectByMouse: true
                    clip: true
                    onAccepted: {
                        root.launchRequested(root.customCwd, text);
                        cmdInput.text = "";
                    }
                    onTextChanged: root.customCmd = text

                    Text {
                        anchors.fill: parent
                        visible: !cmdInput.text && !cmdInput.activeFocus
                        text: "e.g. nvim, btop, bash script..."
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                    }
                }

                Rectangle {
                    width: 64
                    height: 18
                    color: spawnCmdMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.secondary

                    Text {
                        anchors.centerIn: parent
                        text: "▶ EXECUTE"
                        color: spawnCmdMouse.containsMouse ? "#ffffff" : root.secondary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    MouseArea {
                        id: spawnCmdMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.launchRequested(root.customCwd, cmdInput.text);
                            cmdInput.text = "";
                        }
                    }
                }
            }
        }

        // Section Label: Preset Launchers
        Text {
            text: "RAPID TASK EXECUTION MATRIX // PRESETS"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.8
        }

        // Preset Commands Grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: root.presetCommands

                Rectangle {
                    id: presetCard
                    required property var modelData
                    Layout.fillWidth: true
                    height: 40
                    color: presetMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : root.itemBg
                    border.width: 1
                    border.color: presetMouse.containsMouse ? root.primary : root.itemBorder
                    scale: presetMouse.pressed ? 0.96 : (presetMouse.containsMouse ? 1.02 : 1.0)

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
                        opacity: presetMouse.containsMouse ? 0.9 : 0.35
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Text {
                            text: presetCard.modelData.icon
                            color: root.primary
                            font.pixelSize: 12
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: presetCard.modelData.label
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Text {
                                text: presetCard.modelData.cmd
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 6
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: "▶"
                            color: presetMouse.containsMouse ? root.primary : root.fgDim
                            font.pixelSize: 7
                        }
                    }

                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchRequested("~", presetCard.modelData.cmd)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Bottom Spawn Shell Action
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: spawnBlankMouse.containsMouse ? root.primary : "#ffffff"
            border.width: 1.5
            border.color: root.primary

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰆍"
                    color: spawnBlankMouse.containsMouse ? "#ffffff" : root.primary
                    font.pixelSize: 12
                }

                Text {
                    text: "SPAWN INTERACTIVE SHELL"
                    color: spawnBlankMouse.containsMouse ? "#ffffff" : root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.0
                }
            }

            MouseArea {
                id: spawnBlankMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchRequested("~", "")
            }
        }
    }
}
