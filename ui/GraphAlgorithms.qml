import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property int graphSize: 3
    property var cellValues: ({})
    property bool isLoading: false

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isLoading
        message: "Computing..."
    }

    function rebuildGrid() {
        gridRepeater.model = graphSize * graphSize
    }

    function getMatrixData() {
        var data = []
        for (var r = 0; r < graphSize; r++) {
            var row = []
            for (var c = 0; c < graphSize; c++) {
                var key = r + "_" + c
                var val = cellValues[key]
                row.push(val !== undefined ? (parseFloat(val) || 0) : 0)
            }
            data.push(row)
        }
        return JSON.stringify(data)
    }

    function runOp(name, extra) {
        root.isLoading = true
        var raw
        if (extra !== undefined)
            raw = GraphBackend[name](getMatrixData(), extra.start, extra.end)
        else
            raw = GraphBackend[name](getMatrixData())
        var obj
        try { obj = JSON.parse(raw) } catch(e) { resultText.text = "Parse error"; root.isLoading = false; return }
        root.isLoading = false
        if (obj.ok) {
            if (obj.connected !== undefined) {
                resultText.text = obj.connected ? "Graph is connected" : "Graph is NOT connected"
            } else if (obj.components !== undefined) {
                resultText.text = "Connected components: " + JSON.stringify(obj.components)
            } else if (obj.bipartite !== undefined) {
                resultText.text = obj.bipartite ? "Graph is bipartite" : "Graph is NOT bipartite"
            } else if (obj.path !== undefined) {
                resultText.text = "Shortest path: " + obj.path.join(" → ")
            } else if (obj.edges !== undefined) {
                resultText.text = "MST edges: " + obj.edges.map(function(e) { return "(" + e[0] + "," + e[1] + ")" }).join(", ")
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
                text: "Graph Algorithms"
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
                    anchors.centerIn: parent; text: "\u2190 Back"
                    color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm - 1
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }
        }

        Text {
            text: "Enter the adjacency matrix below. Use 0 for no edge, positive number for edge weight."
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSm
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: Theme.spacingSm
            Text { text: "Vertices:"; color: Theme.textSecondary }
            SpinBox {
                id: sizeSpin; from: 2; to: 10; value: 4
                onValueChanged: { graphSize = value; rebuildGrid() }
            }
            Rectangle {
                Layout.preferredWidth: 90; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.accentCopper
                Text {
                    anchors.centerIn: parent; text: "Reset"
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
                    columns: graphSize
                    columnSpacing: 4; rowSpacing: 4
                    Repeater {
                        id: gridRepeater
                        model: graphSize * graphSize
                        delegate: Rectangle {
                            width: 56; height: 36
                            color: Theme.cellBg; border.color: Theme.cellBorder; radius: 3
                            TextInput {
                                anchors.fill: parent; anchors.margins: 4
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                font.pixelSize: 14; font.family: Theme.fontMono
                                validator: RegularExpressionValidator { regularExpression: /^-?[0-9]*\.?[0-9]*$/ }
                                Component.onCompleted: {
                                    var r = Math.floor(index / graphSize)
                                    var c = index % graphSize
                                    var key = r + "_" + c
                                    text = cellValues[key] !== undefined ? cellValues[key] : "0"
                                }
                                onTextChanged: {
                                    var r = Math.floor(index / graphSize)
                                    var c = index % graphSize
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
                    { t: "Connectivity", fn: function(){ runOp("connectivity") } },
                    { t: "Components", fn: function(){ runOp("connectedComponents") } },
                    { t: "Bipartite", fn: function(){ runOp("bipartite") } },
                    { t: "Shortest Path", fn: function(){
                        var s = Math.min(startSpin.value, graphSize - 1)
                        var e = Math.min(endSpin.value, graphSize - 1)
                        runOp("shortestPath", {start: s, end: e})
                    } },
                    { t: "MST (Prim)", fn: function(){ runOp("mst") } },
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
                        onClicked: modelData.fn()
                    }
                }
            }
        }

        RowLayout {
            spacing: Theme.spacingSm
            Text { text: "Path Start:"; color: Theme.textSecondary }
            SpinBox { id: startSpin; from: 0; to: Math.max(1, sizeSpin.value - 1); value: 0 }
            Text { text: "End:"; color: Theme.textSecondary }
            SpinBox { id: endSpin; from: 0; to: Math.max(1, sizeSpin.value - 1); value: 0 }
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

