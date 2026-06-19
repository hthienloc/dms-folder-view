import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "./dms-common"

Item {
    id: root
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

    function findSettings() {
        let item = parent
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) return item
            item = item.parent
        }
        return null
    }

    function reset() {
        currentValue = JSON.parse(JSON.stringify(defaultValue));
        saveCurrentValue();
    }

    function loadValue() {
        const settings = findSettings();
        if (settings && settings.pluginService) {
            let loaded = settings.loadValue(settingKey, []);
            currentValue = getNormalizedActions(loaded);
            isInitialized = true;
        }
    }

    function saveCurrentValue() {
        if (!isInitialized) return;
        const settings = findSettings();
        if (settings) {
            settings.saveValue(settingKey, currentValue);
        }
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
            model: root.currentValue

            delegate: Rectangle {
                id: itemRow
                width: layoutColumn.width
                height: 40
                color: "transparent"
                radius: Theme.cornerRadiusSmall

                // Hover highlighting
                HoverHandler {
                    id: rowHover
                }

                Rectangle {
                    anchors.fill: parent
                    color: rowHover.hovered ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
                    radius: parent.radius
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingM

                    // Enable/Disable switch/checkbox
                    DankToggle {
                        id: enabledToggle
                        anchors.verticalCenter: parent.verticalCenter
                        checked: modelData.enabled
                        onToggled: isChecked => {
                            let updated = JSON.parse(JSON.stringify(root.currentValue));
                            updated[index].enabled = isChecked;
                            root.currentValue = updated;
                            root.saveCurrentValue();
                        }
                    }

                    // Action Icon
                    DankIcon {
                        name: root.actionMetadata[modelData.id] ? root.actionMetadata[modelData.id].icon : "extension"
                        size: 20
                        color: modelData.enabled ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Action Name
                    StyledText {
                        text: root.actionMetadata[modelData.id] ? root.actionMetadata[modelData.id].label : modelData.id
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: modelData.enabled ? Theme.surfaceText : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - enabledToggle.width - 20 - 70 - Theme.spacingM * 3
                        elide: Text.ElideRight
                    }

                    // Reorder Buttons (Move Up / Move Down)
                    Row {
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        // Move Up Button
                        MouseArea {
                            width: 28
                            height: 28
                            visible: index > 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let updated = JSON.parse(JSON.stringify(root.currentValue));
                                let temp = updated[index];
                                updated[index] = updated[index - 1];
                                updated[index - 1] = temp;
                                root.currentValue = updated;
                                root.saveCurrentValue();
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "keyboard_arrow_up"
                                size: 20
                                color: parent.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            }
                        }

                        // Spacer for first item to align buttons
                        Item {
                            width: 28
                            height: 28
                            visible: index === 0
                        }

                        // Move Down Button
                        MouseArea {
                            width: 28
                            height: 28
                            visible: index < root.currentValue.length - 1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let updated = JSON.parse(JSON.stringify(root.currentValue));
                                let temp = updated[index];
                                updated[index] = updated[index + 1];
                                updated[index + 1] = temp;
                                root.currentValue = updated;
                                root.saveCurrentValue();
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "keyboard_arrow_down"
                                size: 20
                                color: parent.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            }
                        }

                        // Spacer for last item to align buttons
                        Item {
                            width: 28
                            height: 28
                            visible: index === root.currentValue.length - 1
                        }
                    }
                }
            }
        }
    }
}
