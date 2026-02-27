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
    }

    // Mode Selection
    StyledRect {
        width: parent.width
        height: modeColumnCC.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        
        Column {
            id: modeColumnCC
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS
            
            StyledText {
                text: "Capture Mode"
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
            
            Repeater {
                model: [
                    { label: "Interactive (Region)", value: "interactive", icon: "touch_app" },
                    { label: "Focused Screen", value: "full", icon: "monitor" },
                    { label: "All Screens", value: "all", icon: "monitor_weight" }
                ]
                
                delegate: Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.cornerRadius
                    color: root.mode === modelData.value ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : "transparent"
                    
                    RowLayout { 
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingS
                        spacing: Theme.spacingM
                        
                        DankIcon {
                            name: modelData.icon
                            color: root.mode === modelData.value ? Theme.primary : Theme.surfaceVariantText
                            size: Theme.iconSize
                            Layout.alignment: Qt.AlignVCenter
                        }
                        
                        StyledText {
                            text: modelData.label
                            color: root.mode === modelData.value ? Theme.primary : Theme.surfaceText
                            font.weight: root.mode === modelData.value ? Font.Bold : Font.Normal
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter 
                        }
                        
                        DankIcon {
                            visible: root.mode === modelData.value
                            name: "check"
                            color: Theme.primary
                            size: Theme.iconSize
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                    
                    MouseArea {
                        id: modeMA
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onClicked: {
                            root.saveSetting("mode", modelData.value);
                            root.mode = modelData.value;
                        }
                    }
                }
            }
        }
    }

    // Options
    StyledRect {
        width: parent.width
        height: optionsColumnCC.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        
        Column {
            id: optionsColumnCC
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS
            
            StyledText {
                text: "Options"
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            // Show Pointer
            Rectangle {
                width: parent.width
                height: 40
                color: "transparent"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    spacing: Theme.spacingM
                    
                    DankIcon {
                        name: root.showPointer ? "check_box" : "check_box_outline_blank"
                        color: root.showPointer ? Theme.primary : Theme.surfaceVariantText
                        size: Theme.iconSize
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    StyledText {
                        text: "Show Pointer"
                        color: Theme.surfaceText
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: {
                        root.saveSetting("showPointer", !root.showPointer);
                        root.showPointer = !root.showPointer;
                    }
                }
            }

            // Save to Disk
            Rectangle {
                width: parent.width
                height: 40
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    spacing: Theme.spacingM

                    DankIcon {
                        name: root.saveToDisk ? "check_box" : "check_box_outline_blank"
                        color: root.saveToDisk ? Theme.primary : Theme.surfaceVariantText
                        size: Theme.iconSize
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: "Save to Disk"
                        color: Theme.surfaceText
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: {
                        root.saveSetting("saveToDisk", !root.saveToDisk);
                        root.saveToDisk = !root.saveToDisk;
                    }
                }
            }

            // Custom Path
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                Rectangle {
                    width: parent.width
                    height: 40
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        spacing: Theme.spacingM

                        DankIcon {
                            name: "folder"
                            color: Theme.surfaceVariantText
                            size: Theme.iconSize
                            Layout.alignment: Qt.AlignVCenter
                        }

                        StyledText {
                            text: "Custom Save Path"
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                DankTextField {
                    id: customPathInput
                    width: parent.width
                    height: 40
                    text: root.customPath
                    placeholderText: root.defaultPath
                    backgroundColor: Theme.surfaceContainer
                    textColor: Theme.surfaceText

                    onTextEdited: {
                        root.customPath = text.trim();
                        root.saveSetting("customPath", root.customPath);
                    }
                }

                StyledText {
                    x: Theme.spacingS
                    width: parent.width - Theme.spacingS
                    text: "Leave empty for default. Use a directory or file path."
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }
        }
    } 
}