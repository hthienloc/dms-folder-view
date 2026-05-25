import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "folderView"

    SettingsCard {
        SectionTitle { text: I18n.tr("Aesthetics & Size") }

        SliderSetting {
            settingKey: "backgroundOpacity"
            label: I18n.tr("Background Opacity")
            defaultValue: 80
            minimum: 0
            maximum: 100
            unit: "%"
        }

        SliderSetting {
            settingKey: "cellSize"
            label: I18n.tr("Icon Size")
            defaultValue: 84
            minimum: 48
            maximum: 128
            unit: "px"
        }

        ToggleSetting {
            settingKey: "showHeader"
            label: I18n.tr("Show Folder Header")
            description: I18n.tr("Show a top header bar with folder name.")
            defaultValue: true
        }
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("File Sorting & Display") }

        SelectionSetting {
            settingKey: "sortBy"
            label: I18n.tr("Sort Files By")
            options: [
                { label: I18n.tr("Name"), value: "name" },
                { label: I18n.tr("Modification Time"), value: "time" },
                { label: I18n.tr("File Size"), value: "size" },
                { label: I18n.tr("File Type"), value: "type" }
            ]
            defaultValue: "name"
        }

        SelectionSetting {
            settingKey: "viewMode"
            label: I18n.tr("View Mode")
            options: [
                { label: I18n.tr("Grid View"), value: "grid" },
                { label: I18n.tr("List View"), value: "list" },
                { label: I18n.tr("Compact View"), value: "compact" }
            ]
            defaultValue: "grid"
        }

        ToggleSetting {
            settingKey: "showHidden"
            label: I18n.tr("Show Hidden Files")
            description: I18n.tr("Show files starting with a dot (e.g. .hidden).")
            defaultValue: false
        }
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("Folder Configuration") }

        SelectionSetting {
            settingKey: "folderType"
            label: I18n.tr("Target Folder")
            options: [
                { label: I18n.tr("Desktop"), value: "desktop" },
                { label: I18n.tr("Downloads"), value: "downloads" },
                { label: I18n.tr("Music"), value: "music" },
                { label: I18n.tr("Videos"), value: "videos" },
                { label: I18n.tr("Documents"), value: "documents" },
                { label: I18n.tr("Trash"), value: "trash" },
                { label: I18n.tr("Custom Folder..."), value: "custom" }
            ]
            defaultValue: "desktop"
        }

        StringSetting {
            settingKey: "customFolderPath"
            label: I18n.tr("Custom Folder Path")
            placeholderText: I18n.tr("e.g. /home/user/Projects or ~/Projects")
            defaultValue: ""
            visible: pluginData.folderType === "custom"
        }
    }
}
