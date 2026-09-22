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
    property int hoveredWsId: 0

    // Launcher Toggle Button (Studio Magnetic Interaction)
    Item {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26

        Rectangle {
            id: launcherVisualCore
            anchors.fill: parent
            color: root.isLauncherOpen ? root.primary : (nervMouse.containsMouse ? Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.22) : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.08))
            border.width: 1
            border.color: nervMouse.containsMouse ? "#ff2222" : root.primary

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            // Tactile Spring Scale
            scale: nervMouse.pressed ? 0.92 : (nervMouse.containsMouse ? 1.08 : 1.0)
            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
            }

            // Magnetic Translation
            property real targetX: 0
            property real targetY: 0
            transform: Translate {
                x: launcherVisualCore.targetX
                y: launcherVisualCore.targetY
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            }

            // Directional Specular Lip
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.leftMargin: 2; anchors.rightMargin: 2
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.5)
                visible: nervMouse.containsMouse
            }

            Text {
                anchors.centerIn: parent
                text: "▶"
                color: root.isLauncherOpen ? "#ffffff" : root.secondary
                font.pixelSize: 10
                rotation: root.isLauncherOpen ? 90 : 0

                Behavior on rotation {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }
        }

        MouseArea {
            id: nervMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPositionChanged: (mouse) => {
                var cx = width / 2;
                var cy = height / 2;
                launcherVisualCore.targetX = Math.max(-3, Math.min(3, (mouse.x - cx) * 0.25));
                launcherVisualCore.targetY = Math.max(-3, Math.min(3, (mouse.y - cy) * 0.25));
            }

            onExited: {
                launcherVisualCore.targetX = 0;
                launcherVisualCore.targetY = 0;
            }

            onClicked: {
                if (typeof nervLauncher !== "undefined" && nervLauncher) {
                    nervLauncher.toggle();
                } else if (typeof controlCenter !== "undefined" && controlCenter) {
                    (typeof controlCenter.toggle === "function" ? controlCenter.toggle() : (controlCenter.visible = !controlCenter.visible));
                }
            }
        }
    }

    // Workspace Kanji Indicators (壱 to 捌) — Studio Kinetic Physics
    RowLayout {
        id: wsRow
        spacing: 4

        readonly property var kanjiNumerals: ["壱", "弐", "参", "肆", "伍", "陸", "漆", "捌"]

        Repeater {
            model: 8

            Item {
                readonly property int wsId: index + 1
                readonly property bool isCurrent: root.currentWorkspaceId === wsId
                readonly property bool isHovered: wsMouse.containsMouse
                Layout.preferredWidth: 24
                Layout.preferredHeight: 30

                // Sibling Attenuation (Studio Spotlight Pacing)
                opacity: (root.hoveredWsId > 0 && !isCurrent && !isHovered) ? 0.65 : 1.0
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                // Tactile Spring Scale
                scale: isCurrent ? 1.06 : (wsMouse.pressed ? 0.92 : (isHovered ? 1.05 : 1.0))
                Behavior on scale {
                    NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                }

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
                            ctx.fillStyle = Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.18);
                        } else {
                            ctx.fillStyle = "transparent";
                        }
                        ctx.fill();

                        // Stroke
                        ctx.strokeStyle = isCurrent ? root.primary : (isHovered ? "#ff2222" : Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.35));
                        ctx.lineWidth = isHovered ? 1.5 : 1.0;
                        ctx.stroke();
                    }

                    Connections {
                        target: wsMouse
                        function onContainsMouseChanged() { wsCanvas.requestPaint(); }
                    }
                }

                // Re-paint when workspace changes
                onIsCurrentChanged: wsCanvas.requestPaint()

                // Directional 1px Top Specular Highlight
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.topMargin: 3
                    anchors.leftMargin: 2; anchors.rightMargin: 6
                    height: 1
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.55)
                    visible: isCurrent || isHovered
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onEntered: root.hoveredWsId = wsId
                    onExited: {
                        if (root.hoveredWsId === wsId) root.hoveredWsId = 0;
                    }

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
                        ColorAnimation { duration: 120 }
                    }
                }
            }
        }
    }
}

