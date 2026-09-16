import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

import "modules/controlcenter"
import "modules/areapicker"
import "modules/background"
import "modules/popups"
import "modules/bar"
import "modules/bar/popouts"

ShellRoot {
    id: root

    Background {
        id: background
    }

    PopoutBackdrop {
        id: popoutBackdrop
    }

    Bar {
        id: bar
    }

    // Automatic Live Workspace Snapshot Cache
    readonly property int currentWsId: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) ? Hyprland.focusedWorkspace.id : 1

    onCurrentWsIdChanged: {
        workspaceSnapshotTimer.restart();
    }

    Timer {
        id: workspaceSnapshotTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root.currentWsId >= 1 && root.currentWsId <= 8) {
                Quickshell.execDetached([Quickshell.configPath("scripts/nerv_workspace_clients.py"), "--snapshot", "" + root.currentWsId]);
            }
        }
    }

    Component.onCompleted: {
        workspaceSnapshotTimer.restart();
    }

    NervLauncher {
        id: nervLauncher
    }

    NervVitalsPopout {
        id: vitalsPopout
    }

    NervAudioBrightnessPopout {
        id: audioBriPopout
    }

    NervNetworkPopout {
        id: networkPopout
    }

    ActiveWorkspacePopout {
        id: activeWorkspacePopout
    }

    NotificationPopup {
        id: notificationPopup
    }

    ControlCenterOverlay {
        id: controlCenter
    }

    AreaPicker {
        id: areaPicker
    }

    GlobalShortcut {
        name: "toggleLauncher"
        description: "Toggle NERV-01 Popout Launcher"
        onPressed: {
            nervLauncher.toggle();
        }
    }

    GlobalShortcut {
        name: "toggleVitals"
        description: "Toggle NERV Hardware Vitals Popout"
        onPressed: {
            vitalsPopout.toggle();
        }
    }

    GlobalShortcut {
        name: "toggleAudioBrightness"
        description: "Toggle NERV Audio & Brightness Popout"
        onPressed: {
            audioBriPopout.toggle();
        }
    }

    GlobalShortcut {
        name: "toggleNetwork"
        description: "Toggle NERV Network Radar Popout"
        onPressed: {
            networkPopout.toggle();
        }
    }

    GlobalShortcut {
        name: "toggleWorkspacePreview"
        description: "Toggle Active Workspace Preview Popout"
        onPressed: {
            activeWorkspacePopout.toggle();
        }
    }

    IpcHandler {
        target: "workspace_preview"

        function toggle() {
            activeWorkspacePopout.toggle();
        }

        function open() {
            activeWorkspacePopout.open();
        }

        function close() {
            activeWorkspacePopout.close();
        }
    }

    GlobalShortcut {
        name: "toggleControlCenter"
        description: "Toggle NERV Control Center Overlay"
        onPressed: {
            controlCenter.toggle();
        }
    }

    GlobalShortcut {
        name: "togglePanel"
        description: "Toggle NERV Control Center (Alias)"
        onPressed: {
            controlCenter.toggle();
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle() {
            controlCenter.toggle();
        }

        function open() {
            controlCenter.open();
        }

        function close() {
            controlCenter.close();
        }

        function nextTab() {
            controlCenter.advanceNextTab();
        }

        function prevTab() {
            controlCenter.advancePrevTab();
        }

        function setTab(idx: string) {
            var n = parseInt(idx, 10);
            if (!isNaN(n)) controlCenter.selectTabByWheelIndex(n);
        }

        function toggleWheel() {
            controlCenter.isWheelCollapsed = !controlCenter.isWheelCollapsed;
        }

        function collapseWheel() {
            controlCenter.isWheelCollapsed = true;
        }

        function expandWheel() {
            controlCenter.isWheelCollapsed = false;
        }
    }

    // Alias for existing Hyprland keybinds calling "panel"
    IpcHandler {
        target: "panel"

        function toggle() {
            controlCenter.toggle();
        }

        function open() {
            controlCenter.open();
        }

        function close() {
            controlCenter.close();
        }
    }

    IpcHandler {
        target: "background"

        function setWallpaper(path: string) {
            background.setWallpaper(path);
        }

        function openPicker() {
            background.openFileDialog();
        }
    }

    // Eva Suite & EvaCore System IPC Handler
    IpcHandler {
        target: "eva"

        function openTab(idx: int) {
            if (idx >= 0 && idx < 8) {
                controlCenter.currentTabIndex = idx;
            }
            controlCenter.open();
        }

        function openEvaFile(path: string) {
            Quickshell.execDetached(["evafile", path ? path : (Quickshell.env("HOME") + "/Downloads")]);
        }

        function openEvaTerm(cmd: string) {
            if (cmd && cmd.length > 0) {
                Quickshell.execDetached(["evaterm", "-e", cmd]);
            } else {
                Quickshell.execDetached(["evaterm"]);
            }
        }

        function runEvaSort(path: string) {
            Quickshell.execDetached(["evacore", "sort"]);
        }
    }

    IpcHandler {
        target: "evacore"

        function openTab(idx: int) {
            if (idx >= 0 && idx < 8) {
                controlCenter.currentTabIndex = idx;
            }
            controlCenter.open();
        }

        function openFile(path: string) {
            Quickshell.execDetached(["evafile", path ? path : (Quickshell.env("HOME") + "/Downloads")]);
        }

        function openTerm(cmd: string) {
            if (cmd && cmd.length > 0) {
                Quickshell.execDetached(["evaterm", "-e", cmd]);
            } else {
                Quickshell.execDetached(["evaterm"]);
            }
        }

        function restart() {
            Quickshell.execDetached(["evacore", "shell", "-r", "-d"]);
        }
    }

    IpcHandler {
        target: "bar"

        function toggle() {
            bar.visible = !bar.visible;
        }

        function open() {
            bar.visible = true;
        }

        function close() {
            bar.visible = false;
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle() {
            nervLauncher.toggle();
        }

        function open() {
            nervLauncher.open();
        }

        function close() {
            nervLauncher.close();
        }
    }

    IpcHandler {
        target: "vitals"

        function toggle() {
            vitalsPopout.toggle();
        }

        function open() {
            vitalsPopout.open();
        }

        function close() {
            vitalsPopout.close();
        }
    }

    IpcHandler {
        target: "audiobri"

        function toggle() {
            audioBriPopout.toggle();
        }

        function open() {
            audioBriPopout.open();
        }

        function close() {
            audioBriPopout.close();
        }
    }

    IpcHandler {
        target: "network"

        function toggle() {
            networkPopout.toggle();
        }

        function open() {
            networkPopout.open();
        }

        function close() {
            networkPopout.close();
        }
    }
}
