import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property bool evalinkOnline: false
    property string dlSpeed: "0 B/s"
    property string ulSpeed: "0 B/s"
    property int activeCount: 0
    property int waitingCount: 0
    property int stoppedCount: 0
    property var downloadTasks: []
    property string newDownloadUrl: ""

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

    signal addUriRequested(string url)
    signal pauseRequested(string gid)
    signal resumeRequested(string gid)
    signal cancelRequested(string gid)
    signal pauseAllRequested()
    signal resumeAllRequested()
    signal purgeRequested()
    signal startDaemonRequested()
    signal pasteClipboardRequested()
    signal openDownloadsRequested()

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
                text: "▶ EVALINK // DOWNLINK MATRIX"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 68
                height: 18
                color: root.evalinkOnline ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.evalinkOnline ? root.secondary : root.itemBorder

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 3
                    Rectangle { width: 4; height: 4; radius: 2; color: root.evalinkOnline ? "#ffffff" : root.fgDim }
                    Text {
                        text: root.evalinkOnline ? "ONLINE" : "OFFLINE"
                        color: root.evalinkOnline ? "#ffffff" : root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.evalinkOnline) root.startDaemonRequested();
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

        // Global Bandwidth Telemetry Bar
        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 6

                Text { text: "DL: " + root.dlSpeed; color: root.secondary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
                Text { text: "UL: " + root.ulSpeed; color: root.primary; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }

                Item { Layout.fillWidth: true }

                Text {
                    text: "ACT: " + root.activeCount + " | Q: " + root.waitingCount + " | DONE: " + root.stoppedCount
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }
            }
        }

        // Scrollable Download Tasks List or Radar HUD
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: tasksCol.implicitHeight

            Column {
                id: tasksCol
                width: parent.width
                spacing: 4

                // Empty State: Tactical Downlink Radar HUD
                Item {
                    id: emptyRadar
                    width: tasksCol.width
                    visible: root.downloadTasks.length === 0
                    height: visible ? (radarCol.implicitHeight + 10) : 0
                    clip: true

                    ColumnLayout {
                        id: radarCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 8

                        // Radar Crosshair Reticle
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: 80
                            height: 80

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.02)
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 50
                                height: 50
                                radius: 25
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                radius: 12
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.4)
                            }

                            Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25) }
                            Rectangle { anchors.centerIn: parent; width: 1; height: parent.height; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25) }
                            Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: root.primary }

                            // Sweeping Radar Beam
                            Item {
                                anchors.fill: parent

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.verticalCenter
                                    width: 1.5
                                    height: parent.height / 2
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 1.0; color: root.primary }
                                    }
                                }

                                RotationAnimation on rotation {
                                    from: 0
                                    to: 360
                                    duration: 4000
                                    loops: Animation.Infinite
                                    running: root.visible && root.downloadTasks.length === 0
                                }
                            }
                        }

                        // Subtitle
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰇚 NERV DOWNLINK // STANDBY"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.8
                        }

                        // Fast Presets
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                height: 22
                                color: pasteMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "󰅌"; color: pasteMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                                    Text { text: "PASTE CLIPBOARD"; color: pasteMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                }

                                MouseArea {
                                    id: pasteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.pasteClipboardRequested()
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 22
                                color: openDlMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.secondary

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text { text: "󰝰"; color: openDlMouse.containsMouse ? "#ffffff" : root.secondary; font.pixelSize: 8 }
                                    Text { text: "OPEN DOWNLOADS"; color: openDlMouse.containsMouse ? "#ffffff" : root.secondary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                                }

                                MouseArea {
                                    id: openDlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openDownloadsRequested()
                                }
                            }
                        }
                    }
                }

                // Active Download Cards
                Repeater {
                    model: root.downloadTasks

                    Rectangle {
                        id: taskCard
                        required property var modelData
                        width: tasksCol.width
                        height: 52
                        color: "#ffffff"
                        border.width: 1
                        border.color: taskCard.modelData.status === "active" ? root.secondary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: taskCard.modelData.status === "active" ? "▶" : (taskCard.modelData.status === "paused" ? "⏸" : "✓")
                                    color: taskCard.modelData.status === "active" ? root.secondary : (taskCard.modelData.status === "paused" ? root.primary : root.fgMuted)
                                    font.pixelSize: 8
                                }

                                Text {
                                    text: taskCard.modelData.name
                                    color: taskCard.modelData.status === "active" ? root.secondary : root.fg
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: taskCard.modelData.speedStr
                                    color: taskCard.modelData.status === "active" ? root.secondary : root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }

                            // Progress Bar
                            Rectangle {
                                Layout.fillWidth: true
                                height: 3
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15)

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * Math.max(0, Math.min(1.0, taskCard.modelData.pct))
                                    color: taskCard.modelData.status === "active" ? root.secondary : root.primary
                                }
                            }

                            // Controls & ETA
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    text: Math.round(taskCard.modelData.pct * 100) + "% | " + taskCard.modelData.sizeStr
                                    color: root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "ETA " + taskCard.modelData.eta
                                    color: root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    visible: taskCard.modelData.status === "active"
                                }

                                // Pause / Resume
                                Rectangle {
                                    width: 38
                                    height: 15
                                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                    border.width: 1
                                    border.color: root.secondary
                                    visible: taskCard.modelData.status === "active" || taskCard.modelData.status === "paused"

                                    Text {
                                        anchors.centerIn: parent
                                        text: taskCard.modelData.status === "active" ? "⏸" : "▶"
                                        color: root.secondary
                                        font.pixelSize: 7
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (taskCard.modelData.status === "active") root.pauseRequested(taskCard.modelData.gid);
                                            else root.resumeRequested(taskCard.modelData.gid);
                                        }
                                    }
                                }

                                // Cancel
                                Rectangle {
                                    width: 16
                                    height: 15
                                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                    border.width: 1
                                    border.color: root.primary

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: root.primary
                                        font.pixelSize: 7
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.cancelRequested(taskCard.modelData.gid)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Quick URL Injector Bar
        Rectangle {
            Layout.fillWidth: true
            height: 24
            color: "#ffffff"
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 4
                spacing: 4

                TextInput {
                    id: urlInput
                    Layout.fillWidth: true
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 8
                    clip: true
                    selectByMouse: true
                    text: root.newDownloadUrl
                    onAccepted: {
                        root.addUriRequested(text);
                        urlInput.text = "";
                    }

                    Text {
                        anchors.fill: parent
                        visible: !urlInput.text && !urlInput.activeFocus
                        text: "INPUT URL (HTTP / MAGNET / TORRENT) >"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                    }
                }

                Rectangle {
                    width: 54
                    height: 16
                    color: urlInjectMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.secondary

                    Text {
                        anchors.centerIn: parent
                        text: "+ INJECT"
                        color: urlInjectMouse.containsMouse ? "#ffffff" : root.secondary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }

                    MouseArea {
                        id: urlInjectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.addUriRequested(urlInput.text);
                            urlInput.text = "";
                        }
                    }
                }
            }
        }

        // Batch Action Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                height: 20
                color: pauseAllMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.secondary

                Text {
                    anchors.centerIn: parent
                    text: "⏸ PAUSE ALL"
                    color: pauseAllMouse.containsMouse ? "#ffffff" : root.secondary
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                MouseArea {
                    id: pauseAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pauseAllRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 20
                color: resumeAllMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.secondary

                Text {
                    anchors.centerIn: parent
                    text: "▶ RESUME ALL"
                    color: resumeAllMouse.containsMouse ? "#ffffff" : root.secondary
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                MouseArea {
                    id: resumeAllMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resumeAllRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 20
                color: purgeMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary

                Text {
                    anchors.centerIn: parent
                    text: "⟳ PURGE"
                    color: purgeMouse.containsMouse ? "#ffffff" : root.primary
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                MouseArea {
                    id: purgeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.purgeRequested()
                }
            }
        }
    }
}
