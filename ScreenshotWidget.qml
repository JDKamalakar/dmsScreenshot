import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import QtQuick.Layouts
import QtCore
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
    property int delaySeconds: pluginData.delaySeconds !== undefined ? pluginData.delaySeconds : 0

    // -- Internal ----------------------------------------------------------------------
    property bool isTakingScreenshot: false
    property string defaultPath: ""
    property var _pendingExecCmd: null

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

    Timer {
        id: pendingCaptureTimer
        interval: 0
        repeat: false
        onTriggered: root._fireCapture()
    }

    ccWidgetIcon: "screenshot_region"
    ccWidgetPrimaryText: "Screenshot"
    ccWidgetSecondaryText: _getModeText()
    ccWidgetIsActive: false 
    ccDetailHeight: 480

    function _getModeText() {
        if (root.mode === "interactive") return "Interactive Mode"
        if (root.mode === "full") return "Focused Screen"
        if (root.mode === "all") return "All Screens"
        return "Screenshot"
    }

    // Expands strftime-style date tokens in user-provided path/filename strings.
    // Only tokens whose output is a fixed safe character set ([0-9-:]) are supported,
    // so substitution can never introduce new shell metacharacters. Unknown %X tokens
    // are left as-is.
    function _expandFilenameTemplate(s) {
        if (!s || s.indexOf("%") === -1) return s;
        var d = new Date();
        var pad2 = function(n) { return n < 10 ? "0" + n : "" + n; };
        var pad3 = function(n) { return n < 10 ? "00" + n : (n < 100 ? "0" + n : "" + n); };
        var Y = "" + d.getFullYear();
        var y = pad2(d.getFullYear() % 100);
        var m = pad2(d.getMonth() + 1);
        var day = pad2(d.getDate());
        var H = pad2(d.getHours());
        var M = pad2(d.getMinutes());
        var S = pad2(d.getSeconds());
        var startOfYear = new Date(d.getFullYear(), 0, 0);
        var j = pad3(Math.floor((d - startOfYear) / 86400000));
        var e = "" + Math.floor(d.getTime() / 1000);
        return s.replace(/%(.)/g, function(match, t) {
            if (t === "Y") return Y;
            if (t === "y") return y;
            if (t === "m") return m;
            if (t === "d") return day;
            if (t === "H") return H;
            if (t === "M") return M;
            if (t === "S") return S;
            if (t === "j") return j;
            if (t === "e") return e;
            if (t === "F") return Y + "-" + m + "-" + day;
            if (t === "T") return H + ":" + M + ":" + S;
            if (t === "%") return "%";
            return match;
        });
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
            root.delaySeconds = parseInt(PluginService.loadPluginData("dmsScreenshot", "delaySeconds", 0)) || 0;
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
        if (root.filename) dmsStr += " --filename \"" + root._expandFilenameTemplate(root.filename) + "\"";

        dmsStr += " -f " + root.format;
        if (root.format === "jpg") dmsStr += " -q " + root.quality;

        if (root.saveToDisk && root.customPath) {
            const expandedPath = root._expandFilenameTemplate(root.customPath);
            if (!expandedPath.match(/\.(png|jpe?g|ppm)$/i)) {
                dmsStr += " --dir \"" + expandedPath + "\"";
            } else {
                dmsStr += " --filename \"" + expandedPath + "\"";
            }
        }

        if (root.stdout && root.pipeCommand) {
            dmsStr += " | " + root.pipeCommand;
        }

        execCmd = ["bash", "-c", "sleep 0.3; " + dmsStr];

        root._pendingExecCmd = execCmd;

        const useDelay = root.delaySeconds > 0;
        if (useDelay) {
            pendingCaptureTimer.interval = root.delaySeconds * 1000;
            pendingCaptureTimer.start();
        } else {
            root._fireCapture();
        }
    }

    function _fireCapture() {
        if (root._pendingExecCmd) {
            Quickshell.execDetached(root._pendingExecCmd);
            root._pendingExecCmd = null;
        }
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

            Loader {
                width: parent.width
                asynchronous: true
                sourceComponent: ccDetailInternal
                
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 20 } }
            }
        }
    }

    Component {
        id: ccDetailInternal
        Column {
            id: ccDetailCol
            width: parent.width
            padding: 16
            spacing: Theme.spacingM

            // --- Capture Header Card ---
            StyledRect {
                width: parent.width - 32; anchors.horizontalCenter: parent.horizontalCenter; height: 72
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                RowLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                    Rectangle {
                        width: 42; height: 42; radius: 21
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                        DankIcon { name: "screenshot_region"; size: 24; color: Theme.surfaceText; anchors.centerIn: parent }
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
                    Item {
                        id: captureBtnCC
                        height: 38; width: 110
                        Layout.alignment: Qt.AlignVCenter
                        
                        scale: captureAreaCC.pressed ? 0.9 : (captureAreaCC.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        MouseArea {
                            id: captureAreaCC
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => captureRippleCC.trigger(mouse.x, mouse.y)
                            onClicked: {
                                root.takeScreenshot();
                                if (typeof PopoutService !== "undefined" && PopoutService)
                                    PopoutService.closeControlCenter();
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: captureAreaCC.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                            border.width: 1
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, captureAreaCC.containsMouse ? 0.3 : 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            DankIcon {
                                id: captureBtnIconCC
                                name: "screenshot_region"
                                size: 18
                                color: Theme.primary
                                
                                SequentialAnimation {
                                    running: captureAreaCC.containsMouse
                                    loops: Animation.Infinite
                                    onStopped: captureBtnIconCC.rotation = 0
                                    NumberAnimation { target: captureBtnIconCC; property: "rotation"; to: -8; duration: 150; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: captureBtnIconCC; property: "rotation"; to: 8; duration: 150; easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: captureBtnIconCC; property: "rotation"; to: 0; duration: 150; easing.type: Easing.InOutQuad }
                                    PauseAnimation { duration: 400 }
                                }
                            }
                            
                            StyledText {
                                text: "Capture"
                                color: Theme.primary
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        DankRipple {
                            id: captureRippleCC
                            rippleColor: Theme.surfaceText
                            cornerRadius: Theme.cornerRadius
                            anchors.fill: parent
                        }
                    }
                }
            }

            // --- Settings Form ---
            ScreenshotSettingsForm {
                id: settingsColumnCC
                width: parent.width - 32; anchors.horizontalCenter: parent.horizontalCenter

                pluginService: typeof PluginService !== "undefined" ? PluginService : null
                pluginId: "dmsScreenshot"
                defaultPath: root.defaultPath
                
                mode: root.mode
                showPointer: root.showPointer
                saveToDisk: root.saveToDisk
                customPath: root.customPath
                format: root.format
                quality: root.quality
                copyToClipboard: root.copyToClipboard
                showNotify: root.showNotify
                stdout: root.stdout
                pipeCommand: root.pipeCommand
                delaySeconds: root.delaySeconds
                
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
                    if (key === "delaySeconds") root.delaySeconds = value;

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

            Loader {
                width: parent.width
                asynchronous: false
                sourceComponent: popoutInternal
                
                opacity: status === Loader.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }
    }

    Component {
        id: popoutInternal
        Column {
            id: popoutMainCol
            width: parent.width
            topPadding: 0
            bottomPadding: 2
            spacing: Theme.spacingM

                // --- Capture Header Card ---
                StyledRect {
                    width: parent.width; anchors.horizontalCenter: parent.horizontalCenter; height: 72
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                        Rectangle {
                            width: 42; height: 42; radius: 21
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            DankIcon { name: "screenshot_region"; size: 24; color: Theme.surfaceText; anchors.centerIn: parent }
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
                        Item {
                            id: captureBtnPop
                            height: 38; width: 105
                            Layout.alignment: Qt.AlignVCenter
                            
                            scale: captureAreaPop.pressed ? 0.9 : (captureAreaPop.containsMouse ? 1.05 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            MouseArea {
                                id: captureAreaPop
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => captureRipplePop.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    root.closePopout();
                                    root.takeScreenshot();
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: captureAreaPop.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, captureAreaPop.containsMouse ? 0.3 : 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                
                                DankIcon {
                                    id: captureBtnIconPop
                                    name: "screenshot_region"
                                    size: 18
                                    color: Theme.primary
                                    
                                    SequentialAnimation {
                                        running: captureAreaPop.containsMouse
                                        loops: Animation.Infinite
                                        onStopped: captureBtnIconPop.rotation = 0
                                        NumberAnimation { target: captureBtnIconPop; property: "rotation"; to: -8; duration: 150; easing.type: Easing.InOutQuad }
                                        NumberAnimation { target: captureBtnIconPop; property: "rotation"; to: 8; duration: 150; easing.type: Easing.InOutQuad }
                                        NumberAnimation { target: captureBtnIconPop; property: "rotation"; to: 0; duration: 150; easing.type: Easing.InOutQuad }
                                        PauseAnimation { duration: 400 }
                                    }
                                }
                                
                                StyledText {
                                    text: "Capture"
                                    color: Theme.primary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            DankRipple {
                                id: captureRipplePop
                                rippleColor: Theme.surfaceText
                                cornerRadius: Theme.cornerRadius
                                anchors.fill: parent
                            }
                        }
                    }
                }

                // --- Settings Form ---
                ScreenshotSettingsForm {
                    width: parent.width; anchors.horizontalCenter: parent.horizontalCenter

                    pluginService: typeof PluginService !== "undefined" ? PluginService : null
                    pluginId: "dmsScreenshot"
                    defaultPath: root.defaultPath
                    
                    mode: root.mode
                    showPointer: root.showPointer
                    saveToDisk: root.saveToDisk
                    customPath: root.customPath
                    format: root.format
                    quality: root.quality
                    copyToClipboard: root.copyToClipboard
                    showNotify: root.showNotify
                    stdout: root.stdout
                    pipeCommand: root.pipeCommand
                    delaySeconds: root.delaySeconds
                    
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
                        if (key === "delaySeconds") root.delaySeconds = value;

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
