import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool isLocked: false

    function lock() {
        root.isLocked = true;
    }

    function unlock() {
        root.isLocked = false;
    }

    function toggle() {
        root.isLocked = !root.isLocked;
    }

    WlSessionLock {
        id: sessionLock
        locked: root.isLocked

        surface: Component {
            WlSessionLockSurface {
                id: lockSurface

                LockScreenContent {
                    anchors.fill: parent
                    onUnlockRequested: root.unlock()
                }
            }
        }
    }

    IpcHandler {
        target: "lockscreen"

        function lock() {
            root.lock();
        }

        function unlock() {
            root.unlock();
        }

        function toggle() {
            root.toggle();
        }
    }
}
