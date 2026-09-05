import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property bool isLoading: false
    property string message: "Loading..."

    anchors.fill: parent
    color: "#80000000"
    z: 100
    visible: isLoading

    Rectangle {
        anchors.centerIn: parent
        width: 140
        height: 50
        radius: Theme.radiusSm
        color: Theme.glassBase
        border.color: Theme.divider

        RowLayout {
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: Theme.accentCopper
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            Text {
                text: root.message
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeSm
            }
        }
    }

    Accessible.name: root.message
    Accessible.role: Accessible.ProgressBar
}
