import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../../../components"

Item {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color panelBg: Qt.rgba(0.98, 0.98, 0.98, 0.92)
    readonly property color itemBg: Qt.rgba(1.0, 1.0, 1.0, 0.85)
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.35)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    component SensorTile: Rectangle {
        id: st
        property string iconLabel: ""
        property string value: ""
        Layout.fillWidth: true
        height: 42
        color: root.itemBg
        border.width: 1
        border.color: root.itemBorder
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 1
            Text { text: st.iconLabel; color: root.fgDim; font.family: root.hudFont; font.pixelSize: 8; font.bold: true }
            Text { text: st.value; color: root.secondary; font.family: root.hudFont; font.pixelSize: 10; font.bold: true }
        }
    }

    component NavBtn: Rectangle {
        id: nb
        property string label: ""
        property int btnWidth: 20
        signal clicked()
        width: btnWidth
        height: 18
        color: nbMouse.containsMouse ? root.primary : "#ffffff"
        border.width: 1
        border.color: root.primary
        Text {
            anchors.centerIn: parent
            text: nb.label
            color: nbMouse.containsMouse ? "#ffffff" : root.primary
            font.family: root.hudFont
            font.pixelSize: nb.label.length > 2 ? 7 : 8
            font.bold: true
        }
        MouseArea { id: nbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nb.clicked() }
    }

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
    // MAIN 3-COLUMN LAYOUT
    // ============================================================
    RowLayout {
        anchors.fill: parent
        spacing: 10

        // ============================================================
        // LEFT COLUMN: WEATHER PANEL (METEOROLOGICAL RADAR)
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            Layout.minimumWidth: 230
            Layout.maximumWidth: 290
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

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
                        width: 62
                        height: 18
                        color: rescanMouse.containsMouse ? root.primary : "#ffffff"
                        border.width: 1
                        border.color: root.primary

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Text { text: "⟳"; color: rescanMouse.containsMouse ? "#ffffff" : root.primary; font.pixelSize: 8; font.bold: true }
                            Text { text: "RESCAN"; color: rescanMouse.containsMouse ? "#ffffff" : root.primary; font.family: root.hudFont; font.pixelSize: 7; font.bold: true }
                        }

                        MouseArea {
                            id: rescanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshWeather(true)
                        }
                    }
                }

                // Sector Location Badge
                Rectangle {
                    Layout.fillWidth: true
                    height: 20
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.itemBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 4

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: root.primary
                        }

                        Text {
                            text: root.weatherData ? root.weatherData.sector : "TOKYO-3 // GEO-FRONT"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 9
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "UPD: " + (root.weatherData ? root.weatherData.updated : "--:--")
                            color: root.fgMuted
                            font.family: root.hudFont
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }
                }

                // Primary Weather Condition Card
                Rectangle {
                    Layout.fillWidth: true
                    height: 94
                    color: root.itemBg
                    border.width: 1
                    border.color: root.itemBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12

                        // Giant Weather Glyph
                        Text {
                            text: root.weatherData ? root.weatherData.icon : "󰖙"
                            color: root.secondary
                            font.pixelSize: 46
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Temp & Description
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: (root.weatherData ? root.weatherData.temp : 28) + "°C"
                                    color: root.accent
                                    font.family: root.hudFont
                                    font.pixelSize: 30
                                    font.bold: true
                                }
                                Text {
                                    text: "FEELS " + (root.weatherData ? root.weatherData.feels_like : 31) + "°"
                                    color: root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 4
                                }
                            }

                            Text {
                                text: root.weatherData ? root.weatherData.condition : "ATMOSPHERE NOMINAL"
                                color: root.fg
                                font.family: root.hudFont
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "SURFACE CONDITIONS // VISIBILITY OPTIMAL"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 8
                            }
                        }
                    }
                }

                // 4 Atmospheric Sensor Matrix Tiles
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 4

                    // 4 Atmospheric Sensor Matrix Tiles
                    SensorTile {
                        iconLabel: "󰖆 HUMIDITY"
                        value: (root.weatherData ? root.weatherData.humidity : 65) + "% REL"
                    }
                    SensorTile {
                        iconLabel: "󰖝 WIND VECTOR"
                        value: (root.weatherData ? root.weatherData.wind_speed : 12) + " km/h " + (root.weatherData ? root.weatherData.wind_dir : "NE")
                    }
                    SensorTile {
                        iconLabel: "󰖖 PRECIPITATION"
                        value: (root.weatherData ? root.weatherData.precipitation : 0.0) + " mm/h"
                    }
                    SensorTile {
                        iconLabel: "󰖔 PRESSURE"
                        value: (root.weatherData ? root.weatherData.pressure : 1012) + " hPa"
                    }

                }

                // 5-Day Tactical Forecast Deck
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
                        spacing: 6

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
                            spacing: 4

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
                                        spacing: 8

                                        Text {
                                            text: modelData.day
                                            color: root.primary
                                            font.family: root.hudFont
                                            font.pixelSize: 11
                                            font.bold: true
                                            Layout.preferredWidth: 32
                                        }

                                        Text {
                                            text: modelData.icon
                                            color: root.primary
                                            font.pixelSize: 16
                                        }

                                        Text {
                                            text: modelData.desc
                                            color: root.fg
                                            font.family: root.hudFont
                                            font.pixelSize: 10
                                            font.bold: true
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: modelData.max + "° / " + modelData.min + "°"
                                            color: root.accent
                                            font.family: root.hudFont
                                            font.pixelSize: 11
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

        // ============================================================
        // MIDDLE COLUMN: CLOCK (TOP) & CALENDAR (BOTTOM)
        // ============================================================
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: 380
            spacing: 10

            // TOP MIDDLE: TACTICAL EVA HUD CLOCK
            Rectangle {
                Layout.fillWidth: true
                height: 180
                color: root.panelBg
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // Top Hazard Line
                    NervHazardLines {
                        Layout.fillWidth: true
                        height: 6
                        stripeColor: root.primary
                        bgColor: "#ffffff"
                    }

                    // Header
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "▶ " + NervSettings.hudBranding + " // SYSTEM TIME"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 80
                            height: 16
                            color: "#ffffff"
                            border.width: 1
                            border.color: root.primary

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Rectangle { width: 4; height: 4; radius: 2; color: root.primary }
                                Text {
                                    text: "ATOMIC SYNC"
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // Big Evangelion Digital Clock
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 2

                        Text {
                            text: root.localHours
                            color: root.accent
                            font.family: root.hudFont
                            font.pixelSize: 42
                            font.bold: true
                        }

                        Text {
                            text: ":"
                            color: root.colonBlink ? root.secondary : "transparent"
                            font.family: root.hudFont
                            font.pixelSize: 40
                            font.bold: true
                        }

                        Text {
                            text: root.localMinutes
                            color: root.accent
                            font.family: root.hudFont
                            font.pixelSize: 42
                            font.bold: true
                        }

                        Text {
                            text: ":"
                            color: root.colonBlink ? root.secondary : "transparent"
                            font.family: root.hudFont
                            font.pixelSize: 40
                            font.bold: true
                        }

                        Text {
                            text: root.localSeconds
                            color: root.secondary
                            font.family: root.hudFont
                            font.pixelSize: 42
                            font.bold: true
                        }
                    }

                    // Date Banner
                    Text {
                        text: root.dateBanner
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // Triple Multi-Timezone Array Bar
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
                            spacing: 8

                            Text {
                                text: "LOCAL (WIB): " + root.localHours + ":" + root.localMinutes + ":" + root.localSeconds + " GMT+7"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "NERV HQ (JST): " + root.tokyoTime + " GMT+9"
                                color: root.fgMuted
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "ZULU (UTC): " + root.utcTime + " Z"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // ============================================================
            // MIDDLE: PILOT IDENTIFICATION PROFILE (ASUKA PFP)
            // ============================================================
            Rectangle {
                id: pilotCard
                Layout.fillWidth: true
                height: 92
                color: root.panelBg
                border.width: 1
                border.color: pfpMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    // Tactical Avatar Frame with Reticle Brackets
                    Item {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        Layout.alignment: Qt.AlignVCenter

                        // Outer Reticle Container
                        Rectangle {
                            id: avatarBorder
                            anchors.fill: parent
                            color: "#ffffff"
                            border.width: 1.5
                            border.color: root.primary
                            radius: 2
                            clip: true

                            Image {
                                id: pfpImage
                                anchors.fill: parent
                                anchors.margins: 2
                                source: "file://" + Quickshell.configPath("assets/asukapfp.jpg")
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                                cache: true
                            }

                            // Subtle Scanline / CRT border accent on avatar
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.20)
                            }
                        }

                        // Tactical Corner Reticles (Top-Left & Bottom-Right)
                        Rectangle {
                            anchors.top: avatarBorder.top
                            anchors.left: avatarBorder.left
                            anchors.topMargin: -2
                            anchors.leftMargin: -2
                            width: 6; height: 2; color: root.primary
                        }
                        Rectangle {
                            anchors.top: avatarBorder.top
                            anchors.left: avatarBorder.left
                            anchors.topMargin: -2
                            anchors.leftMargin: -2
                            width: 2; height: 6; color: root.primary
                        }
                        Rectangle {
                            anchors.bottom: avatarBorder.bottom
                            anchors.right: avatarBorder.right
                            anchors.bottomMargin: -2
                            anchors.rightMargin: -2
                            width: 6; height: 2; color: root.primary
                        }
                        Rectangle {
                            anchors.bottom: avatarBorder.bottom
                            anchors.right: avatarBorder.right
                            anchors.bottomMargin: -2
                            anchors.rightMargin: -2
                            width: 2; height: 6; color: root.primary
                        }
                    }

                    // Tactical Pilot Dossier Details Column
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        // 1. Classification & Status Badge Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: "▶ EVA-02 // PILOT"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1.1
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 72
                                height: 16
                                color: "#ffffff"
                                border.width: 1
                                border.color: root.primary
                                radius: 2

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: root.primary
                                    }
                                    Text {
                                        text: "ACTIVE"
                                        color: root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 7
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        // 2. Pilot Full Name & Call Sign
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "ASUKA LANGLEY SORYU"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 13
                                font.bold: true
                                font.letterSpacing: 0.5
                            }

                            Text {
                                text: "式波・アスカ"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 9
                                font.bold: true
                                Layout.alignment: Qt.AlignBaseline
                            }
                        }

                        // 3. Technical Specs / Sync Ratio Array
                        Rectangle {
                            Layout.fillWidth: true
                            height: 22
                            color: "#ffffff"
                            border.width: 1
                            border.color: root.itemBorder

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                Text {
                                    text: "SYNC: 99.4%"
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                // Sync Bar Indicator
                                Rectangle {
                                    width: 50
                                    height: 5
                                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15)
                                    border.width: 1
                                    border.color: root.primary

                                    Rectangle {
                                        width: parent.width * 0.94
                                        height: parent.height
                                        color: root.primary
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "CLEARANCE: LEVEL-AA"
                                    color: root.fgMuted
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "HARMONICS: NORMAL"
                                    color: root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: pfpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // BOTTOM MIDDLE: TACTICAL OPERATIONS CALENDAR
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.panelBg
                border.width: 1
                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // Calendar Navigation & Month Title Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "▶ TACTICAL OPERATIONS CALENDAR"
                            color: root.primary
                            font.family: root.hudFont
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }

                        Item { Layout.fillWidth: true }

                        // Month Navigation
                        RowLayout {
                            spacing: 2

                            NavBtn { label: "◀"; onClicked: root.prevMonth() }

                            // Current Month / Year Label
                            Rectangle {
                                width: 120
                                height: 18
                                color: "#ffffff"
                                border.width: 1
                                border.color: root.primary
                                Text {
                                    anchors.centerIn: parent
                                    text: root.monthNames[root.viewMonth] + " " + root.viewYear
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }

                            NavBtn { label: "▶"; onClicked: root.nextMonth() }
                            NavBtn { label: "TODAY"; btnWidth: 46; onClicked: root.resetToToday() }
                        }
                    }

                    // Weekdays Header Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 18
                                color: "#ffffff"
                                border.width: 1
                                border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: (index >= 5) ? root.primary : root.fg
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // 7x6 Interactive Calendar Grid
                    GridLayout {
                        id: calGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        columnSpacing: 2
                        rowSpacing: 2

                        Repeater {
                            model: root.calendarGridDays

                            Rectangle {
                                id: dayCell
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: modelData.isToday ? root.primary
                                                         : (cellMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08) : "#ffffff")
                                border.width: 1
                                border.color: modelData.isToday ? root.primary
                                                                : (cellMouse.containsMouse ? root.primary : (modelData.isCurrentMonth ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)))

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    spacing: 1

                                    Text {
                                        text: modelData.day
                                        color: modelData.isToday ? "#ffffff"
                                                                 : (modelData.isCurrentMonth ? root.fg : root.fgDim)
                                        font.family: root.hudFont
                                        font.pixelSize: 9
                                        font.bold: modelData.isToday || modelData.isCurrentMonth
                                        Layout.alignment: Qt.AlignHCenter
                                    }

                                    Text {
                                        visible: modelData.isToday
                                        text: "TODAY"
                                        color: "#ffffff"
                                        font.family: root.hudFont
                                        font.pixelSize: 5
                                        font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedDay = modelData.day;
                                    }
                                }
                            }
                        }
                    }

                    // Calendar Footer / Operational Status
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

                            Text {
                                text: "OPERATION DAY: " + root.dayOfYear + " OF 365 // PHASE: ACTIVE DEFENSE"
                                color: root.primary
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "SCHEDULE: STANDBY // NO INTERCEPT DIRECTIVES"
                                color: root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        // ============================================================
        // RIGHT COLUMN: SCROLLABLE MINI NOTIFICATION FEED
        // ============================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 260
            Layout.minimumWidth: 230
            Layout.maximumWidth: 290
            color: root.panelBg
            border.width: 1
            border.color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.45)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "▶ NOTIFICATIONS"
                        color: root.primary
                        font.family: root.hudFont
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // Counter Badge
                    Rectangle {
                        width: root.storedNotifications.length > 0 ? 58 : 44
                        height: 18
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.storedNotifications.length > 0 ? root.primary : root.itemBorder

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: root.storedNotifications.length > 0 ? root.primary : root.fgDim
                            }
                            Text {
                                text: root.storedNotifications.length > 0 ? (root.storedNotifications.length + " RECS") : "EMPTY"
                                color: root.storedNotifications.length > 0 ? root.primary : root.fgDim
                                font.family: root.hudFont
                                font.pixelSize: 7
                                font.bold: true
                            }
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
                            onClicked: root.clearAllNotifications()
                        }
                    }
                }

                // Subheader / Status Line
                Text {
                    text: root.storedNotifications.length > 0 ? "STORED SYSTEM ALERTS ARCHIVE" : "ALL ALERTS PROCESSED // STANDBY"
                    color: root.fgDim
                    font.family: root.hudFont
                    font.pixelSize: 7
                    font.bold: true
                }

                // Scrollable Notifications List
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: notifColumn.implicitHeight

                    ColumnLayout {
                        id: notifColumn
                        width: parent.width
                        spacing: 6

                        // Render Stored Notifications
                        Repeater {
                            model: root.storedNotifications

                            Rectangle {
                                Layout.fillWidth: true
                                height: notifInnerCol.implicitHeight + 14
                                color: "#ffffff"
                                border.width: 1
                                border.color: modelData.urgency === "critical" ? "#ff1a10" : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35)

                                ColumnLayout {
                                    id: notifInnerCol
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 3

                                    // Top Row: App Name, Time, Dismiss Button
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
                                            color: dismissLiveMouse.containsMouse ? root.primary : "#ffffff"
                                            border.width: 1
                                            border.color: root.primary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: dismissLiveMouse.containsMouse ? "#ffffff" : root.primary
                                                font.pixelSize: 7
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: dismissLiveMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.removeNotification(modelData.id)
                                            }
                                        }
                                    }

                                    // Content Row (Icon + Summary/Body)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // Optional Tinted App Icon / Image
                                        Rectangle {
                                            visible: !!modelData.image || !!modelData.appIcon
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 30
                                            color: "#ffffff"
                                            border.width: 1
                                            border.color: root.primary
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                source: root.resolveIconSource(modelData.image, modelData.appIcon)
                                                fillMode: Image.PreserveAspectFit
                                                layer.enabled: true
                                                layer.effect: NervIconEffect {
                                                    tintColor: "#cc0000"
                                                    bgColor: "#ffffff"
                                                }
                                            }
                                        }

                                        // Summary & Body Column
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: modelData.summary || "NO SUMMARY"
                                                color: modelData.urgency === "critical" ? "#ff1100" : root.primary
                                                font.family: root.hudFont
                                                font.pixelSize: 8
                                                font.bold: true
                                                wrapMode: Text.WordWrap
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                visible: !!modelData.body
                                                text: modelData.body || ""
                                                color: "#330000"
                                                font.family: root.hudFont
                                                font.pixelSize: 7
                                                wrapMode: Text.WordWrap
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Authentic Empty State when zero notifications stored
                        Rectangle {
                            visible: root.storedNotifications.length === 0
                            Layout.fillWidth: true
                            height: 120
                            color: "transparent"

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "󰂚 NO STORED NOTIFICATIONS"
                                    color: root.fgDim
                                    font.family: root.hudFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "INCOMING ALERTS WILL BE ARCHIVED HERE"
                                    color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.25)
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
