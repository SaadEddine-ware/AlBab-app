import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    title: "AlBab" + (DevMode ? " [DEV]" : "")
    width: 1200
    height: 800
    minimumWidth: 960
    minimumHeight: 620
    visible: true
    color: Theme.pageBg

    property bool loggedIn: true

    property bool aiProcessing: false
    property string aiStatus: ""

    property bool _isGeminiProvider: (SettingsBackend.llmProvider || "OpenCode") === "Gemini"

    function _updateAIStatus(processing, status) {
        aiProcessing = processing
        aiStatus = status
    }

    Connections {
        target: typeof GeminiBackend !== 'undefined' ? GeminiBackend : null
        ignoreUnknownSignals: true
        function onStatusChanged(s) {
            if (!_isGeminiProvider) return
            if (s === "thinking" || s === "key_updated")
                _updateAIStatus(s === "thinking", s)
        }
        function onToolCallStarted(name, params) {
            if (!_isGeminiProvider) return
            _updateAIStatus(true, "Using " + name + "...")
        }
        function onToolCallFinished(name, result) {
            if (!_isGeminiProvider) return
            _updateAIStatus(false, "")
        }
        function onErrorOccurred(msg) {
            _updateAIStatus(false, "")
        }
        function onResponseReady(msg) {
            _updateAIStatus(false, "")
        }
    }

    Connections {
        target: typeof OpenCodeBackend !== 'undefined' ? OpenCodeBackend : null
        ignoreUnknownSignals: true
        function onStatusChanged(s) {
            if (_isGeminiProvider) return
            if (s === "thinking")
                _updateAIStatus(true, "OpenCode working...")
            else
                _updateAIStatus(false, "")
        }
        function onToolCallStarted(name, params) {
            if (_isGeminiProvider) return
            _updateAIStatus(true, "Using " + name + "...")
        }
        function onToolCallFinished(name, result) {
            if (_isGeminiProvider) return
            _updateAIStatus(false, "")
        }
        function onErrorOccurred(msg) {
            _updateAIStatus(false, "")
        }
        function onResponseReady(msg) {
            _updateAIStatus(false, "")
        }
    }

    function handleNew() {
        var p = pageStack.currentItem
        if (!p) return
        if (typeof p.onNew === "function") p.onNew()
    }
    function handleClose() {
        var p = pageStack.currentItem
        if (!p) return
        if (typeof p.onClose === "function") p.onClose()
    }
    function handleExport() {
        var p = pageStack.currentItem
        if (!p) return
        if (typeof p.onExport === "function") p.onExport()
    }

    Component.onCompleted: {
        if (typeof SettingsBackend !== 'undefined')
            Theme.darkMode = SettingsBackend.theme === "dark"
    }

    Connections {
        target: typeof SettingsBackend !== 'undefined' ? SettingsBackend : null
        ignoreUnknownSignals: true
        function onSettingsChanged() {
            Theme.darkMode = SettingsBackend.theme === "dark"
            _isGeminiProvider = (SettingsBackend.llmProvider || "OpenCode") === "Gemini"
        }
    }

    onWidthChanged: {
        if (width < 1000 && !sidebar.collapsed) sidebar.collapsed = true
        else if (width >= 1100 && sidebar.collapsed) sidebar.collapsed = false
    }

    Shortcut { sequence: "Ctrl+1"; onActivated: { sidebar.activeIndex = 0; pageStack.currentIndex = 0 } }
    Shortcut { sequence: "Ctrl+2"; onActivated: { sidebar.activeIndex = 1; pageStack.currentIndex = 1 } }
    Shortcut { sequence: "Ctrl+3"; onActivated: { sidebar.activeIndex = 2; pageStack.currentIndex = 2 } }
    Shortcut { sequence: "Ctrl+4"; onActivated: { sidebar.activeIndex = 3; pageStack.currentIndex = 3 } }
    Shortcut { sequence: "Ctrl+/"; onActivated: { aboutDialog.open() } }
    Shortcut { sequence: "Ctrl+N"; onActivated: handleNew() }
    Shortcut { sequence: "Ctrl+W"; onActivated: handleClose() }
    Shortcut { sequence: "Ctrl+E"; onActivated: handleExport() }

    Connections {
        target: typeof UserManager !== 'undefined' ? UserManager : null
        ignoreUnknownSignals: true
        function onUserChanged() {
            if (UserManager.isLoggedIn) {
                var ctx = "The user is " + UserManager.currentFirstName + " " + UserManager.currentLastName
                    + ", studying at " + UserManager.currentFaculty
                    + " (email: " + UserManager.currentEmail + ")."
                OpenCodeBackend.sendInput("SYSTEM: Remember this user context for this session: " + ctx)
                if (typeof OpenCodeBackend !== 'undefined' && typeof OpenCodeBackend.setUserContext === "function") OpenCodeBackend.setUserContext(ctx)
                if (typeof GeminiBackend !== 'undefined' && typeof GeminiBackend.setUserContext === "function") GeminiBackend.setUserContext(ctx)
            }
        }
    }

    Dialog {
        id: aboutDialog
        title: "About AlBab"
        modal: true
        width: 360
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingLg
            spacing: Theme.spacingMd
            Text { text: "\u0628"; color: Theme.accentCopper; font.pixelSize: 48; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
            Text { text: "AlBab Student Hub"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeXl; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
            Text { text: "AI-powered student tools"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeMd; Layout.alignment: Qt.AlignHCenter }
            Item { Layout.preferredHeight: 1 }
            Text { text: "Version 1.0.0"; color: Theme.textMuted; font.pixelSize: Theme.fontSizeSm; Layout.alignment: Qt.AlignHCenter }
            Text { text: "Shortcuts: Ctrl+1-4 switch pages, Ctrl+/ for help"; color: Theme.textMuted; font.pixelSize: Theme.fontSizeXs; Layout.alignment: Qt.AlignHCenter }
        }
    }

    Sidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        onPageRequested: (index) => { pageStack.currentIndex = index }
    }

    Rectangle {
        id: contentArea
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: Theme.pageBg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: Theme.glassBase
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: 1; color: Theme.divider
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingLg
                    anchors.rightMargin: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: pageStack.currentIndex === 0 ? "Home" :
                              pageStack.currentIndex === 1 ? "AI Chat" :
                              pageStack.currentIndex === 2 ? "Tools" :
                              pageStack.currentIndex === 3 ? "Settings" : "AlBab"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLg
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        Accessible.name: "Current page: " + text
                    }

                    Rectangle {
                        visible: DevMode
                        Layout.preferredWidth: 48; Layout.preferredHeight: 22
                        radius: 4; color: "#1FFF8000"
                        border.color: "#4DFF8000"
                        Text {
                            anchors.centerIn: parent
                            text: "DEV"; color: "#CC7700"
                            font.pixelSize: 9; font.weight: Font.Bold
                        }
                    }

                    Text {
                        text: UserManager.currentFaculty
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSm
                        visible: UserManager.isLoggedIn
                    }

                    Rectangle {
                        visible: UserManager.currentFirstName !== ""
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                        radius: width / 2; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: UserManager.currentFirstName ? UserManager.currentFirstName.charAt(0).toUpperCase() : ""
                            color: "#ffffff"; font.pixelSize: 12; font.weight: Font.Bold
                        }
                        Accessible.name: "User avatar"
                    }

                    Rectangle {
                        visible: UserManager.isLoggedIn
                        Layout.preferredWidth: 60; Layout.preferredHeight: 24
                        radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                        Text {
                            anchors.centerIn: parent
                            text: "Logout"
                            color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                UserManager.logout()
                                sidebar.activeIndex = 0
                                pageStack.currentIndex = 0
                            }
                        }
                        Accessible.name: "Logout"
                        Accessible.role: Accessible.Button
                    }
                }
            }

            StackLayout {
                id: pageStack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: 0

                MainPage { }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    GeminiChatPage { anchors.fill: parent; visible: _isGeminiProvider }
                    OpenCodeChatPage { anchors.fill: parent; visible: !_isGeminiProvider }
                }
                ToolsPage { }
                SettingsPage { }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: Theme.glassBase
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    height: 1; color: Theme.divider
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMd
                    anchors.rightMargin: Theme.spacingMd
                    spacing: Theme.spacingSm

                    Rectangle {
                        Layout.preferredWidth: 6; Layout.preferredHeight: 6
                        radius: 3
                        color: aiProcessing ? Theme.accentOrange : Theme.accentGreen
                        SequentialAnimation on opacity {
                            running: aiProcessing
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    Text {
                        text: aiProcessing ? (aiStatus || "AI Processing...") : "AI Ready"
                        color: aiProcessing ? Theme.accentOrange : Theme.accentGreen
                        font.pixelSize: Theme.fontSizeSm - 1
                        font.weight: Font.DemiBold
                    }

                    Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 12; color: Theme.divider }

                    Text {
                        text: "AlBab" + (DevMode ? " [DEV]" : "") + (UserManager.isLoggedIn ? "  \u00B7  " + UserManager.currentName : "")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeSm - 1
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Ctrl+1-4: Pages  |  Ctrl+/: Help"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
            }
        }
    }
}
