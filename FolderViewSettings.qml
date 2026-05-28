import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "../dms-common"

PluginSettings {
    id: root
    pluginId: "folderView"

    PluginHeader {
        title: I18n.tr("Folder View Settings")
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("Appearance") }

        SliderSetting {
            settingKey: "backgroundOpacity"
            label: I18n.tr("Background Opacity")
            defaultValue: 80
            minimum: 0
            maximum: 100
            unit: "%"
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
}
