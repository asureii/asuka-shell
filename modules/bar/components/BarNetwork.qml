import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property color primary: "#cc0000"
    property color secondary: "#cc0000"
    property color fgDim: Qt.rgba(0.8, 0.0, 0.0, 0.45)
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    property string netType: "DISCONNECTED"
    property string ssid: ""
    property int signalStrength: 0

    // Network Status Poller
    Process {
        id: netProcess
        command: ["sh", "-c", "wf=$(nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes' | head -n1); if [ -n \"$wf\" ]; then ssid=$(echo \"$wf\" | cut -d: -f2); sig=$(echo \"$wf\" | cut -d: -f3); echo \"WIFI:$ssid:$sig\"; exit 0; fi; eth=$(nmcli -t -f TYPE,STATE dev 2>/dev/null | grep '^ethernet:connected'); if [ -n \"$eth\" ]; then echo \"ETH:CONNECTED:100\"; exit 0; fi; echo \"DISCONNECTED::0\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = text.trim();
                var parts = raw.split(":");
                if (parts.length >= 3) {
                    root.netType = parts[0];
                    root.ssid = parts[1];
                    var s = parseInt(parts[2]);
                    root.signalStrength = !isNaN(s) ? s : 0;
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProcess.running = true
    }

    readonly property string netIcon: {
        if (root.netType === "ETH") return "󰌘";
        if (root.netType === "WIFI") {
            if (root.signalStrength >= 70) return "󰤨";
            if (root.signalStrength >= 45) return "󰤥";
            if (root.signalStrength >= 20) return "󰤢";
            return "󰤟";
        }
        return "󰤭";
    }

    readonly property bool isPopoutActive: typeof networkPopout !== "undefined" && networkPopout && networkPopout.visible

    Layout.preferredWidth: 28
    Layout.preferredHeight: 26
    color: (netMouse.containsMouse || root.isPopoutActive) ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08)
    border.width: root.isPopoutActive ? 1.5 : 1
    border.color: root.primary

    WifiGlow {
        anchors.centerIn: parent
        width: 44
        height: 44
        connected: root.netType === "WIFI"
        visible: root.netType === "WIFI" || root.netType === "DISCONNECTED"
        running: true
        opacity: (root.netType === "DISCONNECTED") ? 0.8 : 1.0
    }

    Text {
        anchors.centerIn: parent
        text: root.netIcon
        color: root.secondary
        font.pixelSize: 13
        visible: root.netType === "ETH"
    }

    MouseArea {
        id: netMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["evaterm", "-e", "nmtui"]);
            } else {
                if (typeof networkPopout !== "undefined" && networkPopout) {
                    networkPopout.toggle();
                } else if (typeof controlCenter !== "undefined" && controlCenter) {
                    controlCenter.currentTabIndex = 5; // Tab 06 Network / Radar
                    if (typeof controlCenter.open === "function") controlCenter.open(); else controlCenter.visible = true;
                }
            }
        }
    }
}
