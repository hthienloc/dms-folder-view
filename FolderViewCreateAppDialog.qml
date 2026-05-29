import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import "./dms-common"

Popup {
    id: createAppDialog
    width: 280
    height: contentColumn.implicitHeight + Theme.spacingM * 2
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property string targetFolderUrl: ""

    onOpened: {
        Qt.callLater(() => {
            nameField.text = "";
            execField.text = "";
            iconField.text = "";
            nameField.forceActiveFocus();
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
            spacing: Theme.spacingS

            StyledText {
                text: I18n.tr("New App")
                font.bold: true
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            DankTextField {
                id: nameField
                width: parent.width
                placeholderText: I18n.tr("App name...")
                focus: true
                onAccepted: execField.forceActiveFocus()
            }

            DankTextField {
                id: execField
                width: parent.width
                placeholderText: I18n.tr("Command...")
                onAccepted: iconField.forceActiveFocus()
            }

            DankTextField {
                id: iconField
                width: parent.width
                placeholderText: I18n.tr("Icon (optional)...")
                onAccepted: createAppDialog.performCreate()
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS
                layoutDirection: Qt.RightToLeft

                DankButton {
                    text: I18n.tr("Create")
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: createAppDialog.performCreate()
                }

                DankButton {
                    text: I18n.tr("Cancel")
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                    onClicked: createAppDialog.close()
                }
            }
        }
    }

    function show() {
        createAppDialog.open();
    }

    function performCreate() {
        const name = nameField.text.trim();
        const execVal = execField.text.trim();
        let iconVal = iconField.text.trim();

        if (name.length === 0 || execVal.length === 0) {
            ToastService.showToast(I18n.tr("App name and Command are required"), ToastService.levelWarning);
            return;
        }

        if (iconVal.length === 0) {
            iconVal = "application-x-executable";
        }

        let pathStr = String(createAppDialog.targetFolderUrl);
        if (pathStr.startsWith("file://")) {
            pathStr = pathStr.substring(7);
        }
        if (pathStr.startsWith("localhost/")) {
            pathStr = pathStr.substring(9);
        }

        const fileName = name.endsWith(".desktop") ? name : name + ".desktop";
        const targetPath = pathStr + "/" + fileName;

        const content = "[Desktop Entry]\nType=Application\nName=" + name + "\nExec=" + execVal + "\nIcon=" + iconVal + "\nTerminal=false\n";

        try {
            Quickshell.execDetached(["python3", "-c", "import sys; open(sys.argv[1], 'w').write(sys.argv[2])", targetPath, content]);
        } catch (e) {
            ToastService.showToast("Create error: " + e.message, ToastService.levelError);
        }
        createAppDialog.close();
    }
}
