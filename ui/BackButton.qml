import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    signal clicked()

    Layout.preferredWidth: 60
    Layout.preferredHeight: 28
    radius: Theme.radiusSm
    color: Theme.inputBg
    border.color: Theme.divider

    property string label: "\u2190 Back"

    Text {
        anchors.centerIn: parent
        text: root.label
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeSm
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Accessible.name: "Go back"
    Accessible.role: Accessible.Button
}
