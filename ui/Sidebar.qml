import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property bool collapsed: false
    property int activeIndex: 0
    signal pageRequested(int index)

    width: collapsed ? Theme.sidebarCollapsed : Theme.sidebarExpanded
    color: Theme.sidebarBg

    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingMd
        anchors.bottomMargin: Theme.spacingSm
        spacing: 0

        Item { Layout.preferredHeight: Theme.spacingSm }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52

            Rectangle {
                x: collapsed ? (parent.width - 38) / 2 : Theme.spacingMd
                y: (parent.height - 38) / 2
                width: 38; height: 38
                radius: Theme.radiusSm
                color: Theme.accentCopper
                Text {
                    anchors.centerIn: parent
                    text: "\u0628"
                    color: "#ffffff"
                    font.pixelSize: 17
                    font.weight: Font.Bold
                }
            }
            Text {
                visible: !collapsed
                x: Theme.spacingMd + 38 + 12
                y: (parent.height - height) / 2
                text: "AlBab"
                color: Theme.textSidebarActive
                font.pixelSize: 17
                font.weight: Font.Bold
            }
        }

        Item { Layout.preferredHeight: Theme.spacingXl }

        Repeater {
            model: [
                { icon: "\u2302", label: "Home", idx: 0, tip: "Home dashboard" },
                { icon: "\u2709", label: "AI Chat", idx: 1, tip: "AI Chat assistant" },
                { icon: "\u2692", label: "Tools", idx: 2, tip: "Productivity tools" },
                { icon: "\u2630", label: "Settings", idx: 3, tip: "Settings and profile" },
            ]
            delegate: SidebarItem {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                iconText: modelData.icon
                labelText: modelData.label
                itemIndex: modelData.idx
                isActive: activeIndex === modelData.idx
                collapsed: root.collapsed
                tooltip: modelData.tip
                onClicked: {
                    activeIndex = modelData.idx
                    pageRequested(modelData.idx)
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: Theme.spacingMd
            Layout.rightMargin: Theme.spacingMd
            color: "#20FFFFFF"
        }
        Item { Layout.preferredHeight: Theme.spacingXs }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Rectangle {
                width: 28; height: 28
                x: collapsed ? (parent.width - width) / 2 : Theme.spacingMd
                y: (parent.height - height) / 2
                radius: Theme.radiusSm
                color: "#0AFFFFFF"
                Text {
                    anchors.centerIn: parent
                    text: collapsed ? "\u276F" : "\u276E"
                    color: "#4DFFFFFF"
                    font.pixelSize: 11
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: parent.color = "#1AFFFFFF"
                    onExited: parent.color = "#0AFFFFFF"
                    onClicked: collapsed = !collapsed
                }
                Accessible.name: collapsed ? "Expand sidebar" : "Collapse sidebar"
                Accessible.role: Accessible.Button
            }
        }
        Item { Layout.preferredHeight: Theme.spacingSm }
    }
}
