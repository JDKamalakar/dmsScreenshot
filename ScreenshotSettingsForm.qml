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
    
    property bool showPointer: true
    property bool saveToDisk: true
    property string customPath: ""
    property string defaultPath: ""
    
    property string format: "png"
    property int quality: 90
    property bool copyToClipboard: true
    property bool showNotify: true
    property bool stdout: false
    property string pipeCommand: ""
    property string output: "" (deprecated)

    signal saveSetting(string key, var value)

    function loadSetting(key, defaultValue) {
        if (pluginService) {
             return pluginService.loadPluginData("dmsScreenshot", key, defaultValue);
        }
        return defaultValue;
    }

    Component.onCompleted: {
        root.mode = loadSetting("mode", "interactive");
        root.showPointer = loadSetting("showPointer", true);
        root.saveToDisk = loadSetting("saveToDisk", true);
        root.customPath = loadSetting("customPath", "") || "";
        root.format = loadSetting("format", "png") || "png";
        root.quality = loadSetting("quality", 90);
        root.copyToClipboard = loadSetting("copyToClipboard", true);
        root.showNotify = loadSetting("showNotify", true);
        root.stdout = loadSetting("stdout", false);
        root.pipeCommand = loadSetting("pipeCommand", "") || "";
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
                height: 176 
                interactive: false
                
                model: [
                    { label: "Interactive", val: "interactive", ic: "touch_app" },
                    { label: "Focused Screen", val: "full", ic: "monitor" },
                    { label: "All Screens", val: "all", ic: "monitor_weight" },
                    { label: "Repeat Last", val: "last", ic: "history" }
                ]
                
                delegate: Rectangle {
                    id: modeDelegate
                    width: modeList.width
                    height: 44
                    radius: Theme.cornerRadius
                    
                    color: {
                        if (root.mode === modelData.val) return Theme.withAlpha(Theme.primary, 0.15);
                        if (modeMouseArea.containsMouse) return Theme.withAlpha(Theme.surfaceText, 0.06);
                        return "transparent";
                    }
                    
                    DankRipple {
                        id: modeRipple
                        cornerRadius: Theme.cornerRadius
                        rippleColor: Theme.primary
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingM
                        DankIcon { name: modelData.ic; color: root.mode === modelData.val ? Theme.primary : Theme.surfaceVariantText; size: Theme.iconSize }
                        StyledText { text: modelData.label; color: root.mode === modelData.val ? Theme.primary : Theme.surfaceText; Layout.fillWidth: true }
                        DankIcon { name: "check"; visible: root.mode === modelData.val; color: Theme.primary; size: Theme.iconSize }
                    }

                    MouseArea { 
                        id: modeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onWheel: function(wheel) { wheel.accepted = false; }
                        onPressed: function(mouse) { modeRipple.trigger(mouse.x, mouse.y); }
                        onClicked: { 
                            root.mode = modelData.val; 
                            root.saveSetting("mode", modelData.val); 
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

        Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }
        
        Column {
            id: optionsColumnCC
            anchors.top: parent.top
            anchors.left: parent.left; anchors.right: parent.right
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
                height: 312 + (root.format === "jpg" ? 48 : 0)
                interactive: false
                currentIndex: -1

                Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }
                
                model: [
                    { t: "Copy to Clipboard", i: "content_copy", k: "copyToClipboard", type: "toggle" },
                    { t: "Save to Disk", i: "save", k: "saveToDisk", type: "toggle" },
                    { t: "Show Pointer", i: "mouse", k: "showPointer", type: "toggle" },
                    { t: "Screenshot Editor", i: "output", k: "stdout", type: "toggle" },
                    { t: "Image Format", i: "image", k: "format", type: "format" },
                    { t: "JPEG Quality", i: "high_quality", k: "quality", type: "qualityField" },
                    { t: "Custom Directory", i: "folder", k: "customPath", type: "pathField" }
                ]
                
                delegate: Rectangle {
                    id: optDelegate
                    width: optionsList.width
                    
                    height: {
                        if (modelData.type === "format") return 88;
                        if (modelData.type === "qualityField") return root.format === "jpg" ? 48 : 0;
                        if (modelData.type === "pathField" || modelData.type === "textField") return 48;
                        return 44; 
                    }

                    Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }
                    
                    visible: height > 0
                    opacity: height > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

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
                            enabled: true 
                            opacity: 1.0
                        }
                    }

                    // 2. UI FOR FORMAT BUTTON GROUP (Aligned to match toggles)
                    Column {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: 8
                        visible: modelData.type === "format"
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingM // Unified gap
                            DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize } // Standard size
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

                    // 3. UI FOR TEXT FIELDS (Aligned icons and gap)
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingM
                        visible: modelData.type === "qualityField" || modelData.type === "pathField" || modelData.type === "textField"

                        DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize } // Standard size
                        
                        DankTextField {
                            Layout.fillWidth: true
                            height: 40
                            text: {
                                if (modelData.type === "qualityField") return root.quality.toString();
                                if (modelData.type === "pathField") return root.customPath;
                                return root[modelData.k];
                            }
                            placeholderText: {
                                if (modelData.type === "qualityField") return "JPEG Quality (1-100)";
                                if (modelData.type === "pathField") return root.defaultPath;
                                return modelData.placeholder || "";
                            }
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
                                } else if (modelData.type === "textField") {
                                    root[modelData.k] = text.trim();
                                    root.saveSetting(modelData.k, root[modelData.k]);
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
                        onWheel: function(wheel) { wheel.accepted = false; }
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