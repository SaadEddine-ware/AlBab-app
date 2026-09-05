import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string iconText: ""
    property string labelText: ""
    property int itemIndex: 0
    property bool isActive: false
    property bool collapsed: false
    property string tooltip: ""
    signal clicked()

    color: {
        if (isActive) return Theme.sidebarActiveBg
        if (mouseArea.containsMouse) return Theme.sidebarHover
        return "transparent"
    }

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        visible: isActive
        x: 0; y: (parent.height - 22) / 2
        width: 3; height: 22
        color: Theme.accentCopper
        radius: 1.5
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: collapsed ? (parent.width - 36) / 2 : Theme.spacingMd
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36
            radius: Theme.radiusSm
            color: isActive ? "#14FFFFFF" : "transparent"
            Text {
                anchors.centerIn: parent
                text: root.iconText
                color: isActive ? Theme.textSidebarActive : Theme.textSidebar
                font.pixelSize: 15
            }
        }
        Text {
            text: root.labelText
            color: isActive ? Theme.textSidebarActive : Theme.textSidebar
            font.pixelSize: Theme.fontSizeMd
            font.weight: isActive ? Font.DemiBold : Font.Normal
            visible: !root.collapsed
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }

    ToolTip {
        visible: mouseArea.containsMouse && root.collapsed && root.tooltip !== ""
        text: root.tooltip
        delay: 500
    }

    Accessible.name: root.tooltip || root.labelText
    Accessible.role: Accessible.MenuItem
    Accessible.selected: root.isActive
}
