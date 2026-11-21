import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

Pane {
    padding: 0
    id: consolePane
    // Hebrew UI: lay everything out right-to-left
    LayoutMirroring.enabled: root.rtl
    LayoutMirroring.childrenInherit: true
    property string uiLang: Chiaki.uiLanguage()
    readonly property bool psnSignedIn: !!Chiaki.settings.psnAuthToken && !!Chiaki.settings.psnAccountId
    readonly property color cardColor: "#1b2030"
    readonly property color cardBorder: "#2b3246"
    readonly property color softText: "#9aa3b8"
    readonly property int visibleHosts: {
        let n = 0;
        for (let i = 0; i < Chiaki.hosts.length; ++i)
            if (Chiaki.hosts[i].display)
                n++;
        return n;
    }
    // Play profiles for the home network (0 = fast response, 1 = balanced, 2 = best picture, -1 = custom).
    // Each one sets resolution, bitrate and the picture-processing preset together.
    readonly property int qualityPreset: {
        const r = Chiaki.settings.resolutionLocalPS5, f = Chiaki.settings.fpsLocalPS5, b = Chiaki.settings.bitrateLocalPS5, v = Chiaki.settings.videoPreset;
        if (f != 60) return -1;
        if (r == 3 && b == 0 && v == 0) return 0;
        if (r == 4 && b == 0 && v == 2) return 1;
        if (r == 4 && b == 30000 && v == 3) return 2;
        return -1;
    }
    function applyQualityPreset(preset) {
        Chiaki.settings.resolutionLocalPS5 = [3, 4, 4][preset];
        Chiaki.settings.fpsLocalPS5 = 60;
        Chiaki.settings.bitrateLocalPS5 = [0, 0, 30000][preset];
        Chiaki.settings.resolutionLocalPS4 = [2, 3, 4][preset];
        Chiaki.settings.fpsLocalPS4 = 60;
        Chiaki.settings.bitrateLocalPS4 = preset == 2 ? 15000 : 0;
        // 0 = fast, 2 = high quality, 3 = high quality + spatial upscaling
        Chiaki.settings.videoPreset = [0, 2, 3][preset];
        Chiaki.settings.vSyncEnabled = false;
    }
    function showGuide() {
        root.showInfoDialog(qsTr("How to start playing"), qsTr("1. On the PS5: Settings > System > Remote Play > Enable Remote Play.\n    On the PS4: Settings > Remote Play Connection Settings > Enable.\n\n2. Make sure the console and this computer are on the same home network.\n    The console appears on this screen by itself within a few seconds.\n\n3. Sign in to your PlayStation account, then click Connect on the console.\n    Registration is needed only once.\n\n4. Connect the controller by USB cable or Bluetooth and click Play.\n\nTip: for full DualSense haptics connect the controller by USB cable."));
    }
    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#161a26" }
            GradientStop { position: 1.0; color: "#0b0d14" }
        }
    }
    StackView.onActivated: {
        forceActiveFocus(Qt.TabFocusReason);
        if(!Chiaki.autoConnect && !root.initialAsk && !Chiaki.window.directStream)
        {
            root.initialAsk = true;
        }
    }
    Keys.onUpPressed: {
        if(hostsView.currentItem && hostsView.currentItem.visible)
        {
            hostsView.decrementCurrentIndex()
            while(!hostsView.currentItem.visible)
                hostsView.decrementCurrentIndex()
        }
    }
    Keys.onDownPressed: {
        if(hostsView.currentItem && hostsView.currentItem.visible)
        {
            hostsView.incrementCurrentIndex()
            while(!hostsView.currentItem.visible)
                 hostsView.incrementCurrentIndex()
        }
    }
    Keys.onMenuPressed: settingsButton.clicked()
    Keys.onReturnPressed: if (hostsView.currentItem) hostsView.currentItem.connectToHost()
    Keys.onYesPressed: if (hostsView.currentItem) hostsView.currentItem.wakeUpHost()
    Keys.onNoPressed: if (hostsView.currentItem) hostsView.currentItem.deleteHost()
    Keys.onEscapePressed: root.showConfirmDialog(qsTr("Quit"), qsTr("Are you sure you want to quit?"), () => Qt.quit())
    Keys.onPressed: (event) => {
        if (event.modifiers)
            return;
        switch (event.key) {
        case Qt.Key_PageUp:
            if (hostsView.currentItem) hostsView.currentItem.setConsolePin();
            event.accepted = true;
            break;
        case Qt.Key_PageDown:
            if (Chiaki.settings.psnAuthToken) Chiaki.refreshPsnToken();
            event.accepted = true;
            break;
        case Qt.Key_F1:
            if (typeof Chiaki.createSteamShortcut === "function") root.showSteamShortcutDialog(false);
            event.accepted = true;
            break;
        case Qt.Key_F2:
            root.showManualHostDialog();
            event.accepted = true;
            break;
        }
    }

    Item {
        id: toolBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 96

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 28
                rightMargin: 28
            }
            spacing: 14

            ColumnLayout {
                spacing: 0
                Label {
                    text: "RemoPlay"
                    font.pixelSize: 34
                    font.bold: true
                    color: Material.accent
                }
                Label {
                    text: qsTr("Play your PlayStation on any screen")
                    font.pixelSize: 16
                    color: consolePane.softText
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                Layout.preferredHeight: 56
                flat: true
                text: qsTr("Steam shortcut")
                font.pixelSize: 18
                focusPolicy: Qt.NoFocus
                onClicked: root.showSteamShortcutDialog(false)
                Material.roundedScale: Material.FullScale
                visible: false
            }

            Button {
                Layout.preferredHeight: 56
                flat: true
                text: qsTr("Refresh PSN consoles")
                font.pixelSize: 18
                focusPolicy: Qt.NoFocus
                onClicked: Chiaki.refreshPsnToken();
                Material.roundedScale: Material.FullScale
                visible: Chiaki.settings.psnAuthToken
            }

            Button {
                Layout.preferredHeight: 56
                text: qsTr("+  Add console")
                font.pixelSize: 18
                focusPolicy: Qt.NoFocus
                onClicked: root.showManualHostDialog()
                Material.roundedScale: Material.FullScale
                Material.background: consolePane.cardColor
            }

            Button {
                Layout.preferredHeight: 56
                flat: true
                text: qsTr("?  Getting started")
                font.pixelSize: 18
                focusPolicy: Qt.NoFocus
                onClicked: consolePane.showGuide()
                Material.roundedScale: Material.FullScale
            }

            RoundButton {
                id: settingsButton
                Layout.preferredHeight: 60
                Layout.preferredWidth: 60
                icon.source: "qrc:/icons/settings-20px.svg";
                icon.width: 30
                icon.height: 30
                focusPolicy: Qt.NoFocus
                onClicked: root.showSettingsDialog()
                Material.background: consolePane.cardColor
            }

            RoundButton {
                Layout.preferredHeight: 60
                Layout.preferredWidth: 60
                text: "×"
                font.pixelSize: 30
                focusPolicy: Qt.NoFocus
                onClicked: root.showConfirmDialog(qsTr("Quit"), qsTr("Are you sure you want to quit?"), () => Qt.quit())
                Material.background: consolePane.cardColor
            }
        }
    }

    ListView {
        id: hostsView
        keyNavigationWraps: true
        anchors {
            top: toolBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 10
            bottomMargin: 80
            leftMargin: 28
            rightMargin: 28
        }
        clip: true
        model: Chiaki.hosts
        header: Item {
            width: hostsView.width
            height: consolePane.psnSignedIn ? 0 : 150
            visible: !consolePane.psnSignedIn

            Rectangle {
                anchors {
                    fill: parent
                    topMargin: 8
                    bottomMargin: 8
                }
                radius: 22
                color: "#2a2233"
                border.width: 1
                border.color: Material.accent

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 26
                        rightMargin: 26
                    }
                    spacing: 20

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Label {
                            text: qsTr("Step 1: sign in to your PlayStation account")
                            font.pixelSize: 24
                            font.bold: true
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr("Sign in once with your PlayStation email and password. After that, connecting a console takes one click.")
                            font.pixelSize: 17
                            color: consolePane.softText
                        }
                    }

                    Button {
                        Layout.preferredHeight: 64
                        text: qsTr("Sign in to PlayStation")
                        font.pixelSize: 20
                        font.bold: true
                        focusPolicy: Qt.NoFocus
                        Material.background: Material.accent
                        Material.foreground: "#101218"
                        Material.roundedScale: Material.FullScale
                        onClicked: root.showPSNTokenDialog(false)
                    }
                }
            }
        }
        onCountChanged: {
            if(!hostsView.currentItem)
                hostsView.incrementCurrentIndex();
            if(!hostsView.currentItem)
                return;
            if(!hostsView.currentItem.visible)
            {
                for(var i = 0; i < hostsView.count; i++)
                {
                    hostsView.incrementCurrentIndex()
                    if(hostsView.currentItem.visible)
                    {
                        break;
                    }
                }
            }
        }
        delegate: Item {
            visible: modelData.display
            id: delegate
            width: parent ? parent.width : 0
            height: modelData.display ? 196 : 0
            readonly property bool highlighted: ListView.isCurrentItem
            readonly property bool online: modelData.state == "ready"
            readonly property bool standby: modelData.state == "standby"

            function connectToHost() {
                // First connection: sign in to PlayStation once, then registration is automatic
                if(!modelData.registered && !modelData.duid && !consolePane.psnSignedIn) {
                    root.showPSNTokenDialog(false);
                    return;
                }
                if(modelData.discovered)
                    Chiaki.connectToHost(index, modelData.name);
                else
                    Chiaki.connectToHost(index);
            }

            function registerWithCode() {
                if(modelData.discovered)
                    Chiaki.connectToHost(index, modelData.name);
                else
                    Chiaki.connectToHost(index);
            }

            function wakeUpHost() {
                if(!modelData.discovered && !modelData.duid)
                    Chiaki.wakeUpHost(index);
            }

            function deleteHost() {
                if (modelData.manual)
                    root.showConfirmDialog(qsTr("Delete Console"), qsTr("Are you sure you want to delete this console?"), () => {Chiaki.deleteHost(index)});

                else if (modelData.discovered && !modelData.registered)
                    root.showConfirmDialog(qsTr("Hide Console"), qsTr("Are you sure you want to hide this console?") + "\n\n" + qsTr("Note: You can unhide from the Consoles section of the Settings under Hidden Consoles"), () => Chiaki.hideHost(modelData.mac, modelData.name));

            }

            function setConsolePin() {
                root.showConsolePinDialog(index);
            }

            Rectangle {
                id: card
                anchors {
                    fill: parent
                    topMargin: 8
                    bottomMargin: 8
                }
                radius: 22
                color: cardMouse.containsMouse ? Qt.lighter(consolePane.cardColor, 1.15) : consolePane.cardColor
                border.width: delegate.highlighted ? 3 : 1
                border.color: delegate.highlighted ? Material.accent : consolePane.cardBorder

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        hostsView.currentIndex = index;
                        delegate.connectToHost();
                    }
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 26
                        rightMargin: 26
                        topMargin: 14
                        bottomMargin: 14
                    }
                    spacing: 28

                    Image {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 120
                        fillMode: Image.PreserveAspectFit
                        source: "image://svg/console-ps" + (modelData.ps5 ? "5" : "4") + (modelData.state == "standby" ? "#light_standby" : "#light_on")
                        sourceSize: Qt.size(width, height)
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Label {
                            text: modelData.name ? modelData.name : (modelData.ps5 ? "PlayStation 5" : "PlayStation 4")
                            font.pixelSize: 28
                            font.bold: true
                        }

                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: delegate.online ? "#3ddc84" : (delegate.standby ? "#ffb347" : "#6b7388")
                            }
                            Label {
                                font.pixelSize: 20
                                text: {
                                    if (modelData.duid && !modelData.discovered)
                                        return qsTr("Remote Connection via PSN");
                                    if (delegate.online)
                                        return qsTr("Online");
                                    if (delegate.standby)
                                        return qsTr("Rest mode");
                                    return qsTr("Not found on the network");
                                }
                            }
                        }

                        Label {
                            font.pixelSize: 16
                            color: consolePane.softText
                            visible: text.length > 0
                            text: {
                                let parts = [];
                                if (modelData.address)
                                    parts.push(Chiaki.settings.streamerMode ? qsTr("address hidden") : modelData.address);
                                parts.push(modelData.registered ? qsTr("registered") : qsTr("unregistered"));
                                if (modelData.duid && modelData.discovered)
                                    parts.push(qsTr("Automatic Registration Available"));
                                else if (modelData.manual)
                                    parts.push(qsTr("manual"));
                                return parts.join("  ·  ");
                            }
                        }

                        Label {
                            font.pixelSize: 16
                            color: consolePane.softText
                            visible: !!modelData.app
                            text: modelData.app ? qsTr("App: %1").arg(modelData.app) : ""
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: modelData.manual ? qsTr("Delete") : qsTr("Hide")
                            flat: true
                            font.pixelSize: 16
                            focusPolicy: Qt.NoFocus
                            visible: modelData.manual || (modelData.discovered && !modelData.registered)
                            onClicked: delegate.deleteHost()
                            Material.roundedScale: Material.FullScale
                        }

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Register with a code instead")
                            flat: true
                            font.pixelSize: 16
                            visible: !modelData.registered && !modelData.duid
                            focusPolicy: Qt.NoFocus
                            onClicked: delegate.registerWithCode()
                            Material.roundedScale: Material.FullScale
                        }

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Wake Up")
                            flat: true
                            font.pixelSize: 16
                            visible: modelData.registered && !modelData.duid && !modelData.discovered
                            focusPolicy: Qt.NoFocus
                            onClicked: delegate.wakeUpHost()
                            Material.roundedScale: Material.FullScale
                        }

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Update Console Pin")
                            flat: true
                            font.pixelSize: 16
                            visible: modelData.registered
                            focusPolicy: Qt.NoFocus
                            onClicked: delegate.setConsolePin()
                            Material.roundedScale: Material.FullScale
                        }
                    }

                    Button {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: 72
                        Layout.preferredWidth: 170
                        text: modelData.registered ? qsTr("▶  Play") : qsTr("Connect")
                        font.pixelSize: 24
                        font.bold: true
                        focusPolicy: Qt.NoFocus
                        Material.background: Material.accent
                        Material.foreground: "#101218"
                        Material.roundedScale: Material.FullScale
                        onClicked: {
                            hostsView.currentIndex = index;
                            delegate.connectToHost();
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: consolePane.visibleHosts == 0
        spacing: 14

        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: parent.visible && Chiaki.discoveryEnabled
            visible: Chiaki.discoveryEnabled
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: Chiaki.discoveryEnabled ? qsTr("Searching for consoles on your home network...") : qsTr("Automatic search is off")
            font.pixelSize: 26
            font.bold: true
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            color: consolePane.softText
            font.pixelSize: 18
            text: qsTr("Make sure the PlayStation is on or in rest mode and on the same network as this computer.\nYou can also add a console manually by address.")
        }
        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            Layout.preferredHeight: 56
            text: qsTr("Guide: getting started")
            font.pixelSize: 18
            focusPolicy: Qt.NoFocus
            Material.background: Material.accent
            Material.foreground: "#101218"
            Material.roundedScale: Material.FullScale
            onClicked: consolePane.showGuide()
        }
    }

    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 28
            rightMargin: 28
            bottomMargin: 16
        }
        spacing: 12

        Switch {
            focusPolicy: Qt.NoFocus
            checked: Chiaki.discoveryEnabled
            onToggled: Chiaki.discoveryEnabled = !Chiaki.discoveryEnabled
        }
        Label {
            text: qsTr("Automatic console search")
            font.pixelSize: 16
            color: consolePane.softText
        }
        Item { Layout.preferredWidth: 30 }
        Label {
            text: qsTr("Play mode:")
            font.pixelSize: 16
            color: consolePane.softText
        }
        Repeater {
            model: [
                { name: qsTr("Fast response"), hint: qsTr("720p, minimal picture processing - lowest delay") },
                { name: qsTr("Balanced"), hint: qsTr("1080p, 60 fps - recommended for most networks") },
                { name: qsTr("Best picture"), hint: qsTr("1080p at double bitrate + sharpening - for fast Wi-Fi or cable") }
            ]
            Button {
                Layout.preferredHeight: 44
                text: modelData.name
                font.pixelSize: 16
                focusPolicy: Qt.NoFocus
                flat: consolePane.qualityPreset != index
                Material.background: consolePane.qualityPreset == index ? Material.accent : "transparent"
                Material.foreground: consolePane.qualityPreset == index ? "#101218" : "#ffffff"
                Material.roundedScale: Material.FullScale
                onClicked: consolePane.applyQualityPreset(index)
                ToolTip.visible: hovered
                ToolTip.text: modelData.hint
            }
        }
        Item { Layout.fillWidth: true }
        Button {
            Layout.preferredHeight: 44
            flat: true
            font.pixelSize: 16
            focusPolicy: Qt.NoFocus
            text: consolePane.uiLang == "en" ? "Language: English" : "שפה: עברית"
            Material.roundedScale: Material.FullScale
            onClicked: languageMenu.open()
            Menu {
                id: languageMenu
                Repeater {
                    model: [ { code: "he", name: "עברית" }, { code: "en", name: "English" } ]
                    MenuItem {
                        text: modelData.name
                        onTriggered: {
                            if (consolePane.uiLang == modelData.code)
                                return;
                            Chiaki.setUiLanguage(modelData.code);
                            consolePane.uiLang = modelData.code;
                            root.showInfoDialog(modelData.code == "en" ? "Language" : "שפה",
                                modelData.code == "en" ? "English will be used the next time you open the app." : "העברית תופעל בפעם הבאה שתפתח את האפליקציה.");
                        }
                    }
                }
            }
        }
        Label {
            text: qsTr("Version %1  ·  based on chiaki-ng (open source, AGPL-3.0)").arg(Qt.application.version)
            font.pixelSize: 14
            color: consolePane.softText
        }
    }
}
