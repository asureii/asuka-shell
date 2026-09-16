import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: pickerScope

    property bool active: false
    property bool clipboardOnly: false
    property var clientRects: []

    readonly property color primaryColor: "#cc0000"
    readonly property color secondaryColor: "#cc0000"
    readonly property color fgColor: "#ffffff"
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    function open() {
        pickerScope.clipboardOnly = false;
        pickerScope.fetchClients();
        pickerScope.active = true;
    }

    function openClip() {
        pickerScope.clipboardOnly = true;
        pickerScope.fetchClients();
        pickerScope.active = true;
    }

    function close() {
        pickerScope.active = false;
        pickerScope.clientRects = [];
    }

    function toggle() {
        if (pickerScope.active) {
            pickerScope.close();
        } else {
            pickerScope.open();
        }
    }

    // IPC Endpoint for CLI / Hyprland bindings
    IpcHandler {
        target: "areapicker"

        function open() {
            pickerScope.open();
        }

        function start() {
            pickerScope.open();
        }

        function openClip() {
            pickerScope.openClip();
        }

        function close() {
            pickerScope.close();
        }

        function toggle() {
            pickerScope.toggle();
        }
    }

    // Hyprland Global Shortcuts
    GlobalShortcut {
        name: "areaPicker"
        description: "NERV Area Screenshot (File + Clipboard)"
        onPressed: {
            pickerScope.open();
        }
    }

    GlobalShortcut {
        name: "areaPickerClip"
        description: "NERV Area Screenshot (Clipboard Only)"
        onPressed: {
            pickerScope.openClip();
        }
    }

    // Query active client geometries from Hyprland for window snapping
    Process {
        id: clientFetcher
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    pickerScope.clientRects = parsed
                        .filter(c => c.mapped && !c.hidden && c.size[0] > 10 && c.size[1] > 10)
                        .map(c => ({
                            x: c.at[0],
                            y: c.at[1],
                            w: c.size[0],
                            h: c.size[1],
                            title: c.title || c.class || "WINDOW"
                        }));
                } catch (e) {
                    pickerScope.clientRects = [];
                }
            }
        }
    }

    function fetchClients() {
        if (!clientFetcher.running) {
            clientFetcher.running = true;
        }
    }

    // Execute screenshot capture via grim & wl-copy
    function executeCapture(gx, gy, gw, gh, clipOnly) {
        var x = Math.round(gx);
        var y = Math.round(gy);
        var w = Math.round(gw);
        var h = Math.round(gh);

        if (w <= 2 || h <= 2) {
            return;
        }

        var geom = x + "," + y + " " + w + "x" + h;
        var now = new Date();
        var pad = function(n) { return n < 10 ? "0" + n : n; };
        var dateStr = now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-" + pad(now.getDate()) + "_" + pad(now.getHours()) + "-" + pad(now.getMinutes()) + "-" + pad(now.getSeconds());
        var home = Quickshell.env("HOME") || "";
        var saveDir = home ? (home + "/Pictures/Screenshots") : "~/Pictures/Screenshots";
        var savePath = saveDir + "/Screenshot_" + dateStr + ".png";

        var cmd;
        if (clipOnly) {
            cmd = "sleep 0.1 && grim -g \"" + geom + "\" - | wl-copy --type image/png && command -v notify-send >/dev/null && notify-send -a \"NERV Telemetry\" \"AREA CAPTURE\" \"Selection copied to clipboard (" + w + "x" + h + ")\"";
        } else {
            cmd = "sleep 0.1 && mkdir -p \"" + saveDir + "\" && grim -g \"" + geom + "\" \"" + savePath + "\" && wl-copy --type image/png < \"" + savePath + "\" && command -v notify-send >/dev/null && notify-send -a \"NERV Telemetry\" -i \"" + savePath + "\" \"AREA CAPTURE\" \"Saved to " + savePath + "\"";
        }

        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // Multi-screen overlay windows
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            visible: pickerScope.active

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: pickerScope.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            mask: pickerScope.active ? null : emptyRegion

            Region {
                id: emptyRegion
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            Connections {
                target: pickerScope
                function onActiveChanged() {
                    if (pickerScope.active) {
                        overlayRoot.forceActiveFocus();
                        overlayRoot.isDragging = false;
                        overlayRoot.onWindowHover = false;
                        overlayRoot.sx = 0;
                        overlayRoot.sy = 0;
                        overlayRoot.ex = 0;
                        overlayRoot.ey = 0;
                    }
                }
            }

            Item {
                id: overlayRoot
                anchors.fill: parent
                focus: true

                property real sx: 0
                property real sy: 0
                property real ex: 0
                property real ey: 0
                property bool isDragging: false
                property bool onWindowHover: false
                property string hoveredTitle: ""

                readonly property real selX: Math.min(sx, ex)
                readonly property real selY: Math.min(sy, ey)
                readonly property real selW: Math.abs(ex - sx)
                readonly property real selH: Math.abs(ey - sy)

                // Keyboard handling to ensure Esc or Q always closes
                Keys.onEscapePressed: function(event) {
                    event.accepted = true;
                    pickerScope.close();
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
                        event.accepted = true;
                        pickerScope.close();
                    }
                }

                // Check if cursor is over a recognized window
                function checkWindowHover(mx, my) {
                    if (isDragging || !pickerScope.active) return;

                    var globalX = win.screen.x + mx;
                    var globalY = win.screen.y + my;

                    for (var i = 0; i < pickerScope.clientRects.length; i++) {
                        var c = pickerScope.clientRects[i];
                        if (globalX >= c.x && globalX <= c.x + c.w && globalY >= c.y && globalY <= c.y + c.h) {
                            sx = c.x - win.screen.x;
                            sy = c.y - win.screen.y;
                            ex = sx + c.w;
                            ey = sy + c.h;
                            onWindowHover = true;
                            hoveredTitle = c.title;
                            return;
                        }
                    }

                    onWindowHover = false;
                    hoveredTitle = "";
                    sx = mx;
                    sy = my;
                    ex = mx;
                    ey = my;
                }

                // Shaded backdrop outside selection
                // Top
                Rectangle {
                    x: 0
                    y: 0
                    width: parent.width
                    height: Math.max(0, overlayRoot.selY)
                    color: "#a0080202"
                }
                // Bottom
                Rectangle {
                    x: 0
                    y: overlayRoot.selY + overlayRoot.selH
                    width: parent.width
                    height: Math.max(0, parent.height - (overlayRoot.selY + overlayRoot.selH))
                    color: "#a0080202"
                }
                // Left
                Rectangle {
                    x: 0
                    y: overlayRoot.selY
                    width: Math.max(0, overlayRoot.selX)
                    height: overlayRoot.selH
                    color: "#a0080202"
                }
                // Right
                Rectangle {
                    x: overlayRoot.selX + overlayRoot.selW
                    y: overlayRoot.selY
                    width: Math.max(0, parent.width - (overlayRoot.selX + overlayRoot.selW))
                    height: overlayRoot.selH
                    color: "#a0080202"
                }



                // Selection Box & Tactical Frame
                Item {
                    visible: overlayRoot.selW > 2 && overlayRoot.selH > 2
                    x: overlayRoot.selX
                    y: overlayRoot.selY
                    width: overlayRoot.selW
                    height: overlayRoot.selH

                    // Bounding box (transparent interior so only the picture is visible)
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 1
                        border.color: pickerScope.primaryColor
                    }

                    // Tactical Corner Brackets
                    Repeater {
                        model: 4
                        Item {
                            anchors.fill: parent
                            Rectangle {
                                x: (index % 2 === 0) ? -1 : parent.width - 13
                                y: (index < 2) ? -1 : parent.height - 2
                                width: 14; height: 3; color: pickerScope.secondaryColor
                            }
                            Rectangle {
                                x: (index % 2 === 0) ? -1 : parent.width - 2
                                y: (index < 2) ? -1 : parent.height - 13
                                width: 3; height: 14; color: pickerScope.secondaryColor
                            }
                        }
                    }

                    // Telemetry HUD Badge
                    Rectangle {
                        id: hudBadge
                        y: (parent.y < 36) ? parent.height + 8 : -32
                        x: Math.max(0, Math.min(parent.width - width, 0))
                        height: 24
                        width: hudRow.implicitWidth + 16
                        color: "#ffffff"
                        border.width: 1
                        border.color: pickerScope.secondaryColor

                        Row {
                            id: hudRow
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "NERV // TARGET"
                                color: pickerScope.secondaryColor
                                font.family: pickerScope.hudFont
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            Text {
                                text: Math.round(overlayRoot.selW) + " × " + Math.round(overlayRoot.selH)
                                color: "#1a0000"
                                font.family: pickerScope.hudFont
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                text: pickerScope.clipboardOnly ? "[CLIP]" : "[SAVE+CLIP]"
                                color: pickerScope.primaryColor
                                font.family: pickerScope.hudFont
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }
                }

                // Screen interaction mouse area
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPositionChanged: function(mouse) {
                        if (overlayRoot.isDragging) {
                            overlayRoot.ex = mouse.x;
                            overlayRoot.ey = mouse.y;
                        } else {
                            overlayRoot.checkWindowHover(mouse.x, mouse.y);
                        }
                    }

                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            pickerScope.close();
                            return;
                        }

                        if (!pickerScope.active) return;

                        overlayRoot.isDragging = true;
                        overlayRoot.onWindowHover = false;
                        overlayRoot.sx = mouse.x;
                        overlayRoot.sy = mouse.y;
                        overlayRoot.ex = mouse.x;
                        overlayRoot.ey = mouse.y;
                    }

                    onReleased: function(mouse) {
                        if (!pickerScope.active || mouse.button === Qt.RightButton) {
                            return;
                        }

                        if (!overlayRoot.isDragging && !overlayRoot.onWindowHover) {
                            return;
                        }

                        var finalW = overlayRoot.selW;
                        var finalH = overlayRoot.selH;
                        var finalX = overlayRoot.selX;
                        var finalY = overlayRoot.selY;

                        overlayRoot.isDragging = false;
                        overlayRoot.onWindowHover = false;

                        // If user single-clicked on empty space, capture whole screen
                        if (finalW < 10 || finalH < 10) {
                            finalX = 0;
                            finalY = 0;
                            finalW = win.screen.width;
                            finalH = win.screen.height;
                        }

                        var globalX = win.screen.x + finalX;
                        var globalY = win.screen.y + finalY;

                        pickerScope.close();
                        pickerScope.executeCapture(globalX, globalY, finalW, finalH, pickerScope.clipboardOnly);
                    }
                }
            }
        }
    }
}
