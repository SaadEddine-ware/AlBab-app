import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win
    width: 400; height: 300; visible: true
    title: "MathEngine Test"
    color: "#F5F0EB"

    property string result: "?"

    Component.onCompleted: {
        if (typeof MathEngine !== "undefined") {
            win.result = MathEngine.evaluate("2+2")
            win.title = "Result: " + win.result
        } else {
            win.result = "NOT FOUND"
        }
    }
}
