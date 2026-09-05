import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property string startDate: "1900"
    property string endDate: "2000"
    property bool timelineCreated: false
    property var timelineData: ({})
    property int selectedEvent: -1
    property bool isLoading: false

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isLoading
        message: "Creating timeline..."
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text { text: "Timeline"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold; Accessible.name: "Timeline title" }
            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                Text { anchors.centerIn: parent; text: "\u2190 Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                Accessible.name: "Go back"; Accessible.role: Accessible.Button
            }
        }

        GlassCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 80

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingMd

                ColumnLayout { spacing: 2
                    Text { text: "Start Date"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                        TextInput { id: startDateInput; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; text: root.startDate; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; Accessible.name: "Start year" } } }

                ColumnLayout { spacing: 2
                    Text { text: "End Date"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                        TextInput { id: endDateInput; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; text: root.endDate; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; Accessible.name: "End year" } } }

                Rectangle {
                    Layout.preferredWidth: 90; Layout.preferredHeight: 28
                    radius: Theme.radiusSm; color: Theme.accentCopper
                    Text { anchors.centerIn: parent; text: "Create"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: createTimeline() }
                    Accessible.name: "Create timeline"; Accessible.role: Accessible.Button
                }

                Rectangle {
                    visible: root.timelineCreated
                    Layout.preferredWidth: 90; Layout.preferredHeight: 28
                    radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: "+ Add Event"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addEventPopup.open() }
                    Accessible.name: "Add event"; Accessible.role: Accessible.Button
                }

                Rectangle {
                    visible: root.timelineCreated
                    Layout.preferredWidth: 60; Layout.preferredHeight: 28
                    radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: "Save"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: saveTimeline() }
                    Accessible.name: "Save timeline"; Accessible.role: Accessible.Button
                }

                Rectangle {
                    Layout.preferredWidth: 60; Layout.preferredHeight: 28
                    radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: "Load"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: loadTimeline() }
                    Accessible.name: "Load timeline"; Accessible.role: Accessible.Button
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.contentBg
            radius: Theme.radiusSm
            border.color: Theme.divider
            clip: true

            Canvas {
                id: timelineCanvas
                anchors.fill: parent

                onPaint: {
                    if (!root.timelineCreated) return
                    var ctx = getContext("2d")
                    var w = width, h = height
                    ctx.clearRect(0, 0, w, h)

                    drawGradientLine(ctx, w, h)
                    drawEventNodes(ctx, w, h)
                }

                function drawGradientLine(ctx, w, h) {
                    var startY = h * 0.4
                    var startX = 40
                    var endX = w - 40

                    var gradient = ctx.createLinearGradient(startX, 0, endX, 0)
                    gradient.addColorStop(0, Theme.accentCopper)
                    gradient.addColorStop(0.5, Theme.accentBlue)
                    gradient.addColorStop(1, Theme.accentGreen)

                    ctx.strokeStyle = gradient
                    ctx.lineWidth = 4
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.moveTo(startX, startY)
                    ctx.lineTo(endX, startY)
                    ctx.stroke()

                    ctx.fillStyle = Theme.textMuted
                    ctx.font = "11px Segoe UI"
                    ctx.textAlign = "left"
                    ctx.fillText(root.startDate, startX, startY + 20)
                    ctx.textAlign = "right"
                    ctx.fillText(root.endDate, endX, startY + 20)
                    ctx.textAlign = "left"

                    var startYear = parseInt(root.startDate) || 1900
                    var endYear = parseInt(root.endDate) || 2000
                    var range = endYear - startYear
                    if (range <= 0) return

                    var step = Math.max(1, Math.floor(range / 10))
                    for (var y = startYear; y <= endYear; y += step) {
                        var x = startX + ((y - startYear) / range) * (endX - startX)
                        ctx.strokeStyle = Theme.divider
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(x, startY - 5)
                        ctx.lineTo(x, startY + 5)
                        ctx.stroke()
                        ctx.fillStyle = Theme.textMuted
                        ctx.textAlign = "center"
                        ctx.fillText(String(y), x, startY + 35)
                    }
                    ctx.textAlign = "left"
                }

                function drawEventNodes(ctx, w, h) {
                    if (!root.timelineData.events) return

                    var startY = h * 0.4
                    var startX = 40
                    var endX = w - 40
                    var startYear = parseInt(root.startDate) || 1900
                    var endYear = parseInt(root.endDate) || 2000
                    var range = endYear - startYear
                    if (range <= 0) return

                    var events = root.timelineData.events
                    for (var i = 0; i < events.length; i++) {
                        var ev = events[i]
                        var evYear = parseInt(ev.date) || startYear
                        var x = startX + ((evYear - startYear) / range) * (endX - startX)
                        var y = startY

                        var isSelected = (root.selectedEvent === i)
                        var nodeRadius = isSelected ? 10 : 7

                        ctx.beginPath()
                        ctx.arc(x, y, nodeRadius, 0, 2 * Math.PI)
                        ctx.fillStyle = isSelected ? Theme.accentCopper : getNodeColor(ev.category)
                        ctx.fill()
                        ctx.strokeStyle = isSelected ? "#ffffff" : "rgba(255,255,255,0.5)"
                        ctx.lineWidth = isSelected ? 3 : 2
                        ctx.stroke()

                        ctx.fillStyle = Theme.textPrimary
                        ctx.font = (isSelected ? "bold " : "") + "11px Segoe UI"
                        ctx.textAlign = "center"
                        var label = ev.title
                        if (label.length > 20) label = label.substring(0, 18) + "..."
                        ctx.fillText(label, x, y - 15)
                        ctx.textAlign = "left"
                    }
                }

                function getNodeColor(category) {
                    if (category === "War" || category === "military") return "#E91E63"
                    if (category === "Politics" || category === "political") return "#4A90D9"
                    if (category === "Culture" || category === "cultural") return "#50B87A"
                    if (category === "Economy" || category === "economy") return "#FF9800"
                    return Theme.accentCopper
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var startX = 40
                        var endX = timelineCanvas.width - 40
                        var startY = timelineCanvas.height * 0.4
                        var startYear = parseInt(root.startDate) || 1900
                        var endYear = parseInt(root.endDate) || 2000
                        var range = endYear - startYear
                        if (range <= 0 || !root.timelineData.events) return

                        var closest = -1
                        var closestDist = 20

                        for (var i = 0; i < root.timelineData.events.length; i++) {
                            var ev = root.timelineData.events[i]
                            var evYear = parseInt(ev.date) || startYear
                            var x = startX + ((evYear - startYear) / range) * (endX - startX)
                            var dx = mouseX - x
                            var dy = mouseY - startY
                            var dist = Math.sqrt(dx * dx + dy * dy)
                            if (dist < closestDist) {
                                closestDist = dist
                                closest = i
                            }
                        }
                        root.selectedEvent = closest
                        timelineCanvas.requestPaint()
                    }
                }
            }
        }

        Rectangle {
            visible: root.selectedEvent >= 0 && root.timelineData.events
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            color: Theme.glassBase
            radius: Theme.radiusSm
            border.color: Theme.divider

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingXs

                RowLayout {
                    Text {
                        text: root.selectedEvent >= 0 && root.timelineData.events ? root.timelineData.events[root.selectedEvent].title : ""
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        Layout.preferredWidth: 60; Layout.preferredHeight: 22
                        radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                        Text { anchors.centerIn: parent; text: "Delete"; color: Theme.errorText; font.pixelSize: Theme.fontSizeXs }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: deleteEvent(root.selectedEvent) }
                        Accessible.name: "Delete event"; Accessible.role: Accessible.Button
                    }
                }

                Text {
                    text: root.selectedEvent >= 0 && root.timelineData.events ? "Date: " + root.timelineData.events[root.selectedEvent].date + " | Category: " + root.timelineData.events[root.selectedEvent].category : ""
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm
                }

                Text {
                    text: root.selectedEvent >= 0 && root.timelineData.events ? root.timelineData.events[root.selectedEvent].desc || "" : ""
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSm
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    Popup {
        id: addEventPopup
        anchors.centerIn: parent
        width: 350
        height: 280
        modal: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMd
            spacing: Theme.spacingSm

            Text { text: "Add Event"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold }

            ColumnLayout { spacing: 2
                Text { text: "Date (Year)"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                    TextInput { id: eventDate; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } } }

            ColumnLayout { spacing: 2
                Text { text: "Title"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                    TextInput { id: eventTitle; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } } }

            ColumnLayout { spacing: 2
                Text { text: "Category"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                    ComboBox { id: eventCategory; anchors.fill: parent; model: ["War", "Politics", "Culture", "Economy"] } } }

            ColumnLayout { spacing: 2
                Text { text: "Description"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 60; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                    TextInput { id: eventDesc; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } } }

            RowLayout {
                spacing: Theme.spacingSm
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addEventPopup.close() } }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusSm; color: Theme.accentCopper
                    Text { anchors.centerIn: parent; text: "Add"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addEvent() } }
            }
        }
    }

    function createTimeline() {
        root.startDate = startDateInput.text.trim() || "1900"
        root.endDate = endDateInput.text.trim() || "2000"
        root.timelineData = { events: [] }
        root.timelineCreated = true
        root.selectedEvent = -1
        timelineCanvas.requestPaint()
    }

    function addEvent() {
        if (!eventDate.text.trim() || !eventTitle.text.trim()) return
        var events = root.timelineData.events || []
        events.push({
            date: eventDate.text.trim(),
            title: eventTitle.text.trim(),
            category: eventCategory.currentText,
            desc: eventDesc.text.trim()
        })
        root.timelineData = { events: events }
        addEventPopup.close()
        eventDate.text = ""
        eventTitle.text = ""
        eventDesc.text = ""
        timelineCanvas.requestPaint()
    }

    function deleteEvent(idx) {
        if (idx < 0 || !root.timelineData.events) return
        var events = root.timelineData.events.slice()
        events.splice(idx, 1)
        root.timelineData = { events: events }
        root.selectedEvent = -1
        timelineCanvas.requestPaint()
    }

    function saveTimeline() {
        var data = {
            startDate: root.startDate,
            endDate: root.endDate,
            events: root.timelineData.events || []
        }
        var key = "timeline_" + (root.startDate || "default")
        DataStore.save(key, JSON.stringify(data))
        DataStore.save("timeline_last", key)
    }

    function loadTimeline() {
        var lastKey = DataStore.load("timeline_last")
        if (!lastKey || lastKey === "[]") lastKey = "timeline_default"
        var raw = DataStore.load(lastKey)
        try {
            var data = JSON.parse(raw)
            if (data.events && data.events.length > 0) {
                root.startDate = data.startDate || "1900"
                root.endDate = data.endDate || "2000"
                root.timelineData = { events: data.events }
                root.timelineCreated = true
                startDateInput.text = root.startDate
                endDateInput.text = root.endDate
                timelineCanvas.requestPaint()
            }
        } catch(e) {}
    }
}

