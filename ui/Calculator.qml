import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property string expr: ""
    property string result: ""
    property string errorMsg: ""
    property bool scientific: false
    property bool showHistory: false
    property var history: []
    property var undoStack: []
    property var redoStack: []
    property real memory: 0

    function pushUndo() {
        undoStack.push({ expr: expr, result: result })
        redoStack = []
        if (undoStack.length > 50) undoStack.shift()
    }

    function undo() {
        if (undoStack.length === 0) return
        redoStack.push({ expr: expr, result: result })
        var prev = undoStack.pop()
        expr = prev.expr
        result = prev.result
        errorMsg = ""
    }

    function redo() {
        if (redoStack.length === 0) return
        undoStack.push({ expr: expr, result: result })
        var next = redoStack.pop()
        expr = next.expr
        result = next.result
        errorMsg = ""
    }

    function addToHistory(e, r) {
        CalculatorBackend.addToHistory(e, r)
        history.unshift({ expr: e, result: r, time: new Date().toLocaleTimeString() })
        if (history.length > 100) history.pop()
    }

    Component.onCompleted: {
        if (typeof CalculatorBackend === 'undefined') return
        var h = JSON.parse(CalculatorBackend.getHistory())
        history = h
    }

    function insert(ch) {
        pushUndo()
        expr += ch
        errorMsg = ""
    }

    function op(ch) {
        pushUndo()
        expr += " " + ch + " "
        errorMsg = ""
    }

    function pressEq() {
        if (!expr.trim()) return
        pushUndo()
        var r = MathEngine.evaluate(expr)
        if (r.indexOf("Error") === 0) {
            errorMsg = r
            result = ""
        } else {
            result = r
            errorMsg = ""
            addToHistory(expr, r)
        }
    }

    function clearAll() {
        pushUndo()
        expr = ""; result = ""; errorMsg = ""
    }

    function memoryRecall() {
        if (memory !== 0) {
            pushUndo()
            expr += String(memory)
        }
    }

    function memoryAdd() {
        var val = parseFloat(result) || 0
        memory += val
    }

    function memorySubtract() {
        var val = parseFloat(result) || 0
        memory -= val
    }

    function memoryClear() {
        memory = 0
    }

    function percentage() {
        pushUndo()
        var val = parseFloat(expr) || 0
        var resultVal = parseFloat(result) || 0
        if (resultVal !== 0) {
            expr = String(resultVal * val / 100)
        } else {
            expr = String(val / 100)
        }
    }

    function backspace() {
        pushUndo()
        expr = expr.slice(0, -1)
        errorMsg = ""
    }

    function negate() {
        pushUndo()
        if (expr.startsWith("-(") && expr.endsWith(")")) {
            expr = expr.slice(2, -1)
        } else if (expr) {
            expr = "-(" + expr + ")"
        }
    }

    function useHistoryItem(e, r) {
        pushUndo()
        expr = e
        result = r
        showHistory = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text {
                text: "Calculator"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
                Accessible.name: "Calculator title"
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: undoStack.length > 0 ? Theme.chipBg : "transparent"
                Text { anchors.centerIn: parent; text: "\u21A9"; color: undoStack.length > 0 ? Theme.textPrimary : Theme.textMuted; font.pixelSize: 14 }
                MouseArea { anchors.fill: parent; cursorShape: undoStack.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: undo() }
                Accessible.name: "Undo"
                Accessible.role: Accessible.Button
            }
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: redoStack.length > 0 ? Theme.chipBg : "transparent"
                Text { anchors.centerIn: parent; text: "\u21AA"; color: redoStack.length > 0 ? Theme.textPrimary : Theme.textMuted; font.pixelSize: 14 }
                MouseArea { anchors.fill: parent; cursorShape: redoStack.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: redo() }
                Accessible.name: "Redo"
                Accessible.role: Accessible.Button
            }

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: showHistory ? Theme.accentCopper : Theme.chipBg
                Text { anchors.centerIn: parent; text: "\u23F0"; color: showHistory ? "#ffffff" : Theme.textSecondary; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: showHistory = !showHistory }
                Accessible.name: "History"
                Accessible.role: Accessible.Button
            }

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.chipBg
                Text { anchors.centerIn: parent; text: "\u2913"; color: Theme.textSecondary; font.pixelSize: 13 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (result) {
                            CalculatorBackend.copyToClipboard(result)
                        }
                    }
                }
                Accessible.name: "Copy result"
                Accessible.role: Accessible.Button
            }

            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.chipBg
                border.color: Theme.divider
                Text { anchors.centerIn: parent; text: "\u2190 Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                Accessible.name: "Go back"
                Accessible.role: Accessible.Button
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.showHistory ? 220 : 0
            visible: root.showHistory
            radius: Theme.radiusSm
            color: Theme.cardBg
            border.color: Theme.divider
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingSm
                spacing: 2

                RowLayout {
                    Text { text: "History (" + history.length + ")"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 50; height: 20; radius: 3; color: Theme.errorBg
                        Text { anchors.centerIn: parent; text: "Clear"; color: Theme.errorText; font.pixelSize: 10 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { CalculatorBackend.clearHistory(); history = [] } }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: history
                    clip: true
                    spacing: 1
                    delegate: Rectangle {
                        width: parent.width; height: 24
                        color: index % 2 === 0 ? Theme.cardBg : "transparent"
                        radius: 2
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                            Text { text: modelData.expr; color: Theme.textSecondary; font.pixelSize: 11; font.family: Theme.fontMono; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: "= " + modelData.result; color: Theme.accentCopper; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: Theme.fontMono }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: useHistoryItem(modelData.expr, modelData.result) }
                    }

                    Text { anchors.centerIn: parent; text: "No history yet"; color: Theme.textMuted; font.pixelSize: 11; visible: history.length === 0 }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: Theme.radiusSm
            color: Theme.inputBg
            border.color: Theme.divider
            clip: true
            Flickable {
                anchors.fill: parent; anchors.margins: 10
                contentWidth: exprText.width; contentHeight: exprText.height
                Text {
                    id: exprText
                    text: root.expr || "0"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeMd
                    font.family: Theme.fontMono
                }
            }
            Accessible.name: "Expression: " + (root.expr || "empty")
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Theme.radiusSm
            color: Theme.glassBase
            border.color: Theme.divider
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 14
                text: root.result || (root.errorMsg ? "" : "0")
                color: root.errorMsg ? Theme.errorText : Theme.textPrimary
                font.pixelSize: Theme.fontSizeXl - 2
                font.weight: Font.DemiBold
            }
            Text {
                visible: root.errorMsg !== ""
                anchors.centerIn: parent
                text: root.errorMsg
                color: Theme.errorText
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
            }
            Accessible.name: root.errorMsg ? "Error: " + root.errorMsg : "Result: " + (root.result || "0")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { t: "C", c: Theme.clearBtn, fn: clearAll },
                    { t: "\u232B", c: Theme.clearBtn, fn: backspace },
                    { t: "\u00B1", c: Theme.negateBtn, fn: negate },
                    { t: "\u00F7", c: Theme.inactiveBtn, fn: function(){ op("\u00F7") } },
                ]
                Rectangle {
                    width: (parent.width - Theme.spacingXs * 3) / 4
                    height: 40
                    radius: Theme.radiusSm
                    color: modelData.c
                    border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: modelData.t; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd + 2 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.fn() }
                    Accessible.name: modelData.t
                    Accessible.role: Accessible.Button
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { t: "7" }, { t: "8" }, { t: "9" }, { t: "\u00D7", c: Theme.inactiveBtn, fn: function(){ op("\u00D7") } },
                    { t: "4" }, { t: "5" }, { t: "6" }, { t: "-", c: Theme.inactiveBtn, fn: function(){ op("-") } },
                    { t: "1" }, { t: "2" }, { t: "3" }, { t: "+", c: Theme.inactiveBtn, fn: function(){ op("+") } },
                ]
                Rectangle {
                    width: (parent.width - Theme.spacingXs * 3) / 4
                    height: 40
                    radius: Theme.radiusSm
                    color: modelData.c || Theme.btnDefault
                    border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: modelData.t; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd + 2 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (modelData.fn) modelData.fn(); else root.insert(modelData.t) }
                    }
                    Accessible.name: modelData.t
                    Accessible.role: Accessible.Button
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { t: "0", w: 2 }, { t: "." }, { t: "=", c: Theme.accentCopper, fn: pressEq },
                ]
                Rectangle {
                    width: modelData.w === 2 ? (parent.width - Theme.spacingXs * 2) / 2 : (parent.width - Theme.spacingXs * 3) / 4
                    height: 40
                    radius: Theme.radiusSm
                    color: modelData.c || Theme.btnDefault
                    border.color: Theme.divider
                    Text {
                        anchors.centerIn: parent; text: modelData.t
                        color: modelData.t === "=" ? "#ffffff" : Theme.textPrimary
                        font.pixelSize: Theme.fontSizeMd + 2
                        font.weight: modelData.t === "=" ? Font.Bold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (modelData.fn) modelData.fn(); else root.insert(modelData.t) }
                    }
                    Accessible.name: modelData.t === "=" ? "Equals" : modelData.t
                    Accessible.role: Accessible.Button
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { t: "MC", c: Theme.inactiveBtn, fn: memoryClear },
                    { t: "MR", c: Theme.inactiveBtn, fn: memoryRecall },
                    { t: "M+", c: Theme.inactiveBtn, fn: memoryAdd },
                    { t: "M-", c: Theme.inactiveBtn, fn: memorySubtract },
                    { t: "%", c: Theme.inactiveBtn, fn: percentage },
                ]
                Rectangle {
                    width: (parent.width - Theme.spacingXs * 4) / 5
                    height: 32
                    radius: Theme.radiusSm
                    color: modelData.c
                    border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: modelData.t; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.fn() }
                    Accessible.name: modelData.t
                    Accessible.role: Accessible.Button
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { t: "sin", c: Theme.sciBtn, tt: "sin(" }, { t: "cos", c: Theme.sciBtn, tt: "cos(" }, { t: "tan", c: Theme.sciBtn, tt: "tan(" },
                    { t: "log", c: Theme.sciBtn, tt: "log(" }, { t: "ln", c: Theme.sciBtn, tt: "ln(" },
                    { t: "\u221A", c: Theme.sciBtn, tt: "sqrt(" },
                    { t: "x\u00B2", c: Theme.sciBtn, tt: "^2" },
                    { t: "x\u02B8", c: Theme.sciBtn, tt: "^" },
                    { t: "(", c: Theme.sciBtn, tt: "(" }, { t: ")", c: Theme.sciBtn, tt: ")" },
                    { t: "\u03C0", c: Theme.sciBtn, tt: "pi" },
                    { t: "e", c: Theme.sciBtn, tt: "e" },
                ]
                Rectangle {
                    width: (parent.width - Theme.spacingXs * 5) / 6
                    height: 36
                    radius: Theme.radiusSm
                    color: modelData.c
                    border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: modelData.t; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm + 1; font.family: Theme.fontMono }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.insert(modelData.tt || modelData.t + "(") }
                    Accessible.name: modelData.t
                    Accessible.role: Accessible.Button
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    function onNew() { clearAll(); history = [] }
    function onExport() {
        if (history.length === 0) return
        var path = ExportBackend.getExportPath("calculator_history.csv")
        var ok = CalculatorBackend.exportCsv(path)
        if (ok) Toast.show("History CSV saved to: " + path)
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) { if (event.modifiers & Qt.ShiftModifier) redo(); else undo(); event.accepted = true; return }
        if (event.key === Qt.Key_Y && (event.modifiers & Qt.ControlModifier)) { redo(); event.accepted = true; return }
        var k = event.text
        if (k >= "0" && k <= "9") root.insert(k)
        else if (k === "+" || k === "-" || k === "*" || k === "/") root.op(k)
        else if (k === ".") root.insert(".")
        else if (k === "(" || k === ")") root.insert(k)
        else if (k === "^") root.insert("^")
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) pressEq()
        else if (event.key === Qt.Key_Backspace) backspace()
        else if (event.key === Qt.Key_Escape) clearAll()
    }

    focus: true
}
