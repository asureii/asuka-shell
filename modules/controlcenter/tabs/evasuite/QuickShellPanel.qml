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

    signal reloadRequested()
    signal reprobeRequested()
    signal openConfigRequested()

    readonly property string evacoreVersion: (root.statusData && root.statusData.evacore) ? (root.statusData.evacore.version || "0.1.0") : "0.1.0"
    readonly property bool evacoreInstalled: !!(root.statusData && root.statusData.evacore && root.statusData.evacore.installed)

    readonly property var modulesList: [
        { name: "TOP BAR PODS", file: "modules/bar/Bar.qml", status: "ONLINE", icon: "󰍹" },
        { name: "CONTROL CENTER", file: "ControlCenterOverlay.qml", status: "ACTIVE", icon: "󰒋" },
        { name: "NOTIFICATIONS", file: "NotificationPopup.qml", status: "STANDBY", icon: "󰂚" },
        { name: "AREA PICKER", file: "AreaPicker.qml", status: "READY", icon: "󰆞" },
        { name: "MAGI 3D CORE", file: "components/MagiHoloCore3D.qml", status: "ONLINE", icon: "󰵆" },
        { name: "ASUKA SDDM", file: "sddm/evangelion-asuka", status: "READY", icon: "󰷛" }
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
                text: "▶ QUICKSHELL // DESKTOP RUNTIME & IPC"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                height: 18
                implicitWidth: qsStatusRow.implicitWidth + 8
                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                border.width: 1
                border.color: root.primary

                RowLayout {
                    id: qsStatusRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle { width: 4; height: 4; radius: 2; color: root.primary }
                    Text {
                        text: "ACTIVE // WAYLAND"
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

        // Hot Reload Shell Hero Action Card
        Rectangle {
            Layout.fillWidth: true
            height: 42
            color: reloadCardMouse.containsMouse ? root.primary : root.itemBg
            border.width: 1.5
            border.color: root.secondary
            scale: reloadCardMouse.pressed ? 0.97 : (reloadCardMouse.containsMouse ? 1.01 : 1.0)

            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            // Directional Specular
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1
                color: "#ffffff"
                opacity: reloadCardMouse.containsMouse ? 0.95 : 0.4
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: reloadCardMouse.containsMouse ? "#ffffff" : root.primary
                    Text {
                        anchors.centerIn: parent
                        text: "⟳"
                        color: reloadCardMouse.containsMouse ? root.primary : "#ffffff"
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "HOT RELOAD QUICKSHELL ENVIRONMENT"
                        color: reloadCardMouse.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    Text {
                        text: "DISPATCH RESTART SIGNAL WITHOUT DISRUPTING COMPOSITOR"
                        color: reloadCardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.8) : root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                    }
                }

                Text {
                    text: "EXECUTE ⟳"
                    color: reloadCardMouse.containsMouse ? "#ffffff" : root.secondary
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }
            }

            MouseArea {
                id: reloadCardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reloadRequested()
            }
        }

        // Section Label: Modules Status
        Text {
            text: "ECOSYSTEM SUBSYSTEMS DIAGNOSTIC MATRIX"
            color: root.primary
            font.family: root.hudFont
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 0.8
        }

        // Subsystems Diagnostic Grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: root.modulesList

                Rectangle {
                    id: modCard
                    required property var modelData
                    Layout.fillWidth: true
                    height: 36
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Text {
                            text: modCard.modelData.icon
                            color: root.primary
                            font.pixelSize: 11
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: modCard.modelData.name
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }

                            Text {
                                text: modCard.modelData.file
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 6
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            height: 14
                            implicitWidth: modStatusText.implicitWidth + 8
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                            border.width: 0.5
                            border.color: root.primary

                            Text {
                                id: modStatusText
                                anchors.centerIn: parent
                                text: modCard.modelData.status
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 6
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // EvaCore Bridge IPC & Config Bar
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: root.itemBg
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 6

                Text {
                    text: "EVACORE IPC: " + (root.evacoreInstalled ? ("ONLINE (v" + root.evacoreVersion + ")") : "FALLBACK")
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                // Re-probe IPC
                Rectangle {
                    width: 60
                    height: 18
                    color: reprobeIpcMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.secondary

                    Text {
                        anchors.centerIn: parent
                        text: "⟳ RE-PROBE"
                        color: reprobeIpcMouse.containsMouse ? "#ffffff" : root.secondary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    MouseArea {
                        id: reprobeIpcMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.reprobeRequested()
                    }
                }

                // Open Config Directory
                Rectangle {
                    width: 72
                    height: 18
                    color: openCfgMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.primary

                    Text {
                        anchors.centerIn: parent
                        text: "󰝰 OPEN CONFIG"
                        color: openCfgMouse.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    MouseArea {
                        id: openCfgMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openConfigRequested()
                    }
                }
            }
        }
    }
}
