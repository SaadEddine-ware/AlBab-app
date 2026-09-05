import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true
    anchors.fill: parent

    property int pendingIdx: -1
    property bool isLoading: false
    property bool sidebarVisible: true
    property string errBuf: "" // unused — kept for ABI compatibility

    property color termBg:      "#0D0D0D"
    property color termText:    "#D4D4D4"
    property color termGreen:   "#4AF626"
    property color termDim:     "#606060"
    property color termAccent:  "#569CD6"
    property color termCodeBg:  "#1A1A1A"
    property color termBorder:  "#252525"
    property color termReason:  "#888888"
    property color termErr:     "#F44747"

    property var sessionModel: ListModel { }

    function refreshSessions() {
        var list = OpenCodeBackend.listSessions()
        sessionModel.clear()
        for (var i = 0; i < list.length; i++) {
            var s = list[i]
            var isCurrent = s.id === (OpenCodeBackend.sessionArgsId || "")
            sessionModel.append({ id: s.id, title: s.title || "New Chat", updated: s.updated, isCurrent: isCurrent })
        }
    }

    function loadSessionHistory(sessionId) {
        chatModel.clear()
        var data = OpenCodeBackend.exportSession(sessionId)
        var msgs = data.messages || []
        for (var mi = 0; mi < msgs.length; mi++) {
            var m = msgs[mi]
            var role = m.info && m.info.role === "user" ? "user" : "ai"
            var text = ""
            var reasoning = ""
            var tokensIn = 0
            var tokensOut = 0
            var parts = m.parts || []
            for (var pi = 0; pi < parts.length; pi++) {
                var p = parts[pi]
                if (p.type === "text" && p.text) text += p.text
                if (p.type === "reasoning" && p.text) reasoning += p.text
                if (p.type === "step-finish" && p.tokens) {
                    tokensIn = p.tokens.input || 0
                    tokensOut = p.tokens.output || 0
                }
            }
            var tokens = (tokensIn || tokensOut) ? "\u2191" + tokensIn + " \u2193" + tokensOut + " tokens" : ""
            chatModel.append({ role: role, text: text, reasoning: reasoning, tokens: tokens, tokensInput: tokensIn, tokensOutput: tokensOut, reasoningExpanded: false })
        }
        pendingIdx = -1
        isLoading = false
    }

    function sendMessage() {
        var text = chatInput.text.trim()
        if (!text || root.isLoading) return
        chatModel.append({ role: "user", text: text, reasoning: "", tokens: "", tokensInput: 0, tokensOutput: 0, reasoningExpanded: false })
        chatModel.append({ role: "ai", text: "Working...", reasoning: "", tokens: "", tokensInput: 0, tokensOutput: 0, reasoningExpanded: true })
        pendingIdx = chatModel.count - 1
        chatInput.text = ""
        isLoading = true
        OpenCodeBackend.sendMessage(text)
    }

    function onNew() {
        OpenCodeBackend.setOpencodeSessionId("")
        OpenCodeBackend.refreshSessions()
        chatModel.clear()
        pendingIdx = -1
        isLoading = false
        refreshSessions()
    }

    function onClose() {
        chatModel.clear()
        pendingIdx = -1
        isLoading = false
    }

    function onExport() { root.exportSession() }

    function exportSession() {
        var sid = OpenCodeBackend.sessionArgsId
        if (!sid) return
        var data = OpenCodeBackend.exportSession(sid)
        var title = data.info ? (data.info.title || "session") : "session"
        chatModel.append({ role: "ai", text: "Exported. Use: opencode export " + sid, reasoning: "", tokens: "", tokensInput: 0, tokensOutput: 0, reasoningExpanded: false })
    }

    Connections {
        target: typeof OpenCodeBackend !== 'undefined' ? OpenCodeBackend : null
        ignoreUnknownSignals: true
        function onResponseReady(msg) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                chatModel.setProperty(pendingIdx, "text", msg)
            }
            isLoading = false
            pendingIdx = -1
        }
        function onErrorOccurred(msg) {
            if (pendingIdx >= 0 && pendingIdx < chatModel.count) {
                chatModel.setProperty(pendingIdx, "text", "\u2716 " + msg)
            }
            isLoading = false
            pendingIdx = -1
        }
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
        function onSessionTitleReceived(sessionId, title) {
            refreshSessions()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: termBg

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: root.sidebarVisible ? 200 : 0
                clip: true
                color: "#1A1A1A"
                border.color: termBorder
                border.width: 1
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: "#0D0D0D"
                        border.color: termBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 4
                            spacing: 4
                            Text { text: "Sessions"; color: termDim; font.pixelSize: 10; font.family: Theme.fontMono }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "\u25CB"; color: termGreen; font.pixelSize: 13; font.family: Theme.fontMono
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.onNew() }
                                Accessible.name: "New chat session"
                            }
                            Text {
                                text: "\u21BB"; color: termDim; font.pixelSize: 11; font.family: Theme.fontMono
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshSessions() }
                                Accessible.name: "Refresh sessions"
                            }
                            Text {
                                text: "\u25C0"; color: termDim; font.pixelSize: 10; font.family: Theme.fontMono
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sidebarVisible = false }
                                Accessible.name: "Hide sidebar"
                            }
                        }
                    }

                    ListView {
                        id: sessionList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 0
                        model: sessionModel

                        delegate: Item {
                            width: ListView.view.width
                            height: 28
                            Rectangle { anchors.fill: parent; color: isCurrent ? "#252525" : "transparent" }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 4
                                Text {
                                    text: isCurrent ? "\u25B6" : " "; color: termGreen; font.pixelSize: 9; font.family: Theme.fontMono
                                }
                                Column {
                                    spacing: 1; Layout.fillWidth: true
                                    Text {
                                        width: parent.parent.width - 24
                                        text: model.title; color: isCurrent ? termGreen : termText; font.pixelSize: 10; font.family: Theme.fontMono; elide: Text.ElideRight
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    OpenCodeBackend.setOpencodeSessionId(model.id)
                                    root.loadSessionHistory(model.id)
                                    root.refreshSessions()
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: "#1A1A1A"
                    border.color: termBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        Text {
                            text: "\u2630"; color: termDim; font.pixelSize: 12; font.family: Theme.fontMono
                            visible: !root.sidebarVisible
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sidebarVisible = true }
                            Accessible.name: "Show sidebar"
                        }
                        Text {
                            text: "OpenCode \u2014 " + (typeof OpenCodeBackend !== 'undefined' && OpenCodeBackend.isThinking ? "Working..." : "Ready")
                            color: typeof OpenCodeBackend !== 'undefined' && OpenCodeBackend.isThinking ? termGreen : termDim; font.pixelSize: 11; font.family: Theme.fontMono
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: typeof OpenCodeBackend !== 'undefined' && OpenCodeBackend.isThinking
                            text: "\u25A0"; color: "#F44747"; font.pixelSize: 11; font.family: Theme.fontMono
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { OpenCodeBackend.stopGeneration(); root.isLoading = false; root.pendingIdx = -1 } }
                        }
                    }
                }

                ListView {
                    id: chatList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 0
                    leftMargin: 4; rightMargin: 4
                    model: ListModel { id: chatModel }
                    ScrollIndicator.vertical: ScrollIndicator { }
                    onContentHeightChanged: {
                        if (contentHeight > height)
                            contentY = contentHeight - height
                    }

                    delegate: Column {
                        width: chatList.width - 8
                        spacing: 0
                        leftPadding: 8; rightPadding: 8

                        Item { height: 6; width: 1 }

                        Text {
                            visible: model.role === "user"
                            width: parent.width
                            text: "> " + model.text
                            color: termGreen; font.pixelSize: 13; font.family: Theme.fontMono; font.weight: Font.Bold
                            wrapMode: Text.Wrap
                        }

                        Column {
                            visible: model.role !== "user"
                            width: parent.width
                            spacing: 2

                            Rectangle {
                                visible: model.reasoning && model.reasoning.length > 0
                                width: parent.width; height: 22; color: termCodeBg; radius: 3
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 4
                                    Text { text: model.reasoningExpanded ? "\u25BC" : "\u25B6"; color: termReason; font.pixelSize: 10; font.family: Theme.fontMono }
                                    Text { text: "Reasoning"; color: termReason; font.pixelSize: 11; font.family: Theme.fontMono }
                                    Item { Layout.fillWidth: true }
                                    Text { text: model.reasoning ? model.reasoning.length + " chars" : ""; color: termDim; font.pixelSize: 9; font.family: Theme.fontMono }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: chatModel.setProperty(index, "reasoningExpanded", !model.reasoningExpanded)
                                }
                            }

                            Rectangle {
                                visible: model.reasoning && model.reasoningExpanded
                                width: parent.width; color: termCodeBg; radius: 3
                                Text {
                                    anchors.fill: parent; anchors.margins: 6
                                    text: model.reasoning || ""; color: termReason; font.pixelSize: 11; font.family: Theme.fontMono; wrapMode: Text.Wrap
                                }
                            }

                            Item { height: model.reasoning && model.reasoningExpanded ? 4 : 0; width: 1 }

                            Text {
                                width: parent.width
                                text: model.text
                                color: termText; font.pixelSize: 13; font.family: Theme.fontMono; wrapMode: Text.Wrap
                            }

                            Text {
                                visible: model.tokens && model.tokens.length > 0
                                width: parent.width
                                text: "\u2014\u2014\u2014 " + model.tokens + " \u2014\u2014\u2014"
                                color: termDim; font.pixelSize: 9; font.family: Theme.fontMono; horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Item { height: 1; width: parent.width
                            Rectangle { anchors.fill: parent; color: termBorder; visible: index < chatModel.count - 1 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "opencode run \u2014 type a message to start\n\nAll CLI commands work natively."
                        color: termDim; font.pixelSize: 12; font.family: Theme.fontMono; horizontalAlignment: Text.AlignHCenter
                        visible: chatModel.count === 0
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 1; color: termBorder
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; color: "#0D0D0D"

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 0
                        Text { text: "$"; color: termGreen; font.pixelSize: 13; font.family: Theme.fontMono; font.weight: Font.Bold }
                        Item { width: 6 }
                        TextInput {
                            id: chatInput
                            Layout.fillWidth: true; Layout.fillHeight: true
                            color: termText; font.pixelSize: 13; font.family: Theme.fontMono
                            verticalAlignment: TextInput.AlignVCenter; focus: true; activeFocusOnTab: true; selectByMouse: true
                            Keys.onReturnPressed: sendMessage()
                            Keys.onEnterPressed: sendMessage()
                            Accessible.name: "OpenCode message input"; Accessible.role: Accessible.EditableText
                        }
                    }
                }
            }
        }
    }
}
