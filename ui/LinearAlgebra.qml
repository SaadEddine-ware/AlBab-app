import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property int matrixRows: 3
    property int matrixCols: 3
    property var cellValues: ({})
    property bool isLoading: false

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isLoading
        message: "Computing..."
    }

    function rebuildGrid() {
        gridRepeater.model = matrixRows * matrixCols
    }

    function getMatrixData() {
        var data = []
        for (var r = 0; r < matrixRows; r++) {
            var row = []
            for (var c = 0; c < matrixCols; c++) {
                var key = r + "_" + c
                var val = cellValues[key]
                row.push(val !== undefined ? (parseFloat(val) || 0) : 0)
            }
            data.push(row)
        }
        return JSON.stringify(data)
    }

    function runOp(name) {
        root.isLoading = true
        var raw = MatrixBackend[name](getMatrixData())
        var obj
        try { obj = JSON.parse(raw) } catch(e) { resultText.text = "Parse error"; root.isLoading = false; return }
        root.isLoading = false
        if (obj.ok) {
            if (obj.result !== undefined) {
                if (typeof obj.result === "object") {
                    var txt = ""
                    for (var i = 0; i < obj.result.length; i++) {
                        var row = obj.result[i]
                        txt += (Array.isArray(row) ? row.map(function(x) { return typeof x === "number" ? x.toFixed(4) : x }).join(", ") : String(row)) + "\n"
                    }
                    resultText.text = txt
                } else {
                    resultText.text = String(obj.result)
                }
            } else {
                resultText.text = JSON.stringify(obj)
            }
        } else {
            resultText.text = "Error: " + (obj.error || "Unknown")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text {
                text: "Linear Algebra"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.chipBg
                border.color: Theme.divider
                Text {
                    anchors.centerIn: parent
                    text: "\u2190 Back"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm - 1
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }
        }

        RowLayout {
            spacing: Theme.spacingSm
            Text { text: "Rows:"; color: Theme.textSecondary }
            SpinBox {
                id: rowsSpin; from: 1; to: 10; value: 3
                onValueChanged: { matrixRows = value; rebuildGrid() }
            }
            Text { text: "Cols:"; color: Theme.textSecondary }
            SpinBox {
                id: colsSpin; from: 1; to: 10; value: 3
                onValueChanged: { matrixCols = value; rebuildGrid() }
            }
            Rectangle {
                Layout.preferredWidth: 90; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.accentCopper
                Text {
                    anchors.centerIn: parent; text: "Reset Grid"
                    color: "#ffffff"; font.pixelSize: Theme.fontSizeSm
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { cellValues = {}; rebuildGrid() }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusSm
            color: Theme.chipBg
            border.color: Theme.divider
            clip: true

            Flickable {
                anchors.fill: parent; anchors.margins: 10
                contentWidth: gridLayout.width; contentHeight: gridLayout.height
                GridLayout {
                    id: gridLayout
                    columns: matrixCols
                    columnSpacing: 4; rowSpacing: 4
                    Repeater {
                        id: gridRepeater
                        model: matrixRows * matrixCols
                        delegate: Rectangle {
                            width: 64; height: 36
                            color: Theme.cellBg; border.color: Theme.cellBorder; radius: 3
                            TextInput {
                                id: inp
                                anchors.fill: parent; anchors.margins: 4
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                font.pixelSize: 14; font.family: Theme.fontMono
                                validator: RegularExpressionValidator { regularExpression: /^-?[0-9]*\.?[0-9]*$/ }
                                Component.onCompleted: {
                                    var r = Math.floor(index / matrixCols)
                                    var c = index % matrixCols
                                    var key = r + "_" + c
                                    text = cellValues[key] !== undefined ? cellValues[key] : "0"
                                }
                                onTextChanged: {
                                    var r = Math.floor(index / matrixCols)
                                    var c = index % matrixCols
                                    cellValues[r + "_" + c] = text
                                }
                            }
                        }
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { t: "Det", op: "det" },
                    { t: "Inv", op: "inverse" },
                    { t: "Rank", op: "rank" },
                    { t: "RREF", op: "rref" },
                    { t: "T", op: "transpose" },
                ]
                delegate: Rectangle {
                    width: (parent.width - Theme.spacingXs * 4) / 5
                    height: 36; radius: Theme.radiusSm
                    color: Theme.accentCopper
                    Text {
                        anchors.centerIn: parent
                        text: modelData.t; color: "#ffffff"
                        font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: runOp(modelData.op)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: Theme.radiusSm
            color: Theme.resultBg
            border.color: Theme.divider
            clip: true
            Flickable {
                anchors.fill: parent; anchors.margins: 10
                contentWidth: resultText.width; contentHeight: resultText.height
                Text {
                    id: resultText
                    text: "Results appear here..."
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeMd
                    font.family: Theme.fontMono
                }
            }
        }
    }
}

