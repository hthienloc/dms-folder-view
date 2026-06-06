import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import "./dms-common"

Item {
    id: root
    property string filePath: ""
    property string fileName: ""
    property bool isDir: false
    property double sizeScale: 1.0
    property bool hover: false
    property string appIcon: ""

    readonly property bool isImage: {
        const parts = fileName.split('.');
        if (parts.length < 2) return false;
        const ext = parts.pop().toLowerCase();
        return ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp"].indexOf(ext) !== -1;
    }

    readonly property bool isAudio: {
        const parts = fileName.split('.');
        if (parts.length < 2) return false;
        const ext = parts.pop().toLowerCase();
        return ["mp3", "wav", "ogg", "flac", "m4a"].indexOf(ext) !== -1;
    }

    readonly property bool isPDF: {
        const parts = fileName.split('.');
        if (parts.length < 2) return false;
        const ext = parts.pop().toLowerCase();
        return ext === "pdf";
    }

    property string artSource: ""
    property bool showThumbnail: (isImage || isAudio || isPDF || root.appIcon !== "") && !isDir && artSource !== "failed"

    DankIcon {
        anchors.centerIn: parent
        name: root.getIconName(fileName, isDir)
        size: parent.width * 0.8
        color: root.getIconColor(fileName, isDir)
        visible: !root.showThumbnail || img.status !== Image.Ready
        scale: root.hover ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: 150 } }
    }

    Image {
        id: img
        anchors.centerIn: parent
        width: parent.width - 4
        height: parent.height - 4
        source: {
            if (root.appIcon !== "") return Quickshell.iconPath(root.appIcon);
            if (root.artSource.startsWith("file://")) return root.artSource;
            if (root.isImage && root.filePath !== "") {
                return root.filePath.startsWith("file://") ? root.filePath : "file://" + root.filePath;
            }
            return "";
        }
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize.width: 128
        sourceSize.height: 128
        visible: root.showThumbnail
        opacity: status === Image.Ready ? 1.0 : 0.0
        scale: root.hover ? 1.08 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 150 } }

        onStatusChanged: {
            if (status === Image.Error && root.isImage) {
                root.artSource = "failed";
            }
        }
    }

    function getIconName(fileName, isDir) {
        if (filePath.startsWith("stack://")) return "layers";
        if (isDir) return "folder";
        const parts = fileName.split('.');
        const ext = parts.length > 1 ? parts.pop().toLowerCase() : "";
        switch (ext) {
            case "mp3": case "wav": case "ogg": case "flac": case "m4a": return "audiotrack";
            case "mp4": case "mkv": case "avi": case "mov": case "webm": return "video_library";
            case "pdf": return "picture_as_pdf";
            case "zip": case "tar": case "gz": case "bz2": case "xz": case "rar": case "7z": return "archive";
            case "txt": case "md": case "json": case "xml": case "yaml": case "yml": case "conf": case "ini": return "description";
            case "sh": case "py": case "js": case "ts": case "rs": case "go": case "c": case "cpp": case "h": case "java": case "html": case "css": return "terminal";
            case "desktop": return "bookmark";
            default: return "insert_drive_file";
        }
    }

    function getIconColor(fileName, isDir) {
        if (filePath.startsWith("stack://")) return Theme.primary; // Stack color: System Theme Accent
        if (isDir) return Theme.primary;
        const parts = fileName.split('.');
        const ext = parts.length > 1 ? parts.pop().toLowerCase() : "";
        switch (ext) {
            case "mp3": case "wav": case "ogg": case "flac": case "m4a": case "mp4": case "mkv": case "avi": case "mov": case "webm": return Theme.secondary;
            case "pdf": return Theme.error;
            case "zip": case "tar": case "gz": case "bz2": case "xz": case "rar": case "7z": return Theme.warning;
            case "txt": case "md": case "json": case "xml": case "yaml": case "yml": case "conf": case "ini": return Theme.primary;
            case "sh": case "py": case "js": case "ts": case "rs": case "go": case "c": case "cpp": case "h": case "java": case "html": case "css": return Theme.primary;
            default: return Theme.surfaceVariantText;
        }
    }

    function djb2Hash(str) {
        let hash = 5381;
        for (let i = 0; i < str.length; i++) {
            hash = ((hash << 5) + hash) + str.charCodeAt(i);
            hash = hash & 0x7FFFFFFF;
        }
        return hash.toString(16).padStart(8, '0');
    }

    function _cleanPath(url) {
        let path = String(url);
        if (path.startsWith("file://")) path = path.substring(7);
        if (path.startsWith("localhost/")) path = path.substring(9);
        return path;
    }

    function requestThumbnail() {
        if (isDir || artSource !== "" || filePath === "" || artSource === "failed") return;
        
        // Use a timer to stagger requests and ensure properties are settled
        loadTimer.restart();
    }

    Timer {
        id: loadTimer
        interval: 50 + Math.random() * 500 // Random delay to spread load
        repeat: false
        onTriggered: {
            if (isDir || artSource !== "" || filePath === "") return;
            
            const rawPath = _cleanPath(filePath);
            const cacheDir = Paths.strip(Paths.cache) + "/folderView/thumbs";
            const hash = djb2Hash(rawPath);
            const cachePath = cacheDir + "/" + hash + ".jpg";
            
            if (isAudio) {
                extractAudioArt(rawPath, cacheDir, cachePath, hash);
            } else if (isPDF) {
                extractPDFThumb(rawPath, cacheDir, cachePath, hash);
            }
        }
    }

    function extractAudioArt(rawPath, cacheDir, cachePath, hash) {
        Quickshell.execDetached(["mkdir", "-p", cacheDir]);
        
        Proc.runCommand("check-art-" + hash, ["test", "-f", cachePath], (out, code) => {
            if (!root) return;
            if (code === 0) {
                root.artSource = "file://" + cachePath;
            } else {
                const cmd = ["ffmpeg", "-y", "-i", rawPath, "-an", "-frames:v", "1", "-f", "image2", cachePath];
                Proc.runCommand("extract-art-" + hash, cmd, (out2, code2) => {
                    if (!root) return;
                    if (code2 === 0) {
                        root.artSource = "file://" + cachePath;
                    } else {
                        root.artSource = "failed";
                    }
                }, 100);
            }
        });
    }

    function extractPDFThumb(rawPath, cacheDir, cachePath, hash) {
        Quickshell.execDetached(["mkdir", "-p", cacheDir]);
        
        Proc.runCommand("check-pdf-" + hash, ["test", "-f", cachePath], (out, code) => {
            if (!root) return;
            if (code === 0) {
                root.artSource = "file://" + cachePath;
            } else {
                const prefix = cacheDir + "/" + hash;
                const cmd = ["pdftoppm", "-jpeg", "-singlefile", "-scale-to", "128", rawPath, prefix];
                Proc.runCommand("extract-pdf-" + hash, cmd, (out2, code2) => {
                    if (!root) return;
                    if (code2 === 0) {
                        root.artSource = "file://" + cachePath;
                    } else {
                        root.artSource = "failed";
                    }
                }, 100);
            }
        });
    }

    onFilePathChanged: requestThumbnail()
    onIsAudioChanged: requestThumbnail()
    onIsPDFChanged: requestThumbnail()

    Component.onCompleted: requestThumbnail()
}
