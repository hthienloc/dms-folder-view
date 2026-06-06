import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import "./dms-common"

Popup {
    id: renameDialog
    width: 260
    height: 156
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

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
        let isVirtualStack = cleanPath.startsWith("stack://");
        if (!isVirtualStack) {
            if (cleanPath.startsWith("file://")) {
                cleanPath = cleanPath.substring(7);
            }
            if (cleanPath.startsWith("localhost/")) {
                cleanPath = cleanPath.substring(9);
            }
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
            if (pathStr.startsWith("stack://")) {
                let stackId = pathStr.substring(8);
                if (typeof parent.renameStack === "function") {
                    parent.renameStack(stackId, newBaseName);
                }
                renameDialog.close();
                return;
            }
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
