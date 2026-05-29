import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./dms-common"

PluginSettings {
    id: root
    pluginId: "folderView"

    SettingsCard {
        SectionTitle { text: I18n.tr("Appearance"); icon: "palette" }

        SliderSetting {
            settingKey: "backgroundOpacity"
            label: I18n.tr("Background Opacity")
            defaultValue: 80
            minimum: 0
            maximum: 100
            unit: "%"
        }

        SliderSetting {
            settingKey: "borderOpacity"
            label: I18n.tr("Border Opacity")
            defaultValue: 8
            minimum: 0
            maximum: 100
            unit: "%"
        }

        SliderSetting {
            settingKey: "cellSize"
            label: I18n.tr("Icon Size")
            description: I18n.tr("Adjust the size of file and folder icons.")
            defaultValue: 84
            minimum: 64
            maximum: 128
            unit: "px"
        }

        SelectionSetting {
            settingKey: "viewMode"
            label: I18n.tr("View Mode")
            description: I18n.tr("Choose how files and folders are displayed.")
            options: [
                { label: I18n.tr("Grid View"), value: "grid" },
                { label: I18n.tr("List View"), value: "list" },
                { label: I18n.tr("Compact View"), value: "compact" }
            ]
            defaultValue: "grid"
        }

        ToggleSetting {
            settingKey: "showHeader"
            label: I18n.tr("Show Folder Header")
            description: I18n.tr("Show a top header bar with folder name.")
            defaultValue: true
        }

        ToggleSetting {
            settingKey: "showHidden"
            label: I18n.tr("Show Hidden Files")
            description: I18n.tr("Show files starting with a dot (e.g. .hidden).")
            defaultValue: false
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-folder-view"
    }
}
