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
        message: "Converting..."
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text { text: "Coordinate Calculator"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.chipBg; border.color: Theme.divider
                Text { anchors.centerIn: parent; text: "\u2190 Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm - 1 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                Accessible.name: "Back to tools"; Accessible.role: Accessible.Button
            }
        }

        RowLayout {
            spacing: Theme.spacingXs
            Repeater {
                model: ["Convert", "Distance", "Batch"]
                Rectangle {
                    Layout.preferredWidth: 100; Layout.preferredHeight: 28
                    radius: Theme.radiusSm
                    color: tabBar.currentIndex === index ? Theme.accentCopper : Theme.chipBg
                    Text { anchors.centerIn: parent; text: modelData; color: tabBar.currentIndex === index ? "#ffffff" : Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tabBar.currentIndex = index }
                }
            }
        }

        SwipeView {
            id: tabBar
            Layout.fillWidth: true; Layout.fillHeight: true
            interactive: false; clip: true

            // Tab 1: Convert
            Item {
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMd; spacing: Theme.spacingSm

                    Text { text: "Decimal Degrees \u2192 DMS"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }

                    RowLayout { spacing: Theme.spacingSm
                        Text { text: "Lat:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: ddLat; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; text: "48.8566"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                    }
                    RowLayout { spacing: Theme.spacingSm
                        Text { text: "Lng:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: ddLng; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; text: "2.3522"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                    }
                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.accentCopper
                        Text { anchors.centerIn: parent; text: "Convert"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: doConvertDD() }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 80
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider; visible: convertResult.text
                        Flickable {
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            contentHeight: convertResult.height
                            clip: true
                            Text { id: convertResult; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere }
                        }
                    }

                    Rectangle { Layout.fillHeight: true; width: 1; color: "#00000000" }

                    Text { text: "DMS \u2192 Decimal Degrees"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }
                    RowLayout { spacing: 2
                        Rectangle { Layout.preferredWidth: 50; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsD1; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                        Rectangle { Layout.preferredWidth: 50; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsM1; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                        Rectangle { Layout.preferredWidth: 50; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsS1; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                        Rectangle { Layout.preferredWidth: 30; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsDir1; anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                    }
                    RowLayout { spacing: 2
                        Rectangle { Layout.preferredWidth: 50; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsD2; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                        Rectangle { Layout.preferredWidth: 50; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsM2; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                        Rectangle { Layout.preferredWidth: 50; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsS2; anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                        Rectangle { Layout.preferredWidth: 30; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: dmsDir2; anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; color: Theme.textPrimary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter } }
                    }
                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.accentCopper
                        Text { anchors.centerIn: parent; text: "Convert"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: doConvertDMS() }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 60
                        color: Theme.contentBg; radius: Theme.radiusSm; border.color: Theme.divider; visible: dmsResult.text
                        Text { id: dmsResult; anchors.fill: parent; anchors.margins: Theme.spacingSm; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.family: Theme.fontMono; wrapMode: Text.Wrap }
                    }
                }
            }

            // Tab 2: Distance
            Item {
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMd; spacing: Theme.spacingSm

                    Text { text: "Haversine Distance"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }

                    RowLayout { spacing: Theme.spacingSm
                        Text { text: "P1:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; Layout.preferredWidth: 20 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: p1Lat; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 4; text: "48.8566"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                        Text { text: ","; color: Theme.textSecondary }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: p1Lng; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; text: "2.3522"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                    }
                    RowLayout { spacing: Theme.spacingSm
                        Text { text: "P2:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; Layout.preferredWidth: 20 }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: p2Lat; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 4; text: "40.7128"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                        Text { text: ","; color: Theme.textSecondary }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 30; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: p2Lng; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; text: "-74.0060"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter } }
                    }
                    Rectangle {
                        Layout.preferredWidth: 100; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.accentCopper
                        Text { anchors.centerIn: parent; text: "Calculate"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: doDistance() }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 60
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider; visible: distResult.text
                        Text { id: distResult; anchors.fill: parent; anchors.margins: Theme.spacingMd; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere }
                    }
                }
            }

            // Tab 3: Batch
            Item {
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: Theme.spacingMd; spacing: Theme.spacingSm

                    Text { text: "Batch Convert (CSV format)"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }
                    Text { text: "Paste rows as lat,lng or DMS values. One pair per line."; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; wrapMode: Text.WordWrap }

                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider; clip: true
                        TextEdit {
                            id: batchInput
                            anchors.fill: parent; anchors.margins: 6
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.family: Theme.fontMono
                            text: "48.8566,2.3522\n40.7128,-74.0060\n51.5074,-0.1278"
                            wrapMode: TextEdit.NoWrap
                        }
                    }
                    RowLayout {
                        Rectangle {
                            Layout.preferredWidth: 100; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.accentCopper
                            Text { anchors.centerIn: parent; text: "Convert"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: doBatch() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.chipBg
                            Text { anchors.centerIn: parent; text: "Clear"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { batchInput.text = ""; batchResult.text = "" } }
                        }
                    }
                    Text { id: batchResult; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                }
            }
        }
    }

    function doConvertDD() {
        root.isLoading = true
        var lat = parseFloat(ddLat.text) || 0
        var lng = parseFloat(ddLng.text) || 0
        var raw = GeoUtils.convertDD(lat, lng)
        var d
        try { d = JSON.parse(raw) } catch(e) { convertResult.text = "Parse error"; root.isLoading = false; return }
        convertResult.text = "DMS:\n" + d.dms_lat + "\n" + d.dms_lng
        root.isLoading = false
    }

    function doConvertDMS() {
        root.isLoading = true
        var d1 = parseFloat(dmsD1.text) || 0
        var m1 = parseFloat(dmsM1.text) || 0
        var s1 = parseFloat(dmsS1.text) || 0
        var dir1 = dmsDir1.text.trim().toUpperCase() || "N"
        var d2 = parseFloat(dmsD2.text) || 0
        var m2 = parseFloat(dmsM2.text) || 0
        var s2 = parseFloat(dmsS2.text) || 0
        var dir2 = dmsDir2.text.trim().toUpperCase() || "E"
        var raw = GeoUtils.convertDMS(d1, m1, s1, dir1, d2, m2, s2, dir2)
        var d
        try { d = JSON.parse(raw) } catch(e) { dmsResult.text = "Parse error"; root.isLoading = false; return }
        dmsResult.text = "Lat: " + d.lat + "\nLng: " + d.lng
        root.isLoading = false
    }

    function doDistance() {
        var lat1 = parseFloat(p1Lat.text) || 0
        var lng1 = parseFloat(p1Lng.text) || 0
        var lat2 = parseFloat(p2Lat.text) || 0
        var lng2 = parseFloat(p2Lng.text) || 0
        var raw = GeoUtils.haversine(lat1, lng1, lat2, lng2)
        var d
        try { d = JSON.parse(raw) } catch(e) { distResult.text = "Parse error"; return }
        var raw2 = GeoUtils.bearing(lat1, lng1, lat2, lng2)
        var b
        try { b = JSON.parse(raw2) } catch(e) { distResult.text = "Parse error"; return }
        distResult.text = "Distance: " + d.km + " km (" + d.miles + " miles)\nBearing: " + b.degrees + "\u00B0 " + b.compass
    }

    function doBatch() {
        var lines = batchInput.text.trim().split("\n")
        var rows = []
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split(",")
            if (parts.length >= 2) {
                rows.push([parts[0].trim(), parts[1].trim()])
            }
        }
        if (rows.length === 0) { batchResult.text = "No valid data"; return }
        var raw = GeoUtils.batchConvert(JSON.stringify(rows), "dd_to_dms")
        var out
        try { out = JSON.parse(raw) } catch(e) { batchResult.text = "Parse error"; return }
        var text = ""
        for (var j = 0; j < out.length; j++) {
            text += out[j][0] + "  " + out[j][1] + "\n"
        }
        batchResult.text = text
    }
}

