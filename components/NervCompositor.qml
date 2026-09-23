pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: root

    readonly property bool isSway: Quickshell.env("SWAYSOCK") !== ""
    readonly property bool isHyprland: !isSway && (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "" || Quickshell.env("XDG_CURRENT_DESKTOP") === "Hyprland")
    readonly property string compositorName: isSway ? "SwayFX" : (isHyprland ? "Hyprland" : "Wayland")

    property int _swayWsId: 1
    readonly property int currentWorkspaceId: isHyprland ? ((Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) ? Hyprland.focusedWorkspace.id : 1) : _swayWsId
    property string activeTitle: "EVA-02 // STANDBY"
    property string activeClass: ""

    function switchWorkspace(id) {
        if (id < 1 || id > 8) return;
        if (root.isSway) {
            Quickshell.execDetached(["swaymsg", "workspace", "number", "" + id]);
            root._swayWsId = id;
        } else if (root.isHyprland) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))"]);
        }
    }

    function focusWindow(address) {
        if (!address) return;
        if (root.isSway) {
            Quickshell.execDetached(["swaymsg", "[con_id=" + address + "] focus"]);
        } else if (root.isHyprland) {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = 'address:" + address + "' })"]);
        }
    }

    function closeWindow(address) {
        if (!address) return;
        if (root.isSway) {
            Quickshell.execDetached(["swaymsg", "[con_id=" + address + "] kill"]);
        } else if (root.isHyprland) {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.close({ window = 'address:" + address + "' })"]);
        }
    }

    function refresh() {
        if (root.isSway) {
            swayWsProcess.running = true;
            swayTreeProcess.running = true;
        } else if (root.isHyprland) {
            hyprActiveProcess.running = true;
        }
    }

    // ============================================================
    // SWAY IPC INTEGRATION
    // ============================================================
    property var swayWsProcess: Process {
        command: ["swaymsg", "-t", "get_workspaces", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(text.trim());
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].focused) {
                            var n = list[i].num !== undefined && list[i].num !== null ? list[i].num : parseInt(list[i].name, 10);
                            if (!isNaN(n) && n >= 1 && n <= 8) {
                                root._swayWsId = n;
                            }
                            break;
                        }
                    }
                } catch (e) {}
            }
        }
    }

    property var swayTreeProcess: Process {
        command: ["swaymsg", "-t", "get_tree", "-r"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var tree = JSON.parse(text.trim());
                    function findFocused(node) {
                        if (!node) return null;
                        if (node.focused) return node;
                        if (node.nodes) {
                            for (var i = 0; i < node.nodes.length; i++) {
                                var res = findFocused(node.nodes[i]);
                                if (res) return res;
                            }
                        }
                        if (node.floating_nodes) {
                            for (var j = 0; j < node.floating_nodes.length; j++) {
                                var res2 = findFocused(node.floating_nodes[j]);
                                if (res2) return res2;
                            }
                        }
                        return null;
                    }
                    var focused = findFocused(tree);
                    if (focused && focused.name) {
                        root.activeTitle = focused.name;
                        var wp = focused.window_properties;
                        root.activeClass = (wp && wp.class) ? wp.class : (focused.app_id || "");
                    } else {
                        root.activeTitle = "EVA-02 // STANDBY";
                        root.activeClass = "";
                    }
                } catch (e) {
                    root.activeTitle = "EVA-02 // STANDBY";
                    root.activeClass = "";
                }
            }
        }
    }

    // ============================================================
    // HYPRLAND IPC INTEGRATION
    // ============================================================
    property var hyprActiveProcess: Process {
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data && data.title) {
                        root.activeTitle = data.title;
                        root.activeClass = data.class || "";
                    } else {
                        root.activeTitle = "EVA-02 // STANDBY";
                        root.activeClass = "";
                    }
                } catch (e) {
                    root.activeTitle = "EVA-02 // STANDBY";
                    root.activeClass = "";
                }
            }
        }
    }

    // ============================================================
    // SWAY REAL-TIME EVENT STREAM (0ms Socket Subscription)
    // ============================================================
    property var swaySubscribeProcess: Process {
        command: ["swaymsg", "-m", "-r", "-t", "subscribe", "[\"workspace\", \"window\"]"]
        stdout: SplitParser {
            onRead: data => {
                var line = (data || "").trim();
                if (!line) return;
                try {
                    var evt = JSON.parse(line);
                    if (evt.current && evt.change === "focus") {
                        var n = evt.current.num !== undefined && evt.current.num !== null ? evt.current.num : parseInt(evt.current.name, 10);
                        if (!isNaN(n) && n >= 1 && n <= 8) {
                            root._swayWsId = n;
                        }
                        if (evt.current.focus && evt.current.focus.length === 0) {
                            root.activeTitle = "EVA-02 // STANDBY";
                            root.activeClass = "";
                        }
                    } else if (evt.container && (evt.change === "focus" || evt.change === "title")) {
                        if (evt.container.focused) {
                            root.activeTitle = evt.container.name || "EVA-02 // STANDBY";
                            var wp = evt.container.window_properties;
                            root.activeClass = (wp && wp.class) ? wp.class : (evt.container.app_id || "");
                        }
                    } else if (evt.change === "close") {
                        swayTreeProcess.running = true;
                    }
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (!running && root.isSway) {
                swaySubRestartTimer.restart();
            }
        }
    }

    property var swaySubRestartTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.isSway && !swaySubscribeProcess.running) {
                swaySubscribeProcess.running = true;
            }
        }
    }

    // Periodic telemetry fallback watchdog timer
    property var telemetryTimer: Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        if (root.isSway) {
            swaySubscribeProcess.running = true;
        }
        root.refresh();
    }
}
