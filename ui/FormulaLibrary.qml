import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property string filterText: ""

    property var categories: [
        {
            name: "Algebra",
            formulas: [
                { name: "Quadratic Formula", formula: "x = (-b \u00B1 \u221A(b\u00B2 - 4ac)) / 2a" },
                { name: "Difference of Squares", formula: "a\u00B2 - b\u00B2 = (a-b)(a+b)" },
                { name: "Binomial Square", formula: "(a \u00B1 b)\u00B2 = a\u00B2 \u00B1 2ab + b\u00B2" },
                { name: "Slope", formula: "m = (y\u2082 - y\u2081) / (x\u2082 - x\u2081)" },
            ]
        },
        {
            name: "Geometry",
            formulas: [
                { name: "Circle Area", formula: "A = \u03C0r\u00B2" },
                { name: "Circle Circumference", formula: "C = 2\u03C0r" },
                { name: "Triangle Area", formula: "A = \u00BDbh" },
                { name: "Pythagorean Theorem", formula: "a\u00B2 + b\u00B2 = c\u00B2" },
                { name: "Rectangle Area", formula: "A = l \u00D7 w" },
                { name: "Sphere Volume", formula: "V = \u00BEd\u03C0r\u00B3" },
            ]
        },
        {
            name: "Calculus",
            formulas: [
                { name: "Power Rule", formula: "d/dx(x\u207F) = nx\u207B\u00B9" },
                { name: "Product Rule", formula: "d/dx(uv) = uv' + vu'" },
                { name: "Chain Rule", formula: "d/dx(f(g(x))) = f'(g(x))g'(x)" },
                { name: "Integration Power", formula: "\u222Bx\u207Fdx = x\u207F\u207A\u00B9/(n+1) + C" },
            ]
        },
        {
            name: "Trigonometry",
            formulas: [
                { name: "Sine", formula: "sin(\u03B8) = opp/hyp" },
                { name: "Cosine", formula: "cos(\u03B8) = adj/hyp" },
                { name: "Tangent", formula: "tan(\u03B8) = opp/adj" },
                { name: "Pythagorean Identity", formula: "sin\u00B2\u03B8 + cos\u00B2\u03B8 = 1" },
            ]
        },
        {
            name: "Physics",
            formulas: [
                { name: "Newton's 2nd Law", formula: "F = ma" },
                { name: "Kinetic Energy", formula: "KE = \u00BDmv\u00B2" },
                { name: "Ohm's Law", formula: "V = IR" },
                { name: "Einstein's E", formula: "E = mc\u00B2" },
            ]
        },
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text {
                text: "Formula Library"
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
                Accessible.name: "Back to tools"
                Accessible.role: Accessible.Button
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: Theme.radiusFull
            color: Theme.inputBg
            border.color: Theme.divider
            TextInput {
                id: searchField
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSm
                verticalAlignment: TextInput.AlignVCenter
                onTextChanged: root.filterText = text.toLowerCase()
            }
            Text {
                anchors.left: searchField.left; anchors.verticalCenter: searchField.verticalCenter
                text: "Search formulas..."
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeSm
                visible: searchField.text.length === 0 && !searchField.activeFocus
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: searchField.forceActiveFocus()
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingMd

                Repeater {
                    model: root.categories.length

                    ColumnLayout {
                        id: catDelegate
                        required property int index
                        property var cat: root.categories[index]
                        property var filtered: {
                            var f = []
                            var arr = cat.formulas
                            if (root.filterText) {
                                for (var i = 0; i < arr.length; i++) {
                                    if (arr[i].name.toLowerCase().indexOf(root.filterText) >= 0 ||
                                        arr[i].formula.toLowerCase().indexOf(root.filterText) >= 0)
                                        f.push(arr[i])
                                }
                            } else {
                                f = arr
                            }
                            return f
                        }
                        visible: filtered.length > 0
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: cat.name
                            color: Theme.accentCopper
                            font.pixelSize: Theme.fontSizeMd
                            font.weight: Font.DemiBold
                            Layout.topMargin: Theme.spacingSm
                        }

                        Repeater {
                            model: catDelegate.filtered

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: Theme.radiusSm
                                color: Theme.chipBg
                                border.color: Theme.divider

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 50
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: modelData.formula
                                        color: Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeSm - 1
                                        font.family: Theme.fontMono
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: 8
                                    width: 28; height: 28
                                    radius: Theme.radiusSm
                                    color: Theme.chipBg
                                    border.color: Theme.divider
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u2398"
                                        color: Theme.textSecondary
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            FormulaLibraryBackend.copyToClipboard(modelData.formula)
                                        }
                                    }
                                    Accessible.name: "Copy formula"
                                    Accessible.role: Accessible.Button
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.spacingMd }
            }
        }
    }
}

