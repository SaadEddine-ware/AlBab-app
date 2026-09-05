import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    signal clicked()

    property string label: ""
    property bool isActive: false
    property bool isPrimary: true
    property int btnWidth: 100
    property int btnHeight: 28

    Layout.preferredWidth: btnWidth
    Layout.preferredHeight: btnHeight
    radius: Theme.radiusSm
    color: isPrimary ? (isActive ? Theme.accentCopper : Theme.chipBg) : Theme.inputBg

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.isPrimary ? (root.isActive ? "#ffffff" : Theme.textSecondary) : Theme.textSecondary
        font.pixelSize: Theme.fontSizeSm
        font.weight: Font.DemiBold
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Accessible.name: root.label
    Accessible.role: Accessible.Button
}
