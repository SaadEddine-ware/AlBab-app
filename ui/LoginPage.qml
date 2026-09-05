import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal loginSuccess()

    property bool isRegistering: !UserManager.hasAnyUsers()
    property string errorMsg: ""

    Flickable {
        anchors.fill: parent
        contentHeight: loginColumn.height + Theme.spacingLg * 2
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: loginColumn
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
            text: isRegistering ? "Create your account" : "Welcome back"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeMd
            Layout.alignment: Qt.AlignHCenter
        }

        Item { Layout.preferredHeight: Theme.spacingSm }

        GlassCard {
            Layout.fillWidth: true
            Layout.preferredHeight: isRegistering ? 420 : 200

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                Rectangle {
                    visible: errorMsg !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.radiusSm
                    color: Theme.errorBg
                    border.color: Theme.errorText
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: errorMsg
                        color: Theme.errorText
                        font.pixelSize: Theme.fontSizeSm
                    }
                }

                ColumnLayout {
                    visible: isRegistering
                    spacing: Theme.spacingXs
                    Text { text: "First Name *"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
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
                            selectByMouse: true; activeFocusOnTab: true
                            Keys.onReturnPressed: lastNameField.forceActiveFocus()
                            Accessible.name: "First name"
                        }
                    }
                }

                ColumnLayout {
                    visible: isRegistering
                    spacing: Theme.spacingXs
                    Text { text: "Last Name *"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
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
                            selectByMouse: true; activeFocusOnTab: true
                            Keys.onReturnPressed: emailField.forceActiveFocus()
                            Accessible.name: "Last name"
                        }
                    }
                }

                ColumnLayout {
                    spacing: Theme.spacingXs
                    Text { text: "Academic Email *"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 42
                        radius: Theme.radiusSm; color: Theme.inputBg
                        border.color: emailField.activeFocus ? Theme.accentCopper : Theme.divider
                        border.width: emailField.activeFocus ? 1.5 : 1
                        TextInput {
                            id: emailField
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true; activeFocusOnTab: true
                            inputMethodHints: Qt.ImhEmailCharactersOnly
                            Keys.onReturnPressed: facultyField.forceActiveFocus()
                            Accessible.name: "Academic email"
                        }
                    }
                }

                ColumnLayout {
                    visible: isRegistering
                    spacing: Theme.spacingXs
                    Text { text: "Faculty *"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
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
                            selectByMouse: true; activeFocusOnTab: true
                            Keys.onReturnPressed: submitAction()
                            Accessible.name: "Faculty name"
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 44
                    radius: Theme.radiusSm; color: Theme.accentCopper
                    Text {
                        anchors.centerIn: parent
                        text: isRegistering ? "Create Account" : "Login"
                        color: "#ffffff"; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: submitAction()
                    }
                    Accessible.name: isRegistering ? "Create account" : "Login"
                    Accessible.role: Accessible.Button
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    Text {
                        text: isRegistering ? "Already have an account?" : "Don't have an account?"
                        color: Theme.textMuted; font.pixelSize: Theme.fontSizeSm
                    }
                    Text {
                        text: isRegistering ? "Login" : "Register"
                        color: Theme.accentCopper; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                isRegistering = !isRegistering
                                errorMsg = ""
                            }
                        }
                    }
                }

                Text {
                    text: "* Required"
                    color: Theme.textMuted; font.pixelSize: Theme.fontSizeXs
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Rectangle {
            visible: UserManager.hasAnyUsers() && !isRegistering
            Layout.fillWidth: true; Layout.preferredHeight: 1
            color: Theme.divider
        }

        ColumnLayout {
            visible: UserManager.hasAnyUsers() && !isRegistering
            spacing: Theme.spacingSm
            Layout.alignment: Qt.AlignHCenter

            Text {
                text: "Quick Login"
                color: Theme.textMuted; font.pixelSize: Theme.fontSizeSm
                Layout.alignment: Qt.AlignHCenter
            }

                Repeater {
                    model: {
                        try { return JSON.parse(UserManager.getUsers()) }
                        catch(e) { return [] }
                    }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 48
                    radius: Theme.radiusSm; color: Theme.glassBase; border.color: Theme.divider
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingSm
                        spacing: Theme.spacingSm

                        Rectangle {
                            width: 32; height: 32; radius: 16; color: Theme.accentCopper
                            Text {
                                anchors.centerIn: parent
                                text: modelData.first_name ? modelData.first_name.charAt(0).toUpperCase() : "?"
                                color: "#ffffff"; font.pixelSize: 14; font.weight: Font.Bold
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Text { text: modelData.first_name + " " + modelData.last_name; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            Text { text: modelData.faculty; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "\u27A4"
                            color: Theme.accentCopper; font.pixelSize: 14
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            try {
                                var result = JSON.parse(UserManager.login(modelData.email))
                                if (result.ok) {
                                    root.loginSuccess()
                                } else {
                                    errorMsg = result.error
                                }
                            } catch(e) {
                                errorMsg = "Login failed"
                            }
                        }
                    }
                    Accessible.name: "Login as " + modelData.first_name
                    Accessible.role: Accessible.Button
                }
            }
        }

        ScrollIndicator.vertical: ScrollIndicator { }
    }

    function submitAction() {
        errorMsg = ""
        try {
            if (isRegistering) {
                var fn = firstNameField.text.trim()
                var ln = lastNameField.text.trim()
                var em = emailField.text.trim()
                var fc = facultyField.text.trim()

                if (!fn && !ln) { errorMsg = "Please enter your name"; return }
                if (!fn) { errorMsg = "Please enter your first name"; return }
                if (!ln) { errorMsg = "Please enter your last name"; return }
                if (!em) { errorMsg = "Please enter your email"; return }
                if (!fc) { errorMsg = "Please enter your faculty"; return }

                var result = JSON.parse(UserManager.register(fn, ln, em, fc))
                if (result.ok) {
                    root.loginSuccess()
                } else {
                    errorMsg = result.error
                }
            } else {
                var em2 = emailField.text.trim()
                if (!em2) { errorMsg = "Please enter your email"; return }

                var result2 = JSON.parse(UserManager.login(em2))
                if (result2.ok) {
                    root.loginSuccess()
                } else {
                    errorMsg = result2.error
                }
            }
        } catch(e) {
            errorMsg = "An error occurred"
        }
    }

    Component.onCompleted: {
        if (typeof UserManager === 'undefined') return
        var lastEmail = UserManager.getLastEmail()
        if (lastEmail) {
            emailField.text = lastEmail
            isRegistering = false
        }
    }
}
