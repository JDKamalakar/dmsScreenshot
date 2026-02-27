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

    StyledText {
        width: parent.width
        text: "DMS Screenshot Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure how screenshots are taken."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "mode"
        label: "Screenshot Mode"
        description: "Choose what to capture"
        options: [
            {label: "Interactive (Region)", value: "interactive"},
            {label: "Focused Screen", value: "full"},
            {label: "All Screens", value: "all"}
        ]
        defaultValue: "interactive"
    }

    ToggleSetting {
        settingKey: "showPointer"
        label: "Show Pointer"
        description: "Include mouse pointer in the screenshot"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "saveToDisk"
        label: "Save to Disk"
        description: "Save screenshot to disk (disable to only save to clipboard)"
        defaultValue: true
    }
    
    StringSetting {
        id: customPathSetting
        settingKey: "customPath"
        label: "Custom Path"
        description: "Absolute path to save screenshots. Can be a directory or a file path. Leave empty for default."
        placeholder: root.defaultPath
        defaultValue: ""
    }
}