import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "dashboard"

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color highlight: "#ff2222"

    anchors.fill: parent

    // ============================================================
    // 1. CLOCK & TIMEZONE BACKEND
    // ============================================================
    property var currentTime: new Date()
    property bool colonBlink: true

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.currentTime = new Date();
            root.colonBlink = !root.colonBlink;
        }
    }

    function pad2(n) { return (n < 10 ? "0" : "") + n; }

    readonly property var dayNames: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    readonly property string localHours: pad2(currentTime.getHours())
    readonly property string localMinutes: pad2(currentTime.getMinutes())
    readonly property string localSeconds: pad2(currentTime.getSeconds())

    readonly property string dateBanner: dayNames[currentTime.getDay()] + " // " + currentTime.getDate() + " "
                                         + monthNames[currentTime.getMonth()] + " " + currentTime.getFullYear()

    function zoneTime(offsetHours) {
        var utcMs = currentTime.getTime() + currentTime.getTimezoneOffset() * 60000;
        var d = new Date(utcMs + offsetHours * 3600000);
        return pad2(d.getHours()) + ":" + pad2(d.getMinutes());
    }
    readonly property string tokyoTime: zoneTime(9)
    readonly property string utcTime: zoneTime(0)

    function dayOfYearFor(d) {
        var start = new Date(d.getFullYear(), 0, 1);
        var a = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate());
        var b = Date.UTC(start.getFullYear(), 0, 1);
        return Math.floor((a - b) / 86400000) + 1;
    }
    function daysInYearFor(y) { return ((y % 4 === 0 && y % 100 !== 0) || y % 400 === 0) ? 366 : 365; }
    function isoWeekFor(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        var dayNum = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dayNum);
        var yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    readonly property int dayOfYear: dayOfYearFor(currentTime)
    readonly property int daysInYear: daysInYearFor(currentTime.getFullYear())

    // ============================================================
    // 2. CALENDAR ENGINE (full date selection, not just day number)
    // ============================================================
    property int viewYear: currentTime.getFullYear()
    property int viewMonth: currentTime.getMonth()
    property var selectedDate: new Date()

    function shiftMonth(delta) {
        var m = root.viewMonth + delta;
        root.viewYear += Math.floor(m / 12);
        root.viewMonth = ((m % 12) + 12) % 12;
    }

    function resetToToday() {
        var now = new Date();
        root.viewYear = now.getFullYear();
        root.viewMonth = now.getMonth();
        root.selectedDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    }

    function selectDate(y, m, d) {
        root.selectedDate = new Date(y, m, d);
        if (y !== root.viewYear || m !== root.viewMonth) {
            root.viewYear = y;
            root.viewMonth = m;
        }
    }

    function shiftSelection(days) {
        var s = root.selectedDate;
        var n = new Date(s.getFullYear(), s.getMonth(), s.getDate() + days);
        selectDate(n.getFullYear(), n.getMonth(), n.getDate());
    }

    // Changes once per day; string bindings only notify on actual change
    readonly property string todayStamp: currentTime.toDateString()
    property var todayDate: new Date()
    onTodayStampChanged: todayDate = new Date(currentTime.getFullYear(), currentTime.getMonth(), currentTime.getDate())

    // 42 cells (6 rows x 7 cols, Monday-first)
    readonly property var calendarGridDays: {
        var y = root.viewYear;
        var m = root.viewMonth;
        var first = new Date(y, m, 1);
        var startOffset = (first.getDay() + 6) % 7;
        var today = root.todayDate;
        var list = [];
        for (var i = 0; i < 42; i++) {
            var d = new Date(y, m, 1 - startOffset + i);
            list.push({
                year: d.getFullYear(),
                month: d.getMonth(),
                day: d.getDate(),
                weekday: (d.getDay() + 6) % 7, // 0 = Mon
                isCurrentMonth: d.getMonth() === m,
                isToday: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate(),
                week: (i % 7 === 0) ? root.isoWeekFor(d) : 0
            });
        }
        return list;
    }

    // ============================================================
    // 3. WEATHER BACKEND
    // ============================================================
    property var weatherData: ({})
    property bool weatherLoading: false

    Process {
        id: weatherProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherLoading = false;
                try {
                    var data = JSON.parse(text.trim());
                    if (data) root.weatherData = data;
                } catch (e) {}
            }
        }
    }

    function refreshWeather(force) {
        if (weatherProcess.running) return;
        root.weatherLoading = true;
        weatherProcess.command = force ? [Quickshell.shellPath("scripts/weather_fetch.py"), "--force"]
                                       : [Quickshell.shellPath("scripts/weather_fetch.py")];
        weatherProcess.running = true;
    }

    // Script caches for 15 min, so cheap re-reads keep the panel fresh while open
    Timer {
        interval: 300000
        running: root.visible
        repeat: true
        onTriggered: root.refreshWeather(false)
    }

    // ============================================================
    // 4. NOTIFICATION STORE
    // ============================================================
    property var storedNotifications: []
    property bool notificationsLoading: false
    property string notifSignature: ""

    function signatureOf(list) {
        return list.map(function(n) { return n.id; }).join(",");
    }

    function setNotifications(list) {
        root.notifSignature = signatureOf(list);
        root.storedNotifications = list;
    }

    Process {
        id: notifStoreProcess
        command: [Quickshell.shellPath("scripts/notification_store.py"), "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.notificationsLoading = false;
                try {
                    var data = JSON.parse(text.trim());
                    if (data && Array.isArray(data) && root.signatureOf(data) !== root.notifSignature)
                        root.setNotifications(data);
                } catch (e) {}
            }
        }
    }

    function refreshNotifications() {
        if (notifStoreProcess.running) return;
        root.notificationsLoading = true;
        notifStoreProcess.running = true;
    }

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        onTriggered: root.refreshNotifications()
    }

    function clearAllNotifications() {
        root.setNotifications([]);
        Quickshell.execDetached([Quickshell.shellPath("scripts/notification_store.py"), "clear"]);
    }

    function removeNotification(id) {
        root.setNotifications(root.storedNotifications.filter(function(n) { return n.id !== id; }));
        Quickshell.execDetached([Quickshell.shellPath("scripts/notification_store.py"), "remove", String(id)]);
    }

    readonly property int criticalCount: {
        var c = 0;
        for (var i = 0; i < storedNotifications.length; i++)
            if (storedNotifications[i].urgency === "critical") c++;
        return c;
    }

    Component.onCompleted: {
        root.refreshWeather(false);
        root.refreshNotifications();
    }

    onVisibleChanged: {
        if (root.visible) {
            root.refreshNotifications();
            root.refreshWeather(false);
        }
    }

    // ============================================================
    // 5. FOCUS ROUTING (hex sector <-> wings)
    // 0: Chrono/Calendar, 1: Weather, 2: Alerts
    // ============================================================
    property int focusSector: 0

    function focusTo(sector) {
        if (sector === 0) {
            opsWing.currentView = 0;
            root.focusSector = 0;
        } else if (sector === 2) {
            opsWing.currentView = 1;
            root.focusSector = 2;
        } else {
            root.focusSector = 1;
            weatherWing.pulse();
        }
    }

    // Keyboard shortcuts, forwarded from ControlCenterOverlay while this tab is active
    function handleKey(event) {
        var calendarActive = opsWing.currentView === 0;
        switch (event.key) {
        case Qt.Key_Left:
            if (event.modifiers & Qt.ShiftModifier) root.shiftMonth(-1);
            else root.shiftSelection(-1);
            return true;
        case Qt.Key_Right:
            if (event.modifiers & Qt.ShiftModifier) root.shiftMonth(1);
            else root.shiftSelection(1);
            return true;
        case Qt.Key_PageUp:
            root.shiftMonth(-1);
            return true;
        case Qt.Key_PageDown:
            root.shiftMonth(1);
            return true;
        case Qt.Key_T:
            root.resetToToday();
            root.focusTo(0);
            return true;
        case Qt.Key_R:
            root.refreshWeather(true);
            root.focusTo(1);
            return true;
        case Qt.Key_N:
            root.focusTo(calendarActive ? 2 : 0);
            return true;
        }
        return false;
    }

    // ============================================================
    // MAIN 3-WING TACTICAL CONSOLE
    // ============================================================
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            DashboardWeatherWing {
                id: weatherWing
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 380
                Layout.minimumWidth: 330

                focused: root.focusSector === 1
                weatherData: root.weatherData
                weatherLoading: root.weatherLoading
                onRefreshRequested: root.refreshWeather(true)
            }

            DataBus { focused: root.focusSector === 1; leftSide: true }

            DashboardHexNexus {
                id: hexNexus
                Layout.fillHeight: true
                Layout.preferredWidth: 350
                Layout.minimumWidth: 330
                Layout.maximumWidth: 370

                colonBlink: root.colonBlink
                localHours: root.localHours
                localMinutes: root.localMinutes
                localSeconds: root.localSeconds
                dateBanner: root.dateBanner
                tokyoTime: root.tokyoTime
                utcTime: root.utcTime
                dayOfYear: root.dayOfYear
                daysInYear: root.daysInYear
                weatherData: root.weatherData
                alertCount: root.storedNotifications.length
                criticalCount: root.criticalCount
                activeSector: root.focusSector

                onSectorClicked: (sector) => root.focusTo(sector)
            }

            DataBus { focused: root.focusSector !== 1; leftSide: false }

            DashboardOpsWing {
                id: opsWing
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 380
                Layout.minimumWidth: 330

                focused: root.focusSector !== 1
                viewYear: root.viewYear
                viewMonth: root.viewMonth
                selectedDate: root.selectedDate
                today: root.currentTime
                calendarGridDays: root.calendarGridDays
                monthNames: root.monthNames
                dayNames: root.dayNames
                selectedDayOfYear: root.dayOfYearFor(root.selectedDate)
                selectedDaysInYear: root.daysInYearFor(root.selectedDate.getFullYear())
                selectedWeek: root.isoWeekFor(root.selectedDate)

                onMonthShiftRequested: (delta) => root.shiftMonth(delta)
                onTodayRequested: root.resetToToday()
                onDateSelected: (y, m, d) => { root.selectDate(y, m, d); root.focusSector = 0; }

                storedNotifications: root.storedNotifications
                onClearAllNotificationsRequested: root.clearAllNotifications()
                onRemoveNotificationRequested: (id) => root.removeNotification(id)
                onCurrentViewChanged: root.focusSector = (currentView === 1 ? 2 : 0)
            }
        }

        // Shortcut hint strip
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "◀ ▶ DAY   ⇧◀ ▶ / PGUP PGDN MONTH   T TODAY   N CALENDAR/ALERTS   R RESCAN WEATHER"
            color: Qt.rgba(0.1, 0.0, 0.0, 0.45)
            font.family: "Liberation Sans, JetBrainsMono Nerd Font"
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1.0
        }
    }

    // Laser data bus between wings; brightens toward the focused wing
    component DataBus: Item {
        property bool focused: false
        property bool leftSide: true
        Layout.fillHeight: true
        Layout.preferredWidth: 14
        Layout.minimumWidth: 14

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 2
            color: root.highlight
            opacity: parent.focused ? 1.0 : 0.35
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.leftSide ? parent.width - width : 0
            width: 4; height: 4; radius: 2
            color: root.highlight
            opacity: parent.focused ? 1.0 : 0.35
        }
    }
}
