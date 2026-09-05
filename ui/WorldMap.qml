import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property real rotY: 0.0
    property real zoom: 1.0
    property real prevMX: 0
    property real prevMY: 0
    property bool dragging: false
    property int currentTab: 0
    property string countryInfo: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text { text: "World Map"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                Text { anchors.centerIn: parent; text: "\u2190 Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
            }
        }

        RowLayout {
            spacing: Theme.spacingXs
            Repeater {
                model: ["Globe", "Search", "Measure"]
                Rectangle {
                    Layout.preferredWidth: 100; Layout.preferredHeight: 28; radius: Theme.radiusSm
                    color: root.currentTab === index ? Theme.accentCopper : Theme.chipBg
                    Text { anchors.centerIn: parent; text: modelData; color: root.currentTab === index ? "#ffffff" : Theme.textSecondary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = index }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: root.currentTab

            // Tab 0: Globe
            Item {
                Rectangle {
                    anchors.fill: parent; color: "#0a1628"; radius: Theme.radiusSm; border.color: Theme.divider; clip: true

                    Rectangle {
                        id: globeContainer
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.85 * root.zoom
                        height: width
                        radius: width / 2
                        color: "#0a1628"
                        border.color: "#20FFFFFF"
                        border.width: 2
                        clip: true

                        Image {
                            id: earthTex
                            anchors.centerIn: parent
                            width: parent.width * 1.4
                            height: parent.height * 1.4
                            source: "../assets/earth_texture.jpg"
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready

                            transform: [
                                Rotation {
                                    origin.x: earthTex.width / 2
                                    origin.y: earthTex.height / 2
                                    angle: root.rotY
                                    axis { x: 0; y: 1; z: 0 }
                                }
                            ]

                            onStatusChanged: {
                                if (status === Image.Ready) {
                                    globeGlow.visible = true
                                }
                            }
                        }

                        // Placeholder if texture fails
                        Rectangle {
                            anchors.fill: parent
                            visible: earthTex.status !== Image.Ready
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#1a5276" }
                                GradientStop { position: 0.5; color: "#2e86c1" }
                                GradientStop { position: 1.0; color: "#1a5276" }
                            }
                        }

                        // Atmosphere glow
                        Rectangle {
                            id: globeGlow
                            anchors.centerIn: parent
                            width: parent.width + 30
                            height: parent.height + 30
                            radius: width / 2
                            color: "transparent"
                            border.color: "#3088ccff"
                            border.width: 3
                            visible: false
                        }
                    }

                    ColumnLayout {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: Theme.spacingSm; spacing: 4
                        Text { text: "Drag to rotate \u00B7 Scroll to zoom"; color: "#80FFFFFF"; font.pixelSize: Theme.fontSizeXs }
                        Text { text: earthTex.status === Image.Ready ? "Earth loaded \u2714" : "Loading texture..."; color: earthTex.status === Image.Ready ? "#80FFFFFF" : "#60FFFFFF"; font.pixelSize: Theme.fontSizeXs }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        onPressed: { root.prevMX = mouseX; root.prevMY = mouseY; root.dragging = true }
                        onReleased: root.dragging = false
                        onPositionChanged: {
                            if (!root.dragging) return
                            root.rotY += (mouseX - root.prevMX) * 0.5
                            root.prevMX = mouseX; root.prevMY = mouseY
                        }
                    }

                    WheelHandler {
                        onWheel: function(event) {
                            root.zoom = Math.max(0.3, Math.min(3.0, root.zoom + event.angleDelta.y * 0.001))
                        }
                    }
                }
            }

            // Tab 1: Search
            Item {
                ColumnLayout { anchors.fill: parent; spacing: Theme.spacingSm
                    RowLayout { spacing: Theme.spacingSm
                        Text { text: "Country:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 28; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput { id: searchQuery; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } }
                        Rectangle { Layout.preferredWidth: 70; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.accentCopper
                            Text { anchors.centerIn: parent; text: "Search"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchCountry(searchQuery.text) } }
                    }

                    Rectangle {
                        visible: root.countryInfo !== ""
                        Layout.fillWidth: true; Layout.preferredHeight: 80
                        color: Theme.glassBase; radius: Theme.radiusSm; border.color: Theme.divider
                        Text { anchors.fill: parent; anchors.margins: Theme.spacingSm; text: root.countryInfo; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; wrapMode: Text.Wrap }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; color: Theme.contentBg; radius: Theme.radiusSm; border.color: Theme.divider; clip: true
                        ListView { anchors.fill: parent; anchors.margins: 4; model: searchResultsModel; clip: true
                            delegate: Rectangle { width: parent.width - 8; height: 36; color: index % 2 === 0 ? Theme.altRowBg : "transparent"; radius: 2
                                ColumnLayout { anchors.fill: parent; anchors.margins: 4; spacing: 1
                                    Text { text: model.name + " (" + model.iso3 + ")"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                                    Text { text: "Capital: " + (model.capital || "N/A") + " | Region: " + (model.region || "N/A"); color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.countryInfo = model.name + " (" + model.iso3 + ")\nCapital: " + (model.capital || "N/A") + "\nRegion: " + (model.region || "N/A") }
                            }
                        }
                    }
                }
            }

            // Tab 2: Measure
            Item {
                ColumnLayout { anchors.fill: parent; spacing: Theme.spacingSm
                    Text { text: "Measure Distance"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeMd; font.weight: Font.DemiBold }
                    RowLayout { spacing: Theme.spacingSm
                        ColumnLayout { spacing: 2
                            Text { text: "Point A"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            RowLayout { spacing: 2
                                Text { text: "Lat:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                                Rectangle { Layout.preferredWidth: 80; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                                    TextInput { id: aLat; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; text: "48.8566"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } }
                            }
                            RowLayout { spacing: 2
                                Text { text: "Lng:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                                Rectangle { Layout.preferredWidth: 80; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                                    TextInput { id: aLng; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; text: "2.3522"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } }
                            }
                        }
                        ColumnLayout { spacing: 2
                            Text { text: "Point B"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            RowLayout { spacing: 2
                                Text { text: "Lat:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                                Rectangle { Layout.preferredWidth: 80; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                                    TextInput { id: bLat; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; text: "40.7128"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } }
                            }
                            RowLayout { spacing: 2
                                Text { text: "Lng:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                                Rectangle { Layout.preferredWidth: 80; Layout.preferredHeight: 26; radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                                    TextInput { id: bLng; anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; text: "-74.0060"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true } }
                            }
                        }
                        Rectangle { Layout.preferredWidth: 70; Layout.preferredHeight: 28; radius: Theme.radiusSm; color: Theme.accentCopper
                            Text { anchors.centerIn: parent; text: "Measure"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: measureDistance(aLat.text, aLng.text, bLat.text, bLng.text) } }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 60; color: Theme.contentBg; radius: Theme.radiusSm; border.color: Theme.divider
                        Text { id: distResult; anchors.fill: parent; anchors.margins: Theme.spacingMd; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.family: Theme.fontMono; wrapMode: Text.WordWrap } }
                }
            }
        }
    }

    ListModel { id: searchResultsModel }

    function searchCountry(q) {
        try {
            var raw = MapBackend.searchCountry(q)
            var d = JSON.parse(raw)
            searchResultsModel.clear()
            for (var i = 0; i < d.length; i++) searchResultsModel.append(d[i])
            if (d.length === 0) root.countryInfo = "No results found for: " + q
        } catch(e) {
            root.countryInfo = "Search error"
        }
    }

    function measureDistance(lat1, lng1, lat2, lng2) {
        var raw = MapBackend.haversine(parseFloat(lat1), parseFloat(lng1), parseFloat(lat2), parseFloat(lng2))
        var d = JSON.parse(raw)
        distResult.text = "Distance: " + d.km + " km\nBearing: " + d.bearing + "\u00B0"
    }
}

