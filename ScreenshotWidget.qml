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
    
    // New DMS Settings
    property string format: pluginData.format || "png"
    property int quality: pluginData.quality !== undefined ? pluginData.quality : 90
    property bool copyToClipboard: pluginData.copyToClipboard !== undefined ? pluginData.copyToClipboard : true
    property bool showNotify: pluginData.showNotify !== undefined ? pluginData.showNotify : true
    property bool showToast: pluginData.showToast !== undefined ? pluginData.showToast : true
    property bool stdout: pluginData.stdout !== undefined ? pluginData.stdout : false
    property string pipeCommand: pluginData.pipeCommand || ""
    property string filename: pluginData.filename || ""

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

    ccWidgetIcon: "screenshot_region"
    ccWidgetPrimaryText: "Screenshot"
    ccWidgetSecondaryText: _getModeText()
    ccWidgetIsActive: false 

    function _getModeText() {
        if (root.mode === "interactive") return "Interactive Mode"
        if (root.mode === "full") return "Focused Screen"
        if (root.mode === "all") return "All Screens"
        if (root.mode === "last") return "Repeat Last"
        return "Screenshot"
    }

    onCcWidgetToggled: {
        takeScreenshot();
        if (typeof PopoutService !== "undefined" && PopoutService) {
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
            root.format = PluginService.loadPluginData("dmsScreenshot", "format", "png") || "png";
            root.quality = PluginService.loadPluginData("dmsScreenshot", "quality", 90);
            root.copyToClipboard = PluginService.loadPluginData("dmsScreenshot", "copyToClipboard", true);
            root.showNotify = PluginService.loadPluginData("dmsScreenshot", "showNotify", true);
            root.showToast = PluginService.loadPluginData("dmsScreenshot", "showToast", true);
            root.stdout = PluginService.loadPluginData("dmsScreenshot", "stdout", false);
            root.pipeCommand = PluginService.loadPluginData("dmsScreenshot", "pipeCommand", "") || "";
            root.filename = PluginService.loadPluginData("dmsScreenshot", "filename", "") || "";
        }

        let dmsStr = "";
        let execCmd;
        if (root.mode === "interactive") {
            dmsStr = "dms screenshot";
        } else {
            dmsStr = "dms screenshot " + root.mode;
        }

        if (root.showPointer) dmsStr += " --cursor on";
        if (!root.saveToDisk) dmsStr += " --no-file";
        if (!root.copyToClipboard) dmsStr += " --no-clipboard";
        if (!root.showNotify) dmsStr += " --no-notify";
        if (root.stdout) dmsStr += " --stdout";
        if (root.filename) dmsStr += " --filename \"" + root.filename + "\"";
        
        dmsStr += " -f " + root.format;
        if (root.format === "jpg") dmsStr += " -q " + root.quality;

        if (root.saveToDisk && root.customPath) {
            if (!root.customPath.match(/\.(png|jpe?g|ppm)$/i)) {
                dmsStr += " --dir \"" + root.customPath + "\"";
            } else {
                dmsStr += " --filename \"" + root.customPath + "\"";
            }
        }

        if (root.stdout && root.pipeCommand) {
            dmsStr += " | " + root.pipeCommand;
        }

        if (root.mode === "interactive") {
            execCmd = ["bash", "-c", dmsStr];
        } else {
            execCmd = ["bash", "-c", "sleep 0.3; " + dmsStr];
        }

        Quickshell.execDetached(execCmd);
        root.isTakingScreenshot = false;
        
        if (root.showToast && typeof ToastService !== "undefined") {
            ToastService.showInfo("Screenshot", "Screenshot triggered");
        }
    }

    // -- CC Detail Settings -------------------------------------------------------------
    ccDetailContent: Component {
        Rectangle {
            implicitHeight: 450
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            DankButton {
                id: captureBtn
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                height: 32
                width: 110
                text: "Capture"
                iconName: "screenshot_region"
                onClicked: {
                    root.takeScreenshot();
                    if (typeof PopoutService !== "undefined" && PopoutService) {
                        PopoutService.closeControlCenter();
                    }
                }
            }

            DankFlickable {
                anchors.top: captureBtn.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                contentHeight: settingsColumnCC.height
                clip: true

                ScreenshotSettingsForm {
                    id: settingsColumnCC
                    width: parent.width
                    
                    pluginService: typeof PluginService !== "undefined" ? PluginService : null
                    pluginId: "dmsScreenshot"
                    defaultPath: root.defaultPath
                    onSaveSetting: function(key, value) {
                        if (key === "mode") root.mode = value;
                        if (key === "showPointer") root.showPointer = value;
                        if (key === "saveToDisk") root.saveToDisk = value;
                        if (key === "customPath") root.customPath = value;
                        if (key === "format") root.format = value;
                        if (key === "quality") root.quality = value;
                        if (key === "copyToClipboard") root.copyToClipboard = value;
                        if (key === "showNotify") root.showNotify = value;
                        if (key === "stdout") root.stdout = value;
                        if (key === "pipeCommand") root.pipeCommand = value;
                        if (key === "filename") root.filename = value;

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
                    
                    pluginService: typeof PluginService !== "undefined" ? PluginService : null
                    pluginId: "dmsScreenshot"
                    defaultPath: root.defaultPath
                    onSaveSetting: function(key, value) {
                        if (key === "mode") root.mode = value;
                        if (key === "showPointer") root.showPointer = value;
                        if (key === "saveToDisk") root.saveToDisk = value;
                        if (key === "customPath") root.customPath = value;
                        if (key === "format") root.format = value;
                        if (key === "quality") root.quality = value;
                        if (key === "copyToClipboard") root.copyToClipboard = value;
                        if (key === "showNotify") root.showNotify = value;
                        if (key === "stdout") root.stdout = value;
                        if (key === "pipeCommand") root.pipeCommand = value;
                        if (key === "filename") root.filename = value;

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