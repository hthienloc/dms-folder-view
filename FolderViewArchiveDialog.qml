import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import "./dms-common"

Popup {
    id: archiveDialog
    width: 400
    height: Math.min(500, contentColumn.implicitHeight + Theme.spacingM * 2)
    padding: 0
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property string filePath: ""
    property string fileName: ""
    property string filterQuery: ""
    property var allFiles: []
    property bool isLoading: false

    readonly property var filteredFiles: {
        if (!allFiles) return [];
        return allFiles.filter(item => {
            if (filterQuery === "") return true;
            return item.filePath.toLowerCase().indexOf(filterQuery) !== -1;
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
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            // Header with Icon and Name
            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankIcon {
                    name: "inventory_2"
                    size: 28
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: archiveDialog.fileName
                        font.bold: true
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.surfaceText
                        width: parent.width
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        text: archiveDialog.isLoading 
                            ? I18n.tr("Loading archive contents...") 
                            : I18n.tr("%1 items inside").arg(archiveDialog.allFiles.length)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.1)
            }

            // Search Filter Field
            DankTextField {
                id: searchField
                placeholderText: I18n.tr("Search files in archive...")
                width: parent.width
                onTextChanged: archiveDialog.filterQuery = text.trim().toLowerCase()
            }

            // Scrollable List of Files
            Rectangle {
                width: parent.width
                height: 250
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                radius: Theme.cornerRadiusSmall
                border.color: Theme.withAlpha(Theme.outline, 0.1)
                clip: true

                ScrollView {
                    anchors.fill: parent
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ListView {
                        id: fileListView
                        width: parent.width
                        model: archiveDialog.filteredFiles
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            width: fileListView.width
                            height: 32
                            color: "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: modelData.isDir ? "folder" : "description"
                                    size: 16
                                    color: modelData.isDir ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.filePath
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 24
                                    elide: Text.ElideRight
                                    font.family: "monospace"
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: I18n.tr("No matching files found")
                            color: Theme.surfaceVariantText
                            visible: fileListView.count === 0 && !archiveDialog.isLoading
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.1)
            }

            // Footer Button
            Row {
                anchors.right: parent.right
                spacing: Theme.spacingS

                DankButton {
                    text: I18n.tr("Close")
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                    buttonHeight: 32
                    onClicked: archiveDialog.close()
                }
            }
        }
    }

    function showFor(path, name) {
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

        archiveDialog.filePath = cleanPath;
        archiveDialog.fileName = name;
        archiveDialog.allFiles = [];
        archiveDialog.filterQuery = "";
        searchField.text = "";
        archiveDialog.isLoading = true;

        archiveDialog.open();

        fetchContents();
    }

    function fetchContents() {
        const path = archiveDialog.filePath;
        const lower = path.toLowerCase();
        let isSevenZip = lower.endsWith(".7z");
        let isRar = lower.endsWith(".rar");
        let cmd = [];

        if (isSevenZip) {
            cmd = ["7z", "l", "-slt", path];
        } else if (isRar) {
            cmd = ["unrar-free", "-t", path];
        } else if (lower.endsWith(".zip")) {
            cmd = ["unzip", "-Z1", path];
        } else {
            // tar covers .tar.gz, .tgz, .tar.xz, .tar.bz2, .tar
            cmd = ["tar", "-tf", path];
        }

        Proc.runCommand("get-archive-contents", cmd, (output, exitCode) => {
            archiveDialog.isLoading = false;
            if (exitCode === 0) {
                let lines = output.trim().split("\n");
                let files = [];
                if (isSevenZip) {
                    let inItems = false;
                    let currentItem = null;
                    for (let line of lines) {
                        if (line.startsWith("----------")) {
                            inItems = true;
                            if (currentItem && currentItem.filePath !== "") {
                                files.push(currentItem);
                            }
                            currentItem = { "filePath": "", "isDir": false };
                            continue;
                        }
                        if (!inItems) continue;
                        if (line.startsWith("Path = ")) {
                            currentItem.filePath = line.substring(7).trim();
                        } else if (line.startsWith("Folder = +")) {
                            currentItem.isDir = true;
                        }
                    }
                    if (currentItem && currentItem.filePath !== "") {
                        files.push(currentItem);
                    }
                } else if (isRar) {
                    let inItems = false;
                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i];
                        if (line.startsWith("----------------------------------------------")) {
                            if (!inItems) {
                                inItems = true;
                                continue;
                            } else {
                                break;
                            }
                        }
                        if (!inItems) continue;
                        let pathLine = line.trim();
                        if (pathLine !== "") {
                            i++; // Skip metadata line
                            files.push({
                                "filePath": pathLine,
                                "isDir": pathLine.endsWith("/")
                            });
                        }
                    }
                } else {
                    for (let line of lines) {
                        let cleaned = line.trim();
                        if (cleaned !== "") {
                            files.push({
                                "filePath": cleaned,
                                "isDir": cleaned.endsWith("/")
                            });
                        }
                    }
                }
                archiveDialog.allFiles = files;
            } else {
                ToastService.showToast(I18n.tr("Failed to read archive contents"), ToastService.levelError);
                archiveDialog.close();
            }
        });
    }
}
