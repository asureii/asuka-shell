import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

RowLayout {
    id: root

    property color primary: "#cc0000"
    property color secondary: "#cc0000"
    property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"
    readonly property int currentWorkspaceId: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) ? Hyprland.focusedWorkspace.id : 1

    function switchWorkspace(id) {
        if (id < 1 || id > 8) return;
        Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))"]);
    }

    spacing: 6

    readonly property bool isLauncherOpen: (typeof nervLauncher !== "undefined" && nervLauncher && nervLauncher.visible)

    // Launcher Toggle Button (Compact Animated Arrow)
    Rectangle {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        color: root.isLauncherOpen ? root.primary : (nervMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08))
        border.width: 1
        border.color: root.primary

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Text {
            anchors.centerIn: parent
            text: "▶"
            color: root.isLauncherOpen ? "#ffffff" : root.secondary
            font.pixelSize: 10
            rotation: root.isLauncherOpen ? 90 : 0

            Behavior on rotation {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        MouseArea {
            id: nervMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (typeof nervLauncher !== "undefined" && nervLauncher) {
                    nervLauncher.toggle();
                } else if (typeof controlCenter !== "undefined" && controlCenter) {
                    (typeof controlCenter.toggle === "function" ? controlCenter.toggle() : (controlCenter.visible = !controlCenter.visible));
                }
            }
        }
    }

    // Workspace Kanji Indicators (壱 to 捌) — Chamfered Corners
    RowLayout {
        id: wsRow
        spacing: 3

        readonly property var kanjiNumerals: ["壱", "弐", "参", "肆", "伍", "陸", "漆", "捌"]

        Repeater {
            model: 8

            Item {
                readonly property int wsId: index + 1
                readonly property bool isCurrent: root.currentWorkspaceId === wsId
                readonly property bool isHovered: wsMouse.containsMouse
                Layout.preferredWidth: 24
                Layout.preferredHeight: 30

                // Bracket Lines (Active Workspace)
                Repeater {
                    model: 2
                    Rectangle {
                        anchors.top: index === 0 ? parent.top : undefined
                        anchors.bottom: index === 1 ? parent.bottom : undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: 1
                        color: root.primary
                        opacity: isCurrent ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Canvas {
                    id: wsCanvas
                    anchors.fill: parent
                    anchors.topMargin: 3
                    anchors.bottomMargin: 3
                    renderTarget: Canvas.Image
                    renderStrategy: Canvas.Immediate

                    property real chamfer: 5

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        var w = width;
                        var h = height;
                        var c = chamfer;

                        // Chamfered polygon path (top-right & bottom-left cuts only)
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(w - c, 0);
                        ctx.lineTo(w, c);
                        ctx.lineTo(w, h);
                        ctx.lineTo(c, h);
                        ctx.lineTo(0, h - c);
                        ctx.closePath();

                        // Fill
                        if (isCurrent) {
                            ctx.fillStyle = root.primary;
                        } else if (isHovered) {
                            ctx.fillStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.15);
                        } else {
                            ctx.fillStyle = "transparent";
                        }
                        ctx.fill();

                        // Stroke
                        ctx.strokeStyle = isCurrent ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35);
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }

                    Connections {
                        target: wsMouse
                        function onContainsMouseChanged() { wsCanvas.requestPaint(); }
                    }
                }

                // Re-paint when workspace changes
                onIsCurrentChanged: wsCanvas.requestPaint()

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            if (typeof activeWorkspacePopout !== "undefined" && activeWorkspacePopout) {
                                if (activeWorkspacePopout.visible && activeWorkspacePopout.targetWorkspaceId === wsId) {
                                    activeWorkspacePopout.close();
                                } else {
                                    if (wsId === root.currentWorkspaceId) {
                                        Quickshell.execDetached([Quickshell.configPath("scripts/nerv_workspace_clients.py"), "--snapshot", "" + wsId]);
                                    }
                                    activeWorkspacePopout.openForWorkspace(wsId);
                                }
                            }
                        } else {
                            root.switchWorkspace(wsId);
                        }
                    }
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) root.switchWorkspace(Math.max(1, root.currentWorkspaceId - 1));
                        else if (wheel.angleDelta.y < 0) root.switchWorkspace(Math.min(8, root.currentWorkspaceId + 1));
                    }
                }

                Text {
                    z: 2
                    anchors.centerIn: wsCanvas
                    text: wsRow.kanjiNumerals[index]
                    color: isCurrent ? "#ffffff" : (wsMouse.containsMouse ? root.primary : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.55))
                    font.family: root.hudFont
                    font.pixelSize: 11
                    font.bold: true

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
            }
        }
    }
}
