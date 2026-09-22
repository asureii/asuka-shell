import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../../components"

Rectangle {
    id: root

    property int currentView: 0 // 0: Operations Calendar, 1: System Alerts

    // Calendar Properties
    property int viewYear: 2026
    property int viewMonth: 8
    property int selectedDay: 19
    property var calendarGridDays: []
    property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    property int dayOfYear: 262

    signal nextMonthRequested()
    signal prevMonthRequested()
    signal todayRequested()
    signal daySelected(int day)

    // Notifications Properties
    property var storedNotifications: []
    property bool notificationsLoading: false
    signal clearAllNotificationsRequested()
    signal removeNotificationRequested(var id)

    function resolveIconSource(img, icon) {
        if (img && img.length > 0) {
            return (img.startsWith("/") ? ("file://" + img) : img);
        }
        if (icon && icon.length > 0) {
            if (icon.startsWith("/") || icon.startsWith("file://") || icon.startsWith("image://")) return icon;
            return Quickshell.iconPath(icon);
        }
        return "";
    }

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
        // 1. TOP SEGMENTED TOGGLE SWITCH (CALENDAR vs NOTIFICATIONS)
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: "#ffffff"
            border.width: 1
            border.color: root.primary

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Option 0: Operations Calendar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.currentView === 0 ? root.primary : (calBtnMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "transparent")

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "📅"
                            font.pixelSize: 9
                        }
                        Text {
                            text: "OPERATIONS CALENDAR"
                            color: root.currentView === 0 ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: calBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentView = 0
                    }
                }

                // Divider line
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: root.primary
                }

                // Option 1: System Alerts
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.currentView === 1 ? root.primary : (notifBtnMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "transparent")

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "🔔"
                            font.pixelSize: 9
                        }
                        Text {
                            text: "SYSTEM ALERTS (" + (root.storedNotifications ? root.storedNotifications.length : 0) + ")"
                            color: root.currentView === 1 ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 0.8
                        }
                    }

                    MouseArea {
                        id: notifBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentView = 1
                    }
                }
            }
        }

        // ============================================================
        // 2. MAIN VIEW AREA (DECK CONTAINER)
        // ============================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ========================================================
            // VIEW 0: TACTICAL OPERATIONS CALENDAR
            // ========================================================
            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: root.currentView === 0

                // Calendar Navigation Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "▶ TACTICAL TIMELINE"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.0
                        Layout.fillWidth: true
                    }

                    // Prev Month
                    Rectangle {
                        width: 22
                        height: 18
                        color: prevMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.primary
                        Text {
                            anchors.centerIn: parent
                            text: "◀"
                            color: prevMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 8
                            font.bold: true
                        }
                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevMonthRequested()
                        }
                    }

                    // Month & Year Badge
                    Rectangle {
                        width: 120
                        height: 18
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.itemBorder

                        Text {
                            anchors.centerIn: parent
                            text: (root.monthNames && root.monthNames[root.viewMonth] ? root.monthNames[root.viewMonth] : "MONTH") + " " + root.viewYear
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                            font.letterSpacing: 1.0
                        }
                    }

                    // Next Month
                    Rectangle {
                        width: 22
                        height: 18
                        color: nextMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.primary
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: nextMouse.containsMouse ? "#ffffff" : root.primary
                            font.pixelSize: 8
                            font.bold: true
                        }
                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextMonthRequested()
                        }
                    }

                    // Today Button
                    Rectangle {
                        width: 44
                        height: 18
                        color: todayMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.primary
                        Text {
                            anchors.centerIn: parent
                            text: "TODAY"
                            color: todayMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                        MouseArea {
                            id: todayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.todayRequested()
                        }
                    }
                }

                // Day of week column headers
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                        Rectangle {
                            Layout.fillWidth: true
                            height: 16
                            color: "#ffffff"
                            border.width: 1
                            border.color: root.itemBorder

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }

                // 42-cell Calendar Grid
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        columns: 7
                        columnSpacing: 2
                        rowSpacing: 2

                        Repeater {
                            model: root.calendarGridDays

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: modelData.isToday
                                    ? root.primary
                                    : (dayMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12) : "#ffffff")
                                border.width: 1
                                border.color: modelData.isToday
                                    ? "#ff2222"
                                    : (dayMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20))

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Text {
                                        Layout.alignment: Qt.AlignCenter
                                        text: modelData.day
                                        color: modelData.isToday
                                            ? "#ffffff"
                                            : (modelData.isCurrentMonth ? root.fg : root.fgDim)
                                        font.family: root.hudFont
                                        font.pixelSize: 9
                                        font.bold: modelData.isCurrentMonth || modelData.isToday
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "TODAY"
                                        color: "#ffffff"
                                        font.family: root.hudFont
                                        font.pixelSize: 5
                                        font.bold: true
                                        visible: modelData.isToday
                                    }
                                }

                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.isCurrentMonth) {
                                            root.daySelected(modelData.day);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Calendar Bottom Status Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "OPERATION DAY: " + root.dayOfYear + " OF 365 // ACTIVE DEFENSE"
                        color: root.fgDim
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "SCHEDULE: STANDBY"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 7
                        font.bold: true
                    }
                }
            }

            // ========================================================
            // VIEW 1: STORED SYSTEM ALERTS ARCHIVE
            // ========================================================
            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: root.currentView === 1

                // Alerts Header & Clear Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "▶ SYSTEM ALERTS ARCHIVE"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.0
                        Layout.fillWidth: true
                    }

                    // Count Tag
                    Rectangle {
                        width: 60
                        height: 18
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.itemBorder

                        Text {
                            anchors.centerIn: parent
                            text: (root.storedNotifications && root.storedNotifications.length > 0 ? (root.storedNotifications.length + " RECS") : "EMPTY")
                            color: root.storedNotifications && root.storedNotifications.length > 0 ? root.primary : root.fgDim
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }
                    }

                    // Clear All Button
                    Rectangle {
                        width: 50
                        height: 18
                        color: clearNotifMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.primary

                        Text {
                            anchors.centerIn: parent
                            text: "CLEAR"
                            color: clearNotifMouse.containsMouse ? "#ffffff" : root.primary
                            font.family: root.hudFont
                            font.pixelSize: 7
                            font.bold: true
                        }

                        MouseArea {
                            id: clearNotifMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAllNotificationsRequested()
                        }
                    }
                }

                // Scrollable Alerts List
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 6
                        contentWidth: width
                        contentHeight: notifCol.implicitHeight
                        clip: true

                        ColumnLayout {
                            id: notifCol
                            width: parent.width
                            spacing: 6

                            // Empty Placeholder
                            Item {
                                Layout.fillWidth: true
                                height: 160
                                visible: !root.storedNotifications || root.storedNotifications.length === 0

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "󰂜"
                                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.40)
                                        font.pixelSize: 36
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "ALL ALERTS PROCESSED // STANDBY"
                                        color: root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 9
                                        font.bold: true
                                        font.letterSpacing: 1.0
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "NO DIRECT INTERCEPT ACTIONS REQUIRED"
                                        color: root.fgDim
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                    }
                                }
                            }

                            // Active Notifications List
                            Repeater {
                                model: root.storedNotifications

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: notifInnerCol.implicitHeight + 12
                                    color: "#ffffff"
                                    border.width: 1
                                    border.color: modelData.urgency === "critical" ? "#ff1a10" : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)

                                    ColumnLayout {
                                        id: notifInnerCol
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 2

                                        // Top Row: App Name Tag, Time, Dismiss Button
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Rectangle {
                                                width: appTagText.implicitWidth + 8
                                                height: 14
                                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                                border.width: 1
                                                border.color: root.primary

                                                Text {
                                                    id: appTagText
                                                    anchors.centerIn: parent
                                                    text: (modelData.app || "ALERT").toUpperCase()
                                                    color: root.primary
                                                    font.family: root.hudFont
                                                    font.pixelSize: 6
                                                    font.bold: true
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: modelData.time || "JUST NOW"
                                                color: root.fgDim
                                                font.family: root.hudFont
                                                font.pixelSize: 6
                                                font.bold: true
                                            }

                                            // Dismiss button
                                            Rectangle {
                                                width: 16
                                                height: 16
                                                color: dismissMouse.containsMouse ? root.primary : "#ffffff"
                                                border.width: 1
                                                border.color: root.primary

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    color: dismissMouse.containsMouse ? "#ffffff" : root.primary
                                                    font.pixelSize: 7
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: dismissMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.removeNotificationRequested(modelData.id)
                                                }
                                            }
                                        }

                                        // Title
                                        Text {
                                            text: modelData.title || "SYSTEM ALERT"
                                            color: root.primary
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        // Body
                                        Text {
                                            text: modelData.body || ""
                                            color: root.fg
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
