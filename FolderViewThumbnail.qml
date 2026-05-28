import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import "../dms-common"

Item {
    id: root
    property string filePath: ""
    property string fileName: ""
    property bool isDir: false
    property double sizeScale: 1.0
    property bool hover: false

    property bool isImage: {
        const ext = fileName.split('.').pop().toLowerCase();
        return ["jpg", "jpeg", "png", "gif", "webp", "svg", "bmp"].indexOf(ext) !== -1;
    }
    
    property bool isAudio: {
        const ext = fileName.split('.').pop().toLowerCase();
        return ["mp3", "wav", "ogg", "flac", "m4a"].indexOf(ext) !== -1;
    }

    property string artSource: ""
    property bool showThumbnail: (isImage || isAudio) && !isDir && artSource !== "failed"

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
        source: root.artSource.startsWith("file://") ? root.artSource : (root.isImage ? "file://" + root.filePath : "")
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
        if (isDir) return "folder";
        const ext = fileName.split('.').pop().toLowerCase();
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
        if (isDir) return Theme.primary;
        const ext = fileName.split('.').pop().toLowerCase();
        switch (ext) {
            case "mp3": case "wav": case "ogg": case "flac": case "m4a": case "mp4": case "mkv": case "avi": case "mov": case "webm": return "#7C4DFF";
            case "pdf": return "#FF1744";
            case "zip": case "tar": case "gz": case "bz2": case "xz": case "rar": case "7z": return "#FF9100";
            case "txt": case "md": case "json": case "xml": case "yaml": case "yml": case "conf": case "ini": return "#2979FF";
            case "sh": case "py": case "js": case "ts": case "rs": case "go": case "c": case "cpp": case "h": case "java": case "html": case "css": return "#FF5252";
            default: return Theme.surfaceText;
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

    function extractArt() {
        if (!isAudio || isDir || artSource !== "") return;
        
        const cacheDir = Paths.strip(Paths.cache) + "/folderView/covers";
        const hash = djb2Hash(filePath);
        const cachePath = cacheDir + "/" + hash + ".jpg";
        
        // Ensure dir exists (minimal overhead if already exists)
        Quickshell.execDetached(["mkdir", "-p", cacheDir]);
        
        Proc.runCommand("check-art-" + hash, ["test", "-f", cachePath], (out, code) => {
            if (code === 0) {
                root.artSource = "file://" + cachePath;
            } else {
                // Try extract with ffmpeg
                // -y (overwrite), -i input, -an (no audio), -vcodec copy (stream copy video/image), -f image2 (output format), output
                const cmd = ["ffmpeg", "-y", "-i", filePath, "-an", "-vcodec", "copy", "-f", "image2", cachePath];
                Proc.runCommand("extract-art-" + hash, cmd, (out2, code2) => {
                    if (code2 === 0) {
                        root.artSource = "file://" + cachePath;
                    } else {
                        root.artSource = "failed";
                    }
                }, 100); // Small debounce
            }
        });
    }

    Component.onCompleted: {
        if (isAudio) {
            extractArt();
        }
    }
}
