import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root
    signal back()

    // ---- State ----
    property int editMode: 0          // 0 = Object, 1 = Edit
    property int selSubMode: 2        // 0 = Vertex, 1 = Edge, 2 = Face
    property string selObjId: ""
    property var selFaces: []
    property var selVerts: []
    property var selEdges: []
    property var sceneData: ({"objects": []})
    property var wcVerts: ({})        // objectId -> world-space vertices cache
    property var wcEdges: ({})        // objectId -> edges list cache
    property bool sceneDirty: true

    // Viewport controls
    property real rotX: -0.6
    property real rotY: 0.8
    property real zoom: 1.0
    property real prevMX: 0
    property real prevMY: 0
    property bool dragging: false

    // ---- Helper: transform vertex by pos/rot/scale ----
    function xfVertex(v, pos, rot, scale) {
        var rx = rot[0], ry = rot[1], rz = rot[2]
        var cx = Math.cos(rx), sx = Math.sin(rx)
        var cy = Math.cos(ry), sy = Math.sin(ry)
        var cz = Math.cos(rz), sz = Math.sin(rz)

        var x = v[0] * scale[0]
        var y = v[1] * scale[1]
        var z = v[2] * scale[2]

        var r00 = cy * cz
        var r01 = cz * sx * sy - cx * sz
        var r02 = sx * sz + cx * cz * sy
        var r10 = cy * sz
        var r11 = cx * cz + sx * sy * sz
        var r12 = cx * sy * sz - cz * sx
        var r20 = -sy
        var r21 = cy * sx
        var r22 = cx * cy

        return [
            x * r00 + y * r01 + z * r02 + pos[0],
            x * r10 + y * r11 + z * r12 + pos[1],
            x * r20 + y * r21 + z * r22 + pos[2]
        ]
    }

    function xfVerts(verts, pos, rot, scale) {
        var out = []
        for (var i = 0; i < verts.length; i++)
            out.push(xfVertex(verts[i], pos, rot, scale))
        return out
    }

    // ---- Helper: build edges from faces ----
    function buildEdges(faces) {
        var edgeMap = {}
        for (var f = 0; f < faces.length; f++) {
            var tri = faces[f]
            for (var k = 0; k < tri.length; k++) {
                var a = tri[k]
                var b = tri[(k + 1) % tri.length]
                var key = a < b ? a + "_" + b : b + "_" + a
                edgeMap[key] = [a, b]
            }
        }
        var arr = []
        for (var k in edgeMap) arr.push(edgeMap[k])
        return arr
    }

    // ---- Helper: hex to rgba ----
    function hexToRgba(hex, alpha) {
        hex = hex.replace("#", "")
        var r = parseInt(hex.substring(0, 2), 16)
        var g = parseInt(hex.substring(2, 4), 16)
        var b = parseInt(hex.substring(4, 6), 16)
        return "rgba(" + r + "," + g + "," + b + "," + alpha + ")"
    }

    // ---- 3D projection ----
    function project3d(v, w, h) {
        var x = v[0], y = v[1], z = v[2]
        var cx = Math.cos(rotX), sx = Math.sin(rotX)
        var cy = Math.cos(rotY), sy = Math.sin(rotY)

        var yy = y * cx - z * sx
        var zz = y * sx + z * cx
        var xx = x * cy + zz * sy
        var depth = -x * sy + zz * cy
        var scale = Math.min(w, h) * 0.35 * zoom
        var d = 4
        var persp = d / (d + depth * 0.3)
        return {
            sx: w / 2 + xx * scale * persp,
            sy: h / 2 - yy * scale * persp,
            depth: depth
        }
    }

    // ---- Refresh scene from backend ----
    function refreshScene() {
        var raw = MeshBackend.getSceneJson()
        sceneData = JSON.parse(raw)
        // Rebuild world-space caches
        var wc = {}
        var ec = {}
        for (var i = 0; i < sceneData.objects.length; i++) {
            var obj = sceneData.objects[i]
            var tf = obj.transform
            var pos = tf.position
            var rot = tf.rotation
            var scale = tf.scale
            wc[obj.id] = xfVerts(obj.mesh.vertices, pos, rot, scale)
            ec[obj.id] = buildEdges(obj.mesh.faces)
        }
        wcVerts = wc
        wcEdges = ec
        sceneDirty = false
        canvas.requestPaint()
    }

    // ---- Undo/Redo ----
    function pushUndo() {
        UndoManager.push(JSON.stringify(sceneData))
    }

    function meshUndo() {
        var state = UndoManager.undo()
        if (state) {
            sceneData = JSON.parse(state)
            refreshScene()
        }
    }

    function meshRedo() {
        var state = UndoManager.redo()
        if (state) {
            sceneData = JSON.parse(state)
            refreshScene()
        }
    }

    // ---- Scene operations ----
    function addPrimitive(type) {
        pushUndo()
        var raw = MeshBackend.addPrimitive(type, JSON.stringify({type: type}))
        sceneData = JSON.parse(raw)
        sceneDirty = true
        refreshScene()
    }

    function deleteSelected() {
        if (!selObjId) return
        pushUndo()
        var raw = MeshBackend.removeObject(selObjId)
        sceneData = JSON.parse(raw)
        selObjId = ""
        selFaces = []; selVerts = []; selEdges = []
        sceneDirty = true
        refreshScene()
    }

    function duplicateSelected() {
        if (!selObjId) return
        pushUndo()
        var raw = MeshBackend.duplicateObject(selObjId)
        sceneData = JSON.parse(raw)
        sceneDirty = true
        refreshScene()
    }

    function updatePosition(oid, x, y, z) {
        pushUndo()
        var raw = MeshBackend.setObjectPosition(oid, x, y, z)
        sceneData = JSON.parse(raw)
        sceneDirty = true
        refreshScene()
    }

    function updateRotation(oid, x, y, z) {
        pushUndo()
        var raw = MeshBackend.setObjectRotation(oid, x, y, z)
        sceneData = JSON.parse(raw)
        sceneDirty = true
        refreshScene()
    }

    function updateScale(oid, sx, sy, sz) {
        pushUndo()
        var raw = MeshBackend.setObjectScale(oid, sx, sy, sz)
        sceneData = JSON.parse(raw)
        sceneDirty = true
        refreshScene()
    }

    function updateColor(oid, hex) {
        var raw = MeshBackend.setObjectColor(oid, hex)
        sceneData = JSON.parse(raw)
        refreshScene()
    }

    // ---- Edit mode operations ----
    function extrudeSelectedFace(dist) {
        if (!selObjId || selFaces.length === 0) return
        pushUndo()
        var raw = MeshBackend.extrudeFace(selObjId, selFaces[0], dist)
        sceneData = JSON.parse(raw)
        selFaces = []
        sceneDirty = true
        refreshScene()
    }

    function subdivideSelected() {
        if (!selObjId) return
        pushUndo()
        var raw = MeshBackend.subdivideObject(selObjId, 1)
        sceneData = JSON.parse(raw)
        sceneDirty = true
        refreshScene()
    }

    function deleteSelectedFaces() {
        if (!selObjId || selFaces.length === 0) return
        pushUndo()
        var raw = MeshBackend.deleteFaces(selObjId, JSON.stringify(selFaces))
        sceneData = JSON.parse(raw)
        selFaces = []
        sceneDirty = true
        refreshScene()
    }

    function weldSelected() {
        if (!selObjId) return
        pushUndo()
        var raw = MeshBackend.weldVertices(selObjId, 0.05)
        sceneData = JSON.parse(raw)
        selVerts = []; selEdges = []; selFaces = []
        sceneDirty = true
        refreshScene()
    }

    // ---- Canvas click handling ----
    function onCanvasClick(mx, my) {
        var cw = canvas.width, ch = canvas.height
        if (!cw || !ch) return

        if (editMode === 0) {
            // Object mode: ray pick
            var ro = JSON.stringify([0, 0, 10])
            // Un-project mouse to ray direction
            var rd = JSON.stringify([(mx - cw / 2) / (Math.min(cw, ch) * 0.35 * zoom),
                                      (ch / 2 - my) / (Math.min(cw, ch) * 0.35 * zoom),
                                      -10])
            var raw = MeshBackend.rayPick(JSON.stringify(sceneData), ro, rd)
            var hit = JSON.parse(raw)
            if (hit.hit) {
                selObjId = hit.objectId
                selFaces = []; selVerts = []; selEdges = []
                canvas.requestPaint()
            }
        } else if (editMode === 1 && selObjId) {
            // Edit mode: find closest element
            var obj = null
            for (var i = 0; i < sceneData.objects.length; i++) {
                if (sceneData.objects[i].id === selObjId) {
                    obj = sceneData.objects[i]
                    break
                }
            }
            if (!obj) return

            var wv = wcVerts[selObjId]
            if (!wv) return

            var proj = []
            for (var vi = 0; vi < wv.length; vi++)
                proj.push(project3d(wv[vi], cw, ch))

            var threshold = 12

            if (selSubMode === 0) {
                // Vertex mode: find closest vertex
                var bestDist = threshold * threshold
                var bestIdx = -1
                for (vi = 0; vi < proj.length; vi++) {
                    var dx = proj[vi].sx - mx
                    var dy = proj[vi].sy - my
                    var d2 = dx * dx + dy * dy
                    if (d2 < bestDist) {
                        bestDist = d2
                        bestIdx = vi
                    }
                }
                if (bestIdx >= 0) {
                    var idx = selVerts.indexOf(bestIdx)
                    if (idx >= 0) selVerts.splice(idx, 1)
                    else selVerts.push(bestIdx)
                }
            } else if (selSubMode === 1) {
                // Edge mode: find closest edge
                var edges = wcEdges[selObjId]
                if (!edges) return
                bestDist = threshold * threshold
                bestIdx = -1
                for (var ei = 0; ei < edges.length; ei++) {
                    var a = edges[ei][0], b = edges[ei][1]
                    var p1 = proj[a], p2 = proj[b]
                    var ex = p2.sx - p1.sx, ey = p2.sy - p1.sy
                    var elen2 = ex * ex + ey * ey
                    var t = ((mx - p1.sx) * ex + (my - p1.sy) * ey) / (elen2 || 1)
                    t = Math.max(0, Math.min(1, t))
                    var cx = p1.sx + t * ex, cy = p1.sy + t * ey
                    dx = cx - mx; dy = cy - my
                    d2 = dx * dx + dy * dy
                    if (d2 < bestDist) {
                        bestDist = d2
                        bestIdx = ei
                    }
                }
                if (bestIdx >= 0) {
                    idx = selEdges.indexOf(bestIdx)
                    if (idx >= 0) selEdges.splice(idx, 1)
                    else selEdges.push(bestIdx)
                }
            } else {
                // Face mode: ray pick on selected object
                ro = JSON.stringify([0, 0, 10])
                rd = JSON.stringify([(mx - cw / 2) / (Math.min(cw, ch) * 0.35 * zoom),
                                      (ch / 2 - my) / (Math.min(cw, ch) * 0.35 * zoom),
                                      -10])
                raw = MeshBackend.rayPick(JSON.stringify({
                    objects: [obj]
                }), ro, rd)
                hit = JSON.parse(raw)
                if (hit.hit) {
                    var fi = hit.faceIndex
                    idx = selFaces.indexOf(fi)
                    if (idx >= 0) selFaces.splice(idx, 1)
                    else selFaces.push(fi)
                }
            }
            canvas.requestPaint()
        }
    }

    // ---- Canvas rendering ----
    function doPaint(ctx, cw, ch) {
        if (!cw || !ch) return
        ctx.clearRect(0, 0, cw, ch)
        ctx.fillStyle = Theme.canvasBg
        ctx.fillRect(0, 0, cw, ch)

        var objects = sceneData.objects

        if (editMode === 0) {
            // Object mode: render all visible objects
            renderObjects(ctx, cw, ch, objects, false)
        } else if (selObjId) {
            // Edit mode: render selected object only with wireframe
            for (var i = 0; i < objects.length; i++) {
                if (objects[i].id === selObjId) {
                    renderEditMode(ctx, cw, ch, objects[i])
                    break
                }
            }
        }

        // HUD
        ctx.fillStyle = Theme.hudText
        ctx.font = "10px Segoe UI"
        ctx.textAlign = "left"
        ctx.fillText("Drag to rotate \u00B7 Scroll to zoom \u00B7 Click to select", 10, 16)
    }

    function renderObjects(ctx, cw, ch, objects, editOnly) {
        var allFaces = []
        for (var oi = 0; oi < objects.length; oi++) {
            var obj = objects[oi]
            if (!obj.visible) continue
            if (editOnly && obj.id !== selObjId) continue

            var wv = wcVerts[obj.id]
            if (!wv) continue
            var faces = obj.mesh.faces

            var proj = []
            for (var vi = 0; vi < wv.length; vi++)
                proj.push(project3d(wv[vi], cw, ch))

            for (var fi = 0; fi < faces.length; fi++) {
                var tri = faces[fi]
                var avgDepth = 0
                for (var k = 0; k < tri.length; k++)
                    avgDepth += proj[tri[k]].depth
                avgDepth /= tri.length
                allFaces.push({
                    objIdx: oi, faceIdx: fi, depth: avgDepth,
                    proj: tri.map(function(idx) { return proj[idx] })
                })
            }
        }

        allFaces.sort(function(a, b) { return b.depth - a.depth })

        for (var fi = 0; fi < allFaces.length; fi++) {
            var f = allFaces[fi]
            var obj = objects[f.objIdx]
            var tri = obj.mesh.faces[f.faceIdx]
            var color = obj.color
            var isSelected = (editMode === 0 && obj.id === selObjId) ||
                             (editMode === 1 && obj.id === selObjId && selFaces.indexOf(f.faceIdx) >= 0)

            ctx.fillStyle = hexToRgba(color, isSelected ? 0.5 : 0.85)
            ctx.strokeStyle = isSelected ? Theme.selectHighlight : Theme.strokeColor
            ctx.lineWidth = isSelected ? 2 : 0.5
            ctx.beginPath()
            var p = f.proj[0]
            ctx.moveTo(p.sx, p.sy)
            for (var k = 1; k < f.proj.length; k++) {
                p = f.proj[k]
                ctx.lineTo(p.sx, p.sy)
            }
            ctx.closePath()
            ctx.fill()
            ctx.stroke()
        }
    }

    function renderEditMode(ctx, cw, ch, obj) {
        // Render faces semi-transparent first
        var wv = wcVerts[obj.id]
        if (!wv) return
        var faces = obj.mesh.faces
        var color = obj.color

        var proj = []
        for (var vi = 0; vi < wv.length; vi++)
            proj.push(project3d(wv[vi], cw, ch))

        var allFaces = []
        for (var fi = 0; fi < faces.length; fi++) {
            var tri = faces[fi]
            var avgDepth = 0
            for (var k = 0; k < tri.length; k++)
                avgDepth += proj[tri[k]].depth
            avgDepth /= tri.length
            allFaces.push({ fi: fi, depth: avgDepth, tri: tri })
        }
        allFaces.sort(function(a, b) { return b.depth - a.depth })

        // Draw faces
        for (var fi = 0; fi < allFaces.length; fi++) {
            var f = allFaces[fi]
            var sel = selFaces.indexOf(f.fi) >= 0
            ctx.fillStyle = hexToRgba(color, sel ? 0.5 : 0.35)
            ctx.strokeStyle = sel ? Theme.selectHighlight : Theme.wireframeNormal
            ctx.lineWidth = sel ? 2 : 0.5
            ctx.beginPath()
            var p = proj[f.tri[0]]
            ctx.moveTo(p.sx, p.sy)
            for (var k = 1; k < f.tri.length; k++) {
                p = proj[f.tri[k]]
                ctx.lineTo(p.sx, p.sy)
            }
            ctx.closePath()
            ctx.fill()
            ctx.stroke()
        }

        // Draw edges
        var edges = wcEdges[obj.id]
        if (edges) {
            for (var ei = 0; ei < edges.length; ei++) {
                var sel = selEdges.indexOf(ei) >= 0
                var a = proj[edges[ei][0]], b = proj[edges[ei][1]]
                ctx.strokeStyle = sel ? Theme.selectHighlight : Theme.wireframeNormal
                ctx.lineWidth = sel ? 3 : 1
                ctx.beginPath()
                ctx.moveTo(a.sx, a.sy)
                ctx.lineTo(b.sx, b.sy)
                ctx.stroke()
            }
        }

        // Draw vertices
        for (var vi = 0; vi < proj.length; vi++) {
            var sel = selVerts.indexOf(vi) >= 0
            var r = sel ? 5 : 3
            ctx.fillStyle = sel ? Theme.selectHighlight : Theme.wireframeNormal
            ctx.beginPath()
            ctx.arc(proj[vi].sx, proj[vi].sy, r, 0, Math.PI * 2)
            ctx.fill()
            if (sel) {
                ctx.strokeStyle = "#FFFFFF"
                ctx.lineWidth = 1.5
                ctx.stroke()
            }
        }
    }

    // ---- Init ----
    Component.onCompleted: { if (typeof MeshBackend !== 'undefined') refreshScene() }

    // ---- UI Layout ----
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        // ---- Header ----
        RowLayout {
            Text {
                text: "3D Creator"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLg
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }

            // Mode selector
            Rectangle {
                Layout.preferredWidth: 110; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.chipBg
                RowLayout {
                    anchors.fill: parent; anchors.margins: 2; spacing: 2
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: Theme.radiusSm - 1
                        color: editMode === 0 ? Theme.accentCopper : "#00000000"
                        Text {
                            anchors.centerIn: parent
                            text: "Object"
                            color: editMode === 0 ? "#ffffff" : Theme.textSecondary
                            font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { editMode = 0; canvas.requestPaint() }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: Theme.radiusSm - 1
                        color: editMode === 1 ? Theme.accentCopper : "#00000000"
                        Text {
                            anchors.centerIn: parent
                            text: "Edit"
                            color: editMode === 1 ? "#ffffff" : Theme.textSecondary
                            font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { editMode = 1; selFaces = []; selVerts = []; selEdges = []; canvas.requestPaint() }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: UndoManager.canUndo() ? Theme.chipBg : "transparent"
                Text { anchors.centerIn: parent; text: "\u21A9"; color: UndoManager.canUndo() ? Theme.textPrimary : Theme.textMuted; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: UndoManager.canUndo() ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: meshUndo() }
                Accessible.name: "Undo"
                Accessible.role: Accessible.Button
            }
            Rectangle {
                Layout.preferredWidth: 28; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: UndoManager.canRedo() ? Theme.chipBg : "transparent"
                Text { anchors.centerIn: parent; text: "\u21AA"; color: UndoManager.canRedo() ? Theme.textPrimary : Theme.textMuted; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: UndoManager.canRedo() ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: meshRedo() }
                Accessible.name: "Redo"
                Accessible.role: Accessible.Button
            }

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

        // ---- Main body ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingMd

            // ---- Left: Outliner ----
            Rectangle {
                Layout.preferredWidth: 160
                Layout.fillHeight: true
                radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingSm
                    spacing: Theme.spacingXs

                    Text {
                        text: "Objects"; color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: Theme.radiusSm - 2; color: Theme.pageBg; clip: true
                        ListView {
                            id: objList
                            anchors.fill: parent; anchors.margins: 2
                            model: sceneData.objects
                            spacing: 1
                            currentIndex: -1
                            delegate: Rectangle {
                                width: objList.width - 4; height: 26
                                radius: 3
                                color: modelData.id === selObjId ? Theme.accentCopper : "#00000000"
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 4
                                    spacing: 4
                                    Rectangle {
                                        width: 10; height: 10; radius: 2
                                        color: modelData.color
                                    }
                                    Text {
                                        text: modelData.name
                                        color: modelData.id === selObjId ? "#ffffff" : Theme.textPrimary
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        selObjId = modelData.id
                                        selFaces = []; selVerts = []; selEdges = []
                                        canvas.requestPaint()
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: Theme.spacingXs
                        Rectangle {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 24
                            radius: Theme.radiusSm; color: Theme.accentCopper
                            Text { anchors.centerIn: parent; text: "+"; color: "#ffffff"; font.pixelSize: 14; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: addMenu.open()
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 24
                            radius: Theme.radiusSm; color: Theme.chipBg
                            Text { anchors.centerIn: parent; text: "\u2212"; color: Theme.textSecondary; font.pixelSize: 14; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: deleteSelected()
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 30; Layout.preferredHeight: 24
                            radius: Theme.radiusSm; color: Theme.chipBg
                            Text { anchors.centerIn: parent; text: "\u2243"; color: Theme.textSecondary; font.pixelSize: 12; font.weight: Font.Bold }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: duplicateSelected()
                            }
                        }
                    }

                    Menu {
                        id: addMenu
                        MenuItem { text: "Cube"; onClicked: addPrimitive("cube") }
                        MenuItem { text: "Sphere"; onClicked: addPrimitive("sphere") }
                        MenuItem { text: "Cylinder"; onClicked: addPrimitive("cylinder") }
                        MenuItem { text: "Cone"; onClicked: addPrimitive("cone") }
                        MenuItem { text: "Torus"; onClicked: addPrimitive("torus") }
                        MenuItem { text: "Pyramid"; onClicked: addPrimitive("pyramid") }
                        MenuSeparator { }
                        MenuItem {
                            text: "Import STL/OBJ..."
                            onClicked: importDialog.open()
                        }
                    }
                }
            }

            // ---- Center: Viewport ----
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#FFFFFF"
                radius: Theme.radiusSm
                border.color: Theme.divider
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Edit mode sub-toolbar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: editMode === 1 ? 28 : 0
                        visible: editMode === 1
                        color: Theme.chipBg
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 2; spacing: 2
                            Repeater {
                                model: ["Vertex", "Edge", "Face"]
                                Rectangle {
                                    height: 22; width: 52
                                    radius: 3
                                    color: selSubMode === index ? Theme.accentCopper : Theme.chipBg
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: selSubMode === index ? "#ffffff" : Theme.textSecondary
                                        font.pixelSize: 10; font.weight: Font.DemiBold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            selSubMode = index
                                            selVerts = []; selEdges = []; selFaces = []
                                            canvas.requestPaint()
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 22; width: 50; radius: 3; color: Theme.chipBg
                                visible: selSubMode === 2 && selFaces.length > 0
                                Text { anchors.centerIn: parent; text: "Extrude"; font.pixelSize: 10; color: Theme.textSecondary; font.weight: Font.DemiBold }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: extrudeSelectedFace(extrudeSlider.value)
                                }
                            }
                            Rectangle {
                                height: 22; width: 56; radius: 3; color: Theme.chipBg
                                Text { anchors.centerIn: parent; text: "Subdivide"; font.pixelSize: 10; color: Theme.textSecondary; font.weight: Font.DemiBold }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: subdivideSelected()
                                }
                            }
                            Rectangle {
                                height: 22; width: 40; radius: 3; color: Theme.chipBg
                                visible: selFaces.length > 0
                                Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 10; color: Theme.textSecondary; font.weight: Font.DemiBold }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: deleteSelectedFaces()
                                }
                            }
                            Rectangle {
                                height: 22; width: 36; radius: 3; color: Theme.chipBg
                                Text { anchors.centerIn: parent; text: "Weld"; font.pixelSize: 10; color: Theme.textSecondary; font.weight: Font.DemiBold }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: weldSelected()
                                }
                            }
                        }
                    }

                    Canvas {
                        id: canvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        onPaint: {
                            var ctx = getContext("2d")
                            doPaint(ctx, width, height)
                        }

                        MouseArea {
                            id: canvasMouseArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.SizeAllCursor
                            property real pressX: 0
                            property real pressY: 0
                            onPressed: {
                                root.prevMX = mouseX; root.prevMY = mouseY
                                pressX = mouseX; pressY = mouseY
                                root.dragging = true
                            }
                            onReleased: {
                                root.dragging = false
                                var dist = Math.sqrt((mouseX - pressX) * (mouseX - pressX) + (mouseY - pressY) * (mouseY - pressY))
                                if (dist < 5) root.onCanvasClick(mouseX, mouseY)
                            }
                            onPositionChanged: {
                                if (!root.dragging) return
                                var dx = mouseX - root.prevMX
                                var dy = mouseY - root.prevMY
                                root.rotY += dx * 0.012
                                root.rotX += dy * 0.012
                                root.prevMX = mouseX; root.prevMY = mouseY
                                canvas.requestPaint()
                            }
                        }

                        WheelHandler {
                            onWheel: function(event) {
                                root.zoom = Math.max(0.3, Math.min(4.0, root.zoom + event.angleDelta.y * 0.001))
                                canvas.requestPaint()
                            }
                        }
                    }
                }
            }

            // ---- Right: Properties ----
            Rectangle {
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingSm
                    spacing: Theme.spacingXs

                    Text {
                        text: "Properties"; color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: propCol.implicitHeight
                        clip: true
                        ColumnLayout {
                            id: propCol
                            width: parent.width
                            spacing: Theme.spacingXs

                            // Transform section
                            Text {
                                text: "Transform"; color: Theme.textPrimary
                                font.pixelSize: 10; font.weight: Font.DemiBold
                                visible: selObjId !== ""
                            }

                            property var selObj: {
                                var result = null
                                for (var i = 0; i < sceneData.objects.length; i++)
                                    if (sceneData.objects[i].id === selObjId) { result = sceneData.objects[i]; break }
                                return result
                            }

                            Repeater {
                                model: selObjId !== "" ? [1] : []
                                delegate: Item {
                                    implicitHeight: 140
                                    width: parent.width
                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 2

                                        Text { text: "Position"; color: Theme.textMuted; font.pixelSize: 9 }
                                        RowLayout {
                                            spacing: 2
                                            Text { text: "X"; color: Theme.textMuted; font.pixelSize: 9; width: 10 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 20
                                                radius: 4; color: Theme.canvasBg
                                                TextInput {
                                                    id: posXInput
                                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                                    color: Theme.textPrimary; font.pixelSize: 10
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: propCol.selObj ? propCol.selObj.transform.position[0].toFixed(2) : "0"
                                                    onEditingFinished: {
                                                        if (selObjId)
                                                            updatePosition(selObjId, parseFloat(text) || 0,
                                                                parseFloat(posYInput.text) || 0,
                                                                parseFloat(posZInput.text) || 0)
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            spacing: 2
                                            Text { text: "Y"; color: Theme.textMuted; font.pixelSize: 9; width: 10 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 20
                                                radius: 4; color: Theme.canvasBg
                                                TextInput {
                                                    id: posYInput
                                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                                    color: Theme.textPrimary; font.pixelSize: 10
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: propCol.selObj ? propCol.selObj.transform.position[1].toFixed(2) : "0"
                                                    onEditingFinished: {
                                                        if (selObjId)
                                                            updatePosition(selObjId, parseFloat(posXInput.text) || 0,
                                                                parseFloat(text) || 0,
                                                                parseFloat(posZInput.text) || 0)
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            spacing: 2
                                            Text { text: "Z"; color: Theme.textMuted; font.pixelSize: 9; width: 10 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 20
                                                radius: 4; color: Theme.canvasBg
                                                TextInput {
                                                    id: posZInput
                                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                                    color: Theme.textPrimary; font.pixelSize: 10
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: propCol.selObj ? propCol.selObj.transform.position[2].toFixed(2) : "0"
                                                    onEditingFinished: {
                                                        if (selObjId)
                                                            updatePosition(selObjId, parseFloat(posXInput.text) || 0,
                                                                parseFloat(posYInput.text) || 0,
                                                                parseFloat(text) || 0)
                                                    }
                                                }
                                            }
                                        }

                                        Text { text: "Rotation"; color: Theme.textMuted; font.pixelSize: 9 }
                                        RowLayout {
                                            spacing: 2
                                            Text { text: "X"; color: Theme.textMuted; font.pixelSize: 9; width: 10 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 20
                                                radius: 4; color: Theme.canvasBg
                                                TextInput {
                                                    id: rotXInput
                                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                                    color: Theme.textPrimary; font.pixelSize: 10
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: propCol.selObj ? (propCol.selObj.transform.rotation[0] * 180 / Math.PI).toFixed(1) : "0"
                                                    onEditingFinished: {
                                                        if (selObjId)
                                                            updateRotation(selObjId,
                                                                (parseFloat(text) || 0) * Math.PI / 180,
                                                                (parseFloat(rotYInput.text) || 0) * Math.PI / 180,
                                                                (parseFloat(rotZInput.text) || 0) * Math.PI / 180)
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            spacing: 2
                                            Text { text: "Y"; color: Theme.textMuted; font.pixelSize: 9; width: 10 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 20
                                                radius: 4; color: Theme.canvasBg
                                                TextInput {
                                                    id: rotYInput
                                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                                    color: Theme.textPrimary; font.pixelSize: 10
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: propCol.selObj ? (propCol.selObj.transform.rotation[1] * 180 / Math.PI).toFixed(1) : "0"
                                                    onEditingFinished: {
                                                        if (selObjId)
                                                            updateRotation(selObjId,
                                                                (parseFloat(rotXInput.text) || 0) * Math.PI / 180,
                                                                (parseFloat(text) || 0) * Math.PI / 180,
                                                                (parseFloat(rotZInput.text) || 0) * Math.PI / 180)
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            spacing: 2
                                            Text { text: "Z"; color: Theme.textMuted; font.pixelSize: 9; width: 10 }
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: 20
                                                radius: 4; color: Theme.canvasBg
                                                TextInput {
                                                    id: rotZInput
                                                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                                    color: Theme.textPrimary; font.pixelSize: 10
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    text: propCol.selObj ? (propCol.selObj.transform.rotation[2] * 180 / Math.PI).toFixed(1) : "0"
                                                    onEditingFinished: {
                                                        if (selObjId)
                                                            updateRotation(selObjId,
                                                                (parseFloat(rotXInput.text) || 0) * Math.PI / 180,
                                                                (parseFloat(rotYInput.text) || 0) * Math.PI / 180,
                                                                (parseFloat(text) || 0) * Math.PI / 180)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Scale
                            Text {
                                text: "Scale"; color: Theme.textPrimary
                                font.pixelSize: 10; font.weight: Font.DemiBold
                                visible: selObjId !== ""
                            }
                            RowLayout {
                                visible: selObjId !== ""
                                spacing: 2
                                Text { text: "S"; color: Theme.textMuted; font.pixelSize: 9; width: 10 }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 20
                                    radius: 4; color: Theme.canvasBg
                                    TextInput {
                                        id: scaleInput
                                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                        color: Theme.textPrimary; font.pixelSize: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: {
                                            if (!selObjId) return "1"
                                            for (var i = 0; i < sceneData.objects.length; i++)
                                                if (sceneData.objects[i].id === selObjId)
                                                    return sceneData.objects[i].transform.scale[0].toFixed(2)
                                            return "1"
                                        }
                                        onEditingFinished: {
                                            if (selObjId) {
                                                var s = parseFloat(text) || 1
                                                updateScale(selObjId, s, s, s)
                                            }
                                        }
                                    }
                                }
                            }

                            // Color
                            Text {
                                text: "Color"; color: Theme.textPrimary
                                font.pixelSize: 10; font.weight: Font.DemiBold
                                visible: selObjId !== ""
                            }
                            RowLayout {
                                visible: selObjId !== ""
                                spacing: 4
                                Rectangle {
                                    id: colorSwatch
                                    width: 24; height: 24; radius: 4
                                    border.color: Theme.strokeColor
                                    color: {
                                        if (!selObjId) return Theme.wireframeNormal
                                        for (var i = 0; i < sceneData.objects.length; i++)
                                            if (sceneData.objects[i].id === selObjId)
                                                return sceneData.objects[i].color
                                        return Theme.wireframeNormal
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: colorDialog.open()
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 20
                                    radius: 4; color: Theme.canvasBg
                                    TextInput {
                                        id: colorInput
                                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                        color: Theme.textPrimary; font.pixelSize: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: colorSwatch.color
                                        onEditingFinished: {
                                            if (selObjId) updateColor(selObjId, text)
                                        }
                                    }
                                }
                            }

                            // Mesh info
                            Text {
                                text: "Mesh Data"; color: Theme.textPrimary
                                font.pixelSize: 10; font.weight: Font.DemiBold
                                visible: selObjId !== ""
                            }
                            Text {
                                visible: selObjId !== ""
                                text: {
                                    var info = "V: 0  F: 0"
                                    if (!selObjId) return info
                                    for (var i = 0; i < sceneData.objects.length; i++)
                                        if (sceneData.objects[i].id === selObjId) {
                                            var m = sceneData.objects[i].mesh
                                            info = "V: " + m.vertices.length + "  F: " + m.faces.length
                                            break
                                        }
                                    return info
                                }
                                color: Theme.textMuted; font.pixelSize: 9; font.family: Theme.fontMono
                            }

                            // Export / Import
                            Text {
                                text: "File"; color: Theme.textPrimary
                                font.pixelSize: 10; font.weight: Font.DemiBold
                                visible: selObjId !== ""
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 24
                                radius: Theme.radiusSm; color: Theme.accentCopper
                                visible: selObjId !== ""
                                Text {
                                    anchors.centerIn: parent
                                    text: "Export STL"
                                    color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: exportDialog.open()
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 24
                                radius: Theme.radiusSm; color: Theme.accentCopper
                                visible: selObjId !== ""
                                Text {
                                    anchors.centerIn: parent
                                    text: "Export OBJ"
                                    color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: exportObjDialog.open()
                                }
                            }

                            // Extrude slider (edit mode)
                            Text {
                                text: "Extrude Dist"; color: Theme.textPrimary
                                font.pixelSize: 10; font.weight: Font.DemiBold
                                visible: editMode === 1 && selFaces.length > 0
                            }
                            RowLayout {
                                visible: editMode === 1 && selFaces.length > 0
                                Slider {
                                    id: extrudeSlider
                                    Layout.fillWidth: true
                                    from: -2; to: 2; value: 0.5; stepSize: 0.05
                                }
                                Text {
                                    text: extrudeSlider.value.toFixed(2)
                                    color: Theme.textMuted; font.pixelSize: 9; width: 30
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- Status bar ----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 22
            radius: Theme.radiusSm - 1; color: Theme.chipBg; border.color: Theme.divider
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                Text {
                    text: sceneData.objects.length + " objects"
                    color: Theme.textMuted; font.pixelSize: 10
                }
                Text {
                    text: selObjId ? " | Sel: " + (function() {
                        for (var i = 0; i < sceneData.objects.length; i++)
                            if (sceneData.objects[i].id === selObjId)
                                return sceneData.objects[i].name
                        return ""
                    })() : ""
                    color: Theme.textMuted; font.pixelSize: 10
                }
                Text {
                    text: editMode === 1 ? " | Edit: " + ["Vertex","Edge","Face"][selSubMode] : ""
                    color: Theme.textMuted; font.pixelSize: 10
                }
                Text {
                    text: selFaces.length > 0 ? " | Faces: " + selFaces.length : ""
                    color: Theme.textMuted; font.pixelSize: 10
                }
            }
        }
    }

    // ---- Dialogs ----
    ColorDialog {
        id: colorDialog
        title: "Pick Object Color"
        selectedColor: colorSwatch.color
        onAccepted: {
            if (selObjId) updateColor(selObjId, selectedColor)
        }
    }

    FileDialog {
        id: importDialog
        title: "Import Mesh"
        nameFilters: ["3D Files (*.stl *.obj)", "STL Files (*.stl)", "OBJ Files (*.obj)"]
        onAccepted: {
            var path = selectedFile.toString()
            if (path.startsWith("file:///"))
                path = path.substring(8)
            var raw = MeshBackend.importMesh(path)
            var geom = JSON.parse(raw)
            if (geom.error) {
                console.log("Import error:", geom.error)
                return
            }
            var name = path.split("/").pop().split(".")[0]
            raw = MeshBackend.addImportedObject(name, JSON.stringify(geom))
            sceneData = JSON.parse(raw)
            sceneDirty = true
            refreshScene()
        }
    }

    FileDialog {
        id: exportDialog
        title: "Export STL"
        nameFilters: ["STL Files (*.stl)"]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "stl"
        onAccepted: {
            var path = selectedFile.toString()
            if (path.startsWith("file:///"))
                path = path.substring(8)
            MeshBackend.exportMesh(selObjId, path, "stl")
        }
    }

    FileDialog {
        id: exportObjDialog
        title: "Export OBJ"
        nameFilters: ["OBJ Files (*.obj)"]
        fileMode: FileDialog.SaveFile
        defaultSuffix: "obj"
        onAccepted: {
            var path = selectedFile.toString()
            if (path.startsWith("file:///"))
                path = path.substring(8)
            MeshBackend.exportMesh(selObjId, path, "obj")
        }
    }
}
