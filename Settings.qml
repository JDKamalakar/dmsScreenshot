import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets
import QtCore

PluginSettings {
    id: root
    pluginId: "dmsScreenshot"

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

    Rectangle {
        width: parent.width
        height: captureGroup.implicitHeight + Theme.spacingM * 2
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outline
        border.width: 1
        opacity: 0.8

        function loadValue() {
            for (var i = 0; i < captureGroup.children.length; i++) {
                var row = captureGroup.children[i];
                for (var j = 0; j < row.children.length; j++) {
                    if (row.children[j].loadValue) row.children[j].loadValue();
                }
            }
        }

        Column {
            id: captureGroup
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "camera"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                SelectionSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "mode"
                    label: "Screenshot Mode"
                    description: "Choose what to capture"
                    options: [
                        {label: "Interactive (Region)", value: "interactive"},
                        {label: "Focused Screen", value: "full"},
                        {label: "All Screens", value: "all"},
                        {label: "Repeat Last Region", value: "last"}
                    ]
                    defaultValue: "interactive"
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: outputGroup.implicitHeight + Theme.spacingM * 2
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outline
        border.width: 1
        opacity: 0.8

        function loadValue() {
            for (var i = 0; i < outputGroup.children.length; i++) {
                var row = outputGroup.children[i];
                for (var j = 0; j < row.children.length; j++) {
                    if (row.children[j].loadValue) row.children[j].loadValue();
                }
            }
        }

        Column {
            id: outputGroup
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "image"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                SelectionSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "format"
                    label: "Image Format"
                    description: "Format to save the screenshot in"
                    options: [
                        {label: "PNG (Lossless)", value: "png"},
                        {label: "JPEG", value: "jpg"},
                        {label: "PPM (Raw)", value: "ppm"}
                    ]
                    defaultValue: "png"
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "high_quality"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                Column {
                    width: parent.width - 22 - Theme.spacingM
                    spacing: Theme.spacingXS
                    StyledText {
                        text: "JPEG Quality"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: "Quality from 1-100 (only applies if format is JPEG)"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                StringSetting {
                    width: parent.width
                    settingKey: "quality"
                    label: ""
                    description: ""
                    defaultValue: "90"
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "folder"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                Column {
                    width: parent.width - 22 - Theme.spacingM
                    spacing: Theme.spacingXS
                    StyledText {
                        text: "Custom Path"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: "Absolute path to save screenshots. Leave empty for default."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                StringSetting {
                    width: parent.width
                    settingKey: "customPath"
                    label: ""
                    description: ""
                    placeholder: root.defaultPath
                    defaultValue: ""
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: actionsGroup.implicitHeight + Theme.spacingM * 2
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outline
        border.width: 1
        opacity: 0.8

        function loadValue() {
            for (var i = 0; i < actionsGroup.children.length; i++) {
                var row = actionsGroup.children[i];
                for (var j = 0; j < row.children.length; j++) {
                    if (row.children[j].loadValue) row.children[j].loadValue();
                }
            }
        }

        Column {
            id: actionsGroup
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "save"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                ToggleSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "saveToDisk"
                    label: "Save to Disk"
                    description: "Save screenshot to disk (disable to only save to clipboard)"
                    defaultValue: true
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "content_copy"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                ToggleSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "copyToClipboard"
                    label: "Copy to Clipboard"
                    description: "Copy the resulting image to your clipboard"
                    defaultValue: true
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: interfaceGroup.implicitHeight + Theme.spacingM * 2
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.outline
        border.width: 1
        opacity: 0.8

        function loadValue() {
            for (var i = 0; i < interfaceGroup.children.length; i++) {
                var row = interfaceGroup.children[i];
                for (var j = 0; j < row.children.length; j++) {
                    if (row.children[j].loadValue) row.children[j].loadValue();
                }
            }
        }

        Column {
            id: interfaceGroup
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "mouse"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                ToggleSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "showPointer"
                    label: "Show Pointer"
                    description: "Include mouse pointer in the screenshot"
                    defaultValue: true
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "notifications"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                ToggleSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "showNotify"
                    label: "Show Notification"
                    description: "Show system notification after capture"
                    defaultValue: true
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                DankIcon { name: "info"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                ToggleSetting {
                    width: parent.width - 22 - Theme.spacingM
                    settingKey: "showToast"
                    label: "Show Toast Notification"
                    description: "Show a quick pop-up toast when screenshot is triggered"
                    defaultValue: true
                }
            }
        }
    }
}