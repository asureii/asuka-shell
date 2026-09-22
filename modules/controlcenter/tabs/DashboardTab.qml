import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "dashboard"

Item {
    id: root

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

    function formatDigits(n) {
        return (n < 10 ? "0" : "") + n;
    }

    // Time calculations
    readonly property string localHours: formatDigits(currentTime.getHours())
    readonly property string localMinutes: formatDigits(currentTime.getMinutes())
    readonly property string localSeconds: formatDigits(currentTime.getSeconds())

    readonly property string dateBanner: {
        var days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        var months = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"];
        return days[currentTime.getDay()] + " // " + currentTime.getDate() + " " + months[currentTime.getMonth()] + " " + currentTime.getFullYear();
    }

    // Secondary Timezones
    readonly property string tokyoTime: {
        var utcMs = currentTime.getTime() + (currentTime.getTimezoneOffset() * 60000);
        var tokyoDate = new Date(utcMs + (3600000 * 9)); // JST = UTC+9
        return formatDigits(tokyoDate.getHours()) + ":" + formatDigits(tokyoDate.getMinutes()) + ":" + formatDigits(tokyoDate.getSeconds());
    }

    readonly property string utcTime: {
        var utcMs = currentTime.getTime() + (currentTime.getTimezoneOffset() * 60000);
        var utcDate = new Date(utcMs);
        return formatDigits(utcDate.getHours()) + ":" + formatDigits(utcDate.getMinutes()) + ":" + formatDigits(utcDate.getSeconds());
    }

    readonly property int dayOfYear: {
        var start = new Date(currentTime.getFullYear(), 0, 0);
        var diff = currentTime - start;
        var oneDay = 1000 * 60 * 60 * 24;
        return Math.floor(diff / oneDay);
    }

    // ============================================================
    // 2. CALENDAR ENGINE
    // ============================================================
    property int viewYear: currentTime.getFullYear()
    property int viewMonth: currentTime.getMonth() // 0-11
    property int selectedDay: currentTime.getDate()

    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    function nextMonth() {
        if (root.viewMonth === 11) {
            root.viewMonth = 0;
            root.viewYear++;
        } else {
            root.viewMonth++;
        }
    }

    function prevMonth() {
        if (root.viewMonth === 0) {
            root.viewMonth = 11;
            root.viewYear--;
        } else {
            root.viewMonth--;
        }
    }

    function resetToToday() {
        var now = new Date();
        root.viewYear = now.getFullYear();
        root.viewMonth = now.getMonth();
        root.selectedDay = now.getDate();
    }

    // 42 cells (6 rows x 7 cols, starting Monday)
    readonly property var calendarGridDays: {
        var y = root.viewYear;
        var m = root.viewMonth;
        var firstDayOfWeek = new Date(y, m, 1).getDay(); // 0 = Sun
        var startOffset = (firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1); // 0 = Mon
        var totalDaysInMonth = new Date(y, m + 1, 0).getDate();
        var prevMonthDays = new Date(y, m, 0).getDate();

        var today = new Date();
        var isCurrentMonthView = (today.getFullYear() === y && today.getMonth() === m);
        var todayDate = today.getDate();

        var list = [];
        // Previous month days
        for (var p = startOffset - 1; p >= 0; p--) {
            list.push({
                day: prevMonthDays - p,
                isCurrentMonth: false,
                isToday: false,
                fullDate: (m === 0 ? (y - 1) : y) + "-" + (m === 0 ? 12 : m) + "-" + (prevMonthDays - p)
            });
        }
        // Current month days
        for (var c = 1; c <= totalDaysInMonth; c++) {
            list.push({
                day: c,
                isCurrentMonth: true,
                isToday: isCurrentMonthView && (c === todayDate),
                fullDate: y + "-" + (m + 1 < 10 ? "0" : "") + (m + 1) + "-" + (c < 10 ? "0" : "") + c
            });
        }
        // Future month days to fill 42 cells
        var remaining = 42 - list.length;
        for (var f = 1; f <= remaining; f++) {
            list.push({
                day: f,
                isCurrentMonth: false,
                isToday: false,
                fullDate: (m === 11 ? (y + 1) : y) + "-" + (m === 11 ? "01" : (m + 2 < 10 ? "0" : "") + (m + 2)) + "-" + (f < 10 ? "0" : "") + f
            });
        }
        return list;
    }

    // ============================================================
    // 3. WEATHER BACKEND
    // ============================================================
    property var weatherData: ({
        sector: "TOKYO-3 // GEO-FRONT",
        temp: 28,
        feels_like: 31,
        humidity: 65,
        wind_speed: 12,
        wind_dir: "NE",
        precipitation: 0.0,
        pressure: 1012,
        condition: "ATMOSPHERE NOMINAL",
        icon: "󰖙",
        updated: "--:--:--",
        forecast: [
            { day: "FRI", max: 32, min: 25, icon: "󰖕", desc: "PARTLY CLOUDY" },
            { day: "SAT", max: 33, min: 25, icon: "󰖙", desc: "CLEAR SKY" },
            { day: "SUN", max: 31, min: 24, icon: "󰖖", desc: "LIGHT RAIN" },
            { day: "MON", max: 34, min: 26, icon: "󰖙", desc: "CLEAR SKY" },
            { day: "TUE", max: 32, min: 25, icon: "󰖐", desc: "OVERCAST" }
        ]
    })
    property bool weatherLoading: false

    Process {
        id: weatherProcess
        command: [Quickshell.configPath("scripts/weather_fetch.py")]
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
        root.weatherLoading = true;
        weatherProcess.command = force ? [Quickshell.configPath("scripts/weather_fetch.py"), "--force"]
                                       : [Quickshell.configPath("scripts/weather_fetch.py")];
        weatherProcess.running = true;
    }

    Timer {
        interval: 900000 // 15 mins
        running: true
        repeat: true
        onTriggered: root.refreshWeather(false)
    }

    // ============================================================
    // 4. NOTIFICATION FEED ENGINE & PERSISTENT STORE
    // ============================================================
    property var storedNotifications: []
    property bool notificationsLoading: false

    Process {
        id: notifStoreProcess
        command: [Quickshell.configPath("scripts/notification_store.py"), "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.notificationsLoading = false;
                try {
                    var data = JSON.parse(text.trim());
                    if (data && Array.isArray(data)) {
                        root.storedNotifications = data;
                    }
                } catch(e) {}
            }
        }
    }

    function refreshNotifications() {
        root.notificationsLoading = true;
        notifStoreProcess.command = [Quickshell.configPath("scripts/notification_store.py"), "load"];
        notifStoreProcess.running = true;
    }

    Timer {
        interval: 3000
        running: root.visible
        repeat: true
        onTriggered: root.refreshNotifications()
    }

    function clearAllNotifications() {
        root.storedNotifications = [];
        Quickshell.execDetached([Quickshell.configPath("scripts/notification_store.py"), "clear"]);
    }

    function removeNotification(id) {
        root.storedNotifications = root.storedNotifications.filter(function(n) { return n.id !== id; });
        Quickshell.execDetached([Quickshell.configPath("scripts/notification_store.py"), "remove", id.toString()]);
    }

    Component.onCompleted: {
        root.refreshWeather(false);
        root.refreshNotifications();
    }

    onVisibleChanged: {
        if (root.visible) {
            root.refreshNotifications();
        }
    }

    anchors.fill: parent

    // ============================================================
    // MAIN 3-WING TACTICAL CONSOLE
    // ============================================================
    RowLayout {
        anchors.fill: parent
        spacing: 6

        // ============================================================
        // 1. LEFT WING: METEOROLOGICAL RADAR
        // ============================================================
        DashboardWeatherWing {
            id: weatherWing
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 380
            Layout.minimumWidth: 330

            weatherData: root.weatherData
            weatherLoading: root.weatherLoading
            onRefreshRequested: root.refreshWeather(true)
        }

        // ============================================================
        // LEFT DATA BUS CONNECTOR (ACTIVE LASER BUS)
        // ============================================================
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: 14
            Layout.minimumWidth: 14

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                color: root.highlight
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: 4
                height: 4
                radius: 2
                color: root.highlight
            }
        }

        // ============================================================
        // 2. CENTER: THE MAGI TRIAD HEXAGON COMMAND NEXUS
        // ============================================================
        DashboardHexNexus {
            id: hexNexus
            Layout.fillHeight: true
            Layout.preferredWidth: 350
            Layout.minimumWidth: 330
            Layout.maximumWidth: 370

            currentTime: root.currentTime
            colonBlink: root.colonBlink
            localHours: root.localHours
            localMinutes: root.localMinutes
            localSeconds: root.localSeconds
            dateBanner: root.dateBanner
            tokyoTime: root.tokyoTime
            utcTime: root.utcTime
            dayOfYear: root.dayOfYear

            weatherData: root.weatherData
            storedNotifications: root.storedNotifications

            onWeatherFocusRequested: {
                // Focus on Weather
            }
            onOpsFocusRequested: {
                opsWing.currentView = 1;
            }
            onChronoFocusRequested: {
                opsWing.currentView = 0;
            }
        }

        // ============================================================
        // RIGHT DATA BUS CONNECTOR (ACTIVE LASER BUS)
        // ============================================================
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: 14
            Layout.minimumWidth: 14

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: 2
                color: root.highlight
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: 4
                height: 4
                radius: 2
                color: root.highlight
            }
        }

        // ============================================================
        // 3. RIGHT WING: OPERATIONS & COMMS DECK
        // ============================================================
        DashboardOpsWing {
            id: opsWing
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 380
            Layout.minimumWidth: 330

            viewYear: root.viewYear
            viewMonth: root.viewMonth
            selectedDay: root.selectedDay
            calendarGridDays: root.calendarGridDays
            monthNames: root.monthNames
            dayOfYear: root.dayOfYear

            onNextMonthRequested: root.nextMonth()
            onPrevMonthRequested: root.prevMonth()
            onTodayRequested: root.resetToToday()
            onDaySelected: (day) => root.selectedDay = day

            storedNotifications: root.storedNotifications
            notificationsLoading: root.notificationsLoading
            onClearAllNotificationsRequested: root.clearAllNotifications()
            onRemoveNotificationRequested: (id) => root.removeNotification(id)
        }
    }
}
