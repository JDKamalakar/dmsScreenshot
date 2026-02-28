import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services

Column {
    id: root
    spacing: Theme.spacingM

    property var pluginService
    property string pluginId: "dmsScreenshot"

    property string mode: "interactive"
    property string targetWindow: ""
    property var windowList: []
    
    property bool showPointer: true
    property bool saveToDisk: true
    property string customPath: ""
    property string defaultPath: ""
    
    property string format: "png"
    property int quality: 90
    property bool copyToClipboard: true
    property bool showNotify: true

    signal saveSetting(string key, var value)

    // Safely fetches Niri windows one by one
    Process {
        id: windowFetcher
        command: ["bash", "-c", "niri msg windows | grep 'Title:' | sed 's/.*Title: \"//;s/\"$//'"]
        running: false
        stdout: SplitParser {
            onRead: function(data) {
                let title = data.trim();
                if (title !== "") {
                    // Update array safely for QML to detect the change
                    let temp = root.windowList.slice();
                    if (temp.indexOf(title) === -1) {
                        temp.push(title);
                        root.windowList = temp;
                    }
                    if (root.targetWindow === "") {
                        root.targetWindow = title;
                        root.saveSetting("targetWindow", title);
                    }
                }
            }
        }
    }

    function refreshWindows() {
        root.windowList = [];
        windowFetcher.running = true;
    }

    function loadSetting(key, defaultValue) {
        if (pluginService) {
             return pluginService.loadPluginData("dmsScreenshot", key, defaultValue);
        }
        return defaultValue;
    }

    Component.onCompleted: {
        root.mode = loadSetting("mode", "interactive");
        root.targetWindow = loadSetting("targetWindow", "");
        root.showPointer = loadSetting("showPointer", true);
        root.saveToDisk = loadSetting("saveToDisk", true);
        root.customPath = loadSetting("customPath", "") || "";
        root.format = loadSetting("format", "png") || "png";
        root.quality = loadSetting("quality", 90);
        root.copyToClipboard = loadSetting("copyToClipboard", true);
        root.showNotify = loadSetting("showNotify", true);
        
        refreshWindows();
    }

    // --- Capture Mode Section ---
    StyledRect {
        width: parent.width
        height: modeColumnCC.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.4)
        
        Column {
            id: modeColumnCC
            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS
            
            RowLayout {
                spacing: Theme.spacingXS
                DankIcon { name: "camera"; size: 14; color: Theme.primary }
                StyledText { text: "Capture Mode"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText }
            }
            
            DankListView {
                id: modeList
                width: parent.width
                // 5 standard mode items (5 * 44) + Window Dropdown Row (88) if visible
                height: 220 + (root.mode === "window" ? 88 : 0)
                interactive: false
                
                model: [
                    { label: "Interactive", val: "interactive", ic: "touch_app", type: "mode" },
                    { label: "Focused Screen", val: "full", ic: "monitor", type: "mode" },
                    { label: "All Screens", val: "all", ic: "monitor_weight", type: "mode" },
                    { label: "Repeat Last", val: "last", ic: "history", type: "mode" },
                    { label: "Specific Window", val: "window", ic: "window", type: "mode" },
                    { label: "Select Window", val: "dropdown", ic: "desktop_windows", type: "dropdown" }
                ]
                
                delegate: Rectangle {
                    id: modeDelegate
                    width: modeList.width
                    
                    height: {
                        if (modelData.type === "dropdown") return root.mode === "window" ? 88 : 0;
                        return 44;
                    }
                    
                    visible: height > 0
                    clip: true // Prevents overlap when height is 0
                    radius: Theme.cornerRadius
                    
                    // Hover and Selected states
                    color: {
                        if (modelData.type === "mode" && root.mode === modelData.val) return Theme.withAlpha(Theme.primary, 0.15);
                        if (modeMouseArea.containsMouse && modelData.type === "mode") return Theme.withAlpha(Theme.surfaceText, 0.06);
                        return "transparent";
                    }
                    
                    DankRipple {
                        id: modeRipple
                        cornerRadius: Theme.cornerRadius
                        rippleColor: Theme.primary
                        visible: modelData.type === "mode"
                    }

                    // 1. UI FOR STANDARD MODES
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingM
                        visible: modelData.type === "mode"
                        DankIcon { name: modelData.ic; color: root.mode === modelData.val ? Theme.primary : Theme.surfaceVariantText; size: Theme.iconSize }
                        StyledText { text: modelData.label; color: root.mode === modelData.val ? Theme.primary : Theme.surfaceText; Layout.fillWidth: true }
                        DankIcon { name: "check"; visible: root.mode === modelData.val; color: Theme.primary; size: Theme.iconSize }
                    }

                    // 2. UI FOR WINDOW DROPDOWN ROW
                    Column {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: 8
                        visible: modelData.type === "dropdown"

                        RowLayout {
                            width: parent.width
                            DankIcon { name: modelData.ic; color: Theme.surfaceVariantText; size: Theme.iconSize }
                            StyledText { text: modelData.label; color: Theme.surfaceText; Layout.fillWidth: true }
                        }

                        DankDropdown {
                            width: parent.width
                            options: root.windowList
                            currentValue: root.targetWindow !== "" ? root.targetWindow : (root.windowList.length > 0 ? root.windowList[0] : "No windows found")
                            onValueChanged: function(value) {
                                root.targetWindow = value;
                                root.saveSetting("targetWindow", value);
                            }
                        }
                    }

                    MouseArea { 
                        id: modeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        // Let clicks pass through to the Dropdown, but capture clicks for standard modes
                        acceptedButtons: modelData.type === "mode" ? Qt.LeftButton : Qt.NoButton
                        cursorShape: modelData.type === "mode" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        
                        onPressed: function(mouse) { 
                            if (modelData.type === "mode") modeRipple.trigger(mouse.x, mouse.y); 
                        }
                        onClicked: { 
                            if (modelData.type === "mode") {
                                root.mode = modelData.val; 
                                root.saveSetting("mode", modelData.val); 
                                if (root.mode === "window") {
                                    root.refreshWindows();
                                }
                            }
                        } 
                    }
                }
            }
        }
    }

    // --- Options Section ---
    StyledRect {
        width: parent.width
        height: optionsColumnCC.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.4)
        
        Column {
            id: optionsColumnCC
            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS
            
            RowLayout {
                spacing: Theme.spacingXS
                DankIcon { name: "settings"; size: 14; color: Theme.primary }
                StyledText { text: "Options"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText }
            }

            DankListView {
                id: optionsList
                width: parent.width
                // 3 Toggles (132) + Format (88) + Path (48) = 268 base. Add 48 for Quality if format is JPG.
                height: 268 + (root.format === "jpg" ? 48 : 0)
                interactive: false
                
                model: [
                    { t: "Copy to Clipboard", i: "content_copy", k: "copyToClipboard", type: "toggle" },
                    { t: "Save to Disk", i: "save", k: "saveToDisk", type: "toggle" },
                    { t: "Show Pointer", i: "mouse", k: "showPointer", type: "toggle" },
                    { t: "Image Format", i: "image", k: "format", type: "format" },
                    { t: "JPEG Quality", i: "high_quality", k: "quality", type: "qualityField" },
                    { t: "Custom Path", i: "folder", k: "customPath", type: "pathField" }
                ]
                
                delegate: Rectangle {
                    id: optDelegate
                    width: optionsList.width
                    
                    height: {
                        if (modelData.type === "format") return 88;
                        if (modelData.type === "qualityField") return root.format === "jpg" ? 48 : 0;
                        if (modelData.type === "pathField") return 48;
                        return 44; 
                    }
                    
                    visible: height > 0
                    clip: true 
                    radius: Theme.cornerRadius
                    color: optMouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent"
                    
                    DankRipple {
                        id: optRipple
                        cornerRadius: Theme.cornerRadius
                        rippleColor: Theme.primary
                        visible: modelData.type === "toggle"
                    }

                    // 1. UI FOR TOGGLES
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingM
                        visible: modelData.type === "toggle"
                        DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize }
                        StyledText { text: modelData.t; color: Theme.surfaceText; Layout.fillWidth: true }
                        DankToggle { 
                            checked: modelData.type === "toggle" ? root[modelData.k] : false
                            enabled: false 
                        }
                    }

                    // 2. UI FOR FORMAT BUTTON GROUP
                    Column {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: 8
                        visible: modelData.type === "format"
                        RowLayout {
                            width: parent.width
                            DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize }
                            StyledText { text: modelData.t; color: Theme.surfaceText; Layout.fillWidth: true }
                        }
                        DankButtonGroup {
                            width: parent.width; buttonHeight: 36; minButtonWidth: 60; checkEnabled: false
                            model: ["PNG", "JPG", "PPM"]
                            currentIndex: root.format === "png" ? 0 : (root.format === "jpg" ? 1 : 2)
                            onSelectionChanged: function(index, selected) {
                                if (selected) {
                                    var fmts = ["png", "jpg", "ppm"];
                                    root.format = fmts[index];
                                    root.saveSetting("format", fmts[index]);
                                }
                            }
                        }
                    }

                    // 3. UI FOR TEXT FIELDS
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 4; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS; spacing: Theme.spacingM
                        visible: modelData.type === "qualityField" || modelData.type === "pathField"

                        DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize }
                        
                        DankTextField {
                            Layout.fillWidth: true
                            height: 40
                            text: modelData.type === "qualityField" ? root.quality.toString() : root.customPath
                            placeholderText: modelData.type === "qualityField" ? "JPEG Quality (1-100)" : root.defaultPath
                            onTextEdited: function() {
                                if (modelData.type === "qualityField") {
                                    var v = parseInt(text);
                                    if (!isNaN(v) && v >= 1 && v <= 100) {
                                        root.quality = v;
                                        root.saveSetting("quality", v);
                                    }
                                } else if (modelData.type === "pathField") {
                                    root.customPath = text.trim();
                                    root.saveSetting("customPath", root.customPath);
                                }
                            }
                        }
                    }

                    MouseArea { 
                        id: optMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        acceptedButtons: modelData.type === "toggle" ? Qt.LeftButton : Qt.NoButton
                        cursorShape: modelData.type === "toggle" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        
                        onPressed: function(mouse) { 
                            if(modelData.type === "toggle") optRipple.trigger(mouse.x, mouse.y); 
                        }
                        onClicked: function(mouse) { 
                            if (modelData.type === "toggle") {
                                root[modelData.k] = !root[modelData.k]; 
                                root.saveSetting(modelData.k, root[modelData.k]); 
                            }
                        } 
                    }
                }
            }
        }
    } 
}