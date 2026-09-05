import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: Theme.spacingXs

    property string label: ""
    property string placeholder: ""
    property alias text: inputField.text
    property alias input: inputField

    Text {
        text: root.label
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeSm
        visible: root.label !== ""
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: Theme.radiusSm
        color: Theme.inputBg
        border.color: inputField.activeFocus ? Theme.accentCopper : Theme.divider
        border.width: inputField.activeFocus ? 1.5 : 1

        TextInput {
            id: inputField
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSm
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            activeFocusOnTab: true
            clip: true
        }

        Text {
            visible: inputField.text === "" && root.placeholder !== ""
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.placeholderText
            font.pixelSize: Theme.fontSizeSm
        }
    }

    Accessible.name: root.label || root.placeholder
    Accessible.role: Accessible.EditableText
}
