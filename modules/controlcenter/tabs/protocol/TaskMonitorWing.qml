import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property int totalTasks: 0
    property real totalCpu: 0.0
    property var filteredProcesses: []
    property string selectedPid: ""
    property string selectedProcName: ""
    property bool isTaskFetching: false

    signal processSelected(string pid, string procName)
    signal processTerminateRequested(string pid)
    signal filterChanged(string query)

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
                    text: "[ TASK MONITOR ]"
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
                    color: root.isTaskFetching ? root.highlight : root.primary
                }
            }

            Text {
                text: "TASKS: " + root.totalTasks + " | CPU: " + root.totalCpu.toFixed(1) + "%"
                color: root.fgMuted
                font.family: root.hudFont
                font.pixelSize: 8
                font.bold: true
            }

            // Filter search input box
            Rectangle {
                Layout.fillWidth: true
                height: 22
                color: "#ffffff"
                border.width: 1
                border.color: filterInput.activeFocus ? root.primary : root.itemBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 4

                    Text {
                        text: "FILTER >"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }

                    TextInput {
                        id: filterInput
                        Layout.fillWidth: true
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                        clip: true
                        selectByMouse: true
                        onTextChanged: root.filterChanged(text)
                    }

                    Text {
                        visible: filterInput.text.length > 0
                        text: "✕"
                        color: root.fgDim
                        font.pixelSize: 8
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: filterInput.text = ""
                        }
                    }
                }
            }
        }

        // Process Table Columns Header
        Rectangle {
            Layout.fillWidth: true
            height: 18
            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 4

                Text { text: "PID"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; Layout.preferredWidth: 26 }
                Text { text: "PROCESS"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; Layout.fillWidth: true }
                Text { text: "CPU"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 32 }
                Text { text: "MEM"; color: root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 30 }
            }
        }

        // Process List View
        ListView {
            id: procListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.filteredProcesses
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: procRow
                width: procListView.width
                height: 18
                readonly property bool isSelected: root.selectedPid === modelData.pid

                color: isSelected
                    ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.16)
                    : (rowMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06) : "#ffffff")

                border.width: isSelected ? 1 : 0
                border.color: root.primary

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 4

                    Text {
                        text: modelData.pid
                        color: isSelected ? root.primary : root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: isSelected
                        Layout.preferredWidth: 26
                    }

                    Text {
                        text: modelData.name
                        color: isSelected ? root.primary : root.fg
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: isSelected
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: modelData.cpu
                        color: isSelected ? root.highlight : (parseFloat(modelData.cpu) > 10.0 ? root.primary : root.fgMuted)
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 32
                    }

                    Text {
                        text: modelData.mem
                        color: isSelected ? root.primary : root.fgMuted
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 30
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.selectedPid === modelData.pid) {
                            root.processSelected("", "");
                        } else {
                            root.processSelected(modelData.pid, modelData.name);
                        }
                    }
                    onDoubleClicked: {
                        root.processTerminateRequested(modelData.pid);
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
