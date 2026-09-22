import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

import "components"
import "../../components"

PanelWindow {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color fg: "#cc0000"
    readonly property color fgMuted: Qt.rgba(0.8, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.8, 0.0, 0.0, 0.50)
    readonly property color bg: "#ffffff"
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.45)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
    }

    margins {
        top: 0
    }

    readonly property real fullHeight: 84
    readonly property bool isLauncherActive: (typeof nervLauncher !== "undefined" && nervLauncher && nervLauncher.visible)
    readonly property bool isVitalsActive: (typeof vitalsPopout !== "undefined" && vitalsPopout && vitalsPopout.visible)
    readonly property bool isAudioBriActive: (typeof audioBriPopout !== "undefined" && audioBriPopout && audioBriPopout.visible)
    readonly property bool isNetworkActive: (typeof networkPopout !== "undefined" && networkPopout && networkPopout.visible)
    readonly property bool isWorkspacePopoutActive: (typeof activeWorkspacePopout !== "undefined" && activeWorkspacePopout && activeWorkspacePopout.visible)
    readonly property bool hasActivePopout: root.isLauncherActive || root.isVitalsActive || root.isAudioBriActive || root.isNetworkActive || root.isWorkspacePopoutActive

    readonly property bool isBarActive: root.revealed || root.forceShow || root.hasActivePopout || (typeof controlCenter !== "undefined" && controlCenter && controlCenter.visible)
    onIsBarActiveChanged: {
        NervVitals.activeMode = root.isBarActive;
        if (root.isBarActive) {
            NervVitals.refresh();
        }
    }

    onHasActivePopoutChanged: {
        if (!root.hasActivePopout) {
            if (!barHoverArea.containsMouse) {
                hideDebounceTimer.restart();
            }
        }
    }

    implicitWidth: 1280
    implicitHeight: (root.revealed || root.forceShow || root.isAnimating || root.hasActivePopout) ? root.fullHeight : 2
    color: "transparent"

    // ============================================================
    // AUTO-HIDE & DROPDOWN STATE
    // ============================================================
    property bool revealed: false
    property bool forceShow: false
    property bool isAnimating: false

    Connections {
        target: (typeof areaPicker !== "undefined") ? areaPicker : null
        function onActiveChanged() {
            if (areaPicker && !areaPicker.active) {
                if (!barHoverArea.containsMouse && !root.hasActivePopout) {
                    hideDebounceTimer.restart();
                }
            }
        }
    }

    Timer {
        id: hideDebounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.hasActivePopout) {
                return;
            }
            if (typeof areaPicker !== "undefined" && areaPicker && areaPicker.active) {
                return;
            }
            if (!barHoverArea.containsMouse) {
                root.revealed = false;
            }
        }
    }

    // ============================================================
    // HOVER DETECTION & MAIN HUD BAR CONTAINER
    // ============================================================
    MouseArea {
        id: barHoverArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: (root.revealed || root.forceShow || root.isAnimating || root.hasActivePopout) ? root.fullHeight : 2
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        clip: true

        onEntered: {
            if (typeof areaPicker !== "undefined" && areaPicker && areaPicker.active) return;
            hideDebounceTimer.stop();
            root.revealed = true;
        }

        onExited: {
            if (typeof areaPicker !== "undefined" && areaPicker && areaPicker.active) return;
            if (root.hasActivePopout) {
                return;
            }
            hideDebounceTimer.restart();
        }

        Item {
            id: barContainer
            width: parent.width
            height: root.fullHeight
            y: (root.revealed || root.forceShow || root.hasActivePopout) ? 0 : (-root.fullHeight + 2)
            opacity: (root.revealed || root.forceShow || root.hasActivePopout) ? 1.0 : 0.0

            Behavior on y {
                SequentialAnimation {
                    ScriptAction { script: root.isAnimating = true }
                    NumberAnimation {
                        duration: (root.revealed || root.forceShow || root.hasActivePopout) ? 220 : 160
                        easing.type: (root.revealed || root.forceShow || root.hasActivePopout) ? Easing.OutCubic : Easing.InQuad
                    }
                    ScriptAction { script: root.isAnimating = false }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

        // Polygonal NERV HUD Vector Background
        BarBackground {
            id: barBg
            anchors.fill: parent
            fillColor: root.bg
            hexFillColor: root.primary
            hexBorderColor: "#ffffff"
            strokeColor: root.primary
            accentColor: root.accent
            strokeWidth: 1.5
            wingHeight: 42
            leftChamferWidth: 42
            rightChamferWidth: 42
            centerTopWidth: 190
            centerMidWidth: 260
            centerBottomWidth: 190
            centerBottomY: root.fullHeight - 1
        }

        // Directional 1px Overhead Specular Highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: barBg.leftChamferWidth
            anchors.rightMargin: barBg.rightChamferWidth
            height: 1
            color: Qt.rgba(1.0, 1.0, 1.0, 0.55)
            z: 10
        }

        // ============================================================
        // LEFT WING (Workspaces & Active Window)
        // ============================================================
        Item {
            id: leftWing
            x: barBg.leftChamferWidth + 6
            y: 0
            width: barBg.centerMidLeftX - x - 8
            height: barBg.wingHeight

            RowLayout {
                anchors.fill: parent
                anchors.rightMargin: 4
                spacing: 6

                BarWorkspaces {
                    primary: root.primary
                    secondary: root.secondary
                    fgMuted: root.fgMuted
                    hudFont: root.hudFont
                }

                BarActiveWindow {
                    primary: root.primary
                    fg: root.fg
                    hudFont: root.hudFont
                }
            }
        }

        // ============================================================
        // CENTER HEX COMMAND POD (Clock, Date, Target Crosshair)
        // ============================================================
        BarClockPod {
            id: centerPod
            x: barBg.centerMidLeftX
            y: 0
            width: barBg.centerMidWidth
            height: root.fullHeight
            hudFont: root.hudFont
        }

        // ============================================================
        // RIGHT WING (Hardware Vitals, Volume & Brightness, Battery, Actions)
        // ============================================================
        Item {
            id: rightWing
            x: barBg.centerMidRightX + 8
            y: 0
            width: root.width - x - barBg.rightChamferWidth - 6
            height: barBg.wingHeight

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                spacing: 6

                Item { Layout.fillWidth: true }

                BarHardwareStats {
                    primary: root.primary
                    secondary: root.secondary
                    fgDim: root.fgDim
                    itemBorder: root.itemBorder
                    hudFont: root.hudFont
                }

                BarAudioVolume {
                    primary: root.primary
                    secondary: root.secondary
                    itemBorder: root.itemBorder
                    hudFont: root.hudFont
                }

                BarNetwork {
                    primary: root.primary
                    secondary: root.secondary
                    fgDim: root.fgDim
                    hudFont: root.hudFont
                }

                BarBattery {
                    primary: root.primary
                    secondary: root.secondary
                    itemBorder: root.itemBorder
                    hudFont: root.hudFont
                }

                BarQuickActions {
                    primary: root.primary
                    secondary: root.secondary
                }
            }
        }
    }
}
}

