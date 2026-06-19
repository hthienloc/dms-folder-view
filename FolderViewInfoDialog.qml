import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import "./dms-common"

Popup {
    id: infoDialog
    width: 340
    height: contentColumn.implicitHeight + Theme.spacingM * 2
    padding: 0
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property string filePath: ""
    property string fileName: ""
    property bool isDir: false
    
    // Info fields
    property string fileType: ""
    property string filePermissions: ""
    property string fileModified: ""
    property string fileSize: ""
    property string fileOwner: ""
    property string fileAccessed: ""
    property string fileOctal: ""
    property string itemsCount: ""
    property string symlinkTarget: ""
    property bool isSymlink: false

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Rectangle {
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            // Header with Icon and Name + Close button
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.right: closeButtonMouseArea.left
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankIcon {
                        name: infoDialog.isDir ? "folder" : "description"
                        size: 28
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: infoDialog.fileName
                        font.bold: true
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        width: parent.width - 64
                        elide: Text.ElideMiddle
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Close Dialog Button (X Icon)
                MouseArea {
                    id: closeButtonMouseArea
                    width: 24
                    height: 24
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: infoDialog.close()
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        color: Theme.surfaceText
                        opacity: parent.containsMouse ? 1.0 : 0.6
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.1)
            }

            // Info List
            Column {
                width: parent.width
                spacing: Theme.spacingS

                readonly property int labelWidth: 90

                // Rows helper component
                component InfoRow: Item {
                    width: parent.width
                    height: visible ? Math.max(label.implicitHeight, value.implicitHeight) : 0
                    property alias labelText: label.text
                    property alias valueText: value.text

                    StyledText {
                        id: label
                        text: ""
                        width: parent.parent.labelWidth
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.surfaceVariantText
                    }

                    StyledText {
                        id: value
                        anchors.left: label.right
                        anchors.right: parent.right
                        text: ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.Wrap
                    }
                }

                InfoRow { labelText: I18n.tr("Type:"); valueText: infoDialog.fileType }
                InfoRow { labelText: I18n.tr("Size:"); valueText: infoDialog.fileSize }
                InfoRow { labelText: I18n.tr("Items:"); valueText: infoDialog.itemsCount; visible: infoDialog.isDir }
                InfoRow { labelText: I18n.tr("Target:"); valueText: infoDialog.symlinkTarget; visible: infoDialog.isSymlink }
                InfoRow { labelText: I18n.tr("Modified:"); valueText: infoDialog.fileModified }
                InfoRow { labelText: I18n.tr("Accessed:"); valueText: infoDialog.fileAccessed }
                InfoRow { labelText: I18n.tr("Owner:"); valueText: infoDialog.fileOwner }
                InfoRow { labelText: I18n.tr("Permissions:"); valueText: infoDialog.filePermissions + (infoDialog.fileOctal ? " (" + infoDialog.fileOctal + ")" : "") }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.1)
            }

            // Path Section
            Column {
                width: parent.width
                spacing: 4
                
                StyledText {
                    text: I18n.tr("Location:")
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    color: Theme.surfaceVariantText
                }

                Rectangle {
                    width: parent.width
                    height: pathText.implicitHeight + 16
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    radius: 4
                    border.color: Theme.withAlpha(Theme.outline, 0.1)

                    StyledText {
                        id: pathText
                        anchors.fill: parent
                        anchors.margins: 8
                        text: infoDialog.filePath
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WrapAnywhere
                        font.family: "monospace"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["dms", "cl", "copy", infoDialog.filePath]);
                            ToastService.showToast(I18n.tr("Path copied to clipboard"), ToastService.levelInfo);
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingS

                DankButton {
                    text: infoDialog.isDir ? I18n.tr("Open Terminal") : I18n.tr("Open VS Code")
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: {
                        infoDialog.close();
                        if (infoDialog.isDir) {
                            const term = SessionData.resolveTerminal() || "xterm";
                            Quickshell.execDetached(["bash", "-c", "cd \"$1\" && exec \"$2\"", "launch_terminal", infoDialog.filePath, term]);
                        } else {
                            Quickshell.execDetached(["code", infoDialog.filePath]);
                        }
                    }
                }

                DankButton {
                    text: infoDialog.isDir ? I18n.tr("Open Folder") : I18n.tr("Open File")
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                    onClicked: {
                        infoDialog.close();
                        Quickshell.execDetached(["gio", "open", infoDialog.filePath]);
                    }
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
        try {
            cleanPath = decodeURIComponent(cleanPath);
        } catch (e) {}
        
        infoDialog.filePath = cleanPath;
        infoDialog.fileName = name;
        infoDialog.isDir = !!isDirectory;
        
        // Reset fields
        infoDialog.fileType = "..."
        infoDialog.filePermissions = "..."
        infoDialog.fileModified = "..."
        infoDialog.fileSize = "..."
        infoDialog.fileOwner = "..."
        infoDialog.fileAccessed = "..."
        infoDialog.fileOctal = ""
        infoDialog.itemsCount = "..."
        infoDialog.symlinkTarget = ""
        infoDialog.isSymlink = false
        
        infoDialog.open();
        fetchInfo();
    }

    function fetchInfo() {
        const path = infoDialog.filePath;
        // %F|%A|%y|%s|%U|%G|%a|%x|%N
        const statCmd = ["stat", "-c", "%F|%A|%y|%s|%U|%G|%a|%x|%N", path];
        
        Proc.runCommand("get-file-info-structured", statCmd, (output, exitCode) => {
            if (exitCode === 0) {
                const parts = output.trim().split('|');
                if (parts.length >= 9) {
                    infoDialog.fileType = parts[0];
                    infoDialog.filePermissions = parts[1];
                    infoDialog.fileModified = parts[2].split('.')[0]; // Remove nanoseconds
                    infoDialog.fileOwner = parts[4] + ":" + parts[5];
                    infoDialog.fileOctal = parts[6];
                    infoDialog.fileAccessed = parts[7].split('.')[0]; // Remove nanoseconds
                    
                    const symInfo = parts[8];
                    infoDialog.isSymlink = infoDialog.fileType.toLowerCase().indexOf("symbolic link") !== -1;
                    if (infoDialog.isSymlink && symInfo.indexOf(" -> ") !== -1) {
                        const targetPart = symInfo.split(" -> ")[1];
                        infoDialog.symlinkTarget = targetPart ? targetPart.replace(/^'|'$/g, "") : "";
                    } else {
                        infoDialog.symlinkTarget = "";
                    }

                    const rawSize = parts[3];
                    
                    if (infoDialog.isDir) {
                        // Fetch items count safely
                        Proc.runCommand("get-dir-items", ["sh", "-c", "ls -A \"$1\" | wc -l", "get_items_count", path], (wcOutput, wcExit) => {
                            if (wcExit === 0) {
                                const count = parseInt(wcOutput.trim(), 10);
                                infoDialog.itemsCount = count + (count === 1 ? " item" : " items");
                            } else {
                                infoDialog.itemsCount = "Unknown";
                            }
                        });

                        Proc.runCommand("get-dir-size", ["du", "-sh", path], (duOutput, duExit) => {
                            if (duExit === 0) {
                                infoDialog.fileSize = duOutput.trim().split(/\s+/)[0];
                            } else {
                                infoDialog.fileSize = rawSize + " bytes";
                            }
                        });
                    } else {
                        infoDialog.itemsCount = "";
                        Proc.runCommand("get-file-size", ["ls", "-lh", path], (lsOutput, lsExit) => {
                            if (lsExit === 0) {
                                const lsParts = lsOutput.trim().split(/\s+/);
                                if (lsParts.length >= 5) {
                                    infoDialog.fileSize = lsParts[4];
                                } else {
                                    infoDialog.fileSize = rawSize + " bytes";
                                }
                            } else {
                                infoDialog.fileSize = rawSize + " bytes";
                            }
                        });
                    }
                }
            } else {
                infoDialog.fileType = "Error fetching info";
            }
        });
    }
}
