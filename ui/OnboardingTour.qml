import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    visible: false
    color: "#CC000000"
    z: 1000

    property int currentStep: 0
    property var steps: [
        { title: "Welcome to AlBab!", desc: "Your AI-powered student hub.\nLet's take a quick tour.", target: "home" },
        { title: "AI Chat", desc: "Talk to the AI assistant for help\nwith any topic.", target: "chat" },
        { title: "Tools", desc: "14 tools for math, science,\nhistory, and more.", target: "tools" },
        { title: "Settings", desc: "Customize your profile\nand preferences.", target: "settings" },
        { title: "Keyboard Shortcuts", desc: "Ctrl+1-4 to switch pages.\nCtrl+/ for help.", target: "shortcuts" },
    ]

    signal tourFinished()

    MouseArea { anchors.fill: parent }

    Rectangle {
        anchors.centerIn: parent
        width: 360; height: 220
        radius: Theme.radiusLg
        color: Theme.pageCardBg
        border.color: Theme.divider
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingLg
            spacing: Theme.spacingMd

            RowLayout {
                Text {
                    text: (currentStep + 1) + " / " + steps.length
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeXs
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: Theme.inputBg
                    Text { anchors.centerIn: parent; text: "\u2715"; color: Theme.textMuted; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.visible = false; tourFinished() } }
                    Accessible.name: "Close tour"
                    Accessible.role: Accessible.Button
                }
            }

            Text {
                text: steps[currentStep].title
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeXl
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: steps[currentStep].desc
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeMd
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                spacing: Theme.spacingSm
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    radius: Theme.radiusSm; color: currentStep > 0 ? Theme.chipBg : "transparent"
                    Text { anchors.centerIn: parent; text: "Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; visible: currentStep > 0 }
                    MouseArea {
                        anchors.fill: parent; cursorShape: currentStep > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { if (currentStep > 0) currentStep-- }
                    }
                    Accessible.name: "Previous step"
                    Accessible.role: Accessible.Button
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 36
                    radius: Theme.radiusSm; color: Theme.accentCopper
                    Text { anchors.centerIn: parent; text: currentStep < steps.length - 1 ? "Next" : "Get Started"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (currentStep < steps.length - 1) currentStep++
                            else { root.visible = false; tourFinished() }
                        }
                    }
                    Accessible.name: currentStep < steps.length - 1 ? "Next step" : "Get started"
                    Accessible.role: Accessible.Button
                }
            }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: steps.length
                    Rectangle {
                        width: index === currentStep ? 16 : 6; height: 6; radius: 3
                        color: index === currentStep ? Theme.accentCopper : Theme.divider
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                }
            }
        }
    }

    function startTour() {
        currentStep = 0
        visible = true
    }
}
