import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property bool _hasMainBackend: typeof MainBackend !== 'undefined'

    states: [
        State { name: "form"; when: _hasMainBackend && !MainBackend.hasProfile },
        State { name: "dashboard"; when: _hasMainBackend && MainBackend.hasProfile },
        State { name: "default"; when: !_hasMainBackend }
    ]

    property string formError: ""

    OnboardingTour {
        id: tour
        anchors.fill: parent
        onTourFinished: { if (typeof SettingsBackend !== 'undefined') SettingsBackend.setOnboardingDone() }
    }

    Component.onCompleted: {
        if (typeof UserManager === 'undefined' || typeof SettingsBackend === 'undefined') return
        if (UserManager.isLoggedIn) return
        if (!SettingsBackend.isOnboardingDone()) {
            Qt.callLater(function() { tour.startTour() })
        }
    }

    Item {
        anchors.fill: parent
        visible: parent.state === "form" || parent.state === "default"

        Flickable {
            anchors.fill: parent
            contentHeight: formColumn.height + Theme.spacingLg * 2
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: formColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingLg
                width: Math.min(parent.width * 0.42, 440)

            Text {
                text: "\u0628"
                color: Theme.accentCopper
                font.pixelSize: 56
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 60
            }

            Text {
                text: "AlBab"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeXxl
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Your AI-powered student hub"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeMd
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.preferredHeight: Theme.spacingSm }

            GlassCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 380

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Welcome"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeLg
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Enter your details to get started"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSm
                    }

                    Rectangle {
                        visible: root.formError !== ""
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.radiusSm
                        color: Theme.errorBg
                        border.color: Theme.errorText
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.formError
                            color: Theme.errorText
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.spacingXs
                        Text {
                            text: "First Name *"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSm
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 42
                            radius: Theme.radiusSm; color: Theme.inputBg
                            border.color: firstNameField.activeFocus ? Theme.accentCopper : Theme.divider
                            border.width: firstNameField.activeFocus ? 1.5 : 1
                            TextInput {
                                id: firstNameField
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                activeFocusOnTab: true
                                Keys.onReturnPressed: lastNameField.forceActiveFocus()
                                Accessible.name: "First name"
                                Accessible.role: Accessible.EditableText
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.spacingXs
                        Text {
                            text: "Last Name *"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSm
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 42
                            radius: Theme.radiusSm; color: Theme.inputBg
                            border.color: lastNameField.activeFocus ? Theme.accentCopper : Theme.divider
                            border.width: lastNameField.activeFocus ? 1.5 : 1
                            TextInput {
                                id: lastNameField
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                activeFocusOnTab: true
                                Keys.onReturnPressed: facultyField.forceActiveFocus()
                                Accessible.name: "Last name"
                                Accessible.role: Accessible.EditableText
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: Theme.spacingXs
                        Text {
                            text: "Faculty / University"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSm
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 42
                            radius: Theme.radiusSm; color: Theme.inputBg
                            border.color: facultyField.activeFocus ? Theme.accentCopper : Theme.divider
                            border.width: facultyField.activeFocus ? 1.5 : 1
                            TextInput {
                                id: facultyField
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                activeFocusOnTab: true
                                Keys.onReturnPressed: submitProfile()
                                Accessible.name: "Faculty or university"
                                Accessible.role: Accessible.EditableText
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 44
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: "Continue"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: submitProfile()
                        }
                        Accessible.name: "Continue"
                        Accessible.role: Accessible.Button
                    }

                    Text {
                        text: "* Required"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeXs
                    }
                }
            }
        }

            ScrollIndicator.vertical: ScrollIndicator { }
        }
    }

    function submitProfile() {
        if (!_hasMainBackend) return
        var fn = firstNameField.text.trim()
        var ln = lastNameField.text.trim()
        if (!fn && !ln) {
            root.formError = "Please enter your first and last name"
        } else if (!fn) {
            root.formError = "Please enter your first name"
        } else if (!ln) {
            root.formError = "Please enter your last name"
        } else {
            root.formError = ""
            MainBackend.submitProfile(fn, ln, facultyField.text.trim())
        }
    }

    Item {
        id: dash
        anchors.fill: parent
        visible: parent.state === "dashboard"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingMd

            Text {
                text: "Hello, " + (UserManager.currentFirstName || "there")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeXxl
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: UserManager.currentFaculty || ""
                color: Theme.accentCopper
                font.pixelSize: Theme.fontSizeLg
                Layout.alignment: Qt.AlignHCenter
                visible: text !== ""
            }
            Item { Layout.preferredHeight: Theme.spacingXl }
            Text {
                text: "Open AI Chat from the sidebar to start talking."
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeMd
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
