pragma Singleton
import QtQuick

QtObject {
    id: root

    // Central HUD Identity / Branding Prefix (e.g. "EVA-02", "EVA-01", "NERV", "WILLE")
    property string hudBranding: "EVA-02"

    property bool crtEnabled: true
    property bool rgbAberrationEnabled: false
    property bool hexHudEnabled: true

    // Dynamic System Paths
    readonly property string homeDir: Quickshell.env("HOME") || "/home"
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (homeDir + "/.config")
    readonly property string evangelionDir: Quickshell.configPath("")
    readonly property string scriptsDir: Quickshell.configPath("scripts")
    readonly property string assetsDir: Quickshell.configPath("assets")
    readonly property string downloadsDir: homeDir + "/Downloads"
    readonly property string picturesDir: homeDir + "/Pictures"
}
