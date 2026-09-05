import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property string editFirst: UserManager.currentFirstName
    property string editLast: UserManager.currentLastName
    property string editFaculty: UserManager.currentFaculty
    property bool isEditing: false
    property string saveMsg: ""
    property string apiKeyMsg: ""
    property string apiKeyTestMsg: ""
    property string apiKeyField: (typeof GeminiBackend !== 'undefined' ? GeminiBackend.apiKey : "") || ""
    property var settingsModel: [
        { label: "Language", value: SettingsBackend.language || "English" },
        { label: "Theme", value: Theme.darkMode ? "Dark Glass" : "Frosted Glass" },
        { label: "AI Auto-Start", value: "Enabled" },
    ]

    function refreshSettingsModel() {
        settingsModel = [
            { label: "Language", value: SettingsBackend.language || "English" },
            { label: "Theme", value: Theme.darkMode ? "Dark Glass" : "Frosted Glass" },
            { label: "AI Status", value: "Active" },
        ]
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.spacingLg * 2
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            width: parent.width
            anchors.margins: Theme.spacingLg
            spacing: Theme.spacingMd

        Text {
            text: "Settings"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeXl
            font.weight: Font.Bold
            Accessible.name: "Settings title"
        }

        Text {
            text: "Your profile and preferences"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeMd
        }

        Item { Layout.preferredHeight: Theme.spacingXs }

        GlassCard {
            Layout.fillWidth: true
            Layout.preferredHeight: profileCol.implicitHeight + Theme.spacingMd * 4

            ColumnLayout {
                id: profileCol
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Text {
                    text: "Profile"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: root.saveMsg !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Theme.radiusSm
                    color: Theme.successBg
                    border.color: Theme.successText
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.saveMsg
                        color: Theme.successText
                        font.pixelSize: Theme.fontSizeSm
                    }
                }

                GridLayout {
                    visible: !root.isEditing
                    columns: 2
                    columnSpacing: Theme.spacingLg
                    rowSpacing: Theme.spacingSm

                    Text { text: "Name"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    Text { text: UserManager.currentName; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm }

                    Text { text: "Email"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    Text { text: UserManager.currentEmail; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm }

                    Text { text: "University"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    Text { text: UserManager.currentFaculty; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm }
                }

                ColumnLayout {
                    visible: root.isEditing
                    spacing: Theme.spacingXs

                    RowLayout {
                        spacing: Theme.spacingSm
                        Text { text: "First Name"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; Layout.minimumWidth: 80 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.inputBg
                            border.color: Theme.divider
                            TextInput {
                                id: editFirstInput
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: root.editFirst = text
                                selectByMouse: true
                                activeFocusOnTab: true
                                Accessible.name: "Edit first name"
                            }
                        }
                    }
                    RowLayout {
                        spacing: Theme.spacingSm
                        Text { text: "Last Name"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; Layout.minimumWidth: 80 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.inputBg
                            border.color: Theme.divider
                            TextInput {
                                id: editLastInput
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: root.editLast = text
                                selectByMouse: true
                                activeFocusOnTab: true
                                Accessible.name: "Edit last name"
                            }
                        }
                    }
                    RowLayout {
                        spacing: Theme.spacingSm
                        Text { text: "University"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; Layout.minimumWidth: 80 }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.inputBg
                            border.color: Theme.divider
                            TextInput {
                                id: editFacultyInput
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                                verticalAlignment: TextInput.AlignVCenter
                                onTextChanged: root.editFaculty = text
                                selectByMouse: true
                                activeFocusOnTab: true
                                Accessible.name: "Edit university"
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: Theme.spacingSm
                    Rectangle {
                        Layout.preferredWidth: root.isEditing ? 70 : 60; Layout.preferredHeight: 28
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: root.isEditing ? "Save" : "Edit"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.isEditing) {
                                    SettingsBackend.updateProfile(root.editFirst, root.editLast, root.editFaculty)
                                    root.isEditing = false
                                    root.saveMsg = "Profile saved"
                                    saveTimer.start()
                                } else {
                                    root.editFirst = UserManager.currentFirstName
                                    root.editLast = UserManager.currentLastName
                                    root.editFaculty = UserManager.currentFaculty
                                    editFirstInput.text = root.editFirst
                                    editLastInput.text = root.editLast
                                    editFacultyInput.text = root.editFaculty
                                    root.isEditing = true
                                }
                            }
                        }
                        Accessible.name: root.isEditing ? "Save profile" : "Edit profile"
                        Accessible.role: Accessible.Button
                    }
                    Rectangle {
                        visible: root.isEditing
                        Layout.preferredWidth: 70; Layout.preferredHeight: 28
                        radius: Theme.radiusSm; color: Theme.chipBg
                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.isEditing = false
                                root.editFirst = UserManager.currentFirstName
                                root.editLast = UserManager.currentLastName
                                root.editFaculty = UserManager.currentFaculty
                            }
                        }
                        Accessible.name: "Cancel editing"
                        Accessible.role: Accessible.Button
                    }
                }
            }
        }

        GlassCard {
            Layout.fillWidth: true
            Layout.preferredHeight: prefsCol.implicitHeight + Theme.spacingMd * 4

            ColumnLayout {
                id: prefsCol
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Text {
                    text: "Preferences"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    spacing: Theme.spacingSm
                    Text { text: "Dark Mode"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; Layout.minimumWidth: 140 }
                    Rectangle {
                        Layout.preferredWidth: 44; Layout.preferredHeight: 24; radius: 12
                        color: Theme.darkMode ? Theme.accentCopper : Theme.divider
                        Rectangle {
                            x: Theme.darkMode ? 22 : 2; y: 2; width: 20; height: 20; radius: 10
                            color: "#ffffff"
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.darkMode = !Theme.darkMode
                            SettingsBackend.setTheme(Theme.darkMode ? "dark" : "light")
                        }
                    }
                        Accessible.name: "Toggle dark mode"
                        Accessible.role: Accessible.CheckBox
                        Accessible.checked: Theme.darkMode
                    }
                    Text { text: Theme.darkMode ? "On" : "Off"; color: Theme.textMuted; font.pixelSize: Theme.fontSizeXs }
                }

                ColumnLayout {
                    spacing: Theme.spacingSm
                    Repeater {
                        model: root.settingsModel
                        RowLayout {
                            Text {
                                text: modelData.label
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeSm
                                Layout.minimumWidth: 140
                                Accessible.name: modelData.label + " setting"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: Theme.radiusSm
                                color: Theme.inputBg
                                border.color: Theme.divider
                                Text {
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    text: modelData.value
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeSm
                                }
                            }
                        }
                    }
                }
            }
        }

        GlassCard {
            Layout.fillWidth: true
            Layout.preferredHeight: aiSettingsCol.implicitHeight + Theme.spacingMd * 4

            ColumnLayout {
                id: aiSettingsCol
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Text {
                    text: "AI Settings"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    spacing: Theme.spacingSm
                    Text {
                        text: "Backend:"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSm
                        Layout.minimumWidth: 80
                    }
                    Rectangle {
                        Layout.preferredWidth: 120; Layout.preferredHeight: 28
                        radius: Theme.radiusSm; color: Theme.inputBg
                        border.color: Theme.divider
                        Text {
                            anchors.centerIn: parent
                            text: SettingsBackend.llmProvider || "OpenCode"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var current = SettingsBackend.llmProvider || "OpenCode"
                                var next = current === "OpenCode" ? "Gemini" : "OpenCode"
                                SettingsBackend.setLlmProvider(next)
                            }
                        }
                        Accessible.name: "Toggle AI backend"
                        Accessible.role: Accessible.Button
                    }
                    Text {
                        text: "(click to toggle)"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeXs
                        visible: true
                    }
                }

                RowLayout {
                    spacing: Theme.spacingSm
                    visible: (SettingsBackend.llmProvider || "OpenCode") === "Gemini"
                    Text {
                        text: "Keys:"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSm
                        Layout.minimumWidth: 80
                    }
                    Rectangle {
                        Layout.preferredWidth: 120; Layout.preferredHeight: 28
                        radius: Theme.radiusSm; color: Theme.inputBg
                        border.color: Theme.divider
                        Text {
                            id: keyStatusText
                            anchors.centerIn: parent
                            text: GeminiBackend.keyStatus || "No keys"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeSm
                        }
                    }
                }

                Text {
                    text: "Gemini API key (for Gemini backend)"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm
                }

                Rectangle {
                    visible: root.apiKeyMsg !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Theme.radiusSm
                    color: Theme.darkMode ? "#332200" : "#FFF3CD"
                    border.color: Theme.darkMode ? "#FFA000" : "#FFC107"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.apiKeyMsg
                        color: Theme.darkMode ? "#FFD54F" : "#856404"
                        font.pixelSize: Theme.fontSizeSm
                    }
                }

                Rectangle {
                    visible: root.apiKeyTestMsg !== ""
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Theme.radiusSm
                    color: root.apiKeyTestMsg.indexOf("Success") >= 0 ? Theme.successBg : "#FFEBEE"
                    border.color: root.apiKeyTestMsg.indexOf("Success") >= 0 ? Theme.successText : "#EF5350"
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: root.apiKeyTestMsg
                        color: root.apiKeyTestMsg.indexOf("Success") >= 0 ? Theme.successText : "#C62828"
                        font.pixelSize: Theme.fontSizeSm
                    }
                }

                RowLayout {
                    spacing: Theme.spacingSm
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radiusSm
                        color: Theme.inputBg
                        border.color: Theme.divider
                        TextInput {
                            id: apiKeyInput
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            onTextChanged: root.apiKeyField = text
                            selectByMouse: true
                            activeFocusOnTab: true
                            Accessible.name: "Gemini API key"
                            Component.onCompleted: text = root.apiKeyField
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 80; Layout.preferredHeight: 28
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: "Save Key"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                GeminiBackend.setApiKey(apiKeyInput.text)
                                root.apiKeyMsg = "API key saved"
                                apiKeyMsgTimer.start()
                            }
                        }
                        Accessible.name: "Save API key"
                        Accessible.role: Accessible.Button
                    }
                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 28
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: "Test Connection"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var online = GeminiBackend.checkOnline()
                                root.apiKeyTestMsg = online ? "Success — internet reachable" : "Offline — check your connection"
                                apiKeyTestTimer.start()
                            }
                        }
                        Accessible.name: "Test internet connection"
                        Accessible.role: Accessible.Button
                    }
                }
            }
        }

        }

        ScrollIndicator.vertical: ScrollIndicator { }
    }

    Connections {
        target: typeof SettingsBackend !== 'undefined' ? SettingsBackend : null
        ignoreUnknownSignals: true
        function onSettingsChanged() {
            root.refreshSettingsModel()
        }
    }

    Connections {
        target: Theme
        ignoreUnknownSignals: true
        function onDarkModeChanged() {
            root.refreshSettingsModel()
        }
    }

    Timer {
        id: saveTimer
        interval: 2000
        onTriggered: root.saveMsg = ""
    }
    Timer {
        id: apiKeyMsgTimer
        interval: 2000
        onTriggered: root.apiKeyMsg = ""
    }
    Timer {
        id: apiKeyTestTimer
        interval: 4000
        onTriggered: root.apiKeyTestMsg = ""
    }
}
