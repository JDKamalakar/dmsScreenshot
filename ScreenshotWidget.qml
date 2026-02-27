import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts
import QtCore

PluginComponent {
    id: root

    // -- Settings ----------------------------------------------------------------------
    property string mode: pluginData.mode || "interactive"
    property bool showPointer: pluginData.showPointer !== undefined ? pluginData.showPointer : true
    property bool saveToDisk: pluginData.saveToDisk !== undefined ? pluginData.saveToDisk : true
    property string customPath: pluginData.customPath || ""

    // -- Internal ----------------------------------------------------------------------
    property bool isTakingScreenshot: false
    property string defaultPath: ""

    Process {
        id: defaultPathDetector
        command: ["bash", "-c", "dir=$(xdg-user-dir PICTURES 2>/dev/null); if [ -n \"$dir\" ]; then echo \"${dir/#$HOME/~}\"; else echo \"~/Pictures\"; fi"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() !== "") {
                    root.defaultPath = data.trim();
                }
            }
        }
    }

    // Control Center Widget Properties
    ccWidgetIcon: "screenshot_region"
    ccWidgetPrimaryText: "Screenshot"
    ccWidgetSecondaryText: _getModeText()
    ccWidgetIsActive: false // Stateless action, so always inactive/ready

    function _getModeText() {
        if (root.mode === "interactive") return "Interactive Mode"
        if (root.mode === "full") return "Focused Screen"
        if (root.mode === "all") return "All Screens"
        return "Screenshot"
    }

    onCcWidgetToggled: {
        takeScreenshot();
        if (PopoutService) {
            PopoutService.closeControlCenter();
        }
    }

    function takeScreenshot() {
        if (root.isTakingScreenshot) return;
        root.isTakingScreenshot = true;

        if (typeof PluginService !== "undefined" && PluginService) {
            root.mode = PluginService.loadPluginData("dmsScreenshot", "mode", "interactive") || "interactive";
            root.showPointer = PluginService.loadPluginData("dmsScreenshot", "showPointer", true);
            root.saveToDisk = PluginService.loadPluginData("dmsScreenshot", "saveToDisk", true);
            root.customPath = PluginService.loadPluginData("dmsScreenshot", "customPath", "") || "";
        }

        let execCmd;

        if (root.mode === "interactive") {
            execCmd = ["dms", "screenshot"];
            if (root.showPointer) execCmd.push("--cursor", "on");
            if (!root.saveToDisk) execCmd.push("--no-file");
            else if (root.customPath) {
                if (!root.customPath.match(/\.(png|jpe?g)$/i)) {
                    execCmd.push("--dir", root.customPath);
                } else {
                    execCmd.push("--filename", root.customPath);
                }
            }
        } else {
            let dmsStr = "dms screenshot " + root.mode;
            if (root.showPointer) dmsStr += " --cursor on";
            if (!root.saveToDisk) dmsStr += " --no-file";
            else if (root.customPath) {
                if (!root.customPath.match(/\.(png|jpe?g)$/i)) {
                    dmsStr += " --dir \"" + root.customPath + "\"";
                } else {
                    dmsStr += " --filename \"" + root.customPath + "\"";
                }
            }
            execCmd = ["sh", "-c", "sleep 0.3; " + dmsStr];
        }

        Quickshell.execDetached(execCmd);
        root.isTakingScreenshot = false;
    }

    // -- CC Detail Settings -------------------------------------------------------------
    ccDetailContent: Component {
        Rectangle {
            implicitHeight: 450
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            
            StyledText {
                id: settingsHeader
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
                font.weight: Font.Medium
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Theme.spacingM
                text: "Screenshot"
            }

            DankButton {
                id: captureBtn
                anchors.right: parent.right
                anchors.verticalCenter: settingsHeader.verticalCenter
                anchors.rightMargin: Theme.spacingM
                height: 32
                width: 110
                text: "Capture"
                iconName: "screenshot_region"
                onClicked: {
                    root.takeScreenshot();
                    if (PopoutService) {
                        PopoutService.closeControlCenter();
                    }
                }
            }

            DankFlickable {
                anchors.top: settingsHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                contentHeight: settingsColumnCC.height
                clip: true

                ScreenshotSettingsForm {
                    id: settingsColumnCC
                    width: parent.width
                    
                    pluginService: PluginService
                    pluginId: "dmsScreenshot"
                    defaultPath: root.defaultPath
                    onSaveSetting: function(key, value) {
                        if (key === "mode") root.mode = value;
                        if (key === "showPointer") root.showPointer = value;
                        if (key === "saveToDisk") root.saveToDisk = value;
                        if (key === "customPath") root.customPath = value;

                        try {
                            if (typeof PluginService !== "undefined" && PluginService) {
                                 PluginService.savePluginData("dmsScreenshot", key, value);
                            } else if (root.pluginService) {
                                 root.pluginService.savePluginData("dmsScreenshot", key, value);
                            }
                        } catch (e) {
                            console.error("ScreenshotWidget: Save error:", e);
                        }
                    }
                }
            }
        }
    }

    // -- Popout Settings ----------------------------------------------------------------
    popoutWidth: 320
    popoutHeight: 450
    
    popoutContent: Component {
        PopoutComponent {
            id: detailPopout
            
            Column {
                width: parent.width
                spacing: Theme.spacingM

                DankButton {
                    text: "Capture"
                    width: parent.width
                    height: 36
                    iconName: "screenshot_region"
                    onClicked: {
                        root.closePopout();
                        root.takeScreenshot();
                    }
                }

                ScreenshotSettingsForm {
                    width: parent.width
                    
                    pluginService: PluginService
                    pluginId: "dmsScreenshot"
                    defaultPath: root.defaultPath
                    onSaveSetting: function(key, value) {
                        if (key === "mode") root.mode = value;
                        if (key === "showPointer") root.showPointer = value;
                        if (key === "saveToDisk") root.saveToDisk = value;
                        if (key === "customPath") root.customPath = value;

                        try {
                            if (typeof PluginService !== "undefined" && PluginService) {
                                 PluginService.savePluginData("dmsScreenshot", key, value);
                            } else if (root.pluginService) {
                                 root.pluginService.savePluginData("dmsScreenshot", key, value);
                            }
                        } catch (e) {
                            console.error("ScreenshotWidget: Popout save error:", e);
                        }
                    }
                }
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "screenshot_region"
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: "screenshot_region"
                size: Theme.barIconSize(root.barThickness, -4)
                color: Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}