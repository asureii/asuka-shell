import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../../components"

PanelWindow {
    id: root

    readonly property color primary: "#cc0000"
    readonly property color secondary: "#cc0000"
    readonly property color accent: "#cc0000"
    readonly property color fg: "#1a0000"
    readonly property color fgMuted: Qt.rgba(0.1, 0.0, 0.0, 0.70)
    readonly property color fgDim: Qt.rgba(0.1, 0.0, 0.0, 0.45)
    readonly property color cardBg: "#ffffff"
    readonly property color itemBorder: Qt.rgba(0.8, 0.0, 0.0, 0.50)
    readonly property string hudFont: "Liberation Sans, JetBrainsMono Nerd Font"

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

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
    }

    margins {
        top: 24
        left: 24
    }

    implicitWidth: 390
    implicitHeight: popupColumn.implicitHeight

    color: "transparent"
    visible: root.activePopups.length > 0

    // List of active popup objects
    property var activePopups: []
    property int nextPopupId: 1

    NotificationServer {
        id: server
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true

        onNotification: (notification) => {
            // Save to persistent notification history
            var urgStr = "normal";
            if (notification.urgency === NotificationUrgency.Critical) urgStr = "critical";
            else if (notification.urgency === NotificationUrgency.Low) urgStr = "low";

            Quickshell.execDetached([
                Quickshell.configPath("scripts/notification_store.py"),
                "add",
                "--app", (notification.appName || "SYSTEM").toString(),
                "--summary", (notification.summary || "ALERT").toString(),
                "--body", (notification.body || "").toString(),
                "--urgency", urgStr,
                "--icon", (notification.appIcon || "").toString(),
                "--image", (notification.image || "").toString()
            ]);

            var duration = 6500;
            if (notification.expireTimeout > 0) {
                duration = notification.expireTimeout;
            } else if (notification.urgency === NotificationUrgency.Critical) {
                duration = 14000;
            } else if (notification.urgency === NotificationUrgency.Low) {
                duration = 4500;
            }

            var item = {
                id: root.nextPopupId++,
                notification: notification,
                appName: (notification.appName || "TACTICAL ALERT").toUpperCase(),
                summary: notification.summary || "NERV BROADCAST",
                body: notification.body || "",
                appIcon: notification.appIcon || "",
                image: notification.image || "",
                urgency: notification.urgency,
                durationMs: duration
            };

            var list = root.activePopups.slice();
            list.unshift(item); // Newer popups at top
            if (list.length > 5) {
                var dropped = list.pop();
                if (dropped && dropped.notification && typeof dropped.notification.close === "function") {
                    dropped.notification.close();
                }
            }
            root.activePopups = list;
        }
    }

    function dismissPopup(id) {
        var list = [];
        for (var i = 0; i < root.activePopups.length; i++) {
            var p = root.activePopups[i];
            if (p.id === id) {
                if (p.notification && typeof p.notification.close === "function") {
                    p.notification.close();
                }
            } else {
                list.push(p);
            }
        }
        root.activePopups = list;
    }

    // Main Column Container
    ColumnLayout {
        id: popupColumn
        width: parent.width
        spacing: 8

        Repeater {
            model: root.activePopups

            Rectangle {
                id: popupCard
                Layout.fillWidth: true
                height: cardCol.implicitHeight
                color: root.cardBg
                border.width: 1.5
                border.color: modelData.urgency === NotificationUrgency.Critical ? "#ff1a10" : (cardHover.hovered ? root.secondary : root.itemBorder)
                clip: true

                property real duration: modelData.durationMs
                property real progress: 1.0

                transform: [
                    Translate {
                        id: cardTrans
                        x: -24
                    },
                    Rotation {
                        id: cardRotX
                        axis.x: 1; axis.y: 0; axis.z: 0
                        origin.x: popupCard.width / 2; origin.y: popupCard.height / 2
                        angle: 0
                        Behavior on angle { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    },
                    Rotation {
                        id: cardRotY
                        axis.x: 0; axis.y: 1; axis.z: 0
                        origin.x: popupCard.width / 2; origin.y: popupCard.height / 2
                        angle: 0
                        Behavior on angle { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    }
                ]
                opacity: 0.0

                ParallelAnimation {
                    running: true
                    NumberAnimation {
                        target: cardTrans
                        property: "x"
                        from: -24
                        to: 0
                        duration: 200
                        easing.type: Easing.OutExpo
                    }
                    NumberAnimation {
                        target: popupCard
                        property: "opacity"
                        from: 0.0
                        to: 1.0
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }

                HoverHandler {
                    id: cardHover
                    onPointChanged: {
                        if (hovered && popupCard.width > 0 && popupCard.height > 0) {
                            var nx = (point.position.x / popupCard.width) - 0.5;
                            var ny = (point.position.y / popupCard.height) - 0.5;
                            cardRotY.angle = Math.max(-13.0, Math.min(13.0, nx * 16.0));
                            cardRotX.angle = Math.max(-13.0, Math.min(13.0, -ny * 16.0));
                        }
                    }
                    onHoveredChanged: {
                        if (!hovered) {
                            cardRotX.angle = 0;
                            cardRotY.angle = 0;
                        }
                    }
                }

                // Top Specular Highlight Rim
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#ffffff"
                    opacity: cardHover.hovered ? 0.95 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                NumberAnimation on progress {
                    from: 1.0
                    to: 0.0
                    duration: modelData.durationMs
                    running: true
                    paused: cardHover.hovered
                    easing.type: Easing.Linear
                    onFinished: root.dismissPopup(modelData.id)
                }

                Behavior on border.color { ColorAnimation { duration: 120 } }

                ColumnLayout {
                    id: cardCol
                    width: parent.width
                    spacing: 0

                    // Top Hazard Strip
                    NervHazardLines {
                        Layout.fillWidth: true
                        height: 5
                        stripeColor: root.primary
                        bgColor: "#ffffff"
                    }

                    // Notification Header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 22
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            // App Source Tag / Badge
                            Rectangle {
                                width: appNameText.implicitWidth + 8
                                height: 16
                                color: "#ffffff"
                                border.width: 1
                                border.color: root.primary

                                Text {
                                    id: appNameText
                                    anchors.centerIn: parent
                                    text: (modelData.appName || "SYSTEM").toUpperCase()
                                    color: root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }
                            }

                            // Urgency Badge
                            Rectangle {
                                width: urgText.implicitWidth + 8
                                height: 14
                                color: "#ffffff"
                                border.width: 1
                                border.color: root.primary

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Rectangle {
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: root.primary
                                    }
                                    Text {
                                        id: urgText
                                        text: modelData.urgency === NotificationUrgency.Critical ? "CRITICAL" : (modelData.urgency === NotificationUrgency.Low ? "INFO" : "DISPATCH")
                                        color: root.primary
                                        font.family: root.hudFont
                                        font.pixelSize: 6
                                        font.bold: true
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // High-Visibility Close / Dismiss Button [✕]
                            Rectangle {
                                id: closeBtn
                                z: 10
                                width: 22
                                height: 18
                                color: closeMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.primary
                                scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.10 : 1.0)

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: closeMouse.containsMouse ? "#ffffff" : root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.dismissPopup(modelData.id);
                                    }
                                }
                            }
                        }
                    }

                    // Content Area (Image/Icon + Summary + Body)
                    Rectangle {
                        Layout.fillWidth: true
                        height: contentRow.implicitHeight + 16
                        color: "transparent"

                        RowLayout {
                            id: contentRow
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            // Optional App Icon or Notification Image
                            Rectangle {
                                visible: !!modelData.image || !!modelData.appIcon
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
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

                            // Text Column
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.summary
                                    color: modelData.urgency === NotificationUrgency.Critical ? "#ff1100" : root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: !!modelData.body
                                    text: modelData.body
                                    color: "#330000"
                                    font.family: root.hudFont
                                    font.pixelSize: 8
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        // Clicking anywhere in the content area dismisses/activates
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.notification && modelData.notification.actions && modelData.notification.actions.length > 0) {
                                    modelData.notification.actions[0].invoke();
                                }
                                root.dismissPopup(modelData.id);
                            }
                        }
                    }

                    // Action Buttons (if notification has actions)
                    RowLayout {
                        visible: modelData.notification && modelData.notification.actions && modelData.notification.actions.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.bottomMargin: 6
                        spacing: 4

                        Repeater {
                            model: modelData.notification ? modelData.notification.actions : []

                            Rectangle {
                                z: 10
                                Layout.fillWidth: true
                                height: 20
                                color: actBtnMouse.containsMouse ? root.primary : "#ffffff"
                                border.width: 1
                                border.color: root.primary
                                scale: actBtnMouse.pressed ? 0.95 : (actBtnMouse.containsMouse ? 1.03 : 1.0)

                                Behavior on color { ColorAnimation { duration: 100 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.text
                                    color: actBtnMouse.containsMouse ? "#ffffff" : root.primary
                                    font.family: root.hudFont
                                    font.pixelSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    id: actBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.invoke();
                                        root.dismissPopup(popupCard.parent.modelData.id);
                                    }
                                }
                            }
                        }
                    }

                    // Bottom Countdown Progress Line
                    Rectangle {
                        Layout.fillWidth: true
                        height: 2
                        color: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.2)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * Math.max(0.0, Math.min(1.0, popupCard.progress))
                            color: modelData.urgency === NotificationUrgency.Critical ? "#ff1a10" : root.secondary
                        }
                    }
                }
            }
        }
    }
}
