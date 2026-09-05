import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property bool isLoading: false

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isLoading
        message: "Computing..."
    }

    function parseNums(s) {
        var parts = s.split(",")
        var arr = []
        for (var i = 0; i < parts.length; i++) {
            var v = parseFloat(parts[i].trim())
            if (!isNaN(v)) arr.push(v)
        }
        return arr
    }

    function computeShape(shape, params) {
        var raw = MathStackBackend.shapeArea(JSON.stringify({ shape: shape, params: params }))
        var d = JSON.parse(raw)
        var result
        if (!d.ok) { result = "Error: " + d.error }
        else {
            result = shape.charAt(0).toUpperCase() + shape.slice(1) + ":\n" +
                "Area: " + d.area.toFixed(4) + "\n" +
                "Perimeter: " + d.perimeter.toFixed(4)
            if (d.volume !== undefined) {
                result += "\nVolume: " + d.volume.toFixed(4)
            }
        }
        if (shape === "circle") geomResultCircle.text = result
        else if (shape === "rectangle") geomResultRect.text = result
        else if (shape === "triangle") geomResultTri.text = result
    }

    function computeDistance() {
        var p1 = parseNums(p1Input.text)
        var p2 = parseNums(p2Input.text)
        if (p1.length < 2 || p2.length < 2) { geomResultDist.text = "Enter two coordinates for each point"; return }
        var raw = MathStackBackend.distance(JSON.stringify({ p1: p1, p2: p2 }))
        var d = JSON.parse(raw)
        if (!d.ok) { geomResultDist.text = "Error: " + d.error; return }
        geomResultDist.text = "Distance: " + d.distance.toFixed(4)
    }

    property var shapes3d: [
        { label: "Cube", type: "cube", params: { size: 2 } },
        { label: "Sphere", type: "sphere", params: { radius: 2 } },
        { label: "Cylinder", type: "cylinder", params: { radius: 1.5, height: 3 } },
        { label: "Cone", type: "cone", params: { radius: 1.5, height: 3 } },
        { label: "Torus", type: "torus", params: { major_radius: 2, minor_radius: 0.8 } },
        { label: "Pyramid", type: "pyramid", params: { base: 2, height: 2.5 } },
    ]

    property string currentShapeType: "cube"
    property var currentShapeParams: ({ size: 2 })
    property var shapeData: ({ vertices: [], faces: [], colors: [] })

    property real rotX: -0.6
    property real rotY: 0.8
    property real zoom: 1.0
    property real prevMX: 0
    property real prevMY: 0
    property bool dragging: false

    function selectShape(idx) {
        var s = shapes3d[idx]
        currentShapeType = s.type
        currentShapeParams = s.params
        var raw = PlotBackend.getShapeGeometry(s.type, JSON.stringify(s.params))
        shapeData = JSON.parse(raw)
        canvas3d.requestPaint()
    }

    function project3d(v, w, h) {
        var x = v[0], y = v[1], z = v[2]
        var rx = rotX, ry = rotY
        var cx = Math.cos(rx), sx = Math.sin(rx)
        var cy = Math.cos(ry), sy = Math.sin(ry)
        var yy = y * cx - z * sx
        var zz = y * sx + z * cx
        var xx = x * cy + zz * sy
        var depth = -x * sy + zz * cy
        var scale = Math.min(w, h) * 0.35 * root.zoom
        var d = 4
        var persp = d / (d + depth * 0.3)
        return {
            sx: w / 2 + xx * scale * persp,
            sy: h / 2 - yy * scale * persp,
            depth: depth
        }
    }

    function hexToRgba(hex, alpha) {
        hex = hex.replace("#", "")
        var r = parseInt(hex.substring(0,2), 16)
        var g = parseInt(hex.substring(2,4), 16)
        var b = parseInt(hex.substring(4,6), 16)
        return "rgba(" + r + "," + g + "," + b + "," + alpha + ")"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text {
                text: "Geometry"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.chipBg
                border.color: Theme.divider
                Text {
                    anchors.centerIn: parent
                    text: "\u2190 Back"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm - 1
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }
        }

        RowLayout {
            spacing: Theme.spacingXs
            Rectangle {
                Layout.preferredWidth: 110; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: shapeTab.currentIndex === 0 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "Circle"
                    color: shapeTab.currentIndex === 0 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: shapeTab.currentIndex = 0
                }
            }
            Rectangle {
                Layout.preferredWidth: 110; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: shapeTab.currentIndex === 1 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "Rectangle"
                    color: shapeTab.currentIndex === 1 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: shapeTab.currentIndex = 1
                }
            }
            Rectangle {
                Layout.preferredWidth: 110; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: shapeTab.currentIndex === 2 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "Triangle"
                    color: shapeTab.currentIndex === 2 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: shapeTab.currentIndex = 2
                }
            }
            Rectangle {
                Layout.preferredWidth: 110; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: shapeTab.currentIndex === 3 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "Distance"
                    color: shapeTab.currentIndex === 3 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: shapeTab.currentIndex = 3
                }
            }
            Rectangle {
                Layout.preferredWidth: 110; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: shapeTab.currentIndex === 4 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "3D Shapes"
                    color: shapeTab.currentIndex === 4 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: shapeTab.currentIndex = 4
                }
            }
        }

        SwipeView {
            id: shapeTab
            Layout.fillWidth: true
            Layout.fillHeight: true
            interactive: false
            clip: true

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    Text { text: "Circle Calculator"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }
                    Text { text: "Radius:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: circleR
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "5"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 30
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: "Compute"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: computeShape("circle", { radius: parseFloat(circleR.text) || 0 })
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: geomResultCircle.implicitHeight + Theme.spacingMd * 2
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider
                        visible: geomResultCircle.text !== ""

                        Text {
                            id: geomResultCircle
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    Text { text: "Rectangle Calculator"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }
                    Text { text: "Width:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: rectW
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "4"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Text { text: "Height:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: rectH
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "6"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 30
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: "Compute"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: computeShape("rectangle", { width: parseFloat(rectW.text) || 0, height: parseFloat(rectH.text) || 0 })
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: geomResultRect.implicitHeight + Theme.spacingMd * 2
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider
                        visible: geomResultRect.text !== ""

                        Text {
                            id: geomResultRect
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    Text { text: "Triangle Calculator (3 sides)"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }

                    RowLayout {
                        spacing: Theme.spacingSm
                        Text { text: "Side a:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 34
                            radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput {
                                id: triA
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                text: "3"
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                                verticalAlignment: TextInput.AlignVCenter
                            }
                        }
                    }
                    RowLayout {
                        spacing: Theme.spacingSm
                        Text { text: "Side b:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 34
                            radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput {
                                id: triB
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                text: "4"
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                                verticalAlignment: TextInput.AlignVCenter
                            }
                        }
                    }
                    RowLayout {
                        spacing: Theme.spacingSm
                        Text { text: "Side c:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 34
                            radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput {
                                id: triC
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                text: "5"
                                color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                                verticalAlignment: TextInput.AlignVCenter
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 30
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: "Compute"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: computeShape("triangle", { a: parseFloat(triA.text) || 0, b: parseFloat(triB.text) || 0, c: parseFloat(triC.text) || 0 })
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: geomResultTri.implicitHeight + Theme.spacingMd * 2
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider
                        visible: geomResultTri.text !== ""

                        Text {
                            id: geomResultTri
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    Text { text: "Distance Between Two Points"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }

                    Text { text: "Point 1 (x,y - comma separated):"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: p1Input
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "0,0"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Text { text: "Point 2 (x,y - comma separated):"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: p2Input
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "3,4"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 30
                        radius: Theme.radiusSm; color: Theme.accentCopper
                        Text {
                            anchors.centerIn: parent
                            text: "Compute"
                            color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: computeDistance()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: geomResultDist.implicitHeight + Theme.spacingMd * 2
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider
                        visible: geomResultDist.text !== ""

                        Text {
                            id: geomResultDist
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    RowLayout {
                        Text { text: "3D Shape Viewer"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs
                        Repeater {
                            model: root.shapes3d
                            Rectangle {
                                height: 28; width: label.width + 20
                                radius: Theme.radiusFull
                                color: root.currentShapeType === modelData.type ? Theme.accentCopper : Theme.chipBg
                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: root.currentShapeType === modelData.type ? "#ffffff" : Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectShape(index)
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#FFFFFF"
                        radius: Theme.radiusSm
                        border.color: Theme.divider
                        clip: true

                        Canvas {
                            id: canvas3d
                            anchors.fill: parent; anchors.margins: 2

                            onPaint: {
                                var ctx = getContext("2d")
                                var w = width, h = height
                                if (!w || !h) return
                                ctx.clearRect(0, 0, w, h)
                                ctx.fillStyle = Theme.canvasBg
                                ctx.fillRect(0, 0, w, h)

                                var data = root.shapeData
                                if (!data || !data.vertices || data.vertices.length === 0 || data.error) {
                                    ctx.fillStyle = Theme.placeholderText
                                    ctx.font = "13px Segoe UI"
                                    ctx.textAlign = "center"
                                    ctx.fillText("Select a shape above", w / 2, h / 2)
                                    ctx.textAlign = "left"
                                    return
                                }

                                var verts = data.vertices
                                var faces = data.faces
                                var colors = data.colors

                                // Project all vertices
                                var proj = []
                                for (var i = 0; i < verts.length; i++) {
                                    proj.push(root.project3d(verts[i], w, h))
                                }

                                // Build sorted face list
                                var faceList = []
                                for (var f = 0; f < faces.length; f++) {
                                    var tri = faces[f]
                                    var avgDepth = 0
                                    for (var k = 0; k < tri.length; k++) {
                                        avgDepth += proj[tri[k]].depth
                                    }
                                    avgDepth /= tri.length
                                    faceList.push({ idx: f, depth: avgDepth })
                                }

                                // Painter's algorithm: sort back to front
                                faceList.sort(function(a, b) { return b.depth - a.depth })

                                for (var fi = 0; fi < faceList.length; fi++) {
                                    var fIdx = faceList[fi].idx
                                    var tri = faces[fIdx]
                                    var color = colors[fIdx]
                                    ctx.fillStyle = root.hexToRgba(color, 0.85)
                                    ctx.strokeStyle = Theme.strokeColor
                                    ctx.lineWidth = 0.5
                                    ctx.beginPath()
                                    var p = proj[tri[0]]
                                    ctx.moveTo(p.sx, p.sy)
                                    for (var k = 1; k < tri.length; k++) {
                                        p = proj[tri[k]]
                                        ctx.lineTo(p.sx, p.sy)
                                    }
                                    ctx.closePath()
                                    ctx.fill()
                                    ctx.stroke()
                                }

                                ctx.fillStyle = Theme.hudText
                                ctx.font = "10px Segoe UI"
                                ctx.textAlign = "left"
                                ctx.fillText("Drag to rotate \u00B7 Scroll to zoom", 10, 16)
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.SizeAllCursor
                                onPressed: {
                                    root.prevMX = mouseX; root.prevMY = mouseY
                                    root.dragging = true
                                }
                                onReleased: root.dragging = false
                                onPositionChanged: {
                                    if (!root.dragging) return
                                    var dx = mouseX - root.prevMX
                                    var dy = mouseY - root.prevMY
                                    root.rotY += dx * 0.012
                                    root.rotX += dy * 0.012
                                    root.prevMX = mouseX; root.prevMY = mouseY
                                    canvas3d.requestPaint()
                                }
                            }

                            WheelHandler {
                                onWheel: function(event) {
                                    root.zoom = Math.max(0.3, Math.min(4.0, root.zoom + event.angleDelta.y * 0.001))
                                    canvas3d.requestPaint()
                                }
                            }
                        }
                    }

                    Text {
                        text: root.currentShapeType.charAt(0).toUpperCase() + root.currentShapeType.slice(1) +
                              " \u2014 Drag to rotate, scroll to zoom"
                        color: Theme.textMuted; font.pixelSize: Theme.fontSizeSm - 1
                    }
                }
            }
        }

        Component.onCompleted: {
            selectShape(0)
        }
    }
}

