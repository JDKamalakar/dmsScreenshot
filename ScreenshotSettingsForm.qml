import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import Qt5Compat.GraphicalEffects

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
    property string output: "" // (deprecated)

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
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true; horizontalOffset: 0; verticalOffset: 3
            radius: 12.0; samples: 24
            color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
        }

        Column {
            id: modeColumnCC
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 4; anchors.rightMargin: 4
                spacing: Theme.spacingXS
                DankIcon { name: "camera"; size: 14; color: Theme.surfaceText }
                StyledText { text: "Capture Mode"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            }

            DankListView {
                id: modeList
                width: parent.width
                height: 188
                interactive: false
                spacing: 4

                model: [
                    { label: "Interactive",    val: "interactive", ic: "touch_app"     },
                    { label: "Focused Screen", val: "full",        ic: "monitor"       },
                    { label: "All Screens",    val: "all",         ic: "monitor_weight"},
                    { label: "Repeat Last",    val: "last",        ic: "history"       }
                ]

                delegate: Item {
                    id: modeDelegate
                    width: modeList.width
                    height: 44
                    readonly property bool isSelected: root.mode === modelData.val
                    readonly property bool hovered: modeMouseArea.containsMouse
                    readonly property int  totalCount: 4   // fixed 4 items

                    // Dynamic background with animated radius and colors
                    Rectangle {
                        id: modeBg
                        anchors.fill: parent
                        
                        // Large uniform radius when selected, otherwise adaptive but smaller
                        radius: isSelected ? 22 : 6
                        
                        color: isSelected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : hovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                        
                        border.width: 1
                        border.color: isSelected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                            : hovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                        
                        // Smooth transitions for all properties
                        Behavior on radius       { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
                        Behavior on color        { ColorAnimation  { duration: 200 } }
                        Behavior on border.color { ColorAnimation  { duration: 200 } }

                        Rectangle { 
                            anchors.fill: parent; radius: parent.radius; color: "white"
                            opacity: hovered ? 0.05 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } 
                        }
                    }

                    DankRipple { id: modeRipple; cornerRadius: isSelected ? 22 : 6; rippleColor: Theme.primary }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingM
                        DankIcon { 
                            name: modelData.ic
                            color: isSelected ? Theme.primary : Theme.surfaceVariantText
                            size: Theme.iconSize
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        StyledText { 
                            text: modelData.label
                            color: isSelected ? Theme.primary : Theme.surfaceText
                            font.bold: isSelected
                            Layout.fillWidth: true
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        DankIcon { 
                            name: "check"
                            color: Theme.primary
                            size: Theme.iconSize
                            opacity: isSelected ? 1 : 0
                            scale: isSelected ? 1 : 0.5
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on scale   { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                        }
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
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true; horizontalOffset: 0; verticalOffset: 3
            radius: 12.0; samples: 24
            color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
        }

        Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }

        Column {
            id: optionsColumnCC
            anchors.top: parent.top
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 4; anchors.rightMargin: 4
                spacing: Theme.spacingXS
                DankIcon { name: "settings"; size: 14; color: Theme.surfaceText }
                StyledText { text: "Options"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            }

            DankListView {
                id: optionsList
                width: parent.width
                height: 346 + (root.format === "jpg" ? 60 : 0)
                interactive: false
                currentIndex: -1
                spacing: 4

                Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }

                readonly property var visibleKeys: {
                    let base = ["copyToClipboard", "saveToDisk", "showPointer", "stdout", "format"];
                    if (root.format === "jpg") base.push("quality");
                    base.push("customPath");
                    return base;
                }

                model: [
                    { t: "Copy to Clipboard", i: "content_copy",  k: "copyToClipboard", type: "toggle"      },
                    { t: "Save to Disk",       i: "save",          k: "saveToDisk",      type: "toggle"      },
                    { t: "Show Pointer",       i: "mouse",         k: "showPointer",     type: "toggle"      },
                    { t: "Screenshot Editor",  i: "output",        k: "stdout",          type: "toggle"      },
                    { t: "Image Format",       i: "image",         k: "format",          type: "format"      },
                    { t: "JPEG Quality",       i: "high_quality",  k: "quality",         type: "qualityField"},
                    { t: "Custom Directory",   i: "folder",        k: "customPath",      type: "pathField"   }
                ]

                delegate: Item {
                    id: optDelegate
                    width: optionsList.width
                    clip: true

                    readonly property var  vk:      optionsList.visibleKeys
                    readonly property int  vIdx:    vk.indexOf(modelData.k)
                    readonly property bool isFirst: vIdx === 0
                    readonly property bool isLast:  vIdx === vk.length - 1
                    readonly property bool hovered: optMouseArea.containsMouse

                    height: {
                        if (modelData.type === "format")       return 88;
                        if (modelData.type === "qualityField") return root.format === "jpg" ? 56 : 0;
                        if (modelData.type === "pathField")    return 72;
                        return 44; 
                    }

                    Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }
                    
                    visible: height > 0
                    opacity: height > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: isFirst ? 12 : (isLast ? 12 : 4)
                        color: hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.05)
                        border.width: 1
                        border.color: hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                        Behavior on color        { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }

                    DankRipple { id: optRipple; cornerRadius: parent.radius; rippleColor: Theme.primary; visible: modelData.type === "toggle" }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingM
                        visible: modelData.type === "toggle"
                        DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize }
                        StyledText { text: modelData.t; color: Theme.surfaceText; Layout.fillWidth: true }
                        DankToggle { 
                            checked: root[modelData.k]
                            onClicked: { root[modelData.k] = checked; root.saveSetting(modelData.k, checked); }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: 8
                        visible: modelData.type === "format"
                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize }
                            StyledText { text: modelData.t; color: Theme.surfaceText; Layout.fillWidth: true }
                        }
                        DankButtonGroup {
                            Layout.fillWidth: true; buttonHeight: 32; minButtonWidth: 60
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

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingS; spacing: Theme.spacingM
                        visible: modelData.type === "pathField" || modelData.type === "qualityField"
                        DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: Theme.iconSize }
                        Column {
                            Layout.fillWidth: true; spacing: 2
                            StyledText { text: modelData.t; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                            DankTextField {
                                width: parent.width; height: 32
                                text: modelData.k === "quality" ? root.quality.toString() : root.customPath
                                placeholderText: modelData.k === "quality" ? "90" : root.defaultPath
                                onTextEdited: {
                                    if (modelData.k === "quality") {
                                        var v = parseInt(text);
                                        if (!isNaN(v)) { root.quality = v; root.saveSetting("quality", v); }
                                    } else {
                                        root.customPath = text; root.saveSetting("customPath", text);
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: optMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: modelData.type === "toggle" ? Qt.LeftButton : Qt.NoButton
                        onPressed: if (modelData.type === "toggle") optRipple.trigger(mouse.x, mouse.y)
                        onClicked: if (modelData.type === "toggle") { root[modelData.k] = !root[modelData.k]; root.saveSetting(modelData.k, root[modelData.k]); }
                    }
                }
            }
        }
    }
}