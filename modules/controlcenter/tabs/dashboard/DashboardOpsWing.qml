import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../../components"

Rectangle {
    id: root

    property int currentView: 0 // 0: Calendar, 1: Alerts
    property bool focused: false

    // Calendar
    property int viewYear: 2026
    property int viewMonth: 0
    property var selectedDate: new Date()
    property var today: new Date()
    property var calendarGridDays: []
    property var monthNames: []
    property var dayNames: []
    property int selectedDayOfYear: 1
    property int selectedDaysInYear: 365
    property int selectedWeek: 1

    signal monthShiftRequested(int delta)
    signal todayRequested()
    signal dateSelected(int year, int month, int day)

    // Alerts
    property var storedNotifications: []
    signal clearAllNotificationsRequested()
    signal removeNotificationRequested(var id)

    readonly property color primary: "#cc0000"
    readonly property color highlight: "#ff2222"
    readonly property color critical: "#ff1a10"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.94)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.85)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.30)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    readonly property int alertCount: storedNotifications ? storedNotifications.length : 0
    readonly property bool hasCritical: {
        for (var i = 0; i < alertCount; i++)
            if (storedNotifications[i].urgency === "critical") return true;
        return false;
    }

    function resolveIconSource(img, icon, app) {
        // image://qsimage/* handles are only valid in the session that created them
        if (img && img.length > 0 && !img.startsWith("image://qsimage"))
            return img.startsWith("/") ? ("file://" + img) : img;
        if (icon && icon.length > 0 && !icon.startsWith("image://qsimage")) {
            if (icon.startsWith("/")) return "file://" + icon;
            if (icon.startsWith("file://") || icon.startsWith("image://")) return icon;
            return Quickshell.iconPath(icon, true);
        }
        if (app && app.length > 0)
            return Quickshell.iconPath(app.toLowerCase().replace(/ /g, "-"), true);
        return "";
    }

    function relativeAge(ts) {
        var diff = Math.max(0, Math.floor(root.today.getTime() / 1000 - ts));
        if (diff < 60) return "JUST NOW";
        if (diff < 3600) return Math.floor(diff / 60) + "m AGO";
        if (diff < 86400) return Math.floor(diff / 3600) + "h AGO";
        return Math.floor(diff / 86400) + "d AGO";
    }

    function isSameDay(a, y, m, d) {
        return a && a.getFullYear() === y && a.getMonth() === m && a.getDate() === d;
    }

    readonly property int selectedOffset: {
        var s = root.selectedDate, t = root.today;
        if (!s || !t) return 0;
        return Math.round((Date.UTC(s.getFullYear(), s.getMonth(), s.getDate())
                         - Date.UTC(t.getFullYear(), t.getMonth(), t.getDate())) / 86400000);
    }
    readonly property string relativeLabel: selectedOffset === 0 ? "TODAY"
                                          : selectedOffset === 1 ? "TOMORROW"
                                          : selectedOffset === -1 ? "YESTERDAY"
                                          : selectedOffset > 0 ? ("IN " + selectedOffset + " DAYS")
                                          : (-selectedOffset + " DAYS AGO")

    readonly property real dayProgressRatio: {
        var t = root.today;
        if (!t) return 0;
        var s = t.getHours() * 3600 + t.getMinutes() * 60 + t.getSeconds();
        return Math.max(0, Math.min(1, s / 86400));
    }
    readonly property int dayProgressPercent: Math.round(dayProgressRatio * 100)

    readonly property real yearProgressRatio: {
        if (!root.selectedDaysInYear || root.selectedDaysInYear <= 0) return 0;
        return Math.max(0, Math.min(1, root.selectedDayOfYear / root.selectedDaysInYear));
    }
    readonly property string yearProgressPercent: (yearProgressRatio * 100).toFixed(1)

    property var completedOps: ({})
    function toggleOp(key) {
        var copy = Object.assign({}, completedOps);
        copy[key] = !copy[key];
        completedOps = copy;
    }

    readonly property var currentDayOps: {
        var d = root.selectedDate || root.today || new Date();
        var y = d.getFullYear();
        var m = d.getMonth();
        var day = d.getDate();
        var seed = (y * 372 + m * 31 + day) % 1000;
        var templates = [
            { time: "08:30", code: "SYNC-02", title: "UNIT-02 HARMONIC SYNC TEST", loc: "CAGE 07 // U-02", urgency: "nominal", defStatus: "COMPLETED" },
            { time: "10:15", code: "LCL-PUR", title: "LCL PURIFICATION & OXYGENATION", loc: "TERMINAL DOGMA", urgency: "nominal", defStatus: "COMPLETED" },
            { time: "12:00", code: "MAGI-SYNC", title: "MAGI TRI-CONSENSUS RECALIBRATION", loc: "CENTRAL DOGMA", urgency: "active", defStatus: "IN PROGRESS" },
            { time: "14:45", code: "GEO-SURV", title: "GEOFRONT PERIMETER SCAN // SECTOR 3", loc: "SECTOR 03-EAST", urgency: "nominal", defStatus: "SCHEDULED" },
            { time: "17:30", code: "RAD-SWP", title: "TOKYO-3 AIRSPACE RADAR SWEEP", loc: "RADAR ARRAY 4", urgency: "standby", defStatus: "SCHEDULED" },
            { time: "20:00", code: "COR-COOL", title: "SUB-SURFACE REACTOR COOLING AUDIT", loc: "POWER BLOCK B", urgency: "nominal", defStatus: "SCHEDULED" },
            { time: "22:15", code: "ORB-LOR", title: "SUB-ORBITAL SURVEILLANCE PASS", loc: "RELAY SAT-04", urgency: "standby", defStatus: "STANDBY" }
        ];
        var count = 3 + (seed % 2);
        var list = [];
        var startIdx = seed % templates.length;
        for (var i = 0; i < count; i++) {
            var item = templates[(startIdx + i * 2) % templates.length];
            var itemKey = y + "-" + m + "-" + day + "-" + item.code;
            var isToggled = completedOps[itemKey] !== undefined ? completedOps[itemKey] : (item.defStatus === "COMPLETED");
            list.push({
                key: itemKey,
                time: item.time,
                code: item.code,
                title: item.title,
                loc: item.loc,
                urgency: item.urgency,
                status: isToggled ? "COMPLETED" : "PENDING",
                completed: isToggled
            });
        }
        return list;
    }

    color: root.panelBg
    border.width: root.focused ? 1.5 : 1
    border.color: root.focused ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.40)
    Behavior on border.color { ColorAnimation { duration: 180 } }

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
        // 1. SEGMENTED SWITCH
        // ============================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            color: "#ffffff"
            border.width: 1
            border.color: root.primary

            RowLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                SegmentButton {
                    viewIndex: 0
                    icon: "󰃭"
                    label: "CALENDAR"
                }
                Rectangle { implicitWidth: 1; Layout.fillHeight: true; color: root.primary }
                SegmentButton {
                    viewIndex: 1
                    icon: root.alertCount > 0 ? "󰂚" : "󰂜"
                    label: "ALERTS"
                    badge: root.alertCount
                }
            }
        }

        // ============================================================
        // 2. VIEW DECK
        // ============================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ========================================================
            // VIEW 0: CALENDAR
            // ========================================================
            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: opacity > 0.01
                opacity: root.currentView === 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                // 1. Navigation
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    HudButton {
                        text: "◀"
                        implicitWidth: 26
                        implicitHeight: 24
                        onClicked: root.monthShiftRequested(-1)
                        tip: "Previous month (PgUp)"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 24
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.itemBorder

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: (root.monthNames[root.viewMonth] || "").toUpperCase() + " " + root.viewYear
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1.5
                            }
                            Text {
                                text: "// M-" + (root.viewMonth < 9 ? ("0" + (root.viewMonth + 1)) : (root.viewMonth + 1))
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }
                    }

                    HudButton {
                        text: "▶"
                        implicitWidth: 26
                        implicitHeight: 24
                        onClicked: root.monthShiftRequested(1)
                        tip: "Next month (PgDn)"
                    }

                    HudButton {
                        text: "TODAY"
                        implicitWidth: 52
                        implicitHeight: 24
                        active: root.selectedOffset === 0 && root.viewYear === root.today.getFullYear() && root.viewMonth === root.today.getMonth()
                        onClicked: root.todayRequested()
                        tip: "Jump to today (T)"
                    }
                }

                // 2. Substantial Calendar Grid Card (expands to fill vertical space)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 290
                    Layout.preferredHeight: 330
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        property real acc: 0
                        onWheel: (event) => {
                            acc += event.angleDelta.y;
                            if (acc >= 120) { root.monthShiftRequested(-1); acc = 0; }
                            else if (acc <= -120) { root.monthShiftRequested(1); acc = 0; }
                        }
                    }

                    ColumnLayout {
                        id: calCol
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2

                        // Weekday header
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.14)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 2
                                anchors.rightMargin: 2
                                spacing: 2

                                Text {
                                    Layout.preferredWidth: 22
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "WK"
                                    color: root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                }

                                Repeater {
                                    model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                                    Text {
                                        required property string modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: modelData
                                        color: index >= 5 ? root.highlight : root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.letterSpacing: 0.5
                                    }
                                }
                            }
                        }

                        // 6 Week rows (expand evenly to give substantial box height)
                        Repeater {
                            model: 6

                            RowLayout {
                                id: weekRow
                                required property int index
                                readonly property int rowIndex: index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: 48
                                Layout.minimumHeight: 40
                                spacing: 2

                                Text {
                                    Layout.preferredWidth: 22
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: root.calendarGridDays.length === 42 ? root.calendarGridDays[weekRow.rowIndex * 7].week : ""
                                    color: root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                }

                                Repeater {
                                    model: 7

                                    Rectangle {
                                        id: cell
                                        required property int index
                                        readonly property var info: root.calendarGridDays.length === 42
                                                                    ? root.calendarGridDays[weekRow.rowIndex * 7 + index] : null
                                        readonly property bool isSelected: info !== null && root.isSelectedDay(info)
                                        readonly property bool isToday: info !== null && info.isToday
                                        readonly property bool inMonth: info !== null && info.isCurrentMonth
                                        readonly property bool weekend: index >= 5

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 1

                                        color: isToday ? root.primary
                                             : isSelected ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.14)
                                             : dayMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                             : weekend && inMonth ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.03)
                                             : "#ffffff"
                                        border.width: isSelected ? 2 : 1
                                        border.color: isSelected ? root.highlight
                                                    : isToday ? root.highlight
                                                    : dayMouse.containsMouse ? root.primary
                                                    : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, inMonth ? 0.18 : 0.08)
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        // Subtle top highlight pip on today
                                        Rectangle {
                                            visible: cell.isToday
                                            anchors.top: parent.top
                                            anchors.topMargin: 2
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 14
                                            height: 2
                                            color: "#ffffff"
                                        }

                                        // Day number (crisp 13px bold, cleanly placed in upper half)
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.top
                                            anchors.topMargin: cell.isToday ? 6 : Math.max(6, Math.round((parent.height - 16) / 2))
                                            text: cell.info ? cell.info.day : ""
                                            color: cell.isToday ? "#ffffff"
                                                 : !cell.inMonth ? Qt.rgba(0.1, 0.0, 0.0, 0.28)
                                                 : cell.weekend ? root.highlight
                                                 : root.fg
                                            font.family: root.hudFont
                                            font.pixelSize: 13
                                            font.bold: cell.inMonth
                                        }

                                        // "TODAY" micro-chip (white pill badge at bottom of cell, zero overlap)
                                        Rectangle {
                                            visible: cell.isToday
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 4
                                            implicitWidth: 32
                                            implicitHeight: 12
                                            radius: 2
                                            color: "#ffffff"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "TODAY"
                                                color: root.primary
                                                font.family: root.hudFont
                                                font.pixelSize: 7
                                                font.bold: true
                                                font.letterSpacing: 0.5
                                            }
                                        }

                                        // Selection indicator pip for non-today selected days
                                        Rectangle {
                                            visible: cell.isSelected && !cell.isToday
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 4
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: root.primary
                                        }

                                        MouseArea {
                                            id: dayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (cell.info) root.dateSelected(cell.info.year, cell.info.month, cell.info.day)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Selected date & temporal telemetry readout banner
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder

                    Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 3; color: root.primary }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: root.selectedDate
                                          ? (root.dayNames[root.selectedDate.getDay()] + ", " + root.selectedDate.getDate() + " "
                                             + root.monthNames[root.selectedDate.getMonth()] + " " + root.selectedDate.getFullYear()).toUpperCase()
                                          : ""
                                    color: root.fg
                                    font.family: root.hudFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            RowLayout {
                                spacing: 10
                                Text {
                                    text: "WEEK " + root.selectedWeek + " · DAY " + root.selectedDayOfYear + " / " + root.selectedDaysInYear
                                    color: root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                                Text {
                                    text: "YEAR " + root.yearProgressPercent + "%"
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                                Text {
                                    text: "DAY CYCLE " + root.dayProgressPercent + "%"
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: relText.implicitWidth + 12
                            implicitHeight: 20
                            color: root.selectedOffset === 0 ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                            border.width: 1
                            border.color: root.primary
                            Text {
                                id: relText
                                anchors.centerIn: parent
                                text: root.relativeLabel
                                color: root.selectedOffset === 0 ? "#ffffff" : root.primary
                                font.family: root.hudFont
                                font.pixelSize: 8
                                font.bold: true
                                font.letterSpacing: 0.6
                            }
                        }
                    }
                }

                // 4. Tactical Operations Deck (compact, snugly fitted)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 104
                    Layout.fillHeight: false
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 3

                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "▶ TACTICAL OPERATIONS"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1.0
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                implicitWidth: opBadgeText.implicitWidth + 8
                                implicitHeight: 15
                                color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                border.width: 1
                                border.color: root.primary
                                Text {
                                    id: opBadgeText
                                    anchors.centerIn: parent
                                    text: root.currentDayOps.length + " MISSIONS"
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }
                        }

                        // Agenda list (3 missions at 22px each = 66px, plus 2*2 spacing = 70px)
                        ListView {
                            id: opListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            model: root.currentDayOps
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                id: opItem
                                required property var modelData
                                required property int index

                                width: opListView.width
                                implicitHeight: 22
                                color: opMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06) : "#ffffff"
                                border.width: 1
                                border.color: modelData.completed ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)
                                                                  : (modelData.urgency === "active" ? root.highlight
                                                                                                    : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35))
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 3
                                    color: modelData.completed ? "#888888"
                                         : modelData.urgency === "active" ? root.highlight
                                         : modelData.urgency === "critical" ? root.critical
                                         : root.primary
                                }

                                MouseArea {
                                    id: opMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleOp(modelData.key)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 5

                                    Rectangle {
                                        implicitWidth: 32
                                        implicitHeight: 15
                                        color: modelData.completed ? Qt.rgba(0.2, 0.2, 0.2, 0.08) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
                                        border.width: 1
                                        border.color: modelData.completed ? Qt.rgba(0.2, 0.2, 0.2, 0.25) : root.primary

                                        Text {
                                            anchors.centerIn: parent
                                            text: opItem.modelData.time
                                            color: opItem.modelData.completed ? root.fgDim : root.primary
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            text: opItem.modelData.title
                                            color: opItem.modelData.completed ? root.fgDim : root.fg
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: opItem.modelData.loc + " // " + opItem.modelData.code
                                            color: opItem.modelData.completed ? Qt.rgba(0.1, 0.0, 0.35) : root.fgDim
                                            font.family: root.hudFont
                                            font.pixelSize: 7
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: 15
                                        implicitHeight: 15
                                        color: opItem.modelData.completed ? root.primary : "transparent"
                                        border.width: 1
                                        border.color: opItem.modelData.completed ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.40)

                                        Text {
                                            anchors.centerIn: parent
                                            text: opItem.modelData.completed ? "✓" : "○"
                                            color: opItem.modelData.completed ? "#ffffff" : root.fgDim
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

            // ========================================================
            // VIEW 1: ALERTS
            // ========================================================
            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                visible: opacity > 0.01
                opacity: root.currentView === 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: root.alertCount > 0 ? ("▶ " + root.alertCount + (root.alertCount === 1 ? " ALERT" : " ALERTS")) : "▶ ALERTS ARCHIVE"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.0
                        Layout.fillWidth: true
                    }

                    // Two-step clear: first click arms, second click confirms
                    HudButton {
                        id: clearBtn
                        property bool armed: false
                        visible: root.alertCount > 0
                        implicitWidth: armed ? 92 : 64
                        text: armed ? "CONFIRM CLEAR" : "CLEAR ALL"
                        active: armed
                        tip: armed ? "Click again to delete all alerts" : "Delete all stored alerts"
                        onClicked: {
                            if (armed) {
                                armed = false;
                                root.clearAllNotificationsRequested();
                            } else {
                                armed = true;
                                disarmTimer.restart();
                            }
                        }
                        Timer { id: disarmTimer; interval: 3000; onTriggered: clearBtn.armed = false }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder
                    clip: true

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: root.alertCount === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰂜"
                            color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)
                            font.family: root.hudFont
                            font.pixelSize: 40
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "ALL CLEAR"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 12
                            font.bold: true
                            font.letterSpacing: 1.5
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "NO ALERTS IN THE ARCHIVE"
                            color: root.fgDim
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    ListView {
                        id: notifList
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.rightMargin: 10
                        spacing: 6
                        clip: true
                        model: root.storedNotifications
                        boundsBehavior: Flickable.StopAtBounds
                        visible: root.alertCount > 0

                        ScrollBar.vertical: ScrollBar {
                            parent: notifList.parent
                            anchors.top: notifList.top
                            anchors.bottom: notifList.bottom
                            anchors.left: notifList.right
                            anchors.leftMargin: 1
                            policy: notifList.contentHeight > notifList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                            contentItem: Rectangle { implicitWidth: 3; color: root.primary; opacity: 0.6 }
                            background: Rectangle { implicitWidth: 3; color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) }
                        }

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property bool isCritical: modelData.urgency === "critical"
                            readonly property string iconSrc: root.resolveIconSource(modelData.image, modelData.appIcon || modelData.icon, modelData.app)
                            property bool expanded: false

                            width: notifList.width
                            height: cardCol.implicitHeight + 14
                            color: cardMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.04) : "#ffffff"
                            border.width: 1
                            border.color: isCritical ? root.critical : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, cardMouse.containsMouse ? 0.55 : 0.28)
                            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 3
                                color: card.isCritical ? root.critical : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.5)
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: bodyText.truncated || card.expanded ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (bodyText.truncated || card.expanded) card.expanded = !card.expanded
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 7
                                anchors.topMargin: 7
                                anchors.bottomMargin: 7
                                spacing: 8

                                // App icon (falls back to glyph)
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        source: card.iconSrc
                                        sourceSize.width: 44
                                        sourceSize.height: 44
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: appIcon.status !== Image.Ready
                                        text: card.isCritical ? "󰀦" : "󰂚"
                                        color: card.isCritical ? root.critical : root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 14
                                    }
                                }

                                ColumnLayout {
                                    id: cardCol
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text {
                                            text: (card.modelData.app || "SYSTEM").toUpperCase()
                                            color: card.isCritical ? root.critical : root.primary
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.letterSpacing: 0.6
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: card.modelData.timestamp ? root.relativeAge(card.modelData.timestamp) : (card.modelData.time || "")
                                            color: root.fgDim
                                            font.family: root.hudFont
                                            font.pixelSize: 8
                                            font.bold: true
                                        }
                                        // Dismiss
                                        Rectangle {
                                            implicitWidth: 18
                                            implicitHeight: 18
                                            color: dismissMouse.containsMouse ? root.primary : "transparent"
                                            border.width: 1
                                            border.color: dismissMouse.containsMouse || cardMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: dismissMouse.containsMouse ? "#ffffff" : root.primary
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: dismissMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.removeNotificationRequested(card.modelData.id)
                                            }
                                            ToolTip.visible: dismissMouse.containsMouse
                                            ToolTip.delay: 600
                                            ToolTip.text: "Dismiss"
                                        }
                                    }

                                    Text {
                                        text: card.modelData.summary || card.modelData.title || "Notification"
                                        color: root.fg
                                        font.family: root.hudFont
                                        font.pixelSize: 10
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        id: bodyText
                                        visible: text.length > 0
                                        text: card.modelData.body || ""
                                        textFormat: Text.PlainText
                                        color: root.fgMuted
                                        font.family: root.hudFont
                                        font.pixelSize: 9
                                        wrapMode: Text.Wrap
                                        maximumLineCount: card.expanded ? 50 : 2
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: bodyText.truncated || card.expanded
                                        text: card.expanded ? "▲ LESS" : "▼ MORE"
                                        color: root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 8
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

    function isSelectedDay(info) {
        return isSameDay(root.selectedDate, info.year, info.month, info.day);
    }

    // ---------- reusable controls ----------
    component HudButton: Rectangle {
        id: btn
        property string text: ""
        property string tip: ""
        property bool active: false
        signal clicked()

        implicitWidth: 40
        implicitHeight: 22
        color: (btnMouse.containsMouse || active) ? root.primary : "#ffffff"
        border.width: 1
        border.color: root.primary
        scale: btnMouse.pressed ? 0.95 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on implicitWidth { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: btn.text
            color: (btnMouse.containsMouse || btn.active) ? "#ffffff" : root.primary
            font.family: root.hudFont
            font.pixelSize: 9
            font.bold: true
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
        ToolTip.visible: btnMouse.containsMouse && btn.tip.length > 0
        ToolTip.delay: 600
        ToolTip.text: btn.tip
    }

    component SegmentButton: Rectangle {
        id: seg
        property int viewIndex: 0
        property string icon: ""
        property string label: ""
        property int badge: 0
        readonly property bool selected: root.currentView === viewIndex

        Layout.fillWidth: true
        Layout.fillHeight: true
        color: selected ? root.primary : (segMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: seg.icon
                color: seg.selected ? "#ffffff" : root.primary
                font.family: root.hudFont
                font.pixelSize: 12
            }
            Text {
                text: seg.label
                color: seg.selected ? "#ffffff" : root.primary
                font.family: root.hudFont
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.0
            }
            Rectangle {
                visible: seg.badge > 0
                implicitWidth: Math.max(16, badgeText.implicitWidth + 8)
                implicitHeight: 16
                radius: 8
                color: seg.selected ? "#ffffff" : (root.hasCritical ? root.critical : root.primary)
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: seg.badge > 99 ? "99+" : seg.badge
                    color: seg.selected ? root.primary : "#ffffff"
                    font.family: root.hudFont
                    font.pixelSize: 8
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: segMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentView = seg.viewIndex
        }
    }
}
