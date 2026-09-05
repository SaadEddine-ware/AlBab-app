import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property string currentSession: ""
    property bool loaded: false
    property bool isLoading: false
    property var sessionList: []

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isLoading
        message: "Loading..."
    }

    function loadSession(name) {
        var raw = SourceAnalyzer.loadSession(name)
        var d = JSON.parse(raw)
        if (d.error) return
        currentSession = name
        typeBox.currentIndex = d.type === "Primary" ? 0 : (d.type === "Secondary" ? 1 : 2)
        titleInput.text = d.title || ""
        authorInput.text = d.author || ""
        dateInput.text = d.date || ""
        contextInput.text = d.context || ""
        purposeInput.text = d.purpose || ""
        audienceInput.text = d.audience || ""
        biasInput.text = d.bias || ""
        reliabilityInput.text = d.reliability || ""
        notesInput.text = d.notes || ""
        loaded = true
    }

    function saveCurrent(name) {
        var data = JSON.stringify({
            type: ["Primary", "Secondary", "Other"][typeBox.currentIndex],
            title: titleInput.text, author: authorInput.text, date: dateInput.text,
            context: contextInput.text, purpose: purposeInput.text,
            audience: audienceInput.text, bias: biasInput.text,
            reliability: reliabilityInput.text, notes: notesInput.text
        })
        SourceAnalyzer.saveSession(name || currentSession || "untitled", data)
        currentSession = name || currentSession || "untitled"
    }

    function gatherData() {
        return JSON.stringify({
            type: ["Primary", "Secondary", "Other"][typeBox.currentIndex],
            title: titleInput.text, author: authorInput.text, date: dateInput.text,
            context: contextInput.text
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text { text: "Source Analyzer"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 100; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.chipBg
                Text { anchors.centerIn: parent; text: "Load..."; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: loadMenu.open() }
                Menu {
                    id: loadMenu
                    Instantiator {
                        model: root.sessionList
                        MenuItem {
                            text: modelData
                            onTriggered: root.loadSession(modelData)
                        }
                        onObjectAdded: loadMenu.insertItem(index, object)
                        onObjectRemoved: loadMenu.removeItem(object)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                Text { anchors.centerIn: parent; text: "\u2190 Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm - 1 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
            }
        }

        Flickable {
            Layout.fillWidth: true; Layout.fillHeight: true
            contentHeight: formCol.height + Theme.spacingMd
            clip: true

            ColumnLayout {
                id: formCol
                width: parent.width
                spacing: Theme.spacingSm

                Text { text: "Source Metadata"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }

                RowLayout { spacing: Theme.spacingSm
                    Text { text: "Type:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    ComboBox { id: typeBox; model: ["Primary", "Secondary", "Other"]; Layout.preferredWidth: 120 }
                    Text { text: "Title:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput { id: titleInput; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                }

                RowLayout { spacing: Theme.spacingSm
                    Text { text: "Author:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput { id: authorInput; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                    Text { text: "Date:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    Rectangle { Layout.preferredWidth: 120; Layout.preferredHeight: 28; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput { id: dateInput; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                }

                Text { text: "Historical Context:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 50; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                    TextEdit { id: contextInput; anchors.fill: parent; anchors.margins: 8; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; wrapMode: TextEdit.WordWrap } }

                Text { text: "Analysis"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }

                    ColumnLayout { spacing: 2
                        Text { text: "Purpose:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                            TextEdit { id: purposeInput; anchors.fill: parent; anchors.margins: 6; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; wrapMode: TextEdit.WordWrap } }
                        Text { text: "Audience:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                            TextEdit { id: audienceInput; anchors.fill: parent; anchors.margins: 6; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; wrapMode: TextEdit.WordWrap } }
                        Text { text: "Bias / Perspective:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                            TextEdit { id: biasInput; anchors.fill: parent; anchors.margins: 6; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; wrapMode: TextEdit.WordWrap } }
                        Text { text: "Reliability:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                            TextEdit { id: reliabilityInput; anchors.fill: parent; anchors.margins: 6; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; wrapMode: TextEdit.WordWrap } }
                    }

                Text { text: "Key Quotes & Notes"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 60; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                    TextEdit { id: notesInput; anchors.fill: parent; anchors.margins: 8; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; wrapMode: TextEdit.WordWrap } }

                Rectangle { Layout.preferredHeight: Theme.spacingMd; color: "#00000000"; width: 1 }
            }
        }

        RowLayout {
            spacing: Theme.spacingSm
            Rectangle {
                Layout.preferredWidth: 100; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.accentCopper
                Text { anchors.centerIn: parent; text: "Save"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { saveCurrent(titleInput.text.replace(/\s+/g, '_') || "untitled"); loaded = true } }
            }
            Rectangle {
                Layout.preferredWidth: 120; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.chipBg
                Text { anchors.centerIn: parent; text: "\uD83E\uDD16 AI Analyze"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var prompt = SourceAnalyzer.generateAiPrompt(gatherData())
                        if (typeof GeminiBackend !== 'undefined') GeminiBackend.sendMessage(prompt)
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: 80; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.chipBg
                Text { anchors.centerIn: parent; text: "New"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        typeBox.currentIndex = 0; titleInput.text = ""; authorInput.text = ""
                        dateInput.text = ""; contextInput.text = ""; purposeInput.text = ""
                        audienceInput.text = ""; biasInput.text = ""; reliabilityInput.text = ""
                        notesInput.text = ""; currentSession = ""; loaded = false
                    }
                }
            }
            Rectangle {
                visible: loaded && currentSession !== ""
                Layout.preferredWidth: 80; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.accentCopper
                Text { anchors.centerIn: parent; text: "Export HTML"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.onExport()
                }
            }
            Item { Layout.fillWidth: true }
            Text { text: loaded ? "Saved: " + currentSession : ""; color: Theme.textMuted; font.pixelSize: Theme.fontSizeSm - 1 }
        }
    }

    function refreshSessions() {
        if (typeof SourceAnalyzer === 'undefined') return
        try {
            var raw = SourceAnalyzer.listSessions()
            root.sessionList = JSON.parse(raw)
        } catch(e) {
            root.sessionList = []
        }
    }

    Component.onCompleted: refreshSessions()

    function onNew() {
        typeBox.currentIndex = 0; titleInput.text = ""; authorInput.text = ""
        dateInput.text = ""; contextInput.text = ""; purposeInput.text = ""
        audienceInput.text = ""; biasInput.text = ""; reliabilityInput.text = ""
        notesInput.text = ""; currentSession = ""; loaded = false
    }
    function onExport() {
        if (!currentSession) return
        var path = ExportBackend.getExportPath("source_" + currentSession + ".html")
        var ok = SourceAnalyzer.exportHtml(currentSession, path)
        if (ok) Toast.show("HTML saved to: " + path)
    }
}
