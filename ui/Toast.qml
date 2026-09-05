import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string message: ""
    property string type: "info"
    visible: false

    width: Math.min(parent.width - 40, 400)
    height: 40
    radius: Theme.radiusSm
    color: type === "error" ? Theme.errorBg : type === "success" ? Theme.successBg : Theme.chipBg
    border.color: type === "error" ? Theme.errorText : type === "success" ? Theme.successText : Theme.divider
    border.width: 1
    anchors.horizontalCenter: parent.horizontalCenter
    y: visible ? 20 : -50
    z: 1000

    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Connections {
        target: Toast
        function onShowToast(msg, msgType) {
            root.message = msg
            root.type = msgType || "info"
            root.visible = true
            hideTimer.restart()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            text: type === "error" ? "\u26A0" : type === "success" ? "\u2714" : "\u2139"
            color: type === "error" ? Theme.errorText : type === "success" ? Theme.successText : Theme.textSecondary
            font.pixelSize: 14
        }

        Text {
            text: root.message
            color: type === "error" ? Theme.errorText : type === "success" ? Theme.successText : Theme.textPrimary
            font.pixelSize: Theme.fontSizeSm
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
    }

    Timer {
        id: hideTimer
        interval: 3000
        onTriggered: root.visible = false
    }

    function show(msg, msgType) {
        root.message = msg
        root.type = msgType || "info"
        root.visible = true
        hideTimer.restart()
    }

    Accessible.name: root.message
    Accessible.role: Accessible.Alert
}
