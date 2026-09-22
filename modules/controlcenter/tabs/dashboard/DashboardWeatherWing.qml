import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../components"

Rectangle {
    id: root

    property var weatherData: ({})
    property bool weatherLoading: false
    signal refreshRequested()

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

    // Top Specular Highlight Lip
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
        // 1. HEADER & RESCAN ACTION
        // ============================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "▶ METEOROLOGICAL RADAR"
                color: root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.2
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // Rescan Button
            Rectangle {
                width: 64
                height: 20
                color: rescanMouse.containsMouse ? root.primary : "#ffffff"
                border.width: 1
                border.color: root.primary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 3
                    Text {
                        text: "⟳"
                        color: rescanMouse.containsMouse ? "#ffffff" : root.primary
                        font.pixelSize: 8
                        font.bold: true
                    }
                    Text {
                        text: root.weatherLoading ? "SYNC..." : "RESCAN"
                        color: rescanMouse.containsMouse ? "#ffffff" : root.primary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }
                }

                MouseArea {
                    id: rescanMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refreshRequested()
                }
            }
        }

        // ============================================================
        // 2. LOCATION & SECTOR BADGE
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            height: 22
            color: "#ffffff"
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 4

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    color: root.primary
                }

                Text {
                    text: root.weatherData && root.weatherData.sector ? root.weatherData.sector : "TOKYO-3 // GEO-FRONT"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: "UPD: " + (root.weatherData && root.weatherData.updated ? root.weatherData.updated : "--:--:--")
                    color: root.fgMuted
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }
            }
        }

        // ============================================================
        // 3. HERO CURRENT WEATHER CARD
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            height: 88
            color: root.itemBg
            border.width: 1
            border.color: root.itemBorder

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                // Giant Weather Glyph
                Text {
                    text: root.weatherData && root.weatherData.icon ? root.weatherData.icon : "󰖙"
                    color: root.primary
                    font.pixelSize: 42
                    Layout.alignment: Qt.AlignVCenter
                }

                // Temp & Description
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        spacing: 6
                        Text {
                            text: (root.weatherData && root.weatherData.temp !== undefined ? root.weatherData.temp : 28) + "°C"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 28
                            font.bold: true
                        }
                        Text {
                            text: "FEELS " + (root.weatherData && root.weatherData.feels_like !== undefined ? root.weatherData.feels_like : 31) + "°"
                            color: root.fgMuted
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 4
                        }
                    }

                    Text {
                        text: root.weatherData && root.weatherData.condition ? root.weatherData.condition : "ATMOSPHERE NOMINAL"
                        color: root.fg
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "SURFACE CONDITIONS // VISIBILITY OPTIMAL"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }
                }
            }
        }

        // ============================================================
        // 4. ATMOSPHERIC SENSOR TILES (2x2 GRID)
        // ============================================================
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 4
            rowSpacing: 4

            Rectangle {
                Layout.fillWidth: true
                height: 38
                color: "#ffffff"
                border.width: 1
                border.color: root.itemBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 1
                    Text { text: "󰖆 HUMIDITY"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: (root.weatherData && root.weatherData.humidity !== undefined ? root.weatherData.humidity : 65) + "% REL"; color: root.primary; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 38
                color: "#ffffff"
                border.width: 1
                border.color: root.itemBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 1
                    Text { text: "󰖝 WIND VECTOR"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: (root.weatherData && root.weatherData.wind_speed !== undefined ? root.weatherData.wind_speed : 12) + " km/h " + (root.weatherData && root.weatherData.wind_dir ? root.weatherData.wind_dir : "NE"); color: root.primary; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 38
                color: "#ffffff"
                border.width: 1
                border.color: root.itemBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 1
                    Text { text: "󰖖 PRECIPITATION"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: (root.weatherData && root.weatherData.precipitation !== undefined ? root.weatherData.precipitation : 0.0) + " mm/h"; color: root.primary; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 38
                color: "#ffffff"
                border.width: 1
                border.color: root.itemBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 1
                    Text { text: "󰖔 PRESSURE"; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                    Text { text: (root.weatherData && root.weatherData.pressure !== undefined ? root.weatherData.pressure : 1012) + " hPa"; color: root.primary; font.family: root.hudFont; font.pixelSize: 9; font.bold: true }
                }
            }
        }

        // ============================================================
        // 5. 5-DAY TACTICAL FORECAST DECK
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

                Text {
                    text: "▶ 5-DAY ATMOSPHERIC FORECAST:"
                    color: root.primary
                    font.family: root.hudFont
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3

                    Repeater {
                        model: root.weatherData && root.weatherData.forecast ? root.weatherData.forecast : []

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "#ffffff"
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Text {
                                    text: modelData.day
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    Layout.preferredWidth: 30
                                }

                                Text {
                                    text: modelData.icon || "󰖙"
                                    color: root.primary
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 20
                                }

                                Text {
                                    text: (modelData.desc || "").toUpperCase()
                                    color: root.fg
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.max + "° / " + modelData.min + "°"
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
