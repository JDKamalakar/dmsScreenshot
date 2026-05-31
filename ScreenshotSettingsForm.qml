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
    property int delaySeconds: 0
    property string output: "" // (deprecated)
    
    property bool _isReady: true

    signal saveSetting(string key, var value)

    function loadSetting(key, defaultValue) {
        if (pluginService) {
             return pluginService.loadPluginData("dmsScreenshot", key, defaultValue);
        }
        return defaultValue;
    }


    // --- Capture Mode Section ---
    StyledRect {
        width: parent.width; anchors.horizontalCenter: parent.horizontalCenter
        height: modeColumnCC.implicitHeight + Theme.spacingM * 2

        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

        Column {
            id: modeColumnCC
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 4; anchors.rightMargin: 4
                spacing: Theme.spacingXS
                DankIcon { name: "camera"; size: 14; color: Theme.surfaceText }
                StyledText { text: "Capture Mode"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            }

            Column {
                id: modeList
                width: parent.width
                spacing: 4

                Repeater {
                    model: [
                        { label: "Interactive",    val: "interactive", ic: "touch_app"     },
                        { label: "Focused Screen", val: "full",        ic: "monitor"       },
                        { label: "All Screens",    val: "all",         ic: "monitor_weight"}
                    ]

                    delegate: Item {
                    id: modeDelegate
                    width: modeList.width
                    height: 44
                    readonly property bool isSelected: root.mode === modelData.val
                    readonly property bool hovered: modeMouseArea.containsMouse
                    readonly property int  totalCount: 3   // fixed 3 items

                    // Dynamic background with Canvas for selective corner rounding
                    Canvas {
                        id: modeBg
                        anchors.fill: parent

                        property real innerRadius: 6
                        property real outerRadius: 12
                        property bool isFirst: index === 0
                        property bool isLast:  index === modeDelegate.totalCount - 1
                        
                        property real tlr: isSelected ? 21.5 : (isFirst ? outerRadius : innerRadius)
                        property real trr: isSelected ? 21.5 : (isFirst ? outerRadius : innerRadius)
                        property real blr: isSelected ? 21.5 : (isLast ? outerRadius : innerRadius)
                        property real brr: isSelected ? 21.5 : (isLast ? outerRadius : innerRadius)

                        property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                        property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                        property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                        property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                        property color paintColor: isSelected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : (hovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                        Behavior on paintColor { ColorAnimation { duration: 150 } }
                        
                        property color paintBorder: isSelected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
                            : (hovered
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15))
                        Behavior on paintBorder { ColorAnimation { duration: 150 } }

                        onTlrAnimChanged: requestPaint()
                        onTrrAnimChanged: requestPaint()
                        onBlrAnimChanged: requestPaint()
                        onBrrAnimChanged: requestPaint()
                        onPaintColorChanged: requestPaint()
                        onPaintBorderChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            var x = 0.5, y = 0.5;
                            var w = width - 1, h = height - 1;
                            
                            ctx.reset();
                            ctx.beginPath();
                            ctx.moveTo(x + tlrAnim, y);
                            ctx.lineTo(x + w - trrAnim, y);
                            ctx.arcTo(x + w, y, x + w, y + trrAnim, trrAnim);
                            ctx.lineTo(x + w, y + h - brrAnim);
                            ctx.arcTo(x + w, y + h, x + w - brrAnim, y + h, brrAnim);
                            ctx.lineTo(x + blrAnim, y + h);
                            ctx.arcTo(x, y + h, x, y + h - blrAnim, blrAnim);
                            ctx.lineTo(x, y + tlrAnim);
                            ctx.arcTo(x, y, x + tlrAnim, y, tlrAnim);
                            ctx.closePath();
                            
                            ctx.fillStyle = paintColor;
                            ctx.fill();
                            ctx.strokeStyle = paintBorder;
                            ctx.lineWidth = 1;
                            ctx.stroke();
                        }

                        Rectangle { 
                            anchors.fill: parent; radius: parent.tlrAnim; color: "white"
                            anchors.margins: 0.5
                            opacity: hovered ? 0.05 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } 
                        }
                    }

                    DankRipple { id: modeRipple; anchors.fill: parent; cornerRadius: modeBg.tlrAnim; rippleColor: Theme.primary }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: Theme.spacingS
                        DankIcon { 
                            name: modelData.ic
                            color: isSelected ? Theme.primary : Theme.surfaceVariantText
                            size: 18
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        StyledText { 
                            text: modelData.label; font.pixelSize: Theme.fontSizeSmall
                            font.weight: isSelected ? Font.Bold : Font.Normal 
                            color: isSelected ? Theme.primary : Theme.surfaceText
                            Layout.fillWidth: true 
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        DankIcon { 
                            name: "check_circle"; size: 16; color: Theme.primary
                            scale: isSelected ? 1.0 : 0.0
                            opacity: isSelected ? 1.0 : 0.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
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
                } // End Item
                } // End Repeater
            } // End Column
        }
    }

    // --- Options Section ---
    StyledRect {
        width: parent.width; anchors.horizontalCenter: parent.horizontalCenter
        height: optionsColumnCC.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)



        Column {
            id: optionsColumnCC
            width: parent.width - Theme.spacingM * 2
            x: Theme.spacingM
            y: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 4; anchors.rightMargin: 4
                spacing: Theme.spacingXS
                DankIcon { name: "settings"; size: 14; color: Theme.surfaceText }
                StyledText { text: "Options"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            }

            Column {
                id: optionsList
                width: parent.width
                spacing: 4

                readonly property var visibleKeys: {
                    let base = ["copyToClipboard", "saveToDisk", "showPointer", "stdout", "delaySeconds"];
                    base.push("format");
                    if (root.format === "jpg") base.push("quality");
                    base.push("customPath");
                    return base;
                }

                function getGroup(key) {
                    if (key === "copyToClipboard" || key === "saveToDisk" || key === "showPointer" || key === "stdout" || key === "delaySeconds") return 1;
                    if (key === "format" || key === "quality") return 2;
                    if (key === "customPath") return 3;
                    return 0;
                }

                Repeater {
                    model: [
                        { t: "Copy to Clipboard", i: "content_copy",  k: "copyToClipboard", type: "toggle"      },
                        { t: "Save to Disk",       i: "save",          k: "saveToDisk",      type: "toggle"      },
                        { t: "Show Pointer",       i: "mouse",         k: "showPointer",     type: "toggle"      },
                        { t: "Screenshot Editor",  i: "output",        k: "stdout",          type: "toggle"      },
                        { t: "Capture Delay",      i: "schedule",      k: "delaySeconds",    type: "delay"       },
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
                    readonly property int  myGroup: optionsList.getGroup(modelData.k)
                    readonly property bool isVisible: vIdx !== -1
                    readonly property bool isFirst: isVisible && (vIdx === 0 || optionsList.getGroup(vk[vIdx - 1]) !== myGroup)
                    readonly property bool isLast:  isVisible && (vIdx === vk.length - 1 || optionsList.getGroup(vk[vIdx + 1]) !== myGroup)
                    readonly property bool hovered: optMouseArea.containsMouse

                    property real baseHeight: {
                        if (modelData.type === "format")       return 72;
                        if (modelData.type === "delay")        return 72;
                        if (modelData.type === "qualityField") return root.format === "jpg" ? 72 : 0;
                        if (modelData.type === "pathField")    return 72;
                        return 44;
                    }

                    readonly property real groupMargin: (isLast && vIdx !== vk.length - 1 && baseHeight > 0) ? 8 : 0
                    
                    height: baseHeight + groupMargin
                    
                    visible: height > 0 || baseHeight > 0
                    opacity: baseHeight > 0 ? 1 : 0

                    Item {
                        id: contentCard
                        width: parent.width
                        height: parent.baseHeight
                        clip: true

                    Canvas {
                        id: optBg
                        anchors.fill: parent

                        property real innerRadius: 6
                        property real outerRadius: 12
                        
                        property real tlr: isFirst ? outerRadius : innerRadius
                        property real trr: isFirst ? outerRadius : innerRadius
                        property real blr: isLast ? outerRadius : innerRadius
                        property real brr: isLast ? outerRadius : innerRadius

                        property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                        property color paintColor: hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                        Behavior on paintColor { ColorAnimation { duration: 150 } }
                        property color paintBorder: hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                        Behavior on paintBorder { ColorAnimation { duration: 150 } }

                        onTlrAnimChanged: requestPaint()
                        onTrrAnimChanged: requestPaint()
                        onBlrAnimChanged: requestPaint()
                        onBrrAnimChanged: requestPaint()
                        onPaintColorChanged: requestPaint()
                        onPaintBorderChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.beginPath();
                            ctx.moveTo(tlrAnim, 0);
                            ctx.lineTo(width - trrAnim, 0);
                            ctx.arcTo(width, 0, width, trrAnim, trrAnim);
                            ctx.lineTo(width, height - brrAnim);
                            ctx.arcTo(width, height, width - brrAnim, height, brrAnim);
                            ctx.lineTo(blrAnim, height);
                            ctx.arcTo(0, height, 0, height - blrAnim, blrAnim);
                            ctx.lineTo(0, tlrAnim);
                            ctx.arcTo(0, 0, tlrAnim, 0, tlrAnim);
                            ctx.closePath();
                            ctx.fillStyle = paintColor;
                            ctx.fill();
                            ctx.strokeStyle = paintBorder;
                            ctx.lineWidth = 1;
                            ctx.stroke();
                        }
                    }

                    DankRipple { id: optRipple; anchors.fill: parent; cornerRadius: optBg.tlrAnim; rippleColor: Theme.primary; visible: modelData.type === "toggle" }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: Theme.spacingS
                        visible: modelData.type === "toggle"
                        DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: 18 }
                        StyledText { text: modelData.t; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true }
                        DankToggle { 
                            scale: 0.85
                            checked: root[modelData.k]
                            onClicked: { root[modelData.k] = checked; root.saveSetting(modelData.k, checked); }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 4
                        visible: modelData.type === "format"
                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingS
                            DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: 18 }
                            StyledText { text: modelData.t; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true }
                        }
                        DankButtonGroup {
                            Layout.fillWidth: true; buttonHeight: 30; minButtonWidth: 54
                            scale: 0.85
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

                    ColumnLayout {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 4
                        visible: modelData.type === "delay"
                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingS
                            DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: 18 }
                            StyledText { text: modelData.t; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true }
                        }
                        DankButtonGroup {
                            Layout.fillWidth: true; buttonHeight: 30; minButtonWidth: 54
                            scale: 0.85
                            model: ["Off", "3s", "5s", "10s"]
                            currentIndex: {
                                if (root.delaySeconds === 3) return 1;
                                if (root.delaySeconds === 5) return 2;
                                if (root.delaySeconds === 10) return 3;
                                return 0;
                            }
                            onSelectionChanged: function(index, selected) {
                                if (selected) {
                                    var vals = [0, 3, 5, 10];
                                    root.delaySeconds = vals[index];
                                    root.saveSetting("delaySeconds", String(vals[index]));
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 4
                        visible: modelData.type === "pathField" || modelData.type === "qualityField"
                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingS
                            DankIcon { name: modelData.i; color: Theme.surfaceVariantText; size: 18 }
                            StyledText { text: modelData.t; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.fillWidth: true }
                        }
                        DankTextField {
                            Layout.fillWidth: true; height: 28
                            font.pixelSize: Theme.fontSizeSmall - 2
                            text: modelData.k === "quality" ? root.quality.toString() : root.customPath
                            placeholderText: modelData.k === "quality" ? "90" : root.defaultPath
                            onEditingFinished: {
                                if (modelData.k === "quality") {
                                    var v = parseInt(text);
                                    if (!isNaN(v)) { root.quality = v; root.saveSetting("quality", v); }
                                } else {
                                    root.customPath = text; root.saveSetting("customPath", text);
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
                } // End Item
            } // End Repeater
        } // End Column optionsList
        } // End Column optionsColumnCC
    } // End StyledRect
} // End root Item