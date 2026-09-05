import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true
    anchors.fill: parent

    property int pendingIdx: -1
    property bool isLoading: false
    property bool sessionPanelOpen: false
    property bool sessionPanelCollapsed: false
    property real sessionPanelWidth: sessionPanelCollapsed ? 64 : 300
    property real inputAreaHeight: 60
    property ListModel searchResultsModel: ListModel { }

    Component.onCompleted: {
        var existing = ChatSessionManager.sessions
        if (existing.length > 0) {
            var target = ChatSessionManager.currentSessionId || existing[0].id
            root.switchToSession(target)
        } else {
            ChatSessionManager.newSession("Gemini")
        }
    }

    function loadSessionMessages() {
        chatModel.clear()
        var msgs = ChatSessionManager.loadMessages()
        for (var i = 0; i < msgs.length; i++) {
            var m = msgs[i]
            var entry = { role: m.role, text: m.content, isError: m.isError, reasoning: "", tokens: "", tokensInput: 0, tokensOutput: 0, reasoningExpanded: false, msgId: m.id, editing: false }
            if (m.role === "ai") {
                entry.reasoning = m.reasoning || ""
                var tin = parseInt(m.tokensInput) || 0
                var tout = parseInt(m.tokensOutput) || 0
                entry.tokensInput = tin
                entry.tokensOutput = tout
                entry.tokens = (tin || tout) ? "\u2191" + tin + " \u2193" + tout + " tokens" : ""
            }
            chatModel.append(entry)
        }
    }

    function switchToSession(id) {
        ChatSessionManager.switchSession(id)
        var msgs = ChatSessionManager.loadMessagesForSession(id)
        GeminiBackend.setHistory(JSON.stringify(msgs))
        GeminiBackend.stopGeneration()
        pendingIdx = -1
        isLoading = false
        loadSessionMessages()
        sessionPanelOpen = false
    }

    Connections {
        target: typeof GeminiBackend !== 'undefined' ? GeminiBackend : null
        ignoreUnknownSignals: true
        function onResponseReady(msg) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                chatModel.setProperty(pendingIdx, "text", msg)
                var entry = chatModel.get(pendingIdx)
                root.saveAiMessage(msg, entry.reasoning || "", 0, 0)
            }
            isLoading = false
            pendingIdx = -1
        }
        function onToolCallStarted(toolName, params) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                var current = chatModel.get(pendingIdx).text
                chatModel.setProperty(pendingIdx, "text", current + "\n  \u2192 " + toolName)
            }
        }
        function onToolCallFinished(toolName, result) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                var current = chatModel.get(pendingIdx).text
                chatModel.setProperty(pendingIdx, "text", current + " \u2713")
            }
        }
        function onErrorOccurred(msg) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                chatModel.setProperty(pendingIdx, "text", "\u2716 " + msg)
                chatModel.setProperty(pendingIdx, "isError", true)
                var entry = chatModel.get(pendingIdx)
                root.saveAiMessage(msg, entry.reasoning || "", 0, 0)
            }
            isLoading = false
            pendingIdx = -1
        }
        function onOfflineChanged(offline) { }
        function onStatusChanged(status) { }
        function onReasoningReady(sessionId, text) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                var cur = chatModel.get(pendingIdx).reasoning || ""
                chatModel.setProperty(pendingIdx, "reasoning", cur + text)
                chatModel.setProperty(pendingIdx, "reasoningExpanded", true)
            }
        }
        function onTokenInfo(sessionId, inp, out) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                chatModel.setProperty(pendingIdx, "tokens", "\u2191" + inp + " \u2193" + out + " tokens")
                chatModel.setProperty(pendingIdx, "tokensInput", inp)
                chatModel.setProperty(pendingIdx, "tokensOutput", out)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.pageBg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Theme.glassBase

                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: 1; color: Theme.divider
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        text: "\u2630"
                        color: Theme.textSecondary
                        font.pixelSize: 16
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: sessionPanelOpen = !sessionPanelOpen
                        }
                        Accessible.name: "Sessions"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Gemini"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLg
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: newChatMouse.containsMouse ? Theme.chipBg : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "\u2795"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: newChatMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.onNew()
                        }
                        Accessible.name: "New chat"
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.pageBg

                ListView {
                    id: chatList
                    anchors.fill: parent
                    anchors.margins: 4
                    anchors.bottomMargin: 8
                    model: chatModel
                    spacing: 0
                    clip: true
                    onContentHeightChanged: {
                        if (contentHeight > height)
                            contentY = contentHeight - height
                    }

                    header: Item {
                        width: chatList.width
                        height: chatModel.count === 0 ? emptyState.height + 40 : 0
                        visible: chatModel.count === 0

                        Column {
                            id: emptyState
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -40
                            spacing: 24

                            Text {
                                text: "\u2728"
                                font.pixelSize: 40
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "Hello" + (UserManager.currentFirstName ? ", " + UserManager.currentFirstName : "")
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeXxl
                                font.weight: Font.Bold
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Text {
                                text: "How can I help you today?"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeLg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Flow {
                                width: 400
                                spacing: 8
                                anchors.horizontalCenter: parent.horizontalCenter

                                Repeater {
                                    model: ["Explain quantum computing", "Write a Python function", "Help me study for exams", "Summarize this article"]
                                    Rectangle {
                                        width: suggestionLabel.implicitWidth + 24
                                        height: 36
                                        radius: 18
                                        color: suggestionMouse.containsMouse ? Theme.chipBg : Theme.inputBg
                                        border.color: Theme.divider
                                        border.width: 1

                                        Text {
                                            id: suggestionLabel
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: Theme.textSecondary
                                            font.pixelSize: Theme.fontSizeSm
                                        }

                                        MouseArea {
                                            id: suggestionMouse
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: {
                                                chatInput.text = modelData
                                                chatInput.forceActiveFocus()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    delegate: Item {
                        width: chatList.width - 32
                        height: delegateCol.height + 16
                        anchors.horizontalCenter: parent.horizontalCenter

                        Column {
                            id: delegateCol
                            width: Math.min(parent.width, 720)
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 0

                            Item { height: 4; width: 1 }

                            Text {
                                visible: model.isError === true
                                width: parent.width
                                text: model.text
                                color: Theme.accentRed
                                font.pixelSize: Theme.fontSizeSm
                                wrapMode: Text.Wrap
                            }

                            Item {
                                visible: model.isError !== true && model.role === "user"
                                width: parent.width

                                RowLayout {
                                    anchors.right: parent.right
                                    anchors.left: parent.left
                                    spacing: 8
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        id: userBubble
                                        Layout.maximumWidth: parent.width * 0.8
                                        Layout.preferredWidth: bubbleText.implicitWidth + 24
                                        Layout.preferredHeight: bubbleText.implicitHeight + 24
                                        radius: Theme.radiusLg
                                        color: Theme.chipBg

                                        Text {
                                            id: bubbleText
                                            anchors.centerIn: parent
                                            width: userBubble.width - 24
                                            text: model.text
                                            color: Theme.textPrimary
                                            font.pixelSize: Theme.fontSizeMd
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }

                            Column {
                                visible: model.isError !== true && model.role !== "user"
                                width: parent.width
                                spacing: 4

                                Row {
                                    spacing: 8
                                    Text {
                                        text: "\u2728"
                                        font.pixelSize: 14
                                        color: Theme.accentBlue
                                        Layout.topMargin: 4
                                    }

                                    Rectangle {
                                        visible: model.reasoning && model.reasoning.length > 0
                                        width: reasoningRow.width + 16
                                        height: 22
                                        radius: 4
                                        color: Theme.inputBg

                                        Row {
                                            id: reasoningRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Text {
                                                text: model.reasoningExpanded ? "\u25BC" : "\u25B6"
                                                color: Theme.textMuted
                                                font.pixelSize: 9
                                            }
                                            Text {
                                                text: "Reasoning"
                                                color: Theme.textMuted
                                                font.pixelSize: Theme.fontSizeXs
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: chatModel.setProperty(index, "reasoningExpanded", !model.reasoningExpanded)
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: model.reasoning && model.reasoningExpanded
                                    width: parent.width
                                    radius: Theme.radiusSm
                                    color: Theme.inputBg

                                    Text {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        text: model.reasoning || ""
                                        color: Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeXs
                                        font.family: Theme.fontMono
                                        wrapMode: Text.Wrap
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: model.text
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeMd
                                    wrapMode: Text.Wrap
                                    textFormat: Text.Markdown
                                    linkColor: Theme.accentBlue
                                }

                                Row {
                                    visible: model.text !== "Working..." && model.text.length > 0
                                    spacing: 4
                                    anchors.topMargin: 4

                                    Text {
                                        text: "\u21BB"
                                        color: Theme.textMuted
                                        font.pixelSize: 13
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.regenerateAt(index)
                                        }
                                        Accessible.name: "Regenerate"
                                    }
                                }

                                Row {
                                    visible: model.text !== "Working..." && model.text.length > 0
                                    spacing: 6
                                    anchors.topMargin: 4

                                    Repeater {
                                        model: ["Tell me more", "Summarize", "Give me an example"]
                                        Rectangle {
                                            height: 28; radius: 14
                                            color: suggestionChipMouse.containsMouse ? Theme.chipBg : Theme.inputBg
                                            border.color: Theme.divider
                                            border.width: 1
                                            implicitWidth: chipLabel.implicitWidth + 16

                                            Text {
                                                id: chipLabel
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: Theme.textSecondary
                                                font.pixelSize: Theme.fontSizeXs
                                            }

                                            MouseArea {
                                                id: suggestionChipMouse
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: {
                                                    chatInput.text = modelData
                                                    chatInput.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { height: 4; width: 1 }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.divider
            }

            Rectangle {
                id: inputBar
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(chatInput.contentHeight + 24, 48), 150)
                color: Theme.pageBg
                onHeightChanged: inputAreaHeight = height + 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(chatInput.contentHeight + 16, 140)
                        radius: Theme.radiusLg
                        color: Theme.inputBg
                        border.color: chatInput.activeFocus ? Theme.accentBlue : Theme.divider

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 40
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: "Ask Gemini..."
                            color: Theme.placeholderText
                            font.pixelSize: Theme.fontSizeMd
                            visible: chatInput.text.length === 0 && !chatInput.activeFocus
                        }

                        TextEdit {
                            id: chatInput
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 40
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeMd
                            verticalAlignment: TextInput.AlignVCenter
                            focus: false
                            activeFocusOnTab: true
                            selectByMouse: true
                            wrapMode: Text.Wrap
                            Keys.onReturnPressed: {
                                if (!(event.modifiers & Qt.ShiftModifier)) {
                                    event.accepted = true
                                    sendMessage()
                                }
                            }
                            Keys.onEnterPressed: {
                                if (!(event.modifiers & Qt.ShiftModifier)) {
                                    event.accepted = true
                                    sendMessage()
                                }
                            }
                            Accessible.name: "Message input"
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32; radius: 16
                            color: GeminiBackend.isThinking ? Theme.textMuted : (chatInput.text.trim().length > 0 ? Theme.accentBlue : Theme.textMuted)

                            Text {
                                anchors.centerIn: parent
                                text: GeminiBackend.isThinking ? "\u25A0" : "\u2191"
                                color: "#FFFFFF"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (GeminiBackend.isThinking) {
                                        GeminiBackend.stopGeneration()
                                        isLoading = false
                                        if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                                            chatModel.setProperty(pendingIdx, "text", chatModel.get(pendingIdx).text + "\n\n*Stopped*")
                                        }
                                        pendingIdx = -1
                                    } else {
                                        sendMessage()
                                    }
                                }
                            }
                            Accessible.name: GeminiBackend.isThinking ? "Stop" : "Send"
                        }
                    }
                }
            }
        }

        Rectangle {
            id: sessionPanelOverlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: inputAreaHeight
            color: "#80000000"
            visible: sessionPanelOpen
            z: 100

            MouseArea {
                anchors.fill: parent
                onClicked: sessionPanelOpen = false
            }
        }

        Rectangle {
            id: sessionPanel
            width: sessionPanelWidth
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: inputAreaHeight
            x: sessionPanelOpen ? 0 : -sessionPanelWidth
            color: Theme.sidebarBg
            z: 101
            clip: true

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: Theme.sidebarBg

                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: 1; color: Theme.divider
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: sessionPanelCollapsed ? 0 : 16
                        anchors.rightMargin: sessionPanelCollapsed ? 0 : 12
                        spacing: 8

                        Text {
                            text: "\u2630"
                            color: Theme.textSecondary
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignHCenter
                            visible: sessionPanelCollapsed
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: sessionPanelCollapsed = false
                            }
                            Accessible.name: "Expand panel"
                        }

                        Text {
                            text: "Chats"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeLg
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            visible: !sessionPanelCollapsed
                        }

                        Rectangle {
                            width: 32; height: 32; radius: 16
                            color: newSessionMouse.containsMouse ? Theme.chipBg : "transparent"
                            visible: !sessionPanelCollapsed
                            Text {
                                anchors.centerIn: parent
                                text: "\u2795"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: newSessionMouse
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.onNew()
                            }
                            Accessible.name: "New chat"
                        }

                        Text {
                            text: "\u25C0"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            visible: !sessionPanelCollapsed
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: sessionPanelCollapsed = true
                            }
                            Accessible.name: "Collapse panel"
                        }

                        Text {
                            text: "\u2716"
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            visible: sessionPanelCollapsed
                            Layout.alignment: Qt.AlignHCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: sessionPanelOpen = false
                            }
                            Accessible.name: "Close"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40
                    color: Theme.sidebarBg
                    visible: !sessionPanelCollapsed

                    Rectangle {
                        anchors.fill: parent; anchors.margins: 8
                        radius: 20; color: Theme.inputBg; border.color: Theme.divider
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; spacing: 6
                            Text { text: "\u2315"; color: Theme.textMuted; font.pixelSize: 12 }
                            TextInput {
                                id: sessionSearch
                                Layout.fillWidth: true; Layout.fillHeight: true
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                Keys.onReturnPressed: root.searchMessages(sessionSearch.text)
                                Keys.onEnterPressed: root.searchMessages(sessionSearch.text)
                                Keys.onEscapePressed: { sessionSearch.text = ""; root.searchMessages("") }
                            }
                            Text {
                                text: "\u2716"; color: Theme.textMuted; font.pixelSize: 10
                                visible: sessionSearch.text.length > 0
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { sessionSearch.text = ""; root.searchMessages("") }
                                }
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 0
                    visible: !sessionSearch.text.length || searchResultsModel.count === 0
                    model: ChatSessionManager.sessions

                    delegate: Item {
                        width: ListView.view.width; height: sessionPanelCollapsed ? 48 : 48

                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4
                            radius: Theme.radiusSm
                            color: model.id === ChatSessionManager.currentSessionId ? Theme.chipBg : (sessionDelegateMouse.containsMouse ? Theme.inputBg : "transparent")
                        }

                        Rectangle {
                            visible: sessionPanelCollapsed
                            width: 32; height: 32; radius: 16
                            anchors.centerIn: parent
                            color: model.id === ChatSessionManager.currentSessionId ? Theme.accentBlue : Theme.chipBg
                            Text {
                                anchors.centerIn: parent
                                text: (model.name || "N").charAt(0).toUpperCase()
                                color: model.id === ChatSessionManager.currentSessionId ? "#FFFFFF" : Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                            }
                        }

                        Column {
                            visible: !sessionPanelCollapsed
                            anchors.left: parent.left; anchors.leftMargin: 16
                            anchors.right: parent.right; anchors.rightMargin: 72
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                width: parent.width
                                text: model.name || "New Chat"
                                color: model.id === ChatSessionManager.currentSessionId ? Theme.textPrimary : Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: model.id === ChatSessionManager.currentSessionId ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: (model.updatedAt || "").substring(0, 10) || ""
                                color: Theme.textMuted; font.pixelSize: Theme.fontSizeXs
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: sessionDelegateMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    renameDialog.sessionId = model.id
                                    renameInput.text = model.name || ""
                                    renameDialog.open()
                                    renameInput.forceActiveFocus()
                                    renameInput.selectAll()
                                } else {
                                    root.switchToSession(model.id)
                                }
                            }
                        }

                        Row {
                            visible: !sessionPanelCollapsed
                            anchors.right: parent.right; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: pinMouse.containsMouse ? Theme.chipBg : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: (model.pinned ? "\u2605" : "\u2606")
                                    color: model.pinned ? Theme.accentBlue : Theme.textMuted
                                    font.pixelSize: 15
                                }
                                MouseArea {
                                    id: pinMouse
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: ChatSessionManager.pinSession(model.id, !model.pinned)
                                    Accessible.name: "Pin chat"
                                }
                            }

                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: deleteMouse.containsMouse ? Theme.chipBg : "transparent"
                                visible: sessionDelegateMouse.containsMouse
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u232B"
                                    color: Theme.textMuted
                                    font.pixelSize: 14
                                }
                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        deleteDialog.sessionId = model.id
                                        deleteDialog.sessionName = model.name || ""
                                        deleteDialog.open()
                                    }
                                    Accessible.name: "Delete chat"
                                }
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 0
                    visible: sessionSearch.text.length > 0 && searchResultsModel.count > 0
                    model: searchResultsModel

                    delegate: Item {
                        width: ListView.view.width; height: 40
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12; spacing: 8
                            Text { text: model.role === "user" ? "\u2192" : "\u25B7"; color: Theme.accentBlue; font.pixelSize: 11 }
                            Text { text: model.content; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { sessionSearch.text = ""; searchResultsModel.clear() }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40
                    color: Theme.sidebarBg

                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        height: 1; color: Theme.divider
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: sessionPanelCollapsed ? 0 : 16
                        anchors.rightMargin: sessionPanelCollapsed ? 0 : 16
                        spacing: 8

                        Text {
                            text: "\u2B07"
                            color: Theme.textMuted; font.pixelSize: 12
                            visible: !sessionPanelCollapsed
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.exportSession() }
                            Accessible.name: "Export session"
                        }
                        Text {
                            text: GeminiBackend.keyStatus || ""
                            color: Theme.textMuted; font.pixelSize: Theme.fontSizeXs
                            visible: !sessionPanelCollapsed
                        }
                        Item { Layout.fillWidth: true; visible: !sessionPanelCollapsed }
                        Rectangle {
                            visible: GeminiBackend.isThinking
                            width: 8; height: 8; radius: 4; color: Theme.accentBlue
                            Layout.alignment: Qt.AlignHCenter
                            SequentialAnimation on opacity {
                                running: typeof GeminiBackend !== 'undefined' && GeminiBackend.isThinking
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: renameDialog
        property string sessionId: ""
        title: "Rename Chat"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            var name = renameInput.text.trim()
            if (name) ChatSessionManager.renameSession(renameDialog.sessionId, name)
        }

        TextInput {
            id: renameInput
            width: 300; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd
            selectByMouse: true
            Keys.onReturnPressed: renameDialog.accept()
            Keys.onEscapePressed: renameDialog.reject()
        }
    }

    Dialog {
        id: deleteDialog
        property string sessionId: ""
        property string sessionName: ""
        title: "Delete Chat?"
        modal: true
        anchors.centerIn: parent

        Text {
            width: 300
            text: "Delete \"" + deleteDialog.sessionName + "\"? Its messages will be removed permanently."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeMd
            wrapMode: Text.Wrap
        }

        footer: DialogButtonBox {
            Button { text: "Cancel"; DialogButtonBox.buttonRole: DialogButtonBox.RejectRole }
            Button {
                text: "Delete"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                onClicked: deleteDialog.accept()
            }
        }
        onAccepted: root.deleteSession(deleteDialog.sessionId)
    }

    function sendMessage() {
        var text = chatInput.text.trim()
        if (!text || root.isLoading) return
        if (!ChatSessionManager.currentSessionId)
            ChatSessionManager.newSession("Gemini")

        var sid = ChatSessionManager.currentSessionId
        var msgId = ChatSessionManager.addUserMessage(sid, text)
        chatModel.append({ role: "user", text: text, isError: false, msgId: msgId, editing: false })
        chatModel.append({ role: "ai", text: "Working...", isError: false, reasoning: "", tokens: "", tokensInput: 0, tokensOutput: 0, reasoningExpanded: true, msgId: 0, editing: false })
        pendingIdx = chatModel.count - 1
        chatInput.text = ""
        isLoading = true
        GeminiBackend.sendMessage(text)
    }

    function saveAiMessage(content, reasoning, tokensIn, tokensOut) {
        var sid = ChatSessionManager.currentSessionId
        if (sid) ChatSessionManager.addAiMessage(sid, content, reasoning || "", tokensIn || 0, tokensOut || 0)
    }

    function onNew() {
        var sid = ChatSessionManager.newSession("Gemini")
        chatModel.clear(); pendingIdx = -1; isLoading = false
        GeminiBackend.setHistory("")
    }

    function deleteSession(id) {
        var wasCurrent = id === ChatSessionManager.currentSessionId
        ChatSessionManager.deleteSession(id)
        if (wasCurrent) {
            var sessions = ChatSessionManager.sessions
            if (sessions.length > 0) {
                root.switchToSession(sessions[0].id)
            } else {
                chatModel.clear(); pendingIdx = -1; isLoading = false
                GeminiBackend.stopGeneration()
                GeminiBackend.setHistory("")
            }
        }
    }

    function onClose() {
        if (typeof GeminiBackend !== 'undefined' && typeof GeminiBackend.stopGeneration === "function") GeminiBackend.stopGeneration()
        chatModel.clear(); pendingIdx = -1; isLoading = false
    }

    function onExport() { root.exportSession() }

    function resendFrom(userIdx, newText) {
        var sid = ChatSessionManager.currentSessionId
        var originalMsgId = chatModel.get(userIdx).msgId
        ChatSessionManager.updateMessage(sid, originalMsgId, newText)
        ChatSessionManager.deleteMessagesAfter(sid, originalMsgId)
        for (var ri = chatModel.count - 1; ri > userIdx; ri--)
            chatModel.remove(ri)
        chatModel.setProperty(userIdx, "text", newText)
        chatModel.append({ role: "ai", text: "Working...", isError: false, reasoning: "", tokens: "", tokensInput: 0, tokensOutput: 0, reasoningExpanded: true, msgId: 0, editing: false })
        pendingIdx = chatModel.count - 1
        isLoading = true
        GeminiBackend.sendMessage(newText)
    }

    function regenerateAt(aiIdx) {
        var sid = ChatSessionManager.currentSessionId
        var userIdx = aiIdx - 1
        if (userIdx < 0 || chatModel.get(userIdx).role !== "user") return
        var userText = chatModel.get(userIdx).text
        var userMsgId = chatModel.get(userIdx).msgId
        ChatSessionManager.deleteMessagesAfter(sid, userMsgId)
        for (var ri = chatModel.count - 1; ri >= userIdx + 1; ri--)
            chatModel.remove(ri)
        chatModel.append({ role: "ai", text: "Working...", isError: false, reasoning: "", tokens: "", tokensInput: 0, tokensOutput: 0, reasoningExpanded: true, msgId: 0, editing: false })
        pendingIdx = chatModel.count - 1
        isLoading = true
        GeminiBackend.sendMessage(userText)
    }

    function exportSession() {
        var sid = ChatSessionManager.currentSessionId
        if (!sid) return
        var path = ChatSessionManager.exportSessionAsMarkdown(sid)
        if (path)
            chatModel.append({ role: "ai", text: "Exported to: " + path, isError: false, reasoning: "", tokens: "", msgId: 0, editing: false })
        else
            chatModel.append({ role: "ai", text: "Export failed", isError: true, reasoning: "", tokens: "", msgId: 0, editing: false })
    }

    function searchMessages(query) {
        searchResultsModel.clear()
        if (!query.trim()) return
        var results = ChatSessionManager.searchMessages(query)
        for (var si = 0; si < results.length; si++) {
            var r = results[si]
            searchResultsModel.append({ role: r.role, content: r.content, sessionId: r.sessionId })
        }
    }

    ListModel { id: chatModel }
}
