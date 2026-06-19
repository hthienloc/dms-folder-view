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
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    property string targetFolderUrl: ""
    property var allApps: []
    property string searchQuery: ""
    property var availableLetters: {
        let list = [];
        const apps = allApps || [];
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i];
            if (app && app.name) {
                const firstChar = app.name.trim().charAt(0).toUpperCase();
                const target = /^[A-Z]$/.test(firstChar) ? firstChar : "#";
                if (list.indexOf(target) === -1) {
                    list.push(target);
                }
            }
        }
        return list;
    }

    function cleanExec(execStr) {
        if (!execStr) return "";
        let clean = execStr.replace(/["']?%[fFuUickdnNvVm]["']?/g, "");
        clean = clean.replace(/%%/g, "%");
        return clean.trim();
    }

    function fetchApps() {
        // Fetch all apps directly from Quickshell's DesktopEntries singleton
        const allEntries = DesktopEntries.applications.values;
        let apps = [];
        for (let i = 0; i < allEntries.length; i++) {
            const app = allEntries[i];
            if (app && !app.noDisplay) {
                apps.push({
                    name: app.name || "",
                    exec: cleanExec(app.execString || (app.command ? app.command.join(" ") : "")),
                    icon: app.icon || ""
                });
            }
        }
        apps.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        createAppDialog.allApps = apps;
    }

    onOpened: {
        Qt.callLater(() => {
            searchField.text = "";
            createAppDialog.searchQuery = "";
            nameField.text = "";
            execField.text = "";
            iconField.text = "";
            if (createAppDialog.allApps.length === 0) {
                fetchApps();
            }
            modeStack.currentIndex = 0;
            searchField.forceActiveFocus();
        });
    }

    function jumpToLetter(letter) {
        const s = searchQuery.toLowerCase().trim();
        const filtered = allApps.filter(app => {
            return s === "" || (app.name && app.name.toLowerCase().indexOf(s) !== -1) || (app.exec && app.exec.toLowerCase().indexOf(s) !== -1);
        });

        let targetIndex = -1;
        for (let i = 0; i < filtered.length; i++) {
            const app = filtered[i];
            if (!app || !app.name) continue;
            const firstChar = app.name.trim().charAt(0).toUpperCase();
            
            if (letter === "#") {
                if (!/^[A-Z]$/.test(firstChar)) {
                    targetIndex = i;
                    break;
                }
            } else {
                if (firstChar === letter) {
                    targetIndex = i;
                    break;
                }
            }
        }

        if (targetIndex !== -1) {
            appListView.positionViewAtIndex(targetIndex, ListView.Beginning);
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

            // Dialog Header
            Item {
                width: parent.width
                height: 24
                
                StyledText {
                    text: I18n.tr("New Application")
                    font.bold: true
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Close Dialog Button
                MouseArea {
                    width: 24
                    height: 24
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: createAppDialog.close()
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

            // Tabs Segmented Control
            Rectangle {
                width: parent.width
                height: 32
                radius: 16
                color: Theme.withAlpha(Theme.surfaceText, 0.05)
                border.color: Theme.withAlpha(Theme.outline, 0.1)
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 2

                    // Tab 1: System Apps
                    MouseArea {
                        id: tabSysBtn
                        width: parent.width / 2
                        height: parent.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modeStack.currentIndex = 0;
                            searchField.forceActiveFocus();
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: modeStack.currentIndex === 0 ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: I18n.tr("System Apps")
                                font.bold: modeStack.currentIndex === 0
                                font.pixelSize: Theme.fontSizeSmall
                                color: modeStack.currentIndex === 0 ? Theme.onPrimary : Theme.surfaceText
                                opacity: modeStack.currentIndex === 0 ? 1.0 : (tabSysBtn.containsMouse ? 0.9 : 0.6)
                            }
                        }
                    }

                    // Tab 2: Custom App
                    MouseArea {
                        id: tabCustBtn
                        width: parent.width / 2
                        height: parent.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modeStack.currentIndex = 1;
                            nameField.forceActiveFocus();
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: modeStack.currentIndex === 1 ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: I18n.tr("Custom App")
                                font.bold: modeStack.currentIndex === 1
                                font.pixelSize: Theme.fontSizeSmall
                                color: modeStack.currentIndex === 1 ? Theme.onPrimary : Theme.surfaceText
                                opacity: modeStack.currentIndex === 1 ? 1.0 : (tabCustBtn.containsMouse ? 0.9 : 0.6)
                            }
                        }
                    }
                }
            }

            StackLayout {
                id: modeStack
                width: parent.width
                height: parent.height - 24 - 32 - (Theme.spacingS * 3)

                // Page 0: System Apps
                Column {
                    spacing: Theme.spacingS
                    width: parent.width
                    height: parent.height
                    
                    DankTextField {
                        id: searchField
                        width: parent.width
                        placeholderText: I18n.tr("Search apps...")
                        onTextChanged: createAppDialog.searchQuery = text
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height - searchField.height - Theme.spacingS
                        color: "transparent"
                        radius: Theme.cornerRadius - 2
                        border.color: Theme.withAlpha(Theme.outline, 0.1)
                        border.width: 1
                        clip: true

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: Theme.spacingXS

                            // Alphabet Index Sidebar (Left side)
                            Item {
                                id: indexSidebar
                                Layout.preferredWidth: 16
                                Layout.fillHeight: true
                                visible: appListView.count > 0 && createAppDialog.searchQuery === ""

                                Column {
                                    id: alphabetColumn
                                    anchors.centerIn: parent
                                    width: parent.width
                                    spacing: 1

                                    Repeater {
                                        model: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"]

                                        delegate: Item {
                                            id: letterItem
                                            required property var modelData
                                            width: parent.width
                                            height: Math.floor(Math.min(13, (indexSidebar.height - 30) / 27))

                                            readonly property bool hasApps: createAppDialog.availableLetters.includes(modelData)

                                            HoverHandler {
                                                id: letterHover
                                                enabled: letterItem.hasApps
                                            }

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: letterHover.hovered ? 9 : 8
                                                font.bold: hasApps || letterHover.hovered
                                                color: letterHover.hovered ? Theme.primary : (hasApps ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.3))
                                                opacity: hasApps ? 1.0 : 0.6
                                                Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: letterItem.hasApps
                                                cursorShape: letterItem.hasApps ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    createAppDialog.jumpToLetter(modelData);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // List of Apps (Right side)
                            ListView {
                                id: appListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                spacing: 2
                                model: {
                                    const s = createAppDialog.searchQuery.toLowerCase().trim();
                                    return createAppDialog.allApps.filter(app => {
                                        return s === "" || (app.name && app.name.toLowerCase().indexOf(s) !== -1) || (app.exec && app.exec.toLowerCase().indexOf(s) !== -1);
                                    });
                                }
                                delegate: Rectangle {
                                    width: appListView.width
                                    height: 38
                                    radius: 6
                                    color: appMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.04) : "transparent"
                                    
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingS
                                        spacing: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Image {
                                            id: appImg
                                            source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                                            width: 24
                                            height: 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: modelData.icon !== ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                        }
                                        
                                        DankIcon {
                                            name: "widgets"
                                            size: 24
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !appImg.visible || appImg.status === Image.Error
                                            color: Theme.primary
                                        }

                                        StyledText {
                                            text: modelData.name
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width - 48
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: appMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            createAppDialog.createSystemAppShortcut(modelData.name, modelData.exec, modelData.icon);
                                        }
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
        try {
            return decodeURIComponent(pathStr);
        } catch (e) {
            return pathStr;
        }
    }

    function createSystemAppShortcut(appName, appExec, appIcon) {
        let pathStr = getTargetFolder();
        let safeName = appName.replace(/[^a-zA-Z0-9_-]/g, "_");
        const targetPath = pathStr + "/" + safeName + ".desktop";
        const content = "[Desktop Entry]\nType=Application\nName=" + appName + "\nExec=" + appExec + "\nIcon=" + appIcon + "\nTerminal=false\n";
        try {
            const escapedContent = content.replace(/'/g, "'\\''");
            const escapedPath = targetPath.replace(/'/g, "'\\''");
            const shellCmd = "printf '%s' '" + escapedContent + "' > '" + escapedPath + "'";
            Quickshell.execDetached(["sh", "-c", shellCmd]);
        } catch (e) {
            ToastService.showToast("Create error: " + e.message, ToastService.levelError);
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
            // Write to file cleanly using POSIX printf, removing dependency on python3 for writing files
            const escapedContent = content.replace(/'/g, "'\\''");
            const escapedPath = targetPath.replace(/'/g, "'\\''");
            const shellCmd = "printf '%s' '" + escapedContent + "' > '" + escapedPath + "'";
            Quickshell.execDetached(["sh", "-c", shellCmd]);
        } catch (e) {
            ToastService.showToast("Create error: " + e.message, ToastService.levelError);
        }
        createAppDialog.close();
    }
}
