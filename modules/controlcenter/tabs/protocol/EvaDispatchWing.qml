import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property var magiLogs: []
    property bool magiBusy: false
    property bool magiDeliberating: false
    property string statusLine: "EVA ORCHESTRATOR: ONLINE // LATENCY: 12ms"

    signal dispatchCommand(string cmdText)
    signal triggerQuickAction(string actionName)

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.94)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.85)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    color: root.panelBg
    border.width: 1
    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

    // Top Directional Specular Highlight Rim
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 1
        color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top Hazard Line Strip
        NervHazardLines {
            Layout.fillWidth: true
            height: 8
            stripeColor: root.primary
            bgColor: "#ffffff"
        }

        // Header Info
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "[ MAGI // EVACORE DISPATCH ]"
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
                    color: (root.magiBusy || root.magiDeliberating) ? root.highlight : root.primary
                }
            }

            Text {
                text: root.statusLine
                color: root.fgMuted
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
            }
        }

        // Quick Dispatch Action Pills
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                height: 18
                color: qStatMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary
                Text { anchors.centerIn: parent; text: "STATUS"; color: qStatMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                MouseArea { id: qStatMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerQuickAction("status") }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 18
                color: qSortMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary
                Text { anchors.centerIn: parent; text: "SORT"; color: qSortMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                MouseArea { id: qSortMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerQuickAction("sort") }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 18
                color: qFileMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary
                Text { anchors.centerIn: parent; text: "FILE"; color: qFileMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                MouseArea { id: qFileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerQuickAction("file") }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 18
                color: qTermMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary
                Text { anchors.centerIn: parent; text: "TERM"; color: qTermMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                MouseArea { id: qTermMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerQuickAction("term") }
            }
        }

        // Terminal Log Stream Buffer
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            color: "#ffffff"
            border.width: 1
            border.color: root.itemBorder
            clip: true

            Flickable {
                id: logFlickable
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: width
                contentHeight: logColumn.implicitHeight
                clip: true

                onContentHeightChanged: {
                    logFlickable.contentY = Math.max(0, logColumn.implicitHeight - logFlickable.height);
                }

                Column {
                    id: logColumn
                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: root.magiLogs

                        Text {
                            width: logColumn.width
                            text: modelData
                            color: modelData.startsWith(">")
                                ? root.highlight
                                : (modelData.indexOf("ONLINE") !== -1 || modelData.indexOf("ACTIVE") !== -1 || modelData.indexOf("PASS") !== -1 || modelData.indexOf("APPROVED") !== -1
                                    ? root.primary
                                    : (modelData.indexOf("DENY") !== -1 || modelData.indexOf("REJECT") !== -1 ? "#ff1100" : root.fgMuted))
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }

        // Bottom Input Field & Dispatch Button
        Rectangle {
            Layout.fillWidth: true
            Layout.margins: 8
            height: 26
            color: "#ffffff"
            border.width: 1
            border.color: root.primary

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 6

                Text {
                    text: "MAGI >"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }

                TextInput {
                    id: aiInput
                    Layout.fillWidth: true
                    color: root.fg
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                    clip: true
                    selectByMouse: true
                    onAccepted: {
                        if (text.trim().length > 0) {
                            root.dispatchCommand(text.trim());
                            text = "";
                        }
                    }
                }

                Rectangle {
                    width: 52
                    height: 18
                    color: sendMouse.containsMouse ? root.primary : "#ffffff"
                    border.width: 1
                    border.color: root.primary

                    Text {
                        anchors.centerIn: parent
                        text: root.magiBusy ? "BUSY" : "DISPATCH"
                        color: sendMouse.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 6
                        font.bold: true
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (aiInput.text.trim().length > 0) {
                                root.dispatchCommand(aiInput.text.trim());
                                aiInput.text = "";
                            }
                        }
                    }
                }
            }
        }

        // Bottom Hazard Line Strip
        NervHazardLines {
            Layout.fillWidth: true
            height: 8
            stripeColor: root.primary
            bgColor: "#ffffff"
            scrollLeft: true
        }
    }
}
