import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property int activeTool: -1
    property string searchQuery: ""

    states: [
        State { name: "grid"; when: activeTool < 0 },
        State { name: "calc"; when: activeTool === 0 },
        State { name: "eqsolve"; when: activeTool === 1 },
        State { name: "graph"; when: activeTool === 2 },
        State { name: "formula"; when: activeTool === 3 },
        State { name: "linalg"; when: activeTool === 4 },
        State { name: "graphalgo"; when: activeTool === 5 },
        State { name: "stats"; when: activeTool === 6 },
        State { name: "geometry"; when: activeTool === 7 },
        State { name: "mesheditor"; when: activeTool === 8 },
        State { name: "timeliner"; when: activeTool === 9 },
        State { name: "source"; when: activeTool === 10 },
        State { name: "coordcalc"; when: activeTool === 11 },
        State { name: "demographics"; when: activeTool === 12 },
        State { name: "mindmap"; when: activeTool === 13 },
    ]

    property var toolGroups: [
        {
            name: "Mathematics",
            tools: [
                { icon: "\u00F7", title: "Calculator", desc: "Basic & scientific\ncalculations" },
                { icon: "x\u02B8", title: "Equation Solver", desc: "Solve equations\nstep by step" },
                { icon: "\u223F", title: "Graph Plotter", desc: "Visualize functions\nand data" },
                { icon: "\u2211", title: "Formula Library", desc: "Math & science\nformulas" },
                { icon: "M", title: "Linear Algebra", desc: "Matrix operations\nDet, Inv, Rank, RREF" },
                { icon: "\u25B3", title: "Graph Algorithms", desc: "Dijkstra, MST\nConnectivity" },
                { icon: "\u03A3", title: "Statistics", desc: "Descriptive, t-test\nANOVA, Regression" },
                { icon: "\u25A0", title: "Geometry", desc: "Area, perimeter\nDistance" },
            ]
        },
        {
            name: "Creative & 3D",
            tools: [
                { icon: "\u25B2", title: "3D Creator", desc: "Model, sculpt &\nedit 3D objects" },
            ]
        },
        {
            name: "History & Geography",
            tools: [
                { icon: "\u23F1", title: "Timeline", desc: "Edit & visualize\nhistorical timelines" },
                { icon: "\uD83D\uDCDC", title: "Source Analyzer", desc: "Analyze primary &\nsecondary sources" },
                { icon: "\u25CB", title: "Coordinates", desc: "DD/DMS conversion\ndistance & bearing" },
                { icon: "\uD83D\uDCCA", title: "Demographics", desc: "Choropleth maps\nrankings & compare" },
            ]
        },
        {
            name: "Study Tools",
            tools: [
                { icon: "\uD83E\uDDE0", title: "Mind Map", desc: "AI-powered mind maps\nfrom documents & text" },
            ]
        }
    ]

    function getToolIndex(groupIdx, toolIdx) {
        var idx = 0
        for (var g = 0; g < toolGroups.length; g++) {
            if (g < groupIdx) {
                idx += toolGroups[g].tools.length
            } else if (g === groupIdx) {
                return idx + toolIdx
            }
        }
        return idx
    }

    function matchesSearch(tool) {
        if (searchQuery === "") return true
        var q = searchQuery.toLowerCase()
        return tool.title.toLowerCase().indexOf(q) >= 0 ||
               tool.desc.toLowerCase().indexOf(q) >= 0
    }

    Item {
        anchors.fill: parent
        visible: parent.state === "grid"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingLg
            spacing: Theme.spacingMd

            Text {
                text: "Tools"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeXl
                font.weight: Font.Bold
                Accessible.name: "Tools title"
            }

            Text {
                text: "Productivity tools for your studies"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeMd
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Theme.radiusFull
                color: Theme.inputBg
                border.color: searchField.activeFocus ? Theme.accentCopper : Theme.divider
                border.width: searchField.activeFocus ? 1.5 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "\uD83D\uDD0D"
                        font.pixelSize: 14
                        color: Theme.textMuted
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeSm
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        onTextChanged: root.searchQuery = text
                        Accessible.name: "Search tools"
                        Accessible.role: Accessible.EditableText
                    }

                    Rectangle {
                        visible: searchField.text !== ""
                        width: 20; height: 20; radius: 10
                        color: Theme.textMuted
                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            color: "#ffffff"
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: searchField.text = ""
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: groupsColumn.height
                clip: true
                flickableDirection: Flickable.VerticalFlick

                ColumnLayout {
                    id: groupsColumn
                    width: parent.width
                    spacing: Theme.spacingLg

                    Repeater {
                        model: toolGroups

                        ColumnLayout {
                            property int groupIndex: index
                            spacing: Theme.spacingSm
                            visible: {
                                for (var t = 0; t < modelData.tools.length; t++)
                                    if (root.matchesSearch(modelData.tools[t])) return true
                                return false
                            }

                            Text {
                                text: modelData.name
                                color: Theme.accentCopper
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Font.DemiBold
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Theme.spacingMd

                                Repeater {
                                    model: modelData.tools

                                    GlassCard {
                                        width: 220; height: 160
                                        hoverable: true
                                        visible: root.matchesSearch(modelData)
                                        scale: cardHovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: activeTool = getToolIndex(parent.parent.parent.groupIndex, index)
                                        }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingSm

                                            Text {
                                                text: modelData.icon
                                                color: Theme.accentCopper
                                                font.pixelSize: 28
                                                font.weight: Font.Bold
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            Text {
                                                text: modelData.title
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontSizeMd
                                                font.weight: Font.DemiBold
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            Text {
                                                text: modelData.desc
                                                color: Theme.textSecondary
                                                font.pixelSize: Theme.fontSizeXs
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }

                                        ToolTip {
                                            visible: parent.cardHovered
                                            text: modelData.title
                                            delay: 500
                                        }

                                        Accessible.name: modelData.title + ": " + modelData.desc
                                        Accessible.role: Accessible.Button
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: {
                            for (var g = 0; g < toolGroups.length; g++)
                                for (var t = 0; t < toolGroups[g].tools.length; t++)
                                    if (root.matchesSearch(toolGroups[g].tools[t])) return false
                            return true
                        }
                        text: "No tools match \"" + root.searchQuery + "\""
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeMd
                        font.italic: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.spacingXl
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    Rectangle {
        id: navBar
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 36; z: 10; visible: activeTool >= 0
        color: Theme.sidebarBg

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; spacing: 2
            Rectangle {
                Layout.preferredWidth: 40; Layout.preferredHeight: 28; radius: 4
                color: activeTool < 0 ? Theme.accentCopper : Theme.inactiveBtn
                Text { anchors.centerIn: parent; text: "\u2261"; color: "#ffffff"; font.pixelSize: 14 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeTool = -1 }
                Accessible.name: "Back to tools grid"
                Accessible.role: Accessible.Button
            }
            Flickable {
                Layout.fillWidth: true; Layout.fillHeight: true
                contentWidth: toolRow.width; clip: true
                interactive: true; flickableDirection: Flickable.HorizontalFlick
                Row {
                    id: toolRow
                    height: parent.height; spacing: 2
                    Repeater {
                        model: [
                            {label: "Calc"}, {label: "Equations"}, {label: "Graphs"},
                            {label: "Formulas"}, {label: "Lin Alg"}, {label: "Graph Alg"},
                            {label: "Stats"}, {label: "Geometry"}, {label: "3D"},
                            {label: "Timeline"}, {label: "Sources"},
                            {label: "Coords"}, {label: "Demographics"},
                            {label: "Mind Map"},
                        ]
                        Rectangle {
                            height: 28; radius: 4
                            color: activeTool === index ? Theme.accentCopper : Theme.inactiveBtn
                            width: labelText.implicitWidth + 20
                            Text {
                                id: labelText
                                anchors.centerIn: parent
                                text: modelData.label; color: "#ffffff"; font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: activeTool = index
                            }
                            Accessible.name: modelData.label
                            Accessible.role: Accessible.Button
                        }
                    }
                }
            }
        }
    }

    property var toolInstances: ({
        0: calculatorTool, 1: equationSolverTool, 2: graphPlotterTool, 3: formulaLibraryTool,
        4: linearAlgebraTool, 5: graphAlgorithmsTool, 6: statisticsTool, 7: geometryTool,
        8: meshEditorTool, 9: timelineTool, 10: sourceAnalyzerTool, 11: coordCalcTool,
        12: demographicsTool, 13: mindMapPageTool
    })

    function onNew() {
        if (activeTool < 0) return
        var tool = toolInstances[activeTool]
        if (tool && typeof tool.onNew === "function") tool.onNew()
    }
    function onClose() {
        if (activeTool >= 0) activeTool = -1
    }
    function onExport() {
        if (activeTool < 0) return
        var tool = toolInstances[activeTool]
        if (tool && typeof tool.onExport === "function") tool.onExport()
    }

    Item {
        id: toolContainer
        anchors.fill: parent
        anchors.topMargin: navBar.visible ? navBar.height : 0
        visible: activeTool >= 0

        Calculator { id: calculatorTool; anchors.fill: parent; visible: activeTool === 0; onBack: activeTool = -1 }
        EquationSolver { id: equationSolverTool; anchors.fill: parent; visible: activeTool === 1; onBack: activeTool = -1 }
        GraphPlotter { id: graphPlotterTool; anchors.fill: parent; visible: activeTool === 2; onBack: activeTool = -1 }
        FormulaLibrary { id: formulaLibraryTool; anchors.fill: parent; visible: activeTool === 3; onBack: activeTool = -1 }
        LinearAlgebra { id: linearAlgebraTool; anchors.fill: parent; visible: activeTool === 4; onBack: activeTool = -1 }
        GraphAlgorithms { id: graphAlgorithmsTool; anchors.fill: parent; visible: activeTool === 5; onBack: activeTool = -1 }
        Statistics { id: statisticsTool; anchors.fill: parent; visible: activeTool === 6; onBack: activeTool = -1 }
        Geometry { id: geometryTool; anchors.fill: parent; visible: activeTool === 7; onBack: activeTool = -1 }
        MeshEditor { id: meshEditorTool; anchors.fill: parent; visible: activeTool === 8; onBack: activeTool = -1 }
        Timeline { id: timelineTool; anchors.fill: parent; visible: activeTool === 9; onBack: activeTool = -1 }
        SourceAnalyzer { id: sourceAnalyzerTool; anchors.fill: parent; visible: activeTool === 10; onBack: activeTool = -1 }
        CoordCalc { id: coordCalcTool; anchors.fill: parent; visible: activeTool === 11; onBack: activeTool = -1 }
        Demographics { id: demographicsTool; anchors.fill: parent; visible: activeTool === 12; onBack: activeTool = -1 }
        MindMapPage { id: mindMapPageTool; anchors.fill: parent; visible: activeTool === 13; onBack: activeTool = -1 }
    }
}
