import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import QtQuick.Dialogs

DesktopPluginComponent {
    id: root

    // Accepts keyboard focus permanently to support text inputs on Wayland
    property bool acceptsKeyboardFocus: true

    // Desktop widget dimensions
    minWidth: 200
    minHeight: 200
    
    // Default initial size if not set
    widgetWidth: pluginData.widgetWidth ?? 320
    widgetHeight: pluginData.widgetHeight ?? 400

    // Settings config
    readonly property real backgroundOpacity: (pluginData.backgroundOpacity ?? 80) / 100
    readonly property bool showHidden: pluginData.showHidden ?? false
    readonly property int cellSize: pluginData.cellSize ?? 84
    readonly property string sortBy: pluginData.sortBy ?? "name"
    readonly property string viewMode: pluginData.viewMode ?? "grid"
    readonly property bool showHeader: pluginData.showHeader ?? true

    // Resolved Folder Settings & URL
    readonly property string folderType: pluginData.folderType ?? "desktop"
    readonly property string customFolderPath: pluginData.customFolderPath ?? ""

    readonly property string targetFolderUrl: {
        const home = Quickshell.env("HOME");
        let path = home + "/Desktop";
        
        switch (folderType) {
            case "downloads":
                path = home + "/Downloads";
                break;
            case "music":
                path = home + "/Music";
                break;
            case "videos":
                path = home + "/Videos";
                break;
            case "documents":
                path = home + "/Documents";
                break;
            case "custom":
                if (customFolderPath && customFolderPath.trim() !== "") {
                    let clean = customFolderPath.trim();
                    if (clean.startsWith("~/")) {
                        clean = home + clean.substring(1);
                    }
                    path = clean;
                }
                break;
            default:
                path = home + "/Desktop";
                break;
        }
        return "file://" + path;
    }

    readonly property string folderDisplayName: {
        switch (folderType) {
            case "desktop": return I18n.tr("Desktop");
            case "downloads": return I18n.tr("Downloads");
            case "music": return I18n.tr("Music");
            case "videos": return I18n.tr("Videos");
            case "documents": return I18n.tr("Documents");
            case "custom":
                if (customFolderPath) {
                    const parts = customFolderPath.trim().split("/");
                    return parts[parts.length - 1] || I18n.tr("Folder");
                }
                return I18n.tr("Folder");
            default: return I18n.tr("Folder");
        }
    }

    // Sorting field mapper
    readonly property int folderSortField: {
        switch (sortBy) {
            case "time": return FolderListModel.Time;
            case "size": return FolderListModel.Size;
            case "type": return FolderListModel.Type;
            default: return FolderListModel.Name;
        }
    }

    // Selected file tracking
    property string selectedFilePath: ""

    function getIconName(fileName, isDir) {
        if (isDir) return "folder";
        
        const ext = fileName.split('.').pop().toLowerCase();
        switch (ext) {
            case "jpg":
            case "jpeg":
            case "png":
            case "gif":
            case "webp":
            case "svg":
            case "bmp":
                return "image";
            case "mp3":
            case "wav":
            case "ogg":
            case "flac":
            case "m4a":
                return "audiotrack";
            case "mp4":
            case "mkv":
            case "avi":
            case "mov":
            case "webm":
                return "video_library";
            case "pdf":
                return "picture_as_pdf";
            case "zip":
            case "tar":
            case "gz":
            case "bz2":
            case "xz":
            case "rar":
            case "7z":
                return "archive";
            case "txt":
            case "md":
            case "json":
            case "xml":
            case "yaml":
            case "yml":
            case "conf":
            case "ini":
                return "description";
            case "sh":
            case "py":
            case "js":
            case "ts":
            case "rs":
            case "go":
            case "c":
            case "cpp":
            case "h":
            case "java":
            case "html":
            case "css":
                return "terminal";
            case "desktop":
                return "bookmark";
            default:
                return "insert_drive_file";
        }
    }

    function getIconColor(fileName, isDir) {
        if (isDir) return Theme.primary;
        
        const ext = fileName.split('.').pop().toLowerCase();
        switch (ext) {
            case "jpg":
            case "jpeg":
            case "png":
            case "gif":
            case "webp":
            case "svg":
            case "bmp":
                return "#00BFA5"; // Teal
            case "mp3":
            case "wav":
            case "ogg":
            case "flac":
            case "m4a":
            case "mp4":
            case "mkv":
            case "avi":
            case "mov":
            case "webm":
                return "#7C4DFF"; // Indigo
            case "pdf":
                return "#FF1744"; // Red
            case "zip":
            case "tar":
            case "gz":
            case "bz2":
            case "xz":
            case "rar":
            case "7z":
                return "#FF9100"; // Amber
            case "txt":
            case "md":
            case "json":
            case "xml":
            case "yaml":
            case "yml":
            case "conf":
            case "ini":
                return "#2979FF"; // Blue
            case "sh":
            case "py":
            case "js":
            case "ts":
            case "rs":
            case "go":
            case "c":
            case "cpp":
            case "h":
            case "java":
            case "html":
            case "css":
                return "#FF5252"; // Coral Red
            default:
                return Theme.surfaceText;
        }
    }

    // Outer frosted glass background
    StyledRect {
        anchors.fill: parent
        anchors.margins: 15
        radius: Theme.cornerRadius
        clip: true
        color: Theme.withAlpha(Theme.surfaceContainer, root.backgroundOpacity)
        border.color: root.editMode ? Theme.primary : Theme.withAlpha(Theme.outline, 0.08)
        border.width: root.editMode ? 2 : 1

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // Premium Header (Optional)
            Item {
                id: headerContainer
                width: parent.width
                height: 24
                visible: root.showHeader

                // Left: Folder Selector
                MouseArea {
                    id: folderSelectorBtn
                    anchors.left: parent.left
                    height: parent.height
                    width: folderRow.implicitWidth
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: folderDropdown.open()

                    Row {
                        id: folderRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "folder_open"
                            size: 18
                            color: folderSelectorBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: folderSelectorBtn.containsMouse ? 1.0 : 0.8
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        StyledText {
                            text: root.folderDisplayName
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: folderSelectorBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: folderSelectorBtn.containsMouse ? 1.0 : 0.8
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        DankIcon {
                            name: "arrow_drop_down"
                            size: 14
                            color: folderSelectorBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: folderSelectorBtn.containsMouse ? 1.0 : 0.6
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                // Right: Controls (View Mode & Sort By)
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    // View Mode Button
                    MouseArea {
                        id: viewModeBtn
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: viewModeDropdown.open()

                        DankIcon {
                            anchors.centerIn: parent
                            name: root.viewMode === "grid" ? "grid_view" : "view_list"
                            size: 16
                            color: viewModeBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: viewModeBtn.containsMouse ? 1.0 : 0.7
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    // Sort By Button
                    MouseArea {
                        id: sortByBtn
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sortByDropdown.open()

                        DankIcon {
                            anchors.centerIn: parent
                            name: {
                                switch (root.sortBy) {
                                    case "time": return "schedule";
                                    case "size": return "bar_chart";
                                    case "type": return "category";
                                    default: return "sort_by_alpha";
                                }
                            }
                            size: 16
                            color: sortByBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: sortByBtn.containsMouse ? 1.0 : 0.7
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }

            // Grid View container
            Item {
                width: parent.width
                height: parent.height - (root.showHeader ? 30 : 0)
                clip: true

                FolderListModel {
                    id: folderModel
                    folder: root.targetFolderUrl
                    showDirsFirst: true
                    showHidden: root.showHidden
                    sortField: root.folderSortField
                }

                // Grid View of icons
                GridView {
                    id: fileGrid
                    anchors.fill: parent
                    cellWidth: root.cellSize
                    cellHeight: root.cellSize + 16
                    model: folderModel
                    visible: root.viewMode === "grid"
                    boundsBehavior: Flickable.StopAtBounds

                    // Smooth add/remove transitions
                    add: Transition {
                        NumberAnimation { properties: "opacity,scale"; from: 0; to: 1.0; duration: 250; easing.type: Easing.OutBack }
                    }
                    remove: Transition {
                        NumberAnimation { properties: "opacity,scale"; to: 0; duration: 200; easing.type: Easing.InQuad }
                    }

                    delegate: Item {
                        id: delegateRoot
                        width: fileGrid.cellWidth
                        height: fileGrid.cellHeight

                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property int index

                        readonly property bool isSelected: root.selectedFilePath === filePath
                        property bool isLaunching: false

                        SequentialAnimation {
                            id: launchPulse
                            running: false
                            NumberAnimation { target: delegateRoot; property: "scale"; to: 0.92; duration: 100; easing.type: Easing.OutQuad }
                            NumberAnimation { target: delegateRoot; property: "scale"; to: 1.05; duration: 150; easing.type: Easing.OutBack }
                            NumberAnimation { target: delegateRoot; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                        }

                        Timer {
                            id: launchTimer
                            interval: 800
                            repeat: false
                            onTriggered: delegateRoot.isLaunching = false
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            radius: Theme.cornerRadius
                            color: isLaunching 
                                ? Theme.withAlpha(Theme.primary, 0.3)
                                : (isSelected 
                                    ? Theme.withAlpha(Theme.primary, 0.15) 
                                    : (itemHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent"))
                            border.color: isLaunching ? Theme.primary : (isSelected ? Theme.primary : "transparent")
                            border.width: isLaunching ? 2 : (isSelected ? 1 : 0)

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingXS

                                // File/Folder Icon
                                Item {
                                    width: parent.width
                                    height: parent.height - 30
                                    
                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: root.getIconName(fileName, fileIsDir)
                                        size: root.cellSize > 70 ? 40 : 32
                                        color: root.getIconColor(fileName, fileIsDir)
                                        scale: itemHover.containsMouse ? 1.08 : 1.0
                                        
                                        Behavior on scale {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                        }
                                    }
                                }

                                // File/Folder Name
                                StyledText {
                                    width: parent.width
                                    text: fileName
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceText
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WrapAnywhere
                                    opacity: itemHover.containsMouse ? 1.0 : 0.85
                                }
                            }

                            MouseArea {
                                id: itemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        root.selectedFilePath = delegateRoot.filePath;
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        quickMenu.currentPath = delegateRoot.filePath;
                                        quickMenu.currentName = delegateRoot.fileName;
                                        quickMenu.currentIsDir = delegateRoot.fileIsDir;
                                        
                                        const globalPos = mapToItem(root, mouse.x, mouse.y);
                                        quickMenu.parent = root;
                                        quickMenu.x = Math.max(0, Math.min(root.width - quickMenu.width, globalPos.x));
                                        quickMenu.y = Math.max(0, Math.min(root.height - quickMenu.height, globalPos.y));
                                        quickMenu.open();
                                    }
                                }

                                onDoubleClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        isLaunching = true;
                                        launchPulse.restart();
                                        launchTimer.restart();
                                        // Open file/folder using default system application
                                        Quickshell.execDetached(["xdg-open", delegateRoot.filePath]);
                                    }
                                }
                            }
                        }
                    }
                }

                // List View of files
                ListView {
                    id: fileList
                    anchors.fill: parent
                    model: folderModel
                    visible: root.viewMode === "list"
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 2
                    clip: true

                    // Smooth add/remove transitions
                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: 200 }
                    }
                    remove: Transition {
                        NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                    }

                    delegate: Item {
                        id: listDelegateRoot
                        width: fileList.width
                        height: 36

                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property int index

                        readonly property bool isSelected: root.selectedFilePath === filePath
                        property bool isLaunching: false

                        Timer {
                            id: listLaunchTimer
                            interval: 800
                            repeat: false
                            onTriggered: listDelegateRoot.isLaunching = false
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingXS
                            anchors.rightMargin: Theme.spacingXS
                            radius: Theme.cornerRadius - 2
                            color: isLaunching 
                                ? Theme.withAlpha(Theme.primary, 0.3)
                                : (isSelected 
                                    ? Theme.withAlpha(Theme.primary, 0.15) 
                                    : (listItemHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent"))
                            border.color: isLaunching ? Theme.primary : (isSelected ? Theme.primary : "transparent")
                            border.width: isLaunching ? 1 : (isSelected ? 1 : 0)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: root.getIconName(fileName, fileIsDir)
                                    size: 20
                                    color: root.getIconColor(fileName, fileIsDir)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: fileName
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - 32
                                }
                            }

                            MouseArea {
                                id: listItemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        root.selectedFilePath = listDelegateRoot.filePath;
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        quickMenu.currentPath = listDelegateRoot.filePath;
                                        quickMenu.currentName = listDelegateRoot.fileName;
                                        quickMenu.currentIsDir = listDelegateRoot.fileIsDir;
                                        
                                        const globalPos = mapToItem(root, mouse.x, mouse.y);
                                        quickMenu.parent = root;
                                        quickMenu.x = Math.max(0, Math.min(root.width - quickMenu.width, globalPos.x));
                                        quickMenu.y = Math.max(0, Math.min(root.height - quickMenu.height, globalPos.y));
                                        quickMenu.open();
                                    }
                                }

                                onDoubleClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        listDelegateRoot.isLaunching = true;
                                        Quickshell.execDetached(["xdg-open", listDelegateRoot.filePath]);
                                        listLaunchTimer.restart();
                                    }
                                }
                            }
                        }
                    }
                }

                // Compact View of files (1 or 2 columns list layout)
                GridView {
                    id: fileCompact
                    anchors.fill: parent
                    cellWidth: parent.width > 280 ? parent.width / 2 : parent.width
                    cellHeight: 30
                    model: folderModel
                    visible: root.viewMode === "compact"
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // Smooth add/remove transitions
                    add: Transition {
                        NumberAnimation { properties: "opacity,scale"; from: 0; to: 1.0; duration: 200 }
                    }
                    remove: Transition {
                        NumberAnimation { properties: "opacity,scale"; to: 0; duration: 150 }
                    }

                    delegate: Item {
                        id: compactDelegateRoot
                        width: fileCompact.cellWidth
                        height: fileCompact.cellHeight

                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property int index

                        readonly property bool isSelected: root.selectedFilePath === filePath
                        property bool isLaunching: false

                        Timer {
                            id: compactLaunchTimer
                            interval: 800
                            repeat: false
                            onTriggered: compactDelegateRoot.isLaunching = false
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingXS
                            anchors.rightMargin: Theme.spacingXS
                            radius: Theme.cornerRadius - 2
                            color: isLaunching 
                                ? Theme.withAlpha(Theme.primary, 0.3)
                                : (isSelected 
                                    ? Theme.withAlpha(Theme.primary, 0.15) 
                                    : (compactItemHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent"))
                            border.color: isLaunching ? Theme.primary : (isSelected ? Theme.primary : "transparent")
                            border.width: isLaunching ? 1 : (isSelected ? 1 : 0)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: root.getIconName(fileName, fileIsDir)
                                    size: 16
                                    color: root.getIconColor(fileName, fileIsDir)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: fileName
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideRight
                                    width: parent.width - 28
                                }
                            }

                            MouseArea {
                                id: compactItemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        root.selectedFilePath = compactDelegateRoot.filePath;
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        quickMenu.currentPath = compactDelegateRoot.filePath;
                                        quickMenu.currentName = compactDelegateRoot.fileName;
                                        quickMenu.currentIsDir = compactDelegateRoot.fileIsDir;
                                        
                                        const globalPos = mapToItem(root, mouse.x, mouse.y);
                                        quickMenu.parent = root;
                                        quickMenu.x = Math.max(0, Math.min(root.width - quickMenu.width, globalPos.x));
                                        quickMenu.y = Math.max(0, Math.min(root.height - quickMenu.height, globalPos.y));
                                        quickMenu.open();
                                    }
                                }

                                onDoubleClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        compactDelegateRoot.isLaunching = true;
                                        Quickshell.execDetached(["xdg-open", compactDelegateRoot.filePath]);
                                        compactLaunchTimer.restart();
                                    }
                                }
                            }
                        }
                    }
                }

                // Placeholder when Desktop is empty
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    visible: folderModel.count === 0 && folderModel.status === FolderListModel.Ready
                    width: parent.width * 0.8

                    DankIcon {
                        name: "folder_open"
                        size: 48
                        color: Theme.surfaceText
                        opacity: 0.25
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: root.folderDisplayName + " " + I18n.tr("is empty")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        opacity: 0.4
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    // Persist dimensions when resized
    onWidgetWidthChanged: {
        if (pluginService && widgetWidth !== pluginData.widgetWidth) {
            pluginService.savePluginData(pluginId, "widgetWidth", widgetWidth);
        }
    }

    onWidgetHeightChanged: {
        if (pluginService && widgetHeight !== pluginData.widgetHeight) {
            pluginService.savePluginData(pluginId, "widgetHeight", widgetHeight);
        }
    }

    // Quick Action Menu on Middle Click
    Popup {
        id: quickMenu
        width: 180
        height: menuColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string currentPath: ""
        property string currentName: ""
        property bool currentIsDir: false

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: [
                        {
                            text: I18n.tr("Open"),
                            icon: "open_in_new",
                            action: function() {
                                quickMenu.close();
                                Quickshell.execDetached(["xdg-open", quickMenu.currentPath]);
                            }
                        },
                        {
                            text: I18n.tr("Copy"),
                            icon: "content_copy",
                            action: function() {
                                quickMenu.close();
                                const uri = "file://" + quickMenu.currentPath;
                                const cmd = "echo -ne \"copy\\n" + uri + "\" | wl-copy -t x-special/gnome-copied-files";
                                Quickshell.execDetached(["bash", "-c", cmd]);
                                ToastService.showToast(I18n.tr("File Copied") + ": " + quickMenu.currentName, ToastService.levelInfo);
                            }
                        },
                        {
                            text: I18n.tr("Copy Path"),
                            icon: "content_copy",
                            action: function() {
                                quickMenu.close();
                                Quickshell.execDetached(["dms", "cl", "copy", quickMenu.currentPath]);
                                ToastService.showToast(I18n.tr("Copied to Clipboard") + ": " + quickMenu.currentName, ToastService.levelInfo);
                            }
                        },
                        {
                            text: I18n.tr("Rename"),
                            icon: "edit",
                            action: function() {
                                quickMenu.close();
                                renameDialog.showFor(quickMenu.currentPath, quickMenu.currentName, quickMenu.currentIsDir);
                            }
                        },
                        {
                            text: I18n.tr("Move to Trash"),
                            icon: "delete",
                            dangerous: true,
                            action: function() {
                                quickMenu.close();
                                Quickshell.execDetached(["gio", "trash", quickMenu.currentPath]);
                            }
                        }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius - 2
                        color: menuArea.containsMouse 
                            ? (modelData.dangerous ? Theme.withAlpha(Theme.error, 0.15) : Theme.withAlpha(Theme.primary, 0.15)) 
                            : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: 14
                                color: modelData.dangerous && menuArea.containsMouse ? Theme.error : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.text
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.dangerous && menuArea.containsMouse ? Theme.error : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: menuArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.action()
                        }
                    }
                }
            }
        }
    }

    // Rename Dialog
    Popup {
        id: renameDialog
        parent: root
        width: 260
        height: 156
        anchors.centerIn: parent
        padding: 0
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string filePath: ""
        property string oldName: ""
        property string fileExt: ""
        property bool isDir: false
        property var inputField: null

        onOpened: {
            Qt.callLater(() => {
                if (renameDialog.inputField) {
                    renameDialog.inputField.forceActiveFocus();
                    renameDialog.inputField.selectAll();
                }
            });
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                StyledText {
                    text: I18n.tr("Rename")
                    font.bold: true
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankTextField {
                        id: renameField
                        width: parent.width - (extLabel.visible ? extLabel.implicitWidth + Theme.spacingS : 0)
                        placeholderText: I18n.tr("Enter new name...")
                        focus: true
                        onAccepted: renameDialog.performRename()

                        Component.onCompleted: {
                            renameDialog.inputField = renameField;
                        }
                    }

                    StyledText {
                        id: extLabel
                        text: renameDialog.fileExt
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        opacity: 0.6
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    layoutDirection: Qt.RightToLeft

                    DankButton {
                        text: I18n.tr("Rename")
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        onClicked: renameDialog.performRename()
                    }

                    DankButton {
                        text: I18n.tr("Cancel")
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.surfaceText
                        onClicked: renameDialog.close()
                    }
                }
            }
        }

        function showFor(path, name, isDirectory) {
            let cleanPath = String(path);
            if (cleanPath.startsWith("file://")) {
                cleanPath = cleanPath.substring(7);
            }
            if (cleanPath.startsWith("localhost/")) {
                cleanPath = cleanPath.substring(9);
            }
            renameDialog.filePath = cleanPath;
            renameDialog.oldName = name;
            renameDialog.isDir = !!isDirectory;

            let baseName = name;
            let extension = "";
            if (!renameDialog.isDir) {
                const lastDot = name.lastIndexOf(".");
                if (lastDot > 0) {
                    baseName = name.substring(0, lastDot);
                    extension = name.substring(lastDot);
                }
            }
            renameDialog.fileExt = extension;

            if (renameDialog.inputField) {
                renameDialog.inputField.text = baseName;
            }
            renameDialog.open();
        }

        function performRename() {
            try {
                if (!renameDialog.inputField) {
                    ToastService.showToast("Rename debug: inputField is null", ToastService.levelError);
                    renameDialog.close();
                    return;
                }

                const newBaseName = renameDialog.inputField.text.trim();
                const newName = newBaseName + renameDialog.fileExt;
                ToastService.showToast("Rename debug: new=" + newName + " old=" + renameDialog.oldName, ToastService.levelInfo);

                if (newName.length === 0 || newName === renameDialog.oldName) {
                    renameDialog.close();
                    return;
                }

                let pathStr = String(renameDialog.filePath);
                ToastService.showToast("Rename debug: path=" + pathStr, ToastService.levelInfo);

                if (pathStr.startsWith("file://")) {
                    pathStr = pathStr.substring(7);
                }
                if (pathStr.startsWith("localhost/")) {
                    pathStr = pathStr.substring(9);
                }
                if (!pathStr || pathStr.length === 0) {
                    renameDialog.close();
                    return;
                }

                const parts = pathStr.split("/");
                parts.pop();
                const dirPath = parts.join("/");
                const newPath = dirPath + "/" + newName;

                ToastService.showToast("Rename debug: mv " + pathStr + " -> " + newPath, ToastService.levelInfo);

                Quickshell.execDetached(["mv", pathStr, newPath]);
            } catch (e) {
                ToastService.showToast("Rename error: " + e.message, ToastService.levelError);
            }
            renameDialog.close();
        }
    }

    // Folder Switcher Dropdown Popup
    Popup {
        id: folderDropdown
        parent: folderSelectorBtn
        width: 140
        height: folderDropdownColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: 0
        y: folderSelectorBtn.height + 4

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1

            Column {
                id: folderDropdownColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: [
                        { label: I18n.tr("Desktop"), value: "desktop", icon: "desktop_mac" },
                        { label: I18n.tr("Downloads"), value: "downloads", icon: "download" },
                        { label: I18n.tr("Music"), value: "music", icon: "music_note" },
                        { label: I18n.tr("Videos"), value: "videos", icon: "movie" },
                        { label: I18n.tr("Documents"), value: "documents", icon: "description" },
                        { label: I18n.tr("Custom..."), value: "custom", icon: "folder" }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius - 2
                        color: dropdownItemArea.containsMouse 
                            ? Theme.withAlpha(Theme.primary, 0.15) 
                            : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: 14
                                color: root.folderType === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.folderType === modelData.value
                                color: root.folderType === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: dropdownItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                folderDropdown.close();
                                if (modelData.value === "custom") {
                                    folderPickerDialog.open();
                                } else {
                                    if (pluginService) {
                                        pluginService.savePluginData(pluginId, "folderType", modelData.value);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // View Mode Dropdown Popup
    Popup {
        id: viewModeDropdown
        parent: viewModeBtn
        width: 130
        height: viewModeDropdownColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: viewModeBtn.width - viewModeDropdown.width
        y: viewModeBtn.height + 4

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1

            Column {
                id: viewModeDropdownColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: [
                        { label: I18n.tr("Grid View"), value: "grid", icon: "grid_view" },
                        { label: I18n.tr("List View"), value: "list", icon: "view_list" },
                        { label: I18n.tr("Compact View"), value: "compact", icon: "view_stream" }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius - 2
                        color: viewModeArea.containsMouse 
                            ? Theme.withAlpha(Theme.primary, 0.15) 
                            : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: 14
                                color: root.viewMode === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.viewMode === modelData.value
                                color: root.viewMode === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: viewModeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                viewModeDropdown.close();
                                if (pluginService) {
                                    pluginService.savePluginData(pluginId, "viewMode", modelData.value);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Sort By Dropdown Popup
    Popup {
        id: sortByDropdown
        parent: sortByBtn
        width: 140
        height: sortByDropdownColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: sortByBtn.width - sortByDropdown.width
        y: sortByBtn.height + 4

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1

            Column {
                id: sortByDropdownColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: [
                        { label: I18n.tr("Sort by Name"), value: "name", icon: "sort_by_alpha" },
                        { label: I18n.tr("Sort by Date"), value: "time", icon: "schedule" },
                        { label: I18n.tr("Sort by Size"), value: "size", icon: "bar_chart" },
                        { label: I18n.tr("Sort by Type"), value: "type", icon: "category" }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius - 2
                        color: sortByArea.containsMouse 
                            ? Theme.withAlpha(Theme.primary, 0.15) 
                            : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon
                                size: 14
                                color: root.sortBy === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.sortBy === modelData.value
                                color: root.sortBy === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: sortByArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sortByDropdown.close();
                                if (pluginService) {
                                    pluginService.savePluginData(pluginId, "sortBy", modelData.value);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Native Folder Dialog Selector
    FolderDialog {
        id: folderPickerDialog
        title: I18n.tr("Select Folder")
        currentFolder: root.targetFolderUrl
        onAccepted: {
            let path = String(selectedFolder);
            if (path.startsWith("file://")) {
                path = path.substring(7);
            }
            if (path.startsWith("localhost/")) {
                path = path.substring(9);
            }
            if (pluginService) {
                pluginService.savePluginData(pluginId, "customFolderPath", path);
                pluginService.savePluginData(pluginId, "folderType", "custom");
            }
        }
    }
}
