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

    component ContextMenuActionsConfig : Item {
        id: configRoot
        width: parent.width
        implicitHeight: layoutColumn.implicitHeight

        property string settingKey: "contextMenuActions"
        property var defaultValue: [
            { "id": "open", "enabled": true },
            { "id": "float", "enabled": true },
            { "id": "copy", "enabled": true },
            { "id": "copyPath", "enabled": true },
            { "id": "rename", "enabled": true },
            { "id": "info", "enabled": true },
            { "id": "extractHere", "enabled": true },
            { "id": "extractToFolder", "enabled": true },
            { "id": "viewContents", "enabled": true },
            { "id": "favorite", "enabled": true },
            { "id": "pin", "enabled": true },
            { "id": "groupStack", "enabled": true },
            { "id": "ungroupStack", "enabled": true },
            { "id": "trash", "enabled": true }
        ]
        property var currentValue: []
        property bool isInitialized: false

        readonly property var actionMetadata: ({
            "open": { "label": I18n.tr("Open"), "icon": "open_in_new" },
            "float": { "label": I18n.tr("Float File"), "icon": "picture_in_picture" },
            "copy": { "label": I18n.tr("Copy"), "icon": "content_copy" },
            "copyPath": { "label": I18n.tr("Copy Path"), "icon": "content_copy" },
            "rename": { "label": I18n.tr("Rename"), "icon": "edit" },
            "info": { "label": I18n.tr("Info"), "icon": "info" },
            "extractHere": { "label": I18n.tr("Extract Here"), "icon": "unarchive" },
            "extractToFolder": { "label": I18n.tr("Extract to folder"), "icon": "folder_zip" },
            "viewContents": { "label": I18n.tr("View Contents"), "icon": "visibility" },
            "favorite": { "label": I18n.tr("Favorite / Unfavorite"), "icon": "star" },
            "pin": { "label": I18n.tr("Pin / Unpin"), "icon": "push_pin" },
            "groupStack": { "label": I18n.tr("Group into Stack"), "icon": "layers" },
            "ungroupStack": { "label": I18n.tr("Ungroup Stack"), "icon": "layers_clear" },
            "trash": { "label": I18n.tr("Move to Trash"), "icon": "delete" }
        })

        function reset() {
            currentValue = JSON.parse(JSON.stringify(defaultValue));
            saveCurrentValue();
        }

        function loadValue() {
            let loaded = root.loadValue(settingKey, []);
            currentValue = getNormalizedActions(loaded);
            isInitialized = true;
        }

        function saveCurrentValue() {
            if (!isInitialized) return;
            root.saveValue(settingKey, currentValue);
        }

        function getNormalizedActions(savedList) {
            let defaults = defaultValue;
            if (!savedList || !Array.isArray(savedList)) {
                return JSON.parse(JSON.stringify(defaults));
            }
            let savedMap = {};
            for (let item of savedList) {
                if (item && item.id) {
                    savedMap[item.id] = item;
                }
            }
            let result = [];
            let addedIds = {};
            for (let item of savedList) {
                if (item && item.id && actionMetadata[item.id]) {
                    result.push({
                        "id": item.id,
                        "enabled": item.enabled !== undefined ? !!item.enabled : true
                    });
                    addedIds[item.id] = true;
                }
            }
            for (let d of defaults) {
                if (!addedIds[d.id]) {
                    result.push({
                        "id": d.id,
                        "enabled": d.enabled
                    });
                }
            }
            return result;
        }

        Component.onCompleted: Qt.callLater(loadValue)

        Column {
            id: layoutColumn
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: configRoot.currentValue

                delegate: Item {
                    id: delegateItem
                    required property var modelData
                    required property int index

                    readonly property var config: configRoot

                    property bool held: dragArea.pressed
                    property real originalY: y

                    width: layoutColumn.width
                    height: 40
                    z: held ? 2 : 1

                    function reorderAction(fromIndex, toIndex) {
                        if (fromIndex === toIndex)
                            return;
                        let updated = JSON.parse(JSON.stringify(delegateItem.config.currentValue));
                        let item = updated.splice(fromIndex, 1)[0];
                        updated.splice(toIndex, 0, item);
                        delegateItem.config.currentValue = updated;
                        delegateItem.config.saveCurrentValue();
                    }

                    Rectangle {
                        id: itemRow
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.cornerRadius - 4

                        HoverHandler {
                            id: rowHover
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: rowHover.hovered || delegateItem.held ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
                            radius: parent.radius
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            spacing: Theme.spacingM

                            Item {
                                width: 20
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "drag_indicator"
                                    size: 16
                                    color: Theme.surfaceVariantText
                                    opacity: dragArea.containsMouse || dragArea.pressed ? 1.0 : 0.5
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeVerCursor
                                    drag.target: delegateItem.held ? delegateItem : undefined
                                    drag.axis: Drag.YAxis
                                    preventStealing: true

                                    onPressed: {
                                        delegateItem.originalY = delegateItem.y;
                                    }

                                    onReleased: {
                                        if (!drag.active) {
                                            delegateItem.y = delegateItem.originalY;
                                            return;
                                        }
                                        const spacing = Theme.spacingS;
                                        const itemH = delegateItem.height + spacing;
                                        let newIndex = Math.round(delegateItem.y / itemH);
                                        newIndex = Math.max(0, Math.min(newIndex, delegateItem.config.currentValue.length - 1));
                                        delegateItem.reorderAction(delegateItem.index, newIndex);
                                        delegateItem.y = delegateItem.originalY;
                                    }
                                }
                            }

                            DankToggle {
                                id: enabledToggle
                                anchors.verticalCenter: parent.verticalCenter
                                checked: delegateItem.modelData.enabled
                                onToggled: isChecked => {
                                    let updated = JSON.parse(JSON.stringify(delegateItem.config.currentValue));
                                    updated[delegateItem.index].enabled = isChecked;
                                    delegateItem.config.currentValue = updated;
                                    delegateItem.config.saveCurrentValue();
                                }
                            }

                            DankIcon {
                                name: delegateItem.config.actionMetadata[delegateItem.modelData.id] ? delegateItem.config.actionMetadata[delegateItem.modelData.id].icon : "extension"
                                size: 20
                                color: delegateItem.modelData.enabled ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: delegateItem.config.actionMetadata[delegateItem.modelData.id] ? delegateItem.config.actionMetadata[delegateItem.modelData.id].label : delegateItem.modelData.id
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: delegateItem.modelData.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20 - enabledToggle.width - 20 - Theme.spacingM * 3
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Behavior on y {
                        enabled: !dragArea.pressed && !dragArea.drag.active
                        NumberAnimation {
                            duration: Theme.shortDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }
            }
        }
    }

    SettingsCard {
        id: appearanceSection
        SectionTitle { 
            text: I18n.tr("Appearance")
            icon: "palette" 
            showReset: backgroundOpacity.isDirty || borderOpacity.isDirty || cellSize.isDirty || viewMode.isDirty || gridDirection.isDirty || headerPosition.isDirty || showHeader.isDirty || showHidden.isDirty
            onResetClicked: {
                backgroundOpacity.resetToDefault();
                borderOpacity.resetToDefault();
                cellSize.resetToDefault();
                viewMode.resetToDefault();
                gridDirection.resetToDefault();
                headerPosition.resetToDefault();
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

        ButtonGroupSettingPlus {
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

        ButtonGroupSettingPlus {
            id: gridDirection
            settingKey: "gridDirection"
            label: I18n.tr("Grid View Direction")
            visible: viewMode.value === "grid"
            options: [
                { label: I18n.tr("Horizontal"), value: "horizontal" },
                { label: I18n.tr("Vertical"), value: "vertical" }
            ]
            defaultValue: "horizontal"
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: headerPosition
            settingKey: "headerPosition"
            label: I18n.tr("Header Position")
            options: [
                { label: I18n.tr("Top"),    value: "top"    },
                { label: I18n.tr("Bottom"), value: "bottom" }
            ]
            defaultValue: "top"
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
            id: contextMenuTitle
            text: I18n.tr("Context Menu Actions")
            icon: "menu"
            collapsible: true
            settingKey: "contextMenuActionsExpanded"
            showReset: true
            onResetClicked: {
                contextMenuActionsSetting.reset();
            }
        }

        ContextMenuActionsConfig {
            id: contextMenuActionsSetting
            visible: contextMenuTitle.isExpanded
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
