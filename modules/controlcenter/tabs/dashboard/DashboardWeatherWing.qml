import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property var weatherData: ({})
    property bool weatherLoading: false
    property bool focused: false
    signal refreshRequested()

    readonly property color primary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.50)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.94)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.85)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.30)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    // ---------- data helpers ----------
    function val(key, def) {
        return (root.weatherData && root.weatherData[key] !== undefined && root.weatherData[key] !== null)
            ? root.weatherData[key] : def;
    }
    readonly property var forecast: val("forecast", [])
    readonly property bool hasData: root.weatherData && root.weatherData.temp !== undefined
    readonly property bool isOffline: root.weatherData && root.weatherData.success === false
    readonly property bool isCached: !!val("cached", false)
    readonly property string statusText: root.weatherLoading ? "SYNCING"
                                       : (!root.hasData ? "NO DATA"
                                       : (root.isOffline ? "OFFLINE" : (root.isCached ? "CACHED" : "LIVE")))
    readonly property color statusColor: (root.statusText === "LIVE") ? "#1f9d3a"
                                       : (root.statusText === "SYNCING" ? root.primary : "#c77700")

    readonly property real rangeMin: {
        var m = 999;
        for (var i = 0; i < forecast.length; i++) m = Math.min(m, forecast[i].min);
        return m === 999 ? 0 : m;
    }
    readonly property real rangeMax: {
        var m = -999;
        for (var i = 0; i < forecast.length; i++) m = Math.max(m, forecast[i].max);
        return m === -999 ? 1 : m;
    }

    function pulse() { pulseAnim.restart(); }

    color: root.panelBg
    border.width: root.focused ? 1.5 : 1
    border.color: root.focused ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.40)
    Behavior on border.color { ColorAnimation { duration: 180 } }

    // Focus flash when the weather sector is selected in the hex nexus
    Rectangle {
        id: pulseFlash
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: root.highlight
        opacity: 0
        z: 50
        SequentialAnimation {
            id: pulseAnim
            NumberAnimation { target: pulseFlash; property: "opacity"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: pulseFlash; property: "opacity"; to: 0.0; duration: 420; easing.type: Easing.InOutQuad }
        }
    }

    // Top specular lip
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
        anchors.margins: 12
        spacing: 8

        // ============================================================
        // 1. HEADER: TITLE, LINK STATUS, RESCAN
        // ============================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "▶ METEOROLOGICAL RADAR"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.2
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // Link status chip
            Rectangle {
                implicitWidth: statusRow.implicitWidth + 12
                implicitHeight: 20
                color: "#ffffff"
                border.width: 1
                border.color: root.statusColor

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: root.statusColor
                        SequentialAnimation on opacity {
                            running: root.visible && root.statusText === "LIVE"
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                        }
                    }
                    Text {
                        text: root.statusText
                        color: root.statusColor
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.8
                    }
                }
            }

            // Rescan button
            Rectangle {
                implicitWidth: 72
                implicitHeight: 20
                color: rescanMouse.containsMouse && !root.weatherLoading ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary
                opacity: root.weatherLoading ? 0.7 : 1.0
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        id: rescanGlyph
                        text: "⟳"
                        color: rescanMouse.containsMouse && !root.weatherLoading ? "#ffffff" : root.primary
                        font.pixelSize: 11
                        font.bold: true
                        RotationAnimation on rotation {
                            running: root.weatherLoading
                            from: 0; to: 360
                            duration: 900
                            loops: Animation.Infinite
                            onStopped: rescanGlyph.rotation = 0
                        }
                    }
                    Text {
                        text: root.weatherLoading ? "SYNC…" : "RESCAN"
                        color: rescanMouse.containsMouse && !root.weatherLoading ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                MouseArea {
                    id: rescanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.weatherLoading
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refreshRequested()
                }
                ToolTip.visible: rescanMouse.containsMouse
                ToolTip.delay: 600
                ToolTip.text: "Force refresh weather (R)"
            }
        }

        // ============================================================
        // 2. LOCATION BADGE
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 24
            color: "#ffffff"
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: "󰍎"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 11
                }
                Text {
                    text: root.val("sector", "UNKNOWN SECTOR")
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: "UPDATED " + root.val("updated", "--:--:--")
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }
            }
        }

        // ============================================================
        // 3. HERO CURRENT CONDITIONS
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            color: root.itemBg
            border.width: 1
            border.color: root.itemBorder

            // Left accent bar
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: root.primary
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 14

                Text {
                    text: root.val("icon", "󰖙")
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 48
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        spacing: 8
                        Text {
                            text: root.hasData ? (root.val("temp", 0) + "°") : "--°"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 34
                            font.bold: true
                        }
                        ColumnLayout {
                            spacing: 0
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                text: "FEELS " + root.val("feels_like", "--") + "°"
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                            }
                            Text {
                                visible: root.forecast.length > 0
                                text: root.forecast.length > 0
                                      ? ("H " + root.forecast[0].max + "°  L " + root.forecast[0].min + "°")
                                      : ""
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }

                    Text {
                        text: root.val("condition", "AWAITING TELEMETRY")
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.isOffline || root.isCached
                        text: root.isOffline ? "⚠ NETWORK UNREACHABLE — SHOWING FALLBACK DATA"
                                             : "⚠ LINK LOST — SHOWING LAST KNOWN READINGS"
                        color: "#c77700"
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ============================================================
        // 4. ATMOSPHERIC SENSOR TILES
        // ============================================================
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            SensorTile {
                icon: "󰖎"
                label: "HUMIDITY"
                value: root.val("humidity", "--") + "%"
                fill: Math.min(1, root.val("humidity", 0) / 100)
            }

            SensorTile {
                icon: "󰖝"
                label: "WIND"
                value: root.val("wind_speed", "--") + " km/h " + root.val("wind_dir", "")
                fill: Math.min(1, root.val("wind_speed", 0) / 60)

                // Compass arrow pointing where the wind blows toward
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -3
                    text: "↓"
                    color: root.primary
                    font.pixelSize: 16
                    font.bold: true
                    rotation: root.val("wind_deg", 0)
                    Behavior on rotation { RotationAnimation { duration: 400; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic } }
                }
            }

            SensorTile {
                icon: "󰖗"
                label: "PRECIPITATION"
                value: root.val("precipitation", 0) + " mm"
                fill: Math.min(1, root.val("precipitation", 0) / 10)
            }

            SensorTile {
                icon: "󰡴"
                label: "PRESSURE"
                value: root.val("pressure", "--") + " hPa"
                // Map 970..1050 hPa onto the bar
                fill: Math.max(0, Math.min(1, (root.val("pressure", 1013) - 970) / 80))
            }
        }

        // ============================================================
        // 5. 5-DAY FORECAST WITH TEMPERATURE RANGE BARS
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.itemBg
            border.width: 1
            border.color: root.itemBorder
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "▶ 5-DAY FORECAST"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.1
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.forecast.length > 0 ? (Math.round(root.rangeMin) + "° – " + Math.round(root.rangeMax) + "°") : ""
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                // Empty state
                Text {
                    visible: root.forecast.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.weatherLoading ? "ACQUIRING FORECAST…" : "NO FORECAST DATA"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                }

                Repeater {
                    model: root.forecast

                    Rectangle {
                        id: fRow
                        required property var modelData
                        required property int index
                        readonly property bool isToday: index === 0
                        readonly property real span: Math.max(1, root.rangeMax - root.rangeMin)

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.maximumHeight: 40
                        color: fRowMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                                                       : (isToday ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04) : "#ffffff")
                        border.width: 1
                        border.color: isToday ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.55)
                                              : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)

                        MouseArea { id: fRowMouse; anchors.fill: parent; hoverEnabled: true }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            ColumnLayout {
                                spacing: 0
                                Layout.preferredWidth: 38
                                Text {
                                    text: fRow.isToday ? "TODAY" : fRow.modelData.day
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                                Text {
                                    visible: !!fRow.modelData.date
                                    text: fRow.modelData.date ? fRow.modelData.date.slice(8, 10) + "/" + fRow.modelData.date.slice(5, 7) : ""
                                    color: root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }

                            Text {
                                text: fRow.modelData.icon || "󰖙"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 16
                                Layout.preferredWidth: 20
                            }

                            Text {
                                text: (fRow.modelData.desc || "").toUpperCase()
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.preferredWidth: 80
                            }

                            Text {
                                text: fRow.modelData.min + "°"
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 22
                            }

                            // Range bar: position relative to week low/high
                            Item {
                                Layout.preferredWidth: 64
                                Layout.fillWidth: true
                                implicitHeight: 6
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.10)
                                }
                                Rectangle {
                                    x: parent.width * (fRow.modelData.min - root.rangeMin) / fRow.span
                                    width: Math.max(6, parent.width * (fRow.modelData.max - fRow.modelData.min) / fRow.span)
                                    height: parent.height
                                    radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "#e07070" }
                                        GradientStop { position: 1.0; color: root.primary }
                                    }
                                }
                            }

                            Text {
                                text: fRow.modelData.max + "°"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                Layout.preferredWidth: 22
                            }
                        }
                    }
                }
            }
        }
    }

    // Compact sensor tile with a fill gauge along the bottom edge
    component SensorTile: Rectangle {
        property string icon: ""
        property string label: ""
        property string value: ""
        property real fill: 0

        Layout.fillWidth: true
        implicitHeight: 46
        color: "#ffffff"
        border.width: 1
        border.color: root.itemBorder

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2
            RowLayout {
                spacing: 4
                Text { text: icon; color: root.primary; font.family: root.hudFont; font.pixelSize: 10 }
                Text { text: label; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.6 }
            }
            Text {
                text: value
                color: root.fg
                font.family: root.hudFont
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 3
            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
            Rectangle {
                height: parent.height
                width: parent.width * fill
                color: root.primary
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }
}
