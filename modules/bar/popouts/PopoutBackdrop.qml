import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: 46
    }

    color: "transparent"
    visible: (typeof nervLauncher !== "undefined" && nervLauncher && nervLauncher.visible) ||
             (typeof vitalsPopout !== "undefined" && vitalsPopout && vitalsPopout.visible) ||
             (typeof audioBriPopout !== "undefined" && audioBriPopout && audioBriPopout.visible) ||
             (typeof networkPopout !== "undefined" && networkPopout && networkPopout.visible) ||
             (typeof activeWorkspacePopout !== "undefined" && activeWorkspacePopout && activeWorkspacePopout.visible)

    function closeAll() {
        if (typeof nervLauncher !== "undefined" && nervLauncher && nervLauncher.visible) nervLauncher.close();
        if (typeof vitalsPopout !== "undefined" && vitalsPopout && vitalsPopout.visible) vitalsPopout.close();
        if (typeof audioBriPopout !== "undefined" && audioBriPopout && audioBriPopout.visible) audioBriPopout.close();
        if (typeof networkPopout !== "undefined" && networkPopout && networkPopout.visible) networkPopout.close();
        if (typeof activeWorkspacePopout !== "undefined" && activeWorkspacePopout && activeWorkspacePopout.visible) activeWorkspacePopout.close();
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: root.closeAll()
    }
}

