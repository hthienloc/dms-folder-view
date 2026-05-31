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
        id: appearanceSection
        SectionTitle { 
            text: I18n.tr("Appearance")
            icon: "palette" 
            showReset: backgroundOpacity.isDirty || borderOpacity.isDirty || cellSize.isDirty || viewMode.isDirty || showHeader.isDirty || showHidden.isDirty
            onResetClicked: {
                backgroundOpacity.resetToDefault();
                borderOpacity.resetToDefault();
                cellSize.resetToDefault();
                viewMode.resetToDefault();
                showHeader.resetToDefault();
                showHidden.resetToDefault();
            }
        }

        SliderSettingPlus {
            id: backgroundOpacity
            settingKey: "backgroundOpacity"
            label: I18n.tr("Background Opacity")
            defaultValue: 80
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0%"
            rightLabel: "100%"
        }

        Separator {}

        SliderSettingPlus {
            id: borderOpacity
            settingKey: "borderOpacity"
            label: I18n.tr("Border Opacity")
            defaultValue: 0
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0%"
            rightLabel: "100%"
        }

        Separator {}

        SliderSettingPlus {
            id: cellSize
            settingKey: "cellSize"
            label: I18n.tr("Icon Size")
            description: I18n.tr("Adjust the size of file and folder icons.")
            defaultValue: 84
            minimum: 64
            maximum: 128
            unit: "px"
            leftLabel: "64"
            rightLabel: "128"
        }

        Separator {}

        SelectionSettingPlus {
            id: viewMode
            settingKey: "viewMode"
            label: I18n.tr("View Mode")
            options: [
                { label: I18n.tr("Grid View"), value: "grid" },
                { label: I18n.tr("List View"), value: "list" },
                { label: I18n.tr("Compact View"), value: "compact" }
            ]
            defaultValue: "grid"
        }

        Separator {}

        ToggleSettingPlus {
            id: showHeader
            settingKey: "showHeader"
            label: I18n.tr("Show Folder Header")
            defaultValue: true
        }

        Separator {}

        ToggleSettingPlus {
            id: showHidden
            settingKey: "showHidden"
            label: I18n.tr("Show Hidden Files")
            defaultValue: false
        }
    }

    SettingsCard {
        SectionTitle { 
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book" 
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("<b>Left-click</b> the folder title to switch between system directories."),
                I18n.tr("<b>Left-click</b> the <b>+ icon</b> to create new folders, documents, or <b>app shortcuts</b>."),
                I18n.tr("<b>Double-click</b> any item to open it with the system default application."),
                I18n.tr("<b>Middle-click</b> an item to open the <b>context menu</b> for file actions."),
                I18n.tr("<b>Middle-click</b> empty space to <b>Paste</b> files or images from clipboard."),
                I18n.tr("Use <b>Ctrl</b> and <b>Shift</b> for multi-selection operations.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-folder-view"
    }
}
