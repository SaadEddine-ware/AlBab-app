import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property string currentCountry: ""
    property var countryNames: []
    property var indicators: ["POP_EST", "GDP_MD_EST", "AREA_KM2", "POP_DENSITY"]
    property int currentTab: 0
    property int currentIndicator: 0
    property bool sortAsc: false
    property bool isLoading: false

    LoadingOverlay {
        anchors.fill: parent
        isLoading: root.isLoading
        message: "Loading data..."
    }

    function refreshCountryList() {
        var raw = DemographicsBackend.getCountries()
        var arr
        try { arr = JSON.parse(raw) } catch(e) { return }
        countryNames = arr.map(function(c) { return c.name + " [" + c.iso3 + "]" })
        countryList.clear()
        for (var i = 0; i < arr.length; i++) { countryList.append(arr[i]) }
    }

    function makeChoropleth(indicator) {
        root.isLoading = true
        var raw = DemographicsBackend.choropleth(indicator)
        var d
        try { d = JSON.parse(raw) } catch(e) { root.isLoading = false; return }
        mapImage.source = "file://" + d.image_path
        indicatorTitle.text = d.title
        legendInfo.text = "Min: " + d.min_val + "  Median: " + d.med_val + "  Max: " + d.max_val
        root.isLoading = false
    }

    function rankCountries(indicator, ascending) {
        var raw = DemographicsBackend.topCountries(indicator, ascending ? "asc" : "desc", 15)
        var d
        try { d = JSON.parse(raw) } catch(e) { return }
        rankModel.clear()
        for (var i = 0; i < d.length; i++) { rankModel.append(d[i]) }
    }

    function compareCountries(c1, c2, indicator) {
        var raw = DemographicsBackend.compareCountries(c1, c2, indicator)
        var d
        try { d = JSON.parse(raw) } catch(e) { return }
        if (d.image_path) compImage.source = "file://" + d.image_path
    }

    function indicatorLabel(ind) {
        if (ind === "POP_EST") return "Population"
        if (ind === "GDP_MD_EST") return "GDP"
        if (ind === "AREA_KM2") return "Area"
        if (ind === "POP_DENSITY") return "Density"
        return ind
    }

    ListModel { id: countryList }
    ListModel { id: rankModel }

    Component.onCompleted: {
        if (typeof DemographicsBackend === 'undefined') return
        refreshCountryList()
        makeChoropleth("POP_EST")
        rankCountries("POP_EST", false)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text { text: "Demographics"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeLg; font.weight: Font.DemiBold; Accessible.name: "Demographics title" }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 60; Layout.preferredHeight: 28
                radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                Text { anchors.centerIn: parent; text: "\u2190 Back"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
                Accessible.name: "Go back"
                Accessible.role: Accessible.Button
            }
        }

        RowLayout {
            spacing: Theme.spacingXs
            Repeater {
                model: ["Choropleth", "Rankings", "Compare"]
                Rectangle {
                    Layout.preferredWidth: 100; Layout.preferredHeight: 28
                    radius: Theme.radiusSm
                    color: root.currentTab === index ? Theme.accentCopper : Theme.chipBg
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: root.currentTab === index ? "#ffffff" : Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = index
                    }
                    Accessible.name: modelData
                    Accessible.role: Accessible.Button
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentTab

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    RowLayout {
                        spacing: Theme.spacingSm
                        Repeater {
                            model: ["POP_EST", "GDP_MD_EST", "AREA_KM2", "POP_DENSITY"]
                            Rectangle {
                                Layout.preferredWidth: 52; Layout.preferredHeight: 22
                                radius: Theme.radiusSm
                                color: root.currentIndicator === index ? Theme.accentCopper : Theme.chipBg
                                Text {
                                    anchors.centerIn: parent
                                    text: indicatorLabel(modelData)
                                    color: root.currentIndicator === index ? "#ffffff" : Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeXs; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentIndicator = index
                                        makeChoropleth(modelData)
                                    }
                                }
                                Accessible.name: indicatorLabel(modelData)
                                Accessible.role: Accessible.Button
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
                        Image { id: mapImage; anchors.fill: parent; anchors.margins: 4; fillMode: Image.PreserveAspectFit }
                    }

                    Text { id: indicatorTitle; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                    Text { id: legendInfo; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeXs }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    RowLayout {
                        spacing: Theme.spacingSm
                        Repeater {
                            model: ["POP_EST", "GDP_MD_EST", "AREA_KM2", "POP_DENSITY"]
                            Rectangle {
                                Layout.preferredWidth: 52; Layout.preferredHeight: 22
                                radius: Theme.radiusSm
                                color: Theme.chipBg
                                Text {
                                    anchors.centerIn: parent
                                    text: indicatorLabel(modelData) + (root.sortAsc ? " \u2191" : " \u2193")
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeXs; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.sortAsc = !root.sortAsc
                                        rankCountries(modelData, root.sortAsc)
                                    }
                                }
                                Accessible.name: "Sort by " + indicatorLabel(modelData)
                                Accessible.role: Accessible.Button
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

                        ListView {
                            anchors.fill: parent
                            anchors.margins: 4
                            model: rankModel
                            clip: true
                            delegate: Rectangle {
                                width: parent.width
                                height: 28
                                color: index % 2 === 0 ? Theme.altRowBg : "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    Text { text: (index + 1) + "."; color: Theme.textMuted; font.pixelSize: Theme.fontSizeXs; Layout.preferredWidth: 24 }
                                    Text { text: modelData.name || modelData.country; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; Layout.fillWidth: true }
                                    Text { text: (modelData.value || 0).toLocaleString(); color: Theme.accentCopper; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingSm

                    RowLayout {
                        spacing: Theme.spacingSm
                        ColumnLayout { spacing: Theme.spacingXs
                            Text { text: "Country A"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                                TextInput { id: compA; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; activeFocusOnTab: true; Accessible.name: "Country A name" } }
                        }
                        ColumnLayout { spacing: Theme.spacingXs
                            Text { text: "Country B"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; radius: Theme.radiusSm; color: Theme.inputBg; border.color: Theme.divider
                                TextInput { id: compB; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; activeFocusOnTab: true; Accessible.name: "Country B name" } }
                        }
                        Rectangle {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 34
                            radius: Theme.radiusSm; color: Theme.accentCopper
                            Text { anchors.centerIn: parent; text: "Compare"; color: "#ffffff"; font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: compareCountries(compA.text, compB.text, indicators[root.currentIndicator]) }
                            Accessible.name: "Compare countries"
                            Accessible.role: Accessible.Button
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.contentBg
                        radius: Theme.radiusSm
                        border.color: Theme.divider
                        clip: true
                        Image { id: compImage; anchors.fill: parent; anchors.margins: 4; fillMode: Image.PreserveAspectFit }
                    }
                }
            }
        }
    }
}

