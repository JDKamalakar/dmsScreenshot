import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts
import QtCore
import Qt5Compat.GraphicalEffects
import QtQuick.Controls

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
        ScrollView {
            width: parent.width
            height: parent.height
            clip: false
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Column {
                id: ccDetailCol
                width: parent.width
            spacing: Theme.spacingM

            // --- Capture Header Card ---
            StyledRect {
                width: parent.width; height: 68
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true; horizontalOffset: 0; verticalOffset: 3
                    radius: 12.0; samples: 24
                    color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                }
                RowLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                        DankIcon { name: "screenshot_region"; size: 20; color: Theme.surfaceText; anchors.centerIn: parent }
                    }
                    Column {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 0
                        StyledText { text: "Screenshot"; font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText }
                        Item {
                            width: parent.width; height: 16
                            StyledText {
                                id: modeTxtCC
                                width: parent.width
                                text: root._getModeText()
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.primary
                                opacity: 0.85

                                onTextChanged: subtitleAnimCC.restart()
                                SequentialAnimation {
                                    id: subtitleAnimCC
                                    ParallelAnimation {
                                        NumberAnimation { target: modeTxtCC; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: modeTxtCC; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                                    }
                                    PropertyAction { target: modeTxtCC; property: "y"; value: -5 }
                                    ParallelAnimation {
                                        NumberAnimation { target: modeTxtCC; property: "opacity"; to: 0.85; duration: 150; easing.type: Easing.InQuad }
                                        NumberAnimation { target: modeTxtCC; property: "y"; to: 0; duration: 150; easing.type: Easing.InQuad }
                                    }
                                }
                            }
                        }
                    }
                    DankButton {
                        id: captureBtnCC
                        height: 36; width: 130
                        text: "" // Using manual Row for perfect alignment and animation
                        
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            DankIcon {
                                id: captureBtnIconCC
                                name: "screenshot_region"
                                size: 18
                                color: "white"
                                
                                SequentialAnimation on rotation {
                                    running: captureBtnCC.hovered
                                    loops: Animation.Infinite
                                    NumberAnimation { to: -8; duration: 150; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 8; duration: 150; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 0; duration: 150; easing.type: Easing.InOutQuad }
                                    PauseAnimation { duration: 400 }
                                }
                            }
                            
                            StyledText {
                                text: "Capture"
                                color: "white"
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        onClicked: {
                            root.takeScreenshot();
                            if (typeof PopoutService !== "undefined" && PopoutService)
                                PopoutService.closeControlCenter();
                        }
                        
                        onHoveredChanged: if (hovered) root.showTooltip(root._getModeText(), captureBtnCC)
                    }
                }
            }

            // --- Settings Form ---
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
                        if (typeof PluginService !== "undefined" && PluginService)
                            PluginService.savePluginData("dmsScreenshot", key, value);
                        else if (root.pluginService)
                            root.pluginService.savePluginData("dmsScreenshot", key, value);
                    } catch (e) {
                        console.error("ScreenshotWidget: Save error:", e);
                    }
                } // function
            } // ScreenshotSettingsForm
        } // Column
        } // ScrollView
    } // Component

    // -- Popout Settings ----------------------------------------------------------------
    popoutWidth: 340
    popoutHeight: 0

    popoutContent: Component {
        PopoutComponent {
            id: detailPopout
            headerText: ""
            detailsText: ""
            showCloseButton: false

            Column {
                id: popoutMainCol
                width: parent.width
                spacing: Theme.spacingM
                topPadding: 0; bottomPadding: 2

                // --- Capture Header Card ---
                StyledRect {
                    width: parent.width; height: 68
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true; horizontalOffset: 0; verticalOffset: 3
                        radius: 12.0; samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            DankIcon { name: "screenshot_region"; size: 22; color: Theme.surfaceText; anchors.centerIn: parent }
                        }
                        Column {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 0
                            StyledText { text: "Screenshot"; font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText }
                            Item {
                                width: parent.width; height: 16
                                StyledText {
                                    id: modeTxtPop
                                    width: parent.width
                                    text: root._getModeText()
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.primary
                                    opacity: 0.85

                                    onTextChanged: subtitleAnimPop.restart()
                                    SequentialAnimation {
                                        id: subtitleAnimPop
                                        ParallelAnimation {
                                            NumberAnimation { target: modeTxtPop; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: modeTxtPop; property: "y"; to: 5; duration: 150; easing.type: Easing.OutQuad }
                                        }
                                        PropertyAction { target: modeTxtPop; property: "y"; value: -5 }
                                        ParallelAnimation {
                                            NumberAnimation { target: modeTxtPop; property: "opacity"; to: 0.85; duration: 200; easing.type: Easing.InQuad }
                                            NumberAnimation { target: modeTxtPop; property: "y"; to: 0; duration: 200; easing.type: Easing.InQuad }
                                        }
                                    }
                                }
                            }
                        }
                        DankButton {
                            id: captureBtnPop
                            height: 36; width: 120
                            text: "" // Using manual Row for perfect alignment and animation

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                
                                DankIcon {
                                    id: captureBtnIconPop
                                    name: "screenshot_region"
                                    size: 18
                                    color: "white"
                                    
                                    SequentialAnimation on rotation {
                                        running: captureBtnPop.hovered
                                        loops: Animation.Infinite
                                        NumberAnimation { to: -8; duration: 150; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 8; duration: 150; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 0; duration: 150; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 400 }
                                    }
                                }
                                
                                StyledText {
                                    text: "Capture"
                                    color: "white"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            onClicked: {
                                root.closePopout();
                                root.takeScreenshot();
                            }
                            
                            onHoveredChanged: if (hovered) root.showTooltip(root._getModeText(), captureBtnPop)
                        }
                    }
                }

                // --- Settings Form ---
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
                            if (typeof PluginService !== "undefined" && PluginService)
                                PluginService.savePluginData("dmsScreenshot", key, value);
                            else if (root.pluginService)
                                root.pluginService.savePluginData("dmsScreenshot", key, value);
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