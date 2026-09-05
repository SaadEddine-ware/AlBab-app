import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: Theme.spacingXs

    property var tabNames: []
    property int currentIndex: 0
    signal tabClicked(int index)

    Repeater {
        model: tabNames
        Rectangle {
            Layout.preferredWidth: 100
            Layout.preferredHeight: 28
            radius: Theme.radiusSm
            color: root.currentIndex === index ? Theme.accentCopper : Theme.chipBg

            Text {
                anchors.centerIn: parent
                text: modelData
                color: root.currentIndex === index ? "#ffffff" : Theme.textSecondary
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.currentIndex = index
                    root.tabClicked(index)
                }
            }

            Accessible.name: modelData
            Accessible.role: Accessible.Button
            Accessible.checked: root.currentIndex === index
        }
    }
}
