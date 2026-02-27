import QtQuick
import QtQuick.Layouts
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
            
            StyledText { text: "Capture Mode"; font.weight: Font.Bold; color: Theme.surfaceText }
            
            Column {
                width: parent.width
                Repeater {
                    model: [
                        { label: "Interactive", val: "interactive", ic: "touch_app" },
                        { label: "Focused Screen", val: "full", ic: "monitor" },
                        { label: "All Screens", val: "all", ic: "monitor_weight" },
                        { label: "Repeat Last", val: "last", ic: "history" }
                    ]
                    delegate: Rectangle {
                        width: parent.width; height: 44; radius: Theme.cornerRadius
                        color: root.mode === modelData.val ? Theme.withAlpha(Theme.primary, 0.1) : "transparent"
                        
                        RowLayout { 
                            anchors.fill: parent; anchors.margins: Theme.spacingS
                            DankIcon { name: modelData.ic; color: root.mode === modelData.val ? Theme.primary : Theme.surfaceVariantText; size: Theme.iconSize }
                            StyledText { text: modelData.label; color: root.mode === modelData.val ? Theme.primary : Theme.surfaceText; Layout.fillWidth: true }
                            DankIcon { name: "check"; visible: root.mode === modelData.val; color: Theme.primary; size: Theme.iconSize }
                        }
                        MouseArea { 
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { 
                                root.mode = modelData.val; 
                                root.saveSetting("mode", modelData.val);
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
            
            StyledText { text: "Options"; font.weight: Font.Bold; color: Theme.surfaceText }

            // Toggles
            Repeater {
                model: [
                    { t: "Copy to Clipboard", i: "content_copy", k: "copyToClipboard" },
                    { t: "Save to Disk", i: "save", k: "saveToDisk" },
                    { t: "Show Pointer", i: "mouse", k: "showPointer" },
                    { t: "Notification", i: "notifications", k: "showNotify" }
                ]
                delegate: Rectangle {
                    width: parent.width; height: 44; color: "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS
                        DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize }
                        StyledText { text: modelData.t; color: Theme.surfaceText; Layout.fillWidth: true }
                        DankToggle {
                            checked: root[modelData.k]
                            enabled: false 
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root[modelData.k] = !root[modelData.k];
                            root.saveSetting(modelData.k, root[modelData.k]);
                        }
                    }
                }
            }

            // --- Format Selection (Moving Buttons to Next Line) ---
            Column {
                width: parent.width
                spacing: Theme.spacingS
                
                RowLayout {
                    width: parent.width
                    DankIcon { name: "image"; color: Theme.surfaceVariantText; size: Theme.iconSize }
                    StyledText { text: "Image Format"; color: Theme.surfaceText; Layout.fillWidth: true }
                }

                DankButtonGroup {
                    id: formatGroup
                    width: parent.width
                    buttonHeight: 36
                    minButtonWidth: (parent.width / 3) - Theme.spacingS
                    buttonPadding: Theme.spacingM
                    
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

            // Quality Input
            DankTextField {
                visible: root.format === "jpg"
                width: parent.width; height: 40
                text: root.quality.toString()
                placeholderText: "JPEG Quality (1-100)"
                onTextEdited: {
                    var v = parseInt(text);
                    if (!isNaN(v) && v >= 1 && v <= 100) {
                        root.quality = v;
                        root.saveSetting("quality", v);
                    }
                }
            }

            // Path Input
            DankTextField {
                width: parent.width; height: 40
                text: root.customPath
                placeholderText: root.defaultPath
                onTextEdited: {
                    root.customPath = text.trim();
                    root.saveSetting("customPath", root.customPath);
                }
            }
        }
    } 
}