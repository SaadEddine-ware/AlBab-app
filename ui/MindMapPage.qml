import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root
    clip: true
    anchors.fill: parent

    signal back()

    property bool isGenerating: false
    property int modelIndex: 0
    property var modelNames: ["Auto", "Groq"]
    property var modelKeys: ["auto", "groq"]
    property string selectedModel: modelKeys[modelIndex]

    Connections {
        target: typeof MindMapBackend !== 'undefined' ? MindMapBackend : null
        ignoreUnknownSignals: true
        function onMindMapReady(jsonString) {
            root.isGenerating = false
            try {
                var data = JSON.parse(jsonString)
                mindMapWindow.pendingTreeData = data
                emptyState.visible = false
                mindMapWindow.open()
            } catch (e) {
                statusLabel.text = "Failed to parse mind map data"
                statusLabel.color = Theme.accentRed
                statusTimer.start()
            }
        }
        function onNodeCountChanged(count) {
            nodeCountLabel.text = count + " nodes"
            nodeCountLabel.visible = true
        }
        function onErrorOccurred(msg) {
            root.isGenerating = false
            statusLabel.text = msg
            statusLabel.color = Theme.accentRed
            statusTimer.start()
        }
        function onStatusChanged(status) {
            if (status === "generating") {
                root.isGenerating = true
                statusLabel.text = "Generating mind map..."
                statusLabel.color = Theme.accentBlue
            } else if (status === "idle") {
                root.isGenerating = false
                if (statusLabel.color !== Theme.accentRed) {
                    statusLabel.text = "Ready"
                    statusLabel.color = Theme.textMuted
                }
            } else {
                statusLabel.text = status
                statusLabel.color = Theme.accentBlue
            }
        }
    }

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
                anchors.leftMargin: 16; anchors.rightMargin: 16
                spacing: 12

                Text {
                    text: "\u2190"
                    color: Theme.textSecondary
                    font.pixelSize: 16
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                }

                Text {
                    text: "Mind Map"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: modelSelector
                    height: 32; radius: 16
                    color: selectorMouse.containsMouse ? Theme.chipBg : Theme.inputBg
                    border.color: Theme.divider
                    implicitWidth: modelSelectorRow.implicitWidth + 20

                    Row {
                        id: modelSelectorRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\u2699"
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }
                        Text {
                            text: modelNames[modelIndex]
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }

                    MouseArea {
                        id: selectorMouse
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: {
                            modelIndex = (modelIndex + 1) % modelNames.length
                            MindMapBackend.setProvider(modelKeys[modelIndex])
                        }
                    }
                }

                Rectangle {
                    id: uploadBtn
                    height: 32; radius: 16
                    color: uploadMouse.containsMouse ? Theme.chipBg : Theme.inputBg
                    border.color: Theme.divider
                    implicitWidth: uploadRow.implicitWidth + 20

                    Row {
                        id: uploadRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "\uD83D\uDCC1"; font.pixelSize: 13 }
                        Text { text: "PDF"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    }

                    MouseArea {
                        id: uploadMouse
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: pdfDialog.open()
                    }
                }

                Rectangle {
                    id: fileBtn
                    height: 32; radius: 16
                    color: fileMouse.containsMouse ? Theme.chipBg : Theme.inputBg
                    border.color: Theme.divider
                    implicitWidth: fileRow.implicitWidth + 20

                    Row {
                        id: fileRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "\uD83D\uDCC4"; font.pixelSize: 13 }
                        Text { text: "File"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    }

                    MouseArea {
                        id: fileMouse
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: txtFileDialog.open()
                    }
                }

                Rectangle {
                    id: pasteBtn
                    height: 32; radius: 16
                    color: pasteMouse.containsMouse ? Theme.chipBg : Theme.inputBg
                    border.color: Theme.divider
                    implicitWidth: pasteRow.implicitWidth + 20

                    Row {
                        id: pasteRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "\uD83D\uDCCB"; font.pixelSize: 13 }
                        Text { text: "Paste"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    }

                    MouseArea {
                        id: pasteMouse
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: pasteDialog.open()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: emptyState
                anchors.fill: parent
                visible: true

                Column {
                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        text: "\uD83E\uDDE0"
                        font.pixelSize: 48
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Create a Mind Map"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeXl
                        font.weight: Font.Bold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Upload a PDF, paste text, or load a file\nto generate an interactive mind map"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeMd
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Flow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            height: 40; radius: 20
                            color: emptyUploadMouse.containsMouse ? Theme.accentCopperDark : Theme.accentCopper
                            implicitWidth: emptyUploadRow.implicitWidth + 24

                            Row {
                                id: emptyUploadRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "\uD83D\uDCC1"; font.pixelSize: 15 }
                                Text { text: "Upload PDF"; color: "#FFFFFF"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            }

                            MouseArea {
                                id: emptyUploadMouse
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: pdfDialog.open()
                            }
                        }

                        Rectangle {
                            height: 40; radius: 20
                            color: emptyPasteMouse.containsMouse ? Theme.accentCopperDark : Theme.accentCopper
                            implicitWidth: emptyPasteRow.implicitWidth + 24

                            Row {
                                id: emptyPasteRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "\uD83D\uDCCB"; font.pixelSize: 15 }
                                Text { text: "Paste Text"; color: "#FFFFFF"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            }

                            MouseArea {
                                id: emptyPasteMouse
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: pasteDialog.open()
                            }
                        }

                        Rectangle {
                            height: 40; radius: 20
                            color: emptyFileMouse.containsMouse ? Theme.accentCopperDark : Theme.accentCopper
                            implicitWidth: emptyFileRow.implicitWidth + 24

                            Row {
                                id: emptyFileRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "\uD83D\uDCC4"; font.pixelSize: 15 }
                                Text { text: "Open File"; color: "#FFFFFF"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            }

                            MouseArea {
                                id: emptyFileMouse
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: txtFileDialog.open()
                            }
                        }
                    }
                }
            }
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
                anchors.leftMargin: 12; anchors.rightMargin: 12

                Rectangle {
                    visible: root.isGenerating
                    width: 8; height: 8; radius: 4; color: Theme.accentBlue
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }

                Text {
                    id: statusLabel
                    text: "Ready"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeXs
                    Layout.fillWidth: true
                }

                Timer {
                    id: statusTimer
                    interval: 4000
                    onTriggered: { statusLabel.text = "Ready"; statusLabel.color = Theme.textMuted }
                }

                Text {
                    id: nodeCountLabel
                    text: ""
                    color: Theme.textMuted
                    font.pixelSize: 9
                    visible: false
                }
                Text {
                    text: "Click branches to expand/collapse  \u2022  Right-click for more options  \u2022  Scroll to zoom  \u2022  Drag to pan"
                    color: Theme.textMuted
                    font.pixelSize: 9
                }
            }
        }
    }

    Dialog {
        id: pasteDialog
        title: "Paste Text"
        modal: true
        anchors.centerIn: parent
        width: 500
        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                text: "Paste or type text to generate a mind map from:"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSm
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                radius: Theme.radiusSm
                color: Theme.inputBg
                border.color: pasteTextEdit.activeFocus ? Theme.accentBlue : Theme.divider

                TextEdit {
                    id: pasteTextEdit
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSm
                    wrapMode: Text.Wrap
                    selectByMouse: true
                    clip: true
                }
            }
        }

        onAccepted: {
            var text = pasteTextEdit.text.trim()
            if (text) {
                MindMapBackend.generateFromText(text)
                pasteTextEdit.text = ""
            }
        }
    }

    FileDialog {
        id: pdfDialog
        title: "Select PDF"
        nameFilters: ["PDF files (*.pdf)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (path.startsWith("file:///")) path = path.substring(8)
            // On Windows, path may start with / after removing file:///
            if (path.startsWith("/") && path.length > 2 && path.charAt(2) === ":")
                path = path.substring(1)
            if (path) MindMapBackend.generateFromPdf(path)
        }
    }

    FileDialog {
        id: txtFileDialog
        title: "Select Text File"
        nameFilters: ["Text files (*.txt *.md *.csv)", "All files (*)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (path.startsWith("file:///")) path = path.substring(8)
            if (path.startsWith("/") && path.length > 2 && path.charAt(2) === ":")
                path = path.substring(1)
            if (path) MindMapBackend.generateFromFile(path)
        }
    }

    function onNew() {
        emptyState.visible = true
        nodeCountLabel.visible = false
        mindMapWindow.close()
    }

    function onExport() {
        if (typeof ExportBackend !== 'undefined') {
            if (!mindMapWindow.pendingTreeData) {
                statusLabel.text = "No mind map to export"
                statusLabel.color = Theme.accentRed
                statusTimer.start()
                return
            }
            ExportBackend.exportText("mindmap_data.json", JSON.stringify(mindMapWindow.pendingTreeData, null, 2))
            statusLabel.text = "Mind map data exported as JSON"
            statusLabel.color = Theme.accentBlue
            statusTimer.start()
        }
    }

    Dialog {
        id: mindMapWindow
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.95, 1400)
        height: Math.min(parent.height * 0.92, 900)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var pendingTreeData: null

        onOpened: {
            if (pendingTreeData) {
                mindMapCanvas.buildTree(pendingTreeData)
                Qt.callLater(function() {
                    mindMapCanvas.fitToView()
                    mindMapCanvas.forceRepaint()
                })
            }
        }

        onClosed: {
            mindMapCanvas.clear()
            pendingTreeData = null
        }

        background: Rectangle {
            color: Theme.pageBg
            border.color: Theme.divider
            border.width: 1
            radius: Theme.radiusLg
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: "transparent"

                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: 1; color: Theme.divider
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16; anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: "\uD83E\uDDE0"
                        font.pixelSize: 16
                    }

                    Text {
                        text: "Mind Map"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLg
                        font.weight: Font.Bold
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 28; radius: 14
                        color: fitMouse2.containsMouse ? Theme.chipBg : Theme.inputBg
                        border.color: Theme.divider
                        implicitWidth: fitRow.implicitWidth + 16
                        Row {
                            id: fitRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "\u25A1"; font.pixelSize: 12; color: Theme.textSecondary }
                            Text { text: "Fit"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                        }
                        MouseArea {
                            id: fitMouse2
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: mindMapCanvas.fitToView()
                        }
                    }

                    Rectangle {
                        height: 28; radius: 14
                        color: centerMouse.containsMouse ? Theme.chipBg : Theme.inputBg
                        border.color: Theme.divider
                        implicitWidth: centerRow.implicitWidth + 16
                        Row {
                            id: centerRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "\u21BB"; font.pixelSize: 12; color: Theme.textSecondary }
                            Text { text: "Center"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                        }
                        MouseArea {
                            id: centerMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: mindMapCanvas.centerView()
                        }
                    }

                    Rectangle {
                        height: 28; radius: 14
                        color: closeMouse.containsMouse ? Theme.accentRed : Theme.inputBg
                        border.color: Theme.divider
                        width: 28
                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: closeMouse.containsMouse ? "#FFFFFF" : Theme.textPrimary
                            font.pixelSize: 12; font.weight: Font.Bold
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: mindMapWindow.close()
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MindMapCanvas {
                    id: mindMapCanvas
                    anchors.fill: parent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: "transparent"

                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    height: 1; color: Theme.divider
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12

                    Text {
                        text: "Scroll to zoom \u2022 Click branches to expand/collapse \u2022 Right-click for options \u2022 Drag nodes to reposition \u2022 Hover for details"
                        color: Theme.textMuted
                        font.pixelSize: 9
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
