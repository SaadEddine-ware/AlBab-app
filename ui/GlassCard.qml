import QtQuick

Rectangle {
    id: root

    property alias contentChildren: content.children
    property int cardRadius: Theme.radiusLg
    property real glassOpacity: 0.60
    property bool hoverable: false
    property bool cardHovered: false

    color: Theme.glassBase
    border.color: cardHovered ? "#E6FFFFFF" : Theme.glassBorder
    border.width: 1
    radius: cardRadius

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        radius: parent.radius
        color: Theme.shadowLight
        z: -1
    }

    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 200 } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: Theme.glassHover
        border.width: 1
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: root.hoverable
        onEntered: root.cardHovered = true
        onExited: root.cardHovered = false
        propagateComposedEvents: true
        onClicked: (m) => m.accepted = false
        onPressed: (m) => m.accepted = false
        onReleased: (m) => m.accepted = false
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
    }

    Accessible.name: "Card"
    Accessible.role: Accessible.Grouping
}
