import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property int mode3d: 0
    property string plotUrl: ""
    property bool isPlotting: false
    property real rotX: -60
    property real rotY: 45
    property real plotZoom: 1.0
    property real prevMX: 0
    property real prevMY: 0
    property bool dragging: false
    property string currentExpr: "sin(x)"
    property var surfaceData: null

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isPlotting
        message: "Computing..."
    }

    property var examples2d: [
        { label: "sin(x)", expr: "sin(x)" },
        { label: "cos(x)", expr: "cos(x)" },
        { label: "tan(x)", expr: "tan(x)" },
        { label: "x^2", expr: "x^2" },
        { label: "x^3", expr: "x^3" },
        { label: "sqrt(x)", expr: "sqrt(x)" },
        { label: "|x|", expr: "abs(x)" },
        { label: "1/x", expr: "1/x" },
        { label: "sin(x)/x", expr: "sin(x)/x" },
        { label: "e^(-x^2)", expr: "exp(-x^2)" },
        { label: "sin(1/x)", expr: "sin(1/x)" },
        { label: "x*sin(x)", expr: "x*sin(x)" },
        { label: "sin(x^2)", expr: "sin(x^2)" },
        { label: "x^3 - 3*x", expr: "x^3 - 3*x" },
        { label: "2^x", expr: "2^x" },
        { label: "log(x)", expr: "log(x)" },
        { label: "ln(x)", expr: "ln(x)" },
        { label: "ceil(x)", expr: "ceil(x)" },
        { label: "floor(x)", expr: "floor(x)" },
    ]

    property var examples3d: [
        { label: "Wave", expr: "sin(sqrt(x^2 + y^2))" },
        { label: "Paraboloid", expr: "x^2 + y^2" },
        { label: "Saddle", expr: "x^2 - y^2" },
        { label: "Ripple", expr: "sin(x)*cos(y)" },
        { label: "Cone", expr: "sqrt(x^2 + y^2)" },
        { label: "Twin Peaks", expr: "exp(-(x^2 + y^2)/4)*sin(x)*cos(y)" },
        { label: "Waves", expr: "cos(x) + sin(y)" },
        { label: "Sombrero", expr: "sin(sqrt(x^2 + y^2))/sqrt(x^2 + y^2 + 0.01)" },
        { label: "Roller", expr: "sin(x) + 0.5*y" },
        { label: "Dome", expr: "sqrt(max(4 - x^2 - y^2, 0))" },
    ]

    function loadExample(expr) {
        currentExpr = expr
        funcInput.text = expr
        plot()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text {
                text: mode3d ? "3D Graph Plotter" : "2D Graph Plotter"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                Text { anchors.centerIn: parent; text: "\u2190 Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                Accessible.name: "Back to tools"; Accessible.role: Accessible.Button
            }
        }

        RowLayout {
            spacing: Theme.spacingSm
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34
                radius: Theme.radiusFull; color: Theme.inputBg; border.color: funcInput.activeFocus ? Theme.accentCopper : Theme.divider
                border.width: funcInput.activeFocus ? 1.5 : 1
                TextInput {
                    id: funcInput
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                    text: root.currentExpr
                    color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.family: Theme.fontMono
                    verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                    onAccepted: { root.currentExpr = text; plot() }
                }
            }
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 34; radius: Theme.radiusSm; color: Theme.accentCopper
                Text { anchors.centerIn: parent; text: "\u25B6"; color: "#ffffff"; font.pixelSize: 14 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.currentExpr = funcInput.text; plot() } }
            }
            Rectangle {
                Layout.preferredWidth: 46; Layout.preferredHeight: 34; radius: Theme.radiusSm
                color: !mode3d ? Theme.accentCopper : Theme.chipBg
                Text { anchors.centerIn: parent; text: "2D"; color: !mode3d ? "#ffffff" : Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { mode3d = 0; surfaceData = null; plot() } }
            }
            Rectangle {
                Layout.preferredWidth: 46; Layout.preferredHeight: 34; radius: Theme.radiusSm
                color: mode3d ? Theme.accentCopper : Theme.chipBg
                Text { anchors.centerIn: parent; text: "3D"; color: mode3d ? "#ffffff" : Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { mode3d = 1; surfaceData = null; plot() } }
            }
        }

        Flow {
            Layout.fillWidth: true; spacing: 4
            Repeater {
                model: mode3d ? root.examples3d : root.examples2d
                Rectangle {
                    height: 24; width: exampleLabel.width + 14; radius: Theme.radiusFull
                    color: Theme.chipBg
                    border.color: root.currentExpr === modelData.expr ? Theme.accentCopper : "transparent"
                    border.width: root.currentExpr === modelData.expr ? 1.5 : 0
                    Text { id: exampleLabel; anchors.centerIn: parent; text: modelData.label; color: root.currentExpr === modelData.expr ? Theme.accentCopperDark : Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loadExample(modelData.expr) }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: Theme.contentBg; radius: Theme.radiusSm; border.color: Theme.divider; clip: true

            Image {
                id: plotImage
                anchors.fill: parent; anchors.margins: 4
                fillMode: Image.PreserveAspectFit
                source: root.plotUrl
                visible: root.plotUrl !== "" && !root.isPlotting && root.mode3d === 0
            }

            Canvas {
                id: canvas3d
                anchors.fill: parent
                visible: root.mode3d === 1 && !root.isPlotting

                onPaint: {
                    if (!root.surfaceData) return
                    var ctx = getContext("2d")
                    var w = width, h = height
                    ctx.clearRect(0, 0, w, h)
                    drawSurface(ctx, w, h)
                }

                function drawSurface(ctx, w, h) {
                    var data = root.surfaceData
                    if (!data || !data.xs || !data.zs || data.xs.length === 0) return

                    var xs = data.xs
                    var zs = data.zs
                    var rows = zs.length
                    var cols = zs[0].length
                    var scale = Math.min(w, h) * 0.35 * root.plotZoom

                    var cx = Math.cos(root.rotX * 0.0175), sx = Math.sin(root.rotX * 0.0175)
                    var cy = Math.cos(root.rotY * 0.0175), sy = Math.sin(root.rotY * 0.0175)

                    var projected = []
                    for (var j = 0; j < rows; j++) {
                        projected[j] = []
                        for (var i = 0; i < cols; i++) {
                            var x = (xs[i] || 0) * 0.5
                            var y = (j / rows - 0.5) * 2
                            var z = (zs[j][i] || 0) * 0.3
                            if (isNaN(z) || !isFinite(z)) z = 0

                            var yy = y * cx - z * sx
                            var zz = y * sx + z * cx
                            var xx = x * cy + zz * sy
                            var depth = -x * sy + zz * cy

                            projected[j][i] = {
                                sx: w / 2 + xx * scale,
                                sy: h / 2 - yy * scale,
                                depth: depth,
                                z: z
                            }
                        }
                    }

                    var faces = []
                    for (var j = 0; j < rows - 1; j++) {
                        for (var i = 0; i < cols - 1; i++) {
                            var p1 = projected[j][i]
                            var p2 = projected[j][i + 1]
                            var p3 = projected[j + 1][i + 1]
                            var p4 = projected[j + 1][i]
                            var avgDepth = (p1.depth + p2.depth + p3.depth + p4.depth) / 4
                            var avgZ = (p1.z + p2.z + p3.z + p4.z) / 4
                            faces.push({ p1: p1, p2: p2, p3: p3, p4: p4, depth: avgDepth, z: avgZ })
                        }
                    }

                    faces.sort(function(a, b) { return b.depth - a.depth })

                    for (var f = 0; f < faces.length; f++) {
                        var face = faces[f]
                        var shade = 0.3 + 0.7 * ((face.z + 1.5) / 3)
                        shade = Math.max(0.1, Math.min(1.0, shade))

                        var r = Math.floor(shade * 180)
                        var g = Math.floor(shade * 100 + 80)
                        var b = Math.floor(shade * 220)

                        ctx.fillStyle = "rgb(" + r + "," + g + "," + b + ")"
                        ctx.strokeStyle = "rgba(0,0,0,0.1)"
                        ctx.lineWidth = 0.5

                        ctx.beginPath()
                        ctx.moveTo(face.p1.sx, face.p1.sy)
                        ctx.lineTo(face.p2.sx, face.p2.sy)
                        ctx.lineTo(face.p3.sx, face.p3.sy)
                        ctx.lineTo(face.p4.sx, face.p4.sy)
                        ctx.closePath()
                        ctx.fill()
                        ctx.stroke()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    onPressed: { root.prevMX = mouseX; root.prevMY = mouseY; root.dragging = true }
                    onReleased: root.dragging = false
                    onPositionChanged: {
                        if (!root.dragging) return
                        root.rotY += (mouseX - root.prevMX) * 0.5
                        root.rotX += (mouseY - root.prevMY) * 0.3
                        root.rotX = Math.max(-89, Math.min(89, root.rotX))
                        root.prevMX = mouseX; root.prevMY = mouseY
                        canvas3d.requestPaint()
                    }
                }

                WheelHandler {
                    onWheel: function(event) {
                        root.plotZoom = Math.max(0.3, Math.min(3.0, root.plotZoom + event.angleDelta.y * 0.001))
                        canvas3d.requestPaint()
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "Enter a function and click \u25B6"
                color: Theme.placeholderText
                font.pixelSize: Theme.fontSizeMd
                visible: root.plotUrl === "" && !root.isPlotting && root.mode3d === 0
            }

            Rectangle {
                anchors.centerIn: parent
                width: 120; height: 32; radius: Theme.radiusSm
                color: Theme.inputBg; border.color: Theme.divider
                visible: root.isPlotting
                RowLayout {
                    anchors.centerIn: parent; spacing: 8
                    Rectangle {
                        width: 8; height: 8; radius: 4; color: Theme.accentCopper
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    Text { text: "Computing..."; color: Theme.textMuted; font.pixelSize: Theme.fontSizeSm }
                }
            }
        }

        RowLayout {
            spacing: Theme.spacingSm
            Text {
                text: (mode3d ? "z = " : "f(x) = ") + root.currentExpr
                color: Theme.textMuted; font.pixelSize: Theme.fontSizeXs; font.family: Theme.fontMono
                Layout.fillWidth: true
            }
            Rectangle {
                visible: root.plotUrl !== "" && root.mode3d === 0
                Layout.preferredWidth: 60; Layout.preferredHeight: 22
                radius: Theme.radiusSm; color: Theme.accentCopper
                Text { anchors.centerIn: parent; text: "Export PDF"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.onExport() }
                Accessible.name: "Export graph as PDF"
                Accessible.role: Accessible.Button
            }
        }

        Text {
            visible: root.mode3d === 1 && root.surfaceData !== null
            text: "Drag to rotate \u00B7 Scroll to zoom"
            color: Theme.placeholderText; font.pixelSize: Theme.fontSizeXs
            Layout.alignment: Qt.AlignHCenter
        }
    }

    function onNew() { currentExpr = "sin(x)"; funcInput.text = "sin(x)"; plotUrl = ""; surfaceData = null; plot() }
    function onExport() {
        if (root.plotUrl === "" || root.mode3d !== 0) return
        var path = ExportBackend.getExportPath("graph_" + root.currentExpr.replace(/[^a-zA-Z0-9]/g, "_") + ".pdf")
        var ok = PlotBackend.exportPdf(root.currentExpr, path)
        if (ok) Toast.show("PDF saved to: " + path)
    }

    function plot() {
        root.currentExpr = funcInput.text
        if (mode3d === 0) {
            root.isPlotting = true
            delayPlot2d.start()
        } else {
            root.isPlotting = true
            root.rotX = -60
            root.rotY = 45
            root.plotZoom = 1.0
            delayCompute3d.start()
        }
    }

    Timer {
        id: delayPlot2d
        interval: 50
        onTriggered: {
            root.plotUrl = PlotBackend.plot2d(root.currentExpr)
            root.isPlotting = false
        }
    }

    Timer {
        id: delayCompute3d
        interval: 50
        onTriggered: {
            var raw = PlotBackend.computeSurface(root.currentExpr, -5, 5, -5, 5, 40)
            root.surfaceData = JSON.parse(raw)
            root.isPlotting = false
            canvas3d.requestPaint()
        }
    }

    Connections {
        target: typeof PlotBackend !== 'undefined' ? PlotBackend : null
        ignoreUnknownSignals: true
        function onPlotUpdated(url) { root.plotUrl = url }
    }

    Component.onCompleted: { if (typeof PlotBackend !== 'undefined') plot() }
}

