import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property int mode: 0
    property string resultText: ""
    property bool isLoading: false

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isLoading
        message: "Computing..."
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text {
                text: "Equation Solver"
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
                Accessible.name: "Back to tools"; Accessible.role: Accessible.Button
            }
        }

        RowLayout {
            spacing: Theme.spacingXs
            Repeater {
                model: [
                    { t: "Solve", m: 0 },
                    { t: "Derivative", m: 1 },
                    { t: "Integrate", m: 2 },
                    { t: "Definite \u222B", m: 3 },
                ]
                Rectangle {
                    Layout.preferredWidth: 64; Layout.preferredHeight: 28
                    radius: Theme.radiusFull
                    color: root.mode === modelData.m ? Theme.accentCopper : Theme.inactiveBtn
                    Text {
                        anchors.centerIn: parent
                        text: modelData.t
                        color: root.mode === modelData.m ? "#ffffff" : Theme.textPrimary
                        font.pixelSize: Theme.fontSizeSm - 1
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.mode = modelData.m
                    }
                }
            }
        }

        Text {
            text: mode === 0 ? "Equation (e.g., x^2 - 4 = 0)" :
                  mode === 1 ? "f(x) to differentiate (e.g., x^3 + 2*x)" :
                  mode === 2 ? "f(x) to integrate (e.g., x^2)" :
                  "f(x) and bounds (e.g., x^2, a=0, b=1)"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSm
            wrapMode: Text.WordWrap
        }

        RowLayout {
            spacing: Theme.spacingSm
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Theme.radiusFull
                color: Theme.inputBg
                border.color: Theme.divider
                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeMd
                    font.family: Theme.fontMono
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted: compute()
                }
            }
            Rectangle {
                Layout.preferredWidth: 80; Layout.preferredHeight: 40
                radius: Theme.radiusSm; color: Theme.accentCopper
                Text {
                    anchors.centerIn: parent
                    text: "Go"
                    color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: compute()
                }
            }
        }

        RowLayout {
            visible: mode === 3
            spacing: Theme.spacingSm
            Text { text: "a ="; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 30
                radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                TextInput {
                    id: boundA
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                    text: "0"
                    color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                    font.family: Theme.fontMono; verticalAlignment: TextInput.AlignVCenter
                }
            }
            Text { text: "b ="; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 30
                radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                TextInput {
                    id: boundB
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                    text: "1"
                    color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                    font.family: Theme.fontMono; verticalAlignment: TextInput.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.resultBg
            radius: Theme.radiusMd
            clip: true
            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                contentHeight: outputText.height
                ScrollIndicator.vertical: ScrollIndicator { }
                Text {
                    id: outputText
                    width: parent.width
                    text: root.resultText || "Enter an expression above and click Go"
                    color: root.resultText ? Theme.textPrimary : Theme.textMuted
                    font.pixelSize: Theme.fontSizeMd
                    font.family: Theme.fontMono
                    wrapMode: Text.WordWrap
                }
            }
        }

        function compute() {
            var expr = input.text.trim()
            if (!expr) return
            root.isLoading = true
            try {
                var result
                if (mode === 0) {
                    result = MathEngine.solve(expr)
                } else if (mode === 1) {
                    result = MathEngine.differentiate(expr)
                } else if (mode === 2) {
                    result = MathEngine.integrate(expr)
                } else if (mode === 3) {
                    var a = parseFloat(boundA.text) || 0
                    var b = parseFloat(boundB.text) || 0
                    result = MathEngine.definiteIntegral(expr, a, b)
                }
                root.resultText = result
                outputText.text = result
            } finally {
                root.isLoading = false
            }
        }
    }
}

