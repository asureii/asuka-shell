import QtQuick
import QtQuick.Controls
import "modules/lockscreen"

Window {
    id: win
    visible: true
    width: 1280
    height: 720
    title: "EVA LOCKSCREEN // TEST PREVIEW"

    LockScreenContent {
        anchors.fill: parent
        isTestMode: true
        onUnlockRequested: win.close()
    }
}
