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
    readonly property double sizeScale: cellSize / 84.0
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
            case "home":
                path = home;
                break;
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
            case "trash":
                path = home + "/.local/share/Trash/files";
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
            case "home": return I18n.tr("Home");
            case "desktop": return I18n.tr("Desktop");
            case "downloads": return I18n.tr("Downloads");
            case "music": return I18n.tr("Music");
            case "videos": return I18n.tr("Videos");
            case "documents": return I18n.tr("Documents");
            case "trash": return I18n.tr("Trash");
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
    property var selectedFilePaths: []
    property string lastSelectedFilePath: ""
    property string searchPattern: ""

    function clearSelection() {
        selectedFilePaths = [];
        lastSelectedFilePath = "";
    }

    function toggleSelection(filePath) {
        let arr = [...selectedFilePaths];
        let idx = arr.indexOf(filePath);
        if (idx === -1) {
            arr.push(filePath);
        } else {
            arr.splice(idx, 1);
        }
        selectedFilePaths = arr;
        lastSelectedFilePath = filePath;
        selectionClearTimer.restart();
    }

    function selectSingle(filePath) {
        selectedFilePaths = [filePath];
        lastSelectedFilePath = filePath;
        selectionClearTimer.restart();
    }

    function selectRangeTo(currentIndex) {
        if (lastSelectedFilePath === "") {
            if (filteredModel.count > currentIndex) {
                selectSingle(filteredModel.get(currentIndex).filePath);
            }
            return;
        }

        let lastIndex = -1;
        for (let i = 0; i < filteredModel.count; i++) {
            if (filteredModel.get(i).filePath === lastSelectedFilePath) {
                lastIndex = i;
                break;
            }
        }

        if (lastIndex === -1) {
            if (filteredModel.count > currentIndex) {
                selectSingle(filteredModel.get(currentIndex).filePath);
            }
            return;
        }

        let start = Math.min(lastIndex, currentIndex);
        let end = Math.max(lastIndex, currentIndex);
        let newSelection = [...selectedFilePaths];

        for (let i = start; i <= end; i++) {
            let path = filteredModel.get(i).filePath;
            if (newSelection.indexOf(path) === -1) {
                newSelection.push(path);
            }
        }
        selectedFilePaths = newSelection;
        selectionClearTimer.restart();
    }

    function _cleanPath(url) {
        let path = String(url);
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        if (path.startsWith("localhost/")) {
            path = path.substring(9);
        }
        return path;
    }

    function pasteFromClipboard() {
        let scriptPath = root._cleanPath(Qt.resolvedUrl("paste.py"));
        let pathStr = root._cleanPath(root.targetFolderUrl);
        
        ToastService.showToast(I18n.tr("Pasting files..."), ToastService.levelInfo);
        Quickshell.execDetached([scriptPath, pathStr]);
    }

    onSelectedFilePathsChanged: {
        if (selectedFilePaths.length > 0) {
            selectionClearTimer.restart();
        } else {
            selectionClearTimer.stop();
        }
    }

    Timer {
        id: selectionClearTimer
        interval: 5000 // 5 seconds of inactivity
        repeat: false
        onTriggered: {
            if (!renameDialog.opened && !quickMenu.opened) {
                clearSelection();
            } else {
                selectionClearTimer.restart();
            }
        }
    }

    ListModel {
        id: filteredModel
    }

    function updateFilteredModel() {
        filteredModel.clear();
        if (folderModel.status !== FolderListModel.Ready) return;
        
        const pattern = root.searchPattern.toLowerCase();
        for (let i = 0; i < folderModel.count; i++) {
            try {
                const fName = folderModel.get(i, "fileName");
                const fPath = folderModel.get(i, "filePath");
                const fIsDir = folderModel.get(i, "fileIsDir");
                
                if (fName === undefined || fName === null || fPath === undefined || fPath === null) {
                    continue;
                }
                
                const nameStr = String(fName);
                if (pattern === "" || nameStr.toLowerCase().indexOf(pattern) !== -1) {
                    filteredModel.append({
                        filePath: String(fPath),
                        fileName: nameStr,
                        fileIsDir: !!fIsDir,
                        index: i
                    });
                }
            } catch (e) {
                console.log("Error processing file at index " + i + ": " + e);
            }
        }
    }

    onSearchPatternChanged: updateFilteredModel()

    Connections {
        target: folderModel
        function onStatusChanged() {
            if (folderModel.status === FolderListModel.Ready) {
                updateFilteredModel();
            }
        }
        function onCountChanged() {
            updateFilteredModel();
        }
    }

    function isImage(fileName) {
        const ext = fileName.split('.').pop().toLowerCase();
        return ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp"].indexOf(ext) !== -1;
    }

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

                        StyledText {
                            text: {
                                let count = folderModel.count;
                                let selected = root.selectedFilePaths.length;
                                let str = "(" + count + ")";
                                if (selected > 0) {
                                    str += " [" + selected + " selected]";
                                }
                                return str;
                            }
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.surfaceVariantText
                            opacity: 0.6
                            anchors.verticalCenter: parent.verticalCenter
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

                // Right: Controls (Search, View Mode & Sort By)
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    // Premium Dynamic Expanding Search Input
                    Rectangle {
                        id: headerSearchContainer
                        
                        // Explicitly expanded state matching App Launcher design
                        property bool expanded: false
                        
                        width: expanded ? 120 : 20
                        height: 20
                        radius: 10
                        color: expanded 
                            ? Theme.withAlpha(Theme.surfaceText, headerSearchField.activeFocus ? 0.12 : 0.08) 
                            : "transparent"
                        border.color: expanded 
                            ? (headerSearchField.activeFocus ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.3)) 
                            : "transparent"
                        border.width: expanded ? 1 : 0
                        
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Clicking on the container focuses the text input (which triggers expansion)
                        MouseArea {
                            anchors.fill: parent
                            visible: !headerSearchContainer.expanded
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                headerSearchContainer.expanded = true;
                                headerSearchField.forceActiveFocus();
                            }
                        }

                        DankIcon {
                            id: headerSearchIcon
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: headerSearchContainer.expanded ? 4 : (headerSearchContainer.width - size) / 2
                            name: "search"
                            size: 14
                            color: Theme.surfaceText
                            opacity: headerSearchField.activeFocus ? 1.0 : (headerSearchContainer.expanded ? 0.6 : 0.7)
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        TextInput {
                            id: headerSearchField
                            anchors.left: headerSearchIcon.right
                            anchors.leftMargin: 4
                            anchors.right: headerClearBtn.visible ? headerClearBtn.left : parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceText
                            selectByMouse: true
                            visible: headerSearchContainer.expanded
                            opacity: headerSearchContainer.expanded ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            
                            // Placeholder Text
                            Text {
                                text: I18n.tr("Search...")
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.surfaceText
                                opacity: 0.35
                                visible: headerSearchField.text === "" && !headerSearchField.activeFocus
                            }

                            onTextChanged: root.searchPattern = text.trim()
                        }

                        // Clear and Collapse button
                        MouseArea {
                            id: headerClearBtn
                            width: 12
                            height: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: headerSearchContainer.expanded
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            
                            DankIcon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 10
                                color: Theme.surfaceText
                                opacity: headerClearBtn.containsMouse ? 0.9 : 0.5
                            }

                            onClicked: {
                                headerSearchField.text = "";
                                root.searchPattern = "";
                                headerSearchField.focus = false;
                                headerSearchContainer.expanded = false;
                            }
                        }
                    }

                    // Create Button (New Folder / New File)
                    MouseArea {
                        id: createBtn
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: createDropdown.open()

                        DankIcon {
                            anchors.centerIn: parent
                            name: "add"
                            size: 16
                            color: createBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: createBtn.containsMouse ? 1.0 : 0.7
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

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

                    // Icon Size Button
                    MouseArea {
                        id: sizeBtn
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sizeDropdown.open()

                        DankIcon {
                            anchors.centerIn: parent
                            name: "zoom_in"
                            size: 16
                            color: sizeBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: sizeBtn.containsMouse ? 1.0 : 0.7
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }
            }
            // Grid View container
            Item {
                width: parent.width
                height: parent.height - (root.showHeader ? headerContainer.height + parent.spacing : 0)
                clip: true

                FolderListModel {
                    id: folderModel
                    folder: root.targetFolderUrl
                    showDirsFirst: true
                    showHidden: root.showHidden
                    sortField: root.folderSortField
                }

                GridView {
                    id: fileGrid
                    anchors.fill: parent
                    cellWidth: root.cellSize
                    cellHeight: root.cellSize + 16
                    model: filteredModel
                    visible: root.viewMode === "grid"
                    boundsBehavior: Flickable.StopAtBounds

                    MouseArea {
                        id: fileGridBackground
                        z: -1
                        width: Math.max(fileGrid.width, fileGrid.contentWidth)
                        height: Math.max(fileGrid.height, fileGrid.contentHeight)
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                root.clearSelection();
                            } else if (mouse.button === Qt.MiddleButton) {
                                root.pasteFromClipboard();
                            }
                        }
                    }

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

                        readonly property bool isSelected: root.selectedFilePaths.indexOf(filePath) !== -1
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
                                FolderViewThumbnail {
                                    width: parent.width
                                    height: parent.height - 30
                                    filePath: delegateRoot.filePath
                                    fileName: delegateRoot.fileName
                                    isDir: delegateRoot.fileIsDir
                                    sizeScale: root.sizeScale
                                    hover: itemHover.containsMouse
                                }

                                // File/Folder Name
                                StyledText {
                                    width: parent.width
                                    text: fileName
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceText
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: (isSelected && root.selectedFilePaths.length === 1) ? Text.ElideNone : Text.ElideMiddle
                                    maximumLineCount: (isSelected && root.selectedFilePaths.length === 1) ? 10 : 2
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
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            root.toggleSelection(delegateRoot.filePath);
                                        } else if (mouse.modifiers & Qt.ShiftModifier) {
                                            root.selectRangeTo(delegateRoot.index);
                                        } else {
                                            root.selectSingle(delegateRoot.filePath);
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        if (root.selectedFilePaths.indexOf(delegateRoot.filePath) === -1) {
                                            root.selectSingle(delegateRoot.filePath);
                                        }

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
                                        Quickshell.execDetached(["gio", "open", root._cleanPath(delegateRoot.filePath)]);
                                        root.clearSelection();
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
                    model: filteredModel
                    visible: root.viewMode === "list"
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 2
                    clip: true

                    MouseArea {
                        id: fileListBackground
                        z: -1
                        width: Math.max(fileList.width, fileList.contentWidth)
                        height: Math.max(fileList.height, fileList.contentHeight)
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                root.clearSelection();
                            } else if (mouse.button === Qt.MiddleButton) {
                                root.pasteFromClipboard();
                            }
                        }
                    }

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
                        height: (isSelected && root.selectedFilePaths.length === 1) ? Math.max(Math.round(36 * root.sizeScale), listRow.implicitHeight + 8) : Math.round(36 * root.sizeScale)

                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property int index

                        readonly property bool isSelected: root.selectedFilePaths.indexOf(filePath) !== -1
                        property bool isLaunching: false

                        SequentialAnimation {
                            id: listLaunchPulse
                            running: false
                            NumberAnimation { target: listDelegateRoot; property: "scale"; to: 0.98; duration: 100; easing.type: Easing.OutQuad }
                            NumberAnimation { target: listDelegateRoot; property: "scale"; to: 1.02; duration: 150; easing.type: Easing.OutBack }
                            NumberAnimation { target: listDelegateRoot; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                        }

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
                                id: listRow
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: (isSelected && root.selectedFilePaths.length === 1) ? undefined : parent.verticalCenter
                                anchors.top: (isSelected && root.selectedFilePaths.length === 1) ? parent.top : undefined
                                anchors.topMargin: (isSelected && root.selectedFilePaths.length === 1) ? 4 : 0

                                FolderViewThumbnail {
                                    width: Math.round(20 * root.sizeScale)
                                    height: width
                                    anchors.verticalCenter: (isSelected && root.selectedFilePaths.length === 1) ? undefined : parent.verticalCenter
                                    anchors.top: (isSelected && root.selectedFilePaths.length === 1) ? parent.top : undefined
                                    filePath: listDelegateRoot.filePath
                                    fileName: listDelegateRoot.fileName
                                    isDir: listDelegateRoot.fileIsDir
                                    sizeScale: root.sizeScale
                                    hover: listItemHover.containsMouse
                                }

                                StyledText {
                                    text: fileName
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: (isSelected && root.selectedFilePaths.length === 1) ? undefined : parent.verticalCenter
                                    anchors.top: (isSelected && root.selectedFilePaths.length === 1) ? parent.top : undefined
                                    elide: (isSelected && root.selectedFilePaths.length === 1) ? Text.ElideNone : Text.ElideMiddle
                                    wrapMode: (isSelected && root.selectedFilePaths.length === 1) ? Text.WrapAnywhere : Text.NoWrap
                                    maximumLineCount: (isSelected && root.selectedFilePaths.length === 1) ? 5 : 1
                                    width: parent.width - Math.round(20 * root.sizeScale) - 12
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
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            root.toggleSelection(listDelegateRoot.filePath);
                                        } else if (mouse.modifiers & Qt.ShiftModifier) {
                                            root.selectRangeTo(listDelegateRoot.index);
                                        } else {
                                            root.selectSingle(listDelegateRoot.filePath);
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        if (root.selectedFilePaths.indexOf(listDelegateRoot.filePath) === -1) {
                                            root.selectSingle(listDelegateRoot.filePath);
                                        }

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
                                        listLaunchPulse.restart();
                                        Quickshell.execDetached(["gio", "open", root._cleanPath(listDelegateRoot.filePath)]);
                                        listLaunchTimer.restart();
                                        root.clearSelection();
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
                    cellHeight: Math.round(30 * root.sizeScale)
                    model: filteredModel
                    visible: root.viewMode === "compact"
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    MouseArea {
                        id: fileCompactBackground
                        z: -1
                        width: Math.max(fileCompact.width, fileCompact.contentWidth)
                        height: Math.max(fileCompact.height, fileCompact.contentHeight)
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                root.clearSelection();
                            } else if (mouse.button === Qt.MiddleButton) {
                                root.pasteFromClipboard();
                            }
                        }
                    }

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
                        height: (isSelected && root.selectedFilePaths.length === 1) ? Math.max(Math.round(30 * root.sizeScale), compactRow.implicitHeight + 8) : Math.round(30 * root.sizeScale)

                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property int index

                        readonly property bool isSelected: root.selectedFilePaths.indexOf(filePath) !== -1
                        property bool isLaunching: false

                        SequentialAnimation {
                            id: compactLaunchPulse
                            running: false
                            NumberAnimation { target: compactDelegateRoot; property: "scale"; to: 0.98; duration: 100; easing.type: Easing.OutQuad }
                            NumberAnimation { target: compactDelegateRoot; property: "scale"; to: 1.02; duration: 150; easing.type: Easing.OutBack }
                            NumberAnimation { target: compactDelegateRoot; property: "scale"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                        }

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
                                id: compactRow
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: (isSelected && root.selectedFilePaths.length === 1) ? undefined : parent.verticalCenter
                                anchors.top: (isSelected && root.selectedFilePaths.length === 1) ? parent.top : undefined
                                anchors.topMargin: (isSelected && root.selectedFilePaths.length === 1) ? 4 : 0

                                FolderViewThumbnail {
                                    width: Math.round(16 * root.sizeScale)
                                    height: width
                                    anchors.verticalCenter: (isSelected && root.selectedFilePaths.length === 1) ? undefined : parent.verticalCenter
                                    anchors.top: (isSelected && root.selectedFilePaths.length === 1) ? parent.top : undefined
                                    filePath: compactDelegateRoot.filePath
                                    fileName: compactDelegateRoot.fileName
                                    isDir: compactDelegateRoot.fileIsDir
                                    sizeScale: root.sizeScale
                                    hover: compactItemHover.containsMouse
                                }

                                StyledText {
                                    text: fileName
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: (isSelected && root.selectedFilePaths.length === 1) ? undefined : parent.verticalCenter
                                    anchors.top: (isSelected && root.selectedFilePaths.length === 1) ? parent.top : undefined
                                    elide: (isSelected && root.selectedFilePaths.length === 1) ? Text.ElideNone : Text.ElideMiddle
                                    wrapMode: (isSelected && root.selectedFilePaths.length === 1) ? Text.WrapAnywhere : Text.NoWrap
                                    maximumLineCount: (isSelected && root.selectedFilePaths.length === 1) ? 5 : 1
                                    width: parent.width - Math.round(16 * root.sizeScale) - 12
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
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            root.toggleSelection(compactDelegateRoot.filePath);
                                        } else if (mouse.modifiers & Qt.ShiftModifier) {
                                            root.selectRangeTo(compactDelegateRoot.index);
                                        } else {
                                            root.selectSingle(compactDelegateRoot.filePath);
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        if (root.selectedFilePaths.indexOf(compactDelegateRoot.filePath) === -1) {
                                            root.selectSingle(compactDelegateRoot.filePath);
                                        }

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
                                        compactLaunchPulse.restart();
                                        Quickshell.execDetached(["gio", "open", root._cleanPath(compactDelegateRoot.filePath)]);
                                        compactLaunchTimer.restart();
                                        root.clearSelection();
                                    }
                                }
                            }
                        }
                    }
                }

                // Placeholder when folder is empty or search returns no results
                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM
                    visible: filteredModel.count === 0 && folderModel.status === FolderListModel.Ready
                    width: parent.width * 0.8

                    DankIcon {
                        name: folderModel.count === 0 ? "folder_open" : "search_off"
                        size: 48
                        color: Theme.surfaceText
                        opacity: 0.25
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: folderModel.count === 0 
                            ? root.folderDisplayName + " " + I18n.tr("is empty") 
                            : I18n.tr("No search results found")
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
                            visible: true,
                            action: function() {
                                quickMenu.close();
                                for (let path of root.selectedFilePaths) {
                                  Quickshell.execDetached(["gio", "open", root._cleanPath(path)]);
                                }
                                root.clearSelection();
                            }
                        },
                        {
                            text: I18n.tr("Copy"),
                            icon: "content_copy",
                            visible: true,
                            action: function() {
                                quickMenu.close();
                                let uris = [];
                                for (let path of root.selectedFilePaths) {
                                    uris.push("file://" + path);
                                }
                                const cmd = "echo -ne \"copy\\n" + uris.join("\\n") + "\" | wl-copy -t x-special/gnome-copied-files";
                                Quickshell.execDetached(["bash", "-c", cmd]);
                                
                                let label = root.selectedFilePaths.length > 1
                                    ? I18n.tr("Copied %1 items").arg(root.selectedFilePaths.length)
                                    : I18n.tr("File Copied") + ": " + quickMenu.currentName;
                                ToastService.showToast(label, ToastService.levelInfo);
                            }
                        },
                        {
                            text: I18n.tr("Copy Path"),
                            icon: "content_copy",
                            visible: true,
                            action: function() {
                                quickMenu.close();
                                const joinedPaths = root.selectedFilePaths.join("\n");
                                Quickshell.execDetached(["dms", "cl", "copy", joinedPaths]);
                                
                                let label = root.selectedFilePaths.length > 1
                                    ? I18n.tr("Copied %1 paths").arg(root.selectedFilePaths.length)
                                    : I18n.tr("Copied to Clipboard") + ": " + quickMenu.currentName;
                                ToastService.showToast(label, ToastService.levelInfo);
                            }
                        },
                        {
                            text: I18n.tr("Rename"),
                            icon: "edit",
                            visible: root.selectedFilePaths.length <= 1,
                            action: function() {
                                quickMenu.close();
                                renameDialog.showFor(quickMenu.currentPath, quickMenu.currentName, quickMenu.currentIsDir);
                            }
                        },
                        {
                            text: I18n.tr("Info"),
                            icon: "info",
                            visible: root.selectedFilePaths.length <= 1,
                            action: function() {
                                quickMenu.close();
                                infoDialog.showFor(quickMenu.currentPath, quickMenu.currentName, quickMenu.currentIsDir);
                            }
                        },
                        { isSeparator: true },
                        {
                            text: I18n.tr("Move to Trash"),
                            icon: "delete",
                            dangerous: true,
                            visible: true,
                            action: function() {
                                quickMenu.close();
                                const cleanPaths = root.selectedFilePaths.map(p => root._cleanPath(p));
                                Quickshell.execDetached(["gio", "trash"].concat(cleanPaths));
                                root.clearSelection();
                            }
                        }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        property bool isSeparator: !!modelData.isSeparator
                        property bool itemVisible: modelData.visible !== undefined ? modelData.visible : true
                        visible: itemVisible
                        height: !itemVisible ? 0 : (isSeparator ? 9 : 28)
                        radius: isSeparator ? 0 : Theme.cornerRadius - 2
                        color: isSeparator 
                            ? "transparent"
                            : (menuArea.containsMouse 
                                ? (modelData.dangerous ? Theme.withAlpha(Theme.error, 0.15) : Theme.withAlpha(Theme.primary, 0.15)) 
                                : "transparent")

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - Theme.spacingS * 2
                            height: 1
                            color: Theme.withAlpha(Theme.outline, 0.15)
                            visible: isSeparator
                        }

                        Row {
                            visible: !isSeparator
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: modelData.icon || ""
                                size: 14
                                color: modelData.dangerous && menuArea.containsMouse ? Theme.error : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !isSeparator && parent.parent.itemVisible
                            }

                            StyledText {
                                text: modelData.text || ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.dangerous && menuArea.containsMouse ? Theme.error : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                visible: !isSeparator && parent.parent.itemVisible
                            }
                        }

                        MouseArea {
                            id: menuArea
                            anchors.fill: parent
                            enabled: !isSeparator
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
    FolderViewRenameDialog {
        id: renameDialog
        parent: root
    }

    // Info Dialog
    FolderViewInfoDialog {
        id: infoDialog
        parent: root
    }

    // Create Folder/File Dialog
    FolderViewCreateDialog {
        id: createDialog
        parent: root
        targetFolderUrl: root.targetFolderUrl
    }

    // Folder Switcher Dropdown Popup
    Popup {
        id: folderDropdown
        parent: folderSelectorBtn
        width: 140
        height: folderDropdownColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        dim: false
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
                        { label: I18n.tr("Home"), value: "home", icon: "home" },
                        { label: I18n.tr("Desktop"), value: "desktop", icon: "desktop_mac" },
                        { label: I18n.tr("Downloads"), value: "downloads", icon: "download" },
                        { label: I18n.tr("Music"), value: "music", icon: "music_note" },
                        { label: I18n.tr("Videos"), value: "videos", icon: "movie" },
                        { label: I18n.tr("Documents"), value: "documents", icon: "description" },
                        { label: I18n.tr("Trash"), value: "trash", icon: "delete" },
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

    // Create Dropdown Popup
    Popup {
        id: createDropdown
        parent: createBtn
        width: 140
        height: createDropdownColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: createBtn.width - createDropdown.width
        y: createBtn.height + 4

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1

            Column {
                id: createDropdownColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: [
                        { label: I18n.tr("New Folder"), value: "folder", icon: "create_new_folder" },
                        { label: I18n.tr("New Document"), value: "file", icon: "note_add" }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius - 2
                        color: createDropdownItemArea.containsMouse 
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
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: createDropdownItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                createDropdown.close();
                                createDialog.showFor(modelData.value === "folder");
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
        modal: true
        dim: false
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
        modal: true
        dim: false
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

    // Size Dropdown Popup
    Popup {
        id: sizeDropdown
        parent: sizeBtn
        width: 140
        height: sizeDropdownColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: sizeBtn.width - sizeDropdown.width
        y: sizeBtn.height + 4

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1

            Column {
                id: sizeDropdownColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 2

                Repeater {
                    model: [
                        { label: I18n.tr("Small (64px)"), value: 64, icon: "photo_size_select_small" },
                        { label: I18n.tr("Medium (84px)"), value: 84, icon: "photo_size_select_large" },
                        { label: I18n.tr("Large (104px)"), value: 104, icon: "photo_size_select_actual" },
                        { label: I18n.tr("Extra Large (128px)"), value: 128, icon: "aspect_ratio" }
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 28
                        radius: Theme.cornerRadius - 2
                        color: sizeArea.containsMouse 
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
                                color: root.cellSize === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.cellSize === modelData.value
                                color: root.cellSize === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: sizeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sizeDropdown.close();
                                if (pluginService) {
                                    pluginService.savePluginData(pluginId, "cellSize", modelData.value);
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
            let path = root._cleanPath(selectedFolder);
            if (pluginService) {
                pluginService.savePluginData(pluginId, "customFolderPath", path);
                pluginService.savePluginData(pluginId, "folderType", "custom");
            }
        }
    }
}
