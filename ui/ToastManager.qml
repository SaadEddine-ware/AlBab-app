pragma Singleton
import QtQuick

QtObject {
    id: manager

    property string message: ""
    property string type: "info"
    property bool active: false

    signal showToast(string msg, string msgType)

    function show(msg, msgType) {
        message = msg
        type = msgType || "info"
        active = true
        showToast(msg, type)
    }
}
