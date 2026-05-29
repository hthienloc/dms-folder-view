import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import "./dms-common"

Popup {
    id: createAppDialog
    width: 380
    height: 520
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property string targetFolderUrl: ""
    property var allApps: []

    function fetchApps() {
        if (createAppDialog.allApps.length > 0) {
            updateAppModel();
            return;
        }
        
        let scriptPath = Qt.resolvedUrl("scripts/scan_apps.py").toString().replace("file://", "");
        if (scriptPath.startsWith("localhost/")) {
            scriptPath = scriptPath.substring(10);
        }
        
        Proc.runCommand("dmsFolderView.scanApps", ["python3", scriptPath], (out, code) => {
            if (code === 0 && out) {
                try {
                    const data = JSON.parse(out);
                    createAppDialog.allApps = data;
                    updateAppModel();
                } catch(e) {
                    console.log("Error parsing apps: " + e);
                }
            }
        });
    }

    onOpened: {
        Qt.callLater(() => {
            searchField.text = "";
            nameField.text = "";
            execField.text = "";
            iconField.text = "";
            if (createAppDialog.allApps.length === 0) {
                fetchApps();
            } else {
                updateAppModel();
            }
            modeStack.currentIndex = 0;
            searchField.forceActiveFocus();
        });
    }

    function updateAppModel() {
        appModel.clear();
        const query = searchField.text.trim().toLowerCase();
        for (let i = 0; i < allApps.length; i++) {
            const app = allApps[i];
            if (query === "" || app.name.toLowerCase().indexOf(query) !== -1 || app.exec.toLowerCase().indexOf(query) !== -1) {
                appModel.append({
                    appName: app.name,
                    appExec: app.exec,
                    appIcon: app.icon,
                    appFilepath: app.filepath
                });
            }
        }
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

            Row {
                width: parent.width
                spacing: Theme.spacingS
                
                DankButton {
                    text: I18n.tr("System Apps")
                    backgroundColor: modeStack.currentIndex === 0 ? Theme.primary : "transparent"
                    textColor: modeStack.currentIndex === 0 ? Theme.primaryText : Theme.surfaceText
                    onClicked: {
                        modeStack.currentIndex = 0;
                        searchField.forceActiveFocus();
                    }
                }
                
                DankButton {
                    text: I18n.tr("Custom App")
                    backgroundColor: modeStack.currentIndex === 1 ? Theme.primary : "transparent"
                    textColor: modeStack.currentIndex === 1 ? Theme.primaryText : Theme.surfaceText
                    onClicked: {
                        modeStack.currentIndex = 1;
                        nameField.forceActiveFocus();
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.15)
            }

            StackLayout {
                id: modeStack
                width: parent.width
                height: parent.height - 48

                // Page 0: System Apps
                Column {
                    spacing: Theme.spacingS
                    
                    DankTextField {
                        id: searchField
                        width: parent.width
                        placeholderText: I18n.tr("Search apps...")
                        onTextChanged: updateAppModel()
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height - searchField.height - Theme.spacingS
                        color: "transparent"
                        radius: Theme.cornerRadius - 2
                        border.color: Theme.withAlpha(Theme.outline, 0.1)
                        border.width: 1
                        clip: true

                        ListModel { id: appModel }

                        ListView {
                            id: appListView
                            anchors.fill: parent
                            model: appModel
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                width: parent.width
                                height: 56
                                color: appMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.1) : "transparent"
                                
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingS
                                    
                                    Image {
                                        id: appImg
                                        source: model.appIcon ? Quickshell.iconPath(model.appIcon) : ""
                                        width: 36
                                        height: 36
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: model.appIcon !== ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                    
                                    DankIcon {
                                        name: "widgets"
                                        size: 36
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !appImg.visible || appImg.status === Image.Error
                                        color: Theme.primary
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 50
                                        spacing: 2
                                        StyledText {
                                            text: model.appName
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.bold: true
                                            color: Theme.surfaceText
                                        }
                                        StyledText {
                                            text: model.appExec
                                            font.pixelSize: Theme.fontSizeTiny
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                }

                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        createAppDialog.copySystemApp(model.appFilepath, model.appName);
                                    }
                                }
                            }
                        }
                    }
                }

                // Page 1: Custom App
                Column {
                    spacing: Theme.spacingS

                    DankTextField {
                        id: nameField
                        width: parent.width
                        placeholderText: I18n.tr("App name...")
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

                    Item { width: 1; height: Theme.spacingM }

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
        }
    }

    function show() {
        createAppDialog.open();
    }

    function getTargetFolder() {
        let pathStr = String(createAppDialog.targetFolderUrl);
        if (pathStr.startsWith("file://")) {
            pathStr = pathStr.substring(7);
        }
        if (pathStr.startsWith("localhost/")) {
            pathStr = pathStr.substring(9);
        }
        return pathStr;
    }

    function copySystemApp(sourceFilepath, appName) {
        let pathStr = getTargetFolder();
        let safeName = appName.replace(/[^a-zA-Z0-9_-]/g, "_");
        const targetPath = pathStr + "/" + safeName + ".desktop";
        try {
            Quickshell.execDetached(["cp", sourceFilepath, targetPath]);
        } catch (e) {
            ToastService.showToast("Copy error: " + e.message, ToastService.levelError);
        }
        createAppDialog.close();
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

        let pathStr = getTargetFolder();
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
