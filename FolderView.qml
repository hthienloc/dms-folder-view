import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import QtQuick.Dialogs
import "./dms-common"

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
    readonly property real borderOpacity: (pluginData.borderOpacity ?? 0) / 100
    readonly property bool showHidden: pluginData.showHidden ?? false
    readonly property int cellSize: pluginData.cellSize ?? 84
    readonly property double sizeScale: cellSize / 84.0
    readonly property string sortBy: pluginData.sortBy ?? "name"
    readonly property string viewMode: pluginData.viewMode ?? "grid"
    readonly property string headerPosition: pluginData.headerPosition ?? "top"
    readonly property bool showHeader: pluginData.showHeader ?? true
    readonly property var pinnedPaths: pluginData.pinnedPaths ?? []
    onPinnedPathsChanged: updateFilteredModel()

    property var stacks: pluginData.stacks ?? []
    onStacksChanged: updateFilteredModel()
    property var expandedStackIds: []

    readonly property bool isScrolledDown: {
        if (viewMode === "grid") {
            return (typeof fileGrid !== "undefined" && fileGrid) ? fileGrid.contentY > 50 : false;
        }
        if (viewMode === "list") {
            return (typeof fileList !== "undefined" && fileList) ? fileList.contentY > 50 : false;
        }
        if (viewMode === "compact") {
            return (typeof fileCompact !== "undefined" && fileCompact) ? fileCompact.contentY > 50 : false;
        }
        return false;
    }

    // Resolved Folder Settings & URL
    readonly property string folderType: pluginData.folderType ?? "desktop"
    readonly property string customFolderPath: pluginData.customFolderPath ?? ""

    readonly property string targetFolderUrl: {
        switch (folderType) {
            case "home":
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString();
            case "downloads":
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.DownloadLocation).toString();
            case "music":
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.MusicLocation).toString();
            case "pictures":
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.PicturesLocation).toString();
            case "videos":
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.MoviesLocation).toString();
            case "documents":
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.DocumentsLocation).toString();
            case "trash":
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString() + "/.local/share/Trash/files";
            case "custom": {
                if (customFolderPath && customFolderPath.trim() !== "") {
                    const clean = customFolderPath.trim();
                    if (clean.startsWith("~/")) {
                        return Platform.StandardPaths.writableLocation(Platform.StandardPaths.HomeLocation).toString() + clean.substring(1);
                    }
                    return "file://" + clean;
                }
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.DesktopLocation).toString();
            }
            default:
                return Platform.StandardPaths.writableLocation(Platform.StandardPaths.DesktopLocation).toString();
        }
    }

    readonly property string folderDisplayName: {
        switch (folderType) {
            case "home": return I18n.tr("Home");
            case "desktop": return I18n.tr("Desktop");
            case "downloads": return I18n.tr("Downloads");
            case "music": return I18n.tr("Music");
            case "pictures": return I18n.tr("Pictures");
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

    function dragMimeData(filePath) {
        // Dragging an item that is part of the current selection drags the
        // whole selection; otherwise just the pressed item.
        let paths = (root.selectedFilePaths.length > 0 && root.selectedFilePaths.indexOf(filePath) !== -1)
            ? root.selectedFilePaths
            : [filePath];
        paths = paths.filter(p => !String(p).startsWith("stack://")).map(p => root._cleanPath(p));
        const uris = paths.map(p => "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F"));
        return {
            "text/uri-list": uris.join("\r\n") + "\r\n",
            "text/plain": paths.join("\n")
        };
    }

    function launchDesktopFile(path) {
        let cleanPath = root._cleanPath(path);
        let shellCmd = 'cmd=$(grep -m 1 "^Exec=" "' + cleanPath + '" | cut -d= -f2- | sed "s/%[fFuUiIcDkKvV]//g"); exec sh -c "$cmd"';
        Quickshell.execDetached(["sh", "-c", shellCmd]);
    }

    function smartTruncate(name, full, availableWidth, fontSize) {
        if (full || !name || name.length <= 10) return name;
        
        let width = availableWidth && availableWidth > 0 ? availableWidth : 80;
        let size = fontSize && fontSize > 0 ? fontSize : 11;
        
        let avgCharWidth = 0.52 * size;
        let charsPerLine = Math.floor(width / avgCharWidth);
        let limit = Math.max(12, charsPerLine * 2);

        if (name.length <= limit) return name;

        const lastDot = name.lastIndexOf('.');
        if (lastDot <= 0 || name.length - lastDot > 6) {
            return name.substring(0, limit - 3) + "...";
        }

        const ext = name.substring(lastDot);
        const base = name.substring(0, lastDot);
        
        const keepEnd = 2 + ext.length;
        const keepStart = limit - keepEnd - 3;

        if (keepStart < 3) {
            let minLimit = ext.length + 5;
            if (name.length <= minLimit) return name;
            return name.substring(0, Math.max(2, minLimit - ext.length - 3)) + "..." + ext;
        }

        return base.substring(0, keepStart) + "..." + base.substring(base.length - 2) + ext;
    }

    function togglePin(filePath) {
        if (!pluginService) return;
        let pins = [];
        for (let i = 0; i < root.pinnedPaths.length; i++) {
            pins.push(root.pinnedPaths[i]);
        }
        let index = pins.indexOf(filePath);
        if (index !== -1) {
            pins.splice(index, 1);
        } else {
            pins.push(filePath);
        }
        pluginService.savePluginData(pluginId, "pinnedPaths", pins);
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
        let pinnedDirs = [];
        let pinnedFiles = [];
        let unpinnedDirs = [];
        let unpinnedFiles = [];

        // Load stacks in this folder and get list of files in collapsed stacks
        let currentFolderStacks = [];
        let collapsedFilePaths = new Set();
        let fileToExpandedStackMap = {}; // filePath -> stackId
        let expandedStackFilesMap = {}; // stackId -> array of item objects
        try {
            let sList = root.stacks || [];
            currentFolderStacks = sList.filter(s => s.folder === root.targetFolderUrl);
            
            // Sort stacks based on sortBy setting
            if (root.sortBy === "time") {
                currentFolderStacks.sort((a, b) => b.id.localeCompare(a.id));
            } else {
                currentFolderStacks.sort((a, b) => a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: 'base'}));
            }

            for (let s of currentFolderStacks) {
                let isExpanded = root.expandedStackIds.indexOf(s.id) !== -1;
                if (!isExpanded) {
                    for (let p of s.filePaths) {
                        collapsedFilePaths.add(p);
                    }
                } else {
                    for (let p of s.filePaths) {
                        fileToExpandedStackMap[p] = s.id;
                    }
                }
            }
        } catch (e) {
            console.log("Error loading stacks: " + e);
        }

        for (let i = 0; i < folderModel.count; i++) {
            try {
                const fName = folderModel.get(i, "fileName");
                const fPath = folderModel.get(i, "filePath");
                const fIsDir = folderModel.get(i, "fileIsDir");
                const fModified = folderModel.get(i, "fileModified");
                
                if (fName === undefined || fName === null || fPath === undefined || fPath === null) {
                    continue;
                }
                
                const nameStr = String(fName);
                let pathStr = String(fPath);

                // Skip file if it is in a collapsed stack
                if (collapsedFilePaths.has(pathStr)) {
                    continue;
                }
                
                // 1. Search Pattern filter check
                if (pattern !== "" && nameStr.toLowerCase().indexOf(pattern) === -1) {
                    continue;
                }
                
                // 2. File Type filter check
                if (root.filterType !== "all") {
                    if (root.filterType === "folders" && !fIsDir) continue;
                    if (root.filterType === "files" && fIsDir) continue;
                    if (root.filterType === "images" && (fIsDir || !root.isImage(nameStr))) continue;
                    if (root.filterType === "documents" && (fIsDir || !root.isDocument(nameStr))) continue;
                    if (root.filterType === "audio_video" && (fIsDir || !root.isAudioVideo(nameStr))) continue;
                }
                
                // 3. Time filter check
                if (root.filterTime !== "all" && fModified !== undefined && fModified !== null) {
                    const elapsed = new Date() - fModified;
                    if (root.filterTime === "today" && elapsed > 24 * 60 * 60 * 1000) continue;
                    if (root.filterTime === "week" && elapsed > 7 * 24 * 60 * 60 * 1000) continue;
                    if (root.filterTime === "month" && elapsed > 30 * 24 * 60 * 60 * 1000) continue;
                    if (root.filterTime === "year" && elapsed > 365 * 24 * 60 * 60 * 1000) continue;
                }

                let isDesktop = nameStr.endsWith(".desktop") && !fIsDir;
                let item = {
                    filePath: pathStr,
                    fileName: nameStr,
                    fileIsDir: !!fIsDir,
                    isDesktop: isDesktop,
                    appName: "",
                    appIcon: "",
                    appExec: "",
                    isStack: false,
                    isExpanded: false,
                    belongingStackId: ""
                };
                
                let expandedStackId = fileToExpandedStackMap[pathStr];
                if (expandedStackId !== undefined) {
                    item.belongingStackId = expandedStackId;
                    if (!expandedStackFilesMap[expandedStackId]) {
                        expandedStackFilesMap[expandedStackId] = [];
                    }
                    expandedStackFilesMap[expandedStackId].push(item);
                    
                    if (isDesktop) {
                        let safePath = root._cleanPath(pathStr);
                        Proc.runCommand("parseDesktop-" + Math.random(), ["cat", safePath], (out, code) => {
                            if (code === 0 && out) {
                                let aName = "";
                                let aIcon = "";
                                let aExec = "";
                                let lines = out.split('\n');
                                for (let j = 0; j < lines.length; j++) {
                                    let l = lines[j].trim();
                                    if (l.startsWith("Name=") && !aName) aName = l.substring(5).trim();
                                    else if (l.startsWith("Icon=") && !aIcon) aIcon = l.substring(5).trim();
                                    else if (l.startsWith("Exec=") && !aExec) aExec = l.substring(5).trim();
                                }
                                
                                let targetIdx = -1;
                                for (let k = 0; k < filteredModel.count; k++) {
                                    if (filteredModel.get(k).filePath === pathStr) {
                                        targetIdx = k;
                                        break;
                                    }
                                }
                                
                                if (targetIdx !== -1) {
                                    filteredModel.setProperty(targetIdx, "appName", aName);
                                    filteredModel.setProperty(targetIdx, "appIcon", aIcon);
                                    filteredModel.setProperty(targetIdx, "appExec", aExec);
                                }
                            }
                        });
                    }
                    continue; // Skip partitioning to general list
                }

                if (isDesktop) {
                    let safePath = root._cleanPath(pathStr);
                    Proc.runCommand("parseDesktop-" + Math.random(), ["cat", safePath], (out, code) => {
                        if (code === 0 && out) {
                            let aName = "";
                            let aIcon = "";
                            let aExec = "";
                            let lines = out.split('\n');
                            for (let j = 0; j < lines.length; j++) {
                                let l = lines[j].trim();
                                if (l.startsWith("Name=") && !aName) aName = l.substring(5).trim();
                                else if (l.startsWith("Icon=") && !aIcon) aIcon = l.substring(5).trim();
                                else if (l.startsWith("Exec=") && !aExec) aExec = l.substring(5).trim();
                            }
                            
                            // Find the item index since model might have changed
                            let targetIdx = -1;
                            for (let k = 0; k < filteredModel.count; k++) {
                                if (filteredModel.get(k).filePath === pathStr) {
                                    targetIdx = k;
                                    break;
                                }
                            }
                            
                            if (targetIdx !== -1) {
                                filteredModel.setProperty(targetIdx, "appName", aName);
                                filteredModel.setProperty(targetIdx, "appIcon", aIcon);
                                filteredModel.setProperty(targetIdx, "appExec", aExec);
                            }
                        }
                    });
                }
                
                let isPinned = root.pinnedPaths.indexOf(pathStr) !== -1;
                if (isPinned) {
                    if (fIsDir) {
                        pinnedDirs.push(item);
                    } else {
                        pinnedFiles.push(item);
                    }
                } else {
                    if (fIsDir) {
                        unpinnedDirs.push(item);
                    } else {
                        unpinnedFiles.push(item);
                    }
                }
            } catch (e) {
                console.log("Error processing file at index " + i + ": " + e);
            }
        }
        
        let pinnedStacks = [];
        let unpinnedStacks = [];

        // Append virtual stack items to pinnedStacks or unpinnedStacks
        for (let s of currentFolderStacks) {
            let isExpanded = root.expandedStackIds.indexOf(s.id) !== -1;
            let stackItem = {
                filePath: "stack://" + s.id,
                fileName: s.name,
                fileIsDir: true,
                isDesktop: false,
                appName: "",
                appIcon: "",
                appExec: "",
                isStack: true,
                isExpanded: isExpanded,
                belongingStackId: isExpanded ? s.id : ""
            };
            
            let isPinned = root.pinnedPaths.indexOf("stack://" + s.id) !== -1;
            if (isPinned) {
                pinnedStacks.push(stackItem);
            } else {
                unpinnedStacks.push(stackItem);
            }
        }

        // 1. Pinned Stacks
        pinnedStacks.forEach(function(item) {
            filteredModel.append(item);
            if (item.isStack && item.isExpanded) {
                let sFiles = expandedStackFilesMap[item.belongingStackId] || [];
                sFiles.forEach(function(f) {
                    filteredModel.append(f);
                });
            }
        });

        // 2. Pinned Directories
        pinnedDirs.forEach(function(item) { filteredModel.append(item); });

        // 3. Pinned Files
        pinnedFiles.forEach(function(item) { filteredModel.append(item); });
        
        // 4. Unpinned Stacks
        unpinnedStacks.forEach(function(item) {
            filteredModel.append(item);
            if (item.isStack && item.isExpanded) {
                let sFiles = expandedStackFilesMap[item.belongingStackId] || [];
                sFiles.forEach(function(f) {
                    filteredModel.append(f);
                });
            }
        });

        // 5. Unpinned Directories
        unpinnedDirs.forEach(function(item) { filteredModel.append(item); });
        
        // 6. Unpinned Files
        unpinnedFiles.forEach(function(item) { filteredModel.append(item); });
    }

    function createStack(stackName, filePaths) {
        let newStack = {
            "id": "stack_" + Date.now() + "_" + Math.floor(Math.random() * 1000),
            "name": stackName,
            "folder": root.targetFolderUrl,
            "filePaths": filePaths
        };
        let newStacks = [...stacks, newStack];
        root.stacks = newStacks;
        if (pluginService) {
            pluginService.savePluginData(pluginId, "stacks", newStacks);
        }
        clearSelection();
        updateFilteredModel();
    }

    function renameStack(stackId, newName) {
        let newStacks = stacks.map(s => {
            if (s.id === stackId) {
                s.name = newName;
            }
            return s;
        });
        root.stacks = newStacks;
        if (pluginService) {
            pluginService.savePluginData(pluginId, "stacks", newStacks);
        }
        updateFilteredModel();
    }

    function ungroupStack(stackId) {
        let newStacks = stacks.filter(s => s.id !== stackId);
        root.stacks = newStacks;
        if (pluginService) {
            pluginService.savePluginData(pluginId, "stacks", newStacks);
        }
        expandedStackIds = expandedStackIds.filter(id => id !== stackId);
        clearSelection();
        updateFilteredModel();
    }

    function toggleStackExpanded(stackId) {
        let arr = [...expandedStackIds];
        let idx = arr.indexOf(stackId);
        if (idx === -1) {
            arr.push(stackId);
        } else {
            arr.splice(idx, 1);
        }
        expandedStackIds = arr;
        updateFilteredModel();
    }

    onSearchPatternChanged: updateFilteredModel()
 
    // Basic Filtering Properties
    property string filterType: "all"
    property string filterTime: "all"
    onFilterTypeChanged: updateFilteredModel()
    onFilterTimeChanged: updateFilteredModel()
 
    function isDocument(fileName) {
        const ext = fileName.split('.').pop().toLowerCase();
        return ["doc", "docx", "pdf", "txt", "odt", "xls", "xlsx", "ppt", "pptx", "md", "csv"].indexOf(ext) !== -1;
    }
 
    function isAudioVideo(fileName) {
        const ext = fileName.split('.').pop().toLowerCase();
        return ["mp3", "wav", "ogg", "flac", "m4a", "mp4", "mkv", "avi", "mov", "webm", "flv"].indexOf(ext) !== -1;
    }

    function scrollToTop() {
        if (viewMode === "grid" && typeof fileGrid !== "undefined" && fileGrid) {
            fileGrid.contentY = 0;
        } else if (viewMode === "list" && typeof fileList !== "undefined" && fileList) {
            fileList.contentY = 0;
        } else if (viewMode === "compact" && typeof fileCompact !== "undefined" && fileCompact) {
            fileCompact.contentY = 0;
        }
    }

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
        border.color: root.editMode ? Theme.primary : Theme.withAlpha(Theme.outline, root.borderOpacity)
        border.width: root.editMode ? 2 : 1

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingM

            // Premium Header (Optional)
            Item {
                id: headerContainer
                anchors.left: parent.left
                anchors.right: parent.right
                height: 24
                visible: root.showHeader

                // Default anchors: top
                anchors.top: parent.top

                states: [
                    State {
                        name: "bottom"
                        when: root.headerPosition === "bottom"
                        AnchorChanges {
                            target: headerContainer
                            anchors.top: undefined
                            anchors.bottom: parent.bottom
                        }
                    }
                ]

                // Left: Folder Selector + File Status
                Row {
                    anchors.left: parent.left
                    height: parent.height
                    spacing: Theme.spacingS

                    // Part 1: Folder Selection
                    MouseArea {
                        id: folderSelectorBtn
                        height: parent.height
                        width: folderRow.implicitWidth
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: folderDropdown.visible ? folderDropdown.close() : folderDropdown.open()

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
                            }

                            StyledText {
                                text: root.folderDisplayName
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                color: folderSelectorBtn.containsMouse ? Theme.primary : Theme.surfaceText
                                opacity: folderSelectorBtn.containsMouse ? 1.0 : 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankIcon {
                                name: "arrow_drop_down"
                                size: 14
                                color: folderSelectorBtn.containsMouse ? Theme.primary : Theme.surfaceText
                                opacity: folderSelectorBtn.containsMouse ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Part 2: File Status (Click for Context Menu)
                    MouseArea {
                        id: fileStatusBtn
                        height: parent.height
                        width: fileStatusRow.implicitWidth
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        visible: folderModel.count > 0
                        
                        onClicked: mouse => {
                            if (quickMenu.visible) {
                                quickMenu.close();
                                return;
                            }
                            if (root.selectedFilePaths.length === 0) return;

                            const globalPos = mapToItem(root, mouse.x, mouse.y);
                            quickMenu.parent = root;
                            quickMenu.x = Math.max(0, Math.min(root.width - quickMenu.width, globalPos.x));
                            quickMenu.y = Math.max(0, Math.min(root.height - quickMenu.height, globalPos.y));
                            
                            if (root.selectedFilePaths.length === 1) {
                                const path = root.selectedFilePaths[0];
                                quickMenu.currentPath = path;
                                quickMenu.currentName = path.split('/').pop();
                                
                                for (let i = 0; i < filteredModel.count; i++) {
                                    if (filteredModel.get(i).filePath === path) {
                                        quickMenu.currentIsDir = filteredModel.get(i).fileIsDir;
                                        break;
                                    }
                                }
                            }

                            quickMenu.open();
                        }

                        Row {
                            id: fileStatusRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            StyledText {
                                text: {
                                    let count = folderModel.count;
                                    let selected = root.selectedFilePaths.length;
                                    let str = "(" + count + ")";
                                    if (selected > 0) {
                                        str += " [" + selected + " " + I18n.tr("selected") + "]";
                                    }
                                    return str;
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: fileStatusBtn.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                opacity: fileStatusBtn.containsMouse ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Right: Controls (Search, View Mode & Sort By)
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    // Back to Top Button
                    MouseArea {
                        id: backToTopBtn
                        width: visible ? 20 : 0
                        height: 20
                        visible: root.isScrolledDown
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.scrollToTop()

                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        DankIcon {
                            anchors.centerIn: parent
                            name: "arrow_upward"
                            size: 16
                            color: backToTopBtn.containsMouse ? Theme.primary : Theme.surfaceText
                            opacity: backToTopBtn.containsMouse ? 1.0 : 0.7
                        }
                    }

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
                        }
                    }
 
                    // Filter Button
                    MouseArea {
                        id: filterBtn
                        width: 20
                        height: 20
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: filterDropdown.open()
 
                        DankIcon {
                            anchors.centerIn: parent
                            name: "filter_list"
                            size: 16
                            color: (root.filterType !== "all" || root.filterTime !== "all") ? Theme.primary : (filterBtn.containsMouse ? Theme.primary : Theme.surfaceText)
                            opacity: (root.filterType !== "all" || root.filterTime !== "all" || filterBtn.containsMouse) ? 1.0 : 0.7
                        }
                    }
                }
            }
            // Grid View container
            Item {
                id: filesContainer
                anchors.left: parent.left
                anchors.right: parent.right
                clip: true

                // Default anchors: header at top
                anchors.top: (root.showHeader && root.headerPosition === "top") ? headerContainer.bottom : parent.top
                anchors.topMargin: (root.showHeader && root.headerPosition === "top") ? Theme.spacingS : 0
                anchors.bottom: parent.bottom

                states: [
                    State {
                        name: "headerBottom"
                        when: root.showHeader && root.headerPosition === "bottom"
                        AnchorChanges {
                            target: filesContainer
                            anchors.top: parent.top
                            anchors.bottom: headerContainer.top
                        }
                        PropertyChanges {
                            target: filesContainer
                            anchors.topMargin: 0
                            anchors.bottomMargin: Theme.spacingS
                        }
                    }
                ]

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

                        required property bool isDesktop
                        required property string appName
                        required property string appIcon
                        required property string appExec
                        required property bool isStack
                        required property string belongingStackId
                        readonly property bool isSelected: root.selectedFilePaths.indexOf(filePath) !== -1
                        property bool isLaunching: false

                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction

                        DragHandler {
                            target: null
                            acceptedButtons: Qt.LeftButton
                            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesCancellation
                            enabled: !delegateRoot.isStack && !delegateRoot.filePath.startsWith("stack://")
                            onActiveChanged: {
                                if (active) {
                                    delegateRoot.Drag.mimeData = root.dragMimeData(delegateRoot.filePath);
                                    delegateRoot.grabToImage(function (result) {
                                        delegateRoot.Drag.imageSource = result.url;
                                        delegateRoot.Drag.active = true;
                                    });
                                } else {
                                    delegateRoot.Drag.active = false;
                                }
                            }
                        }

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
                                    : (delegateRoot.belongingStackId !== ""
                                        ? (delegateRoot.isStack
                                            ? (itemHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.22) : Theme.withAlpha(Theme.primary, 0.12))
                                            : (itemHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.primary, 0.05)))
                                        : (itemHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent")))
                            border.color: isLaunching 
                                ? Theme.primary 
                                : (isSelected 
                                    ? Theme.primary 
                                    : (delegateRoot.belongingStackId !== ""
                                        ? (delegateRoot.isStack ? Theme.primary : Theme.withAlpha(Theme.primary, 0.25))
                                        : "transparent"))
                            border.width: isLaunching ? 2 : (isSelected ? 1 : (delegateRoot.belongingStackId !== "" ? 1 : 0))

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
                                    appIcon: delegateRoot.appIcon
                                    sizeScale: root.sizeScale
                                    hover: itemHover.containsMouse
                                }

                                // File/Folder Name
                                StyledText {
                                    width: parent.width
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    text: root.smartTruncate(delegateRoot.isDesktop ? (delegateRoot.appName ? delegateRoot.appName : delegateRoot.fileName.slice(0, -8)) : delegateRoot.fileName, isSelected && root.selectedFilePaths.length === 1, width, font.pixelSize)
                                    color: Theme.surfaceText
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideNone
                                    maximumLineCount: (isSelected && root.selectedFilePaths.length === 1) ? 10 : 2
                                    wrapMode: Text.WrapAnywhere
                                    opacity: itemHover.containsMouse ? 1.0 : 0.85
                                }
                            }

                            // Pin indicator overlay
                            DankIcon {
                                name: "push_pin"
                                size: 16
                                color: Theme.primary
                                anchors.top: parent.top
                                anchors.topMargin: Theme.spacingXS + 2
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingXS + 2
                                visible: root.pinnedPaths.indexOf(filePath) !== -1
                            }

                            MouseArea {
                                id: itemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (delegateRoot.filePath.startsWith("stack://")) {
                                            let stackId = delegateRoot.filePath.substring(8);
                                            root.toggleStackExpanded(stackId);
                                            return;
                                        }
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
                                        if (delegateRoot.filePath.startsWith("stack://")) {
                                            let stackId = delegateRoot.filePath.substring(8);
                                            root.toggleStackExpanded(stackId);
                                            return;
                                        }
                                        isLaunching = true;
                                        launchPulse.restart();
                                        launchTimer.restart();
                                        // Open file/folder using default system application
                                        if (delegateRoot.isDesktop) {
                                            root.launchDesktopFile(delegateRoot.filePath);
                                        } else {
                                            Quickshell.execDetached(["gio", "open", root._cleanPath(delegateRoot.filePath)]);
                                        }
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
                        height: Math.round(36 * root.sizeScale)

                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property int index

                        required property bool isDesktop
                        required property string appName
                        required property string appIcon
                        required property string appExec
                        required property bool isStack
                        required property string belongingStackId
                        readonly property bool isSelected: root.selectedFilePaths.indexOf(filePath) !== -1
                        property bool isLaunching: false

                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction

                        DragHandler {
                            target: null
                            acceptedButtons: Qt.LeftButton
                            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesCancellation
                            enabled: !listDelegateRoot.isStack && !listDelegateRoot.filePath.startsWith("stack://")
                            onActiveChanged: {
                                if (active) {
                                    listDelegateRoot.Drag.mimeData = root.dragMimeData(listDelegateRoot.filePath);
                                    listDelegateRoot.grabToImage(function (result) {
                                        listDelegateRoot.Drag.imageSource = result.url;
                                        listDelegateRoot.Drag.active = true;
                                    });
                                } else {
                                    listDelegateRoot.Drag.active = false;
                                }
                            }
                        }

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
                                    : (listDelegateRoot.belongingStackId !== ""
                                        ? (listDelegateRoot.isStack
                                            ? (listItemHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.22) : Theme.withAlpha(Theme.primary, 0.12))
                                            : (listItemHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.primary, 0.05)))
                                        : (listItemHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent")))
                            border.color: isLaunching 
                                ? Theme.primary 
                                : (isSelected 
                                    ? Theme.primary 
                                    : (listDelegateRoot.belongingStackId !== ""
                                        ? (listDelegateRoot.isStack ? Theme.primary : Theme.withAlpha(Theme.primary, 0.25))
                                        : "transparent"))
                            border.width: isLaunching ? 1 : (isSelected ? 1 : (listDelegateRoot.belongingStackId !== "" ? 1 : 0))

                            Row {
                                id: listRow
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                FolderViewThumbnail {
                                    width: Math.round(20 * root.sizeScale)
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    filePath: listDelegateRoot.filePath
                                    fileName: listDelegateRoot.fileName
                                    isDir: listDelegateRoot.fileIsDir
                                    appIcon: listDelegateRoot.appIcon
                                    sizeScale: root.sizeScale
                                    hover: listItemHover.containsMouse
                                }

                                StyledText {
                                    font.pixelSize: Theme.fontSizeSmall
                                    width: parent.width - Math.round(20 * root.sizeScale) - (root.pinnedPaths.indexOf(filePath) !== -1 ? 32 : 12)
                                    text: root.smartTruncate(listDelegateRoot.isDesktop ? (listDelegateRoot.appName ? listDelegateRoot.appName : listDelegateRoot.fileName.slice(0, -8)) : listDelegateRoot.fileName, false, width, font.pixelSize)
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideNone
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 2
                                }
                            }

                            // Pin indicator
                            DankIcon {
                                name: "push_pin"
                                size: 14
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                visible: root.pinnedPaths.indexOf(filePath) !== -1
                            }

                            MouseArea {
                                id: listItemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (listDelegateRoot.filePath.startsWith("stack://")) {
                                            let stackId = listDelegateRoot.filePath.substring(8);
                                            root.toggleStackExpanded(stackId);
                                            return;
                                        }
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
                                        if (listDelegateRoot.filePath.startsWith("stack://")) {
                                            let stackId = listDelegateRoot.filePath.substring(8);
                                            root.toggleStackExpanded(stackId);
                                            return;
                                        }
                                        listDelegateRoot.isLaunching = true;
                                        listLaunchPulse.restart();
                                        // Open file/folder using default system application
                                        if (listDelegateRoot.isDesktop) {
                                            root.launchDesktopFile(listDelegateRoot.filePath);
                                        } else {
                                            Quickshell.execDetached(["gio", "open", root._cleanPath(listDelegateRoot.filePath)]);
                                        }
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
                        height: Math.round(30 * root.sizeScale)

                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property int index

                        required property bool isDesktop
                        required property string appName
                        required property string appIcon
                        required property string appExec
                        required property bool isStack
                        required property string belongingStackId
                        readonly property bool isSelected: root.selectedFilePaths.indexOf(filePath) !== -1
                        property bool isLaunching: false

                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction

                        DragHandler {
                            target: null
                            acceptedButtons: Qt.LeftButton
                            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesCancellation
                            enabled: !compactDelegateRoot.isStack && !compactDelegateRoot.filePath.startsWith("stack://")
                            onActiveChanged: {
                                if (active) {
                                    compactDelegateRoot.Drag.mimeData = root.dragMimeData(compactDelegateRoot.filePath);
                                    compactDelegateRoot.grabToImage(function (result) {
                                        compactDelegateRoot.Drag.imageSource = result.url;
                                        compactDelegateRoot.Drag.active = true;
                                    });
                                } else {
                                    compactDelegateRoot.Drag.active = false;
                                }
                            }
                        }

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
                                    : (compactDelegateRoot.belongingStackId !== ""
                                        ? (compactDelegateRoot.isStack
                                            ? (compactItemHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.22) : Theme.withAlpha(Theme.primary, 0.12))
                                            : (compactItemHover.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.primary, 0.05)))
                                        : (compactItemHover.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.06) : "transparent")))
                            border.color: isLaunching 
                                ? Theme.primary 
                                : (isSelected 
                                    ? Theme.primary 
                                    : (compactDelegateRoot.belongingStackId !== ""
                                        ? (compactDelegateRoot.isStack ? Theme.primary : Theme.withAlpha(Theme.primary, 0.25))
                                        : "transparent"))
                            border.width: isLaunching ? 1 : (isSelected ? 1 : (compactDelegateRoot.belongingStackId !== "" ? 1 : 0))

                            Row {
                                id: compactRow
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                FolderViewThumbnail {
                                    width: Math.round(16 * root.sizeScale)
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    filePath: compactDelegateRoot.filePath
                                    fileName: compactDelegateRoot.fileName
                                    isDir: compactDelegateRoot.fileIsDir
                                    appIcon: compactDelegateRoot.appIcon
                                    sizeScale: root.sizeScale
                                    hover: compactItemHover.containsMouse
                                }

                                StyledText {
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    width: parent.width - Math.round(16 * root.sizeScale) - (root.pinnedPaths.indexOf(filePath) !== -1 ? 28 : 12)
                                    text: root.smartTruncate(compactDelegateRoot.isDesktop ? (compactDelegateRoot.appName ? compactDelegateRoot.appName : compactDelegateRoot.fileName.slice(0, -8)) : compactDelegateRoot.fileName, false, width, font.pixelSize)
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    elide: Text.ElideNone
                                    wrapMode: Text.WrapAnywhere
                                    maximumLineCount: 2
                                }
                            }

                            // Pin indicator
                            DankIcon {
                                name: "push_pin"
                                size: 12
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                visible: root.pinnedPaths.indexOf(filePath) !== -1
                            }

                            MouseArea {
                                id: compactItemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (compactDelegateRoot.filePath.startsWith("stack://")) {
                                            let stackId = compactDelegateRoot.filePath.substring(8);
                                            root.toggleStackExpanded(stackId);
                                            return;
                                        }
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
                                        if (compactDelegateRoot.filePath.startsWith("stack://")) {
                                            let stackId = compactDelegateRoot.filePath.substring(8);
                                            root.toggleStackExpanded(stackId);
                                            return;
                                        }
                                        compactDelegateRoot.isLaunching = true;
                                        compactLaunchPulse.restart();
                                        // Open file/folder using default system application
                                        if (compactDelegateRoot.isDesktop) {
                                            root.launchDesktopFile(compactDelegateRoot.filePath);
                                        } else {
                                            Quickshell.execDetached(["gio", "open", root._cleanPath(compactDelegateRoot.filePath)]);
                                        }
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
                                    let clean = root._cleanPath(path);
                                    if (clean.endsWith(".desktop")) {
                                        root.launchDesktopFile(path);
                                    } else {
                                        Quickshell.execDetached(["gio", "open", clean]);
                                    }
                                }
                                root.clearSelection();
                            }
                        },
                        {
                            text: I18n.tr("Float File"),
                            icon: "picture_in_picture",
                            visible: root.selectedFilePaths.length === 1 && (root.isImage(quickMenu.currentName) || quickMenu.currentName.toLowerCase().endsWith(".pdf")),
                            action: function() {
                                quickMenu.close();
                                const path = root.selectedFilePaths[0];
                                Quickshell.execDetached(["dms", "ipc", "call", "floaty", "floatFromUrl", "file://" + path]);
                            }
                        },
                        {
                            text: I18n.tr("Copy"),
                            icon: "content_copy",
                            visible: true,
                            action: function() {
                                quickMenu.close();
                                const paths = root.selectedFilePaths;
                                const name = quickMenu.currentName;

                                // Single image file: use DMS clipboard.copyFile so it appears
                                // in the DMS clipboard history and can be pasted in any app.
                                if (paths.length === 1 && root.isImage(name)) {
                                    DMSService.sendRequest("clipboard.copyFile", { "filePath": paths[0] }, function(resp) {
                                        if (resp.error) {
                                            ToastService.showToast(I18n.tr("Copy failed") + ": " + resp.error, ToastService.levelError);
                                        } else {
                                            ToastService.showToast(I18n.tr("Image Copied") + ": " + name, ToastService.levelInfo);
                                        }
                                    });
                                    return;
                                }

                                // Multi-file or non-image: use wl-copy with the gnome URI
                                // format so the selection can be pasted into file managers.
                                // Note: dms cl copy cannot be used here because the DMS daemon
                                // intercepts and re-serves the entry, corrupting the content.
                                let uris = [];
                                for (let path of paths) {
                                    uris.push("file://" + path);
                                }
                                const cmd = "echo -ne \"copy\\n" + uris.join("\\n") + "\" | wl-copy -t x-special/gnome-copied-files";
                                Quickshell.execDetached(["bash", "-c", cmd]);

                                const label = paths.length > 1
                                    ? I18n.tr("Copied %1 items").arg(paths.length)
                                    : I18n.tr("File Copied") + ": " + name;
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
                            visible: root.selectedFilePaths.length <= 1 && !quickMenu.currentPath.startsWith("stack://"),
                            action: function() {
                                quickMenu.close();
                                infoDialog.showFor(quickMenu.currentPath, quickMenu.currentName, quickMenu.currentIsDir);
                            }
                        },
                        {
                            actionName: "pin",
                            visible: true,
                            action: function() {
                                quickMenu.close();
                                root.togglePin(quickMenu.currentPath);
                            }
                        },
                        {
                            text: I18n.tr("Group into Stack"),
                            icon: "layers",
                            visible: root.selectedFilePaths.length > 1 && root.selectedFilePaths.every(p => !p.startsWith("stack://")),
                            action: function() {
                                quickMenu.close();
                                createStackDialog.showFor(root.selectedFilePaths);
                            }
                        },
                        {
                            text: I18n.tr("Ungroup Stack"),
                            icon: "layers_clear",
                            visible: root.selectedFilePaths.length === 1 && quickMenu.currentPath.startsWith("stack://"),
                            action: function() {
                                quickMenu.close();
                                let stackId = quickMenu.currentPath.substring(8);
                                root.ungroupStack(stackId);
                            }
                        },
                        { isSeparator: true },
                        {
                            text: I18n.tr("Move to Trash"),
                            icon: "delete",
                            dangerous: true,
                            visible: root.selectedFilePaths.every(p => !p.startsWith("stack://")),
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
                                name: modelData.actionName === "pin"
                                    ? "push_pin"
                                    : (modelData.icon || "")
                                size: 14
                                color: modelData.dangerous && menuArea.containsMouse ? Theme.error : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !isSeparator && parent.parent.itemVisible
                            }

                            StyledText {
                                text: modelData.actionName === "pin"
                                    ? (root.pinnedPaths.indexOf(quickMenu.currentPath) !== -1 ? I18n.tr("Unpin from Top") : I18n.tr("Pin to Top"))
                                    : (modelData.text || "")
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

    // Create Stack Dialog
    FolderViewCreateStackDialog {
        id: createStackDialog
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

    // Create App Dialog
    FolderViewCreateAppDialog {
        id: createAppDialog
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
        y: root.headerPosition === "bottom" ? -height - 4 : folderSelectorBtn.height + 4

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
                        { label: I18n.tr("Pictures"), value: "pictures", icon: "image" },
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
        y: root.headerPosition === "bottom" ? -height - 4 : createBtn.height + 4

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
                        { label: I18n.tr("New Document"), value: "file", icon: "note_add" },
                        { label: I18n.tr("New App"), value: "app", icon: "add_to_home_screen" }
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
                                if (modelData.value === "app") {
                                    createAppDialog.show();
                                } else {
                                    createDialog.showFor(modelData.value === "folder");
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
        y: root.headerPosition === "bottom" ? -height - 4 : sortByBtn.height + 4

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



    // Filter Dropdown Popup
    Popup {
        id: filterDropdown
        parent: filterBtn
        width: 160
        height: filterDropdownColumn.implicitHeight + Theme.spacingS * 2
        padding: 0
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: filterBtn.width - filterDropdown.width
        y: root.headerPosition === "bottom" ? -height - 4 : filterBtn.height + 4
 
        background: Rectangle {
            color: "transparent"
        }
 
        contentItem: Rectangle {
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.withAlpha(Theme.outline, 0.15)
            border.width: 1
 
            Column {
                id: filterDropdownColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: 4
 
                // Section 1: File Type
                StyledText {
                    text: I18n.tr("File Type")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.bold: true
                    color: Theme.surfaceVariantText
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                }
 
                Repeater {
                    model: [
                        { label: I18n.tr("All Files"), value: "all", icon: "menu" },
                        { label: I18n.tr("Folders Only"), value: "folders", icon: "folder" },
                        { label: I18n.tr("Files Only"), value: "files", icon: "description" },
                        { label: I18n.tr("Images Only"), value: "images", icon: "image" },
                        { label: I18n.tr("Documents Only"), value: "documents", icon: "article" },
                        { label: I18n.tr("Audio & Video"), value: "audio_video", icon: "movie" }
                    ]
 
                    delegate: Rectangle {
                        width: parent.width
                        height: 24
                        radius: Theme.cornerRadius - 2
                        color: typeArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
 
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
 
                            DankIcon {
                                name: modelData.icon
                                size: 12
                                color: root.filterType === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
 
                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.bold: root.filterType === modelData.value
                                color: root.filterType === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
 
                        MouseArea {
                            id: typeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.filterType = modelData.value;
                                filterDropdown.close();
                            }
                        }
                    }
                }
 
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.withAlpha(Theme.outline, 0.1)
                }
 
                // Section 2: Time
                StyledText {
                    text: I18n.tr("Time Modified")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.bold: true
                    color: Theme.surfaceVariantText
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                }
 
                Repeater {
                    model: [
                        { label: I18n.tr("Any Time"), value: "all", icon: "schedule" },
                        { label: I18n.tr("Last 24 Hours"), value: "today", icon: "today" },
                        { label: I18n.tr("Last 7 Days"), value: "week", icon: "date_range" },
                        { label: I18n.tr("Last 30 Days"), value: "month", icon: "calendar_month" },
                        { label: I18n.tr("Last 365 Days"), value: "year", icon: "history" }
                    ]
 
                    delegate: Rectangle {
                        width: parent.width
                        height: 24
                        radius: Theme.cornerRadius - 2
                        color: timeArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
 
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS
 
                            DankIcon {
                                name: modelData.icon
                                size: 12
                                color: root.filterTime === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
 
                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.bold: root.filterTime === modelData.value
                                color: root.filterTime === modelData.value ? Theme.primary : Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
 
                        MouseArea {
                            id: timeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.filterTime = modelData.value;
                                filterDropdown.close();
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
