import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    signal back()

    property int currentTab: 0
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

    function computeStats() {
        var arr = parseNums(statInput.text)
        if (arr.length < 2) { statResult.text = "Need at least 2 numbers"; return }
        var raw = MathStackBackend.descriptiveStats(JSON.stringify(arr))
        var d
        try { d = JSON.parse(raw) } catch(e) { statResult.text = "Parse error"; return }
        if (!d.ok) { statResult.text = "Error: " + d.error; return }
        statResult.text = "N: " + d.n +
            "\nMean: " + d.mean.toFixed(4) +
            "\nMedian: " + d.median.toFixed(4) +
            "\nMode: " + d.mode +
            "\nVariance: " + d.variance.toFixed(4) +
            "\nStd Dev: " + d.std_dev.toFixed(4) +
            "\nMin: " + d.min.toFixed(4) +
            "\nMax: " + d.max.toFixed(4) +
            "\nQ1: " + d.q1.toFixed(4) +
            "\nQ3: " + d.q3.toFixed(4) +
            "\nSkewness: " + d.skewness.toFixed(4) +
            "\nKurtosis: " + d.kurtosis.toFixed(4)
    }

    function computeOneSample() {
        var arr = parseNums(ttestInput.text)
        if (arr.length < 2) { hypResult.text = "Need at least 2 numbers"; return }
        var mu = parseFloat(ttestMu.text) || 0
        var raw = MathStackBackend.ttestOneSample(JSON.stringify({ values: arr, mu: mu }))
        var d
        try { d = JSON.parse(raw) } catch(e) { hypResult.text = "Parse error"; return }
        if (!d.ok) { hypResult.text = "Error: " + d.error; return }
        hypResult.text = "One-Sample T-Test (vs mu=" + mu + "):\n" +
            "t = " + d.t_stat.toFixed(4) + "\np = " + d.p_value.toFixed(4)
    }

    function computeTwoSample() {
        var a = parseNums(ttestAInput.text)
        var b = parseNums(ttestBInput.text)
        if (a.length < 2 || b.length < 2) { hypResult.text = "Each group needs at least 2 numbers"; return }
        var raw = MathStackBackend.ttestIndependent(JSON.stringify(a), JSON.stringify(b))
        var d
        try { d = JSON.parse(raw) } catch(e) { hypResult.text = "Parse error"; return }
        if (!d.ok) { hypResult.text = "Error: " + d.error; return }
        hypResult.text = "Independent T-Test:\n" +
            "t = " + d.t_stat.toFixed(4) + "\np = " + d.p_value.toFixed(4)
    }

    function computeAnova() {
        var groups = anovaInput.text.split("|")
        var parsed = []
        for (var i = 0; i < groups.length; i++) {
            var arr = parseNums(groups[i])
            if (arr.length > 0) parsed.push(arr)
        }
        if (parsed.length < 2) { hypResult.text = "Need at least 2 groups"; return }
        var raw = MathStackBackend.anova(JSON.stringify(parsed))
        var d
        try { d = JSON.parse(raw) } catch(e) { hypResult.text = "Parse error"; return }
        if (!d.ok) { hypResult.text = "Error: " + d.error; return }
        hypResult.text = "One-Way ANOVA:\n" +
            "F = " + d.f_stat.toFixed(4) + "\np = " + d.p_value.toFixed(4)
    }

    function computeRegression() {
        var x = parseNums(regXInput.text)
        var y = parseNums(regYInput.text)
        if (x.length < 3 || y.length < 3) { regResult.text = "Need at least 3 points"; return }
        if (x.length !== y.length) { regResult.text = "X and Y must have same length"; return }
        var raw = MathStackBackend.linearRegression(JSON.stringify(x), JSON.stringify(y))
        var d
        try { d = JSON.parse(raw) } catch(e) { regResult.text = "Parse error"; return }
        if (!d.ok) { regResult.text = "Error: " + d.error; return }
        regResult.text = "Linear Regression:\n" +
            "y = " + d.slope.toFixed(4) + "x + " + d.intercept.toFixed(4) +
            "\nR\u00B2 = " + d.r_squared.toFixed(4) +
            "\nCorrelation: r = " + d.correlation.toFixed(4)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingMd
        spacing: Theme.spacingSm

        RowLayout {
            Text {
                text: "Statistics"
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
                Layout.preferredWidth: 100; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: currentTab === 0 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "Descriptive"
                    color: currentTab === 0 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: currentTab = 0
                }
            }
            Rectangle {
                Layout.preferredWidth: 100; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: currentTab === 1 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "Hypothesis"
                    color: currentTab === 1 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: currentTab = 1
                }
            }
            Rectangle {
                Layout.preferredWidth: 100; Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: currentTab === 2 ? Theme.accentCopper : Theme.chipBg
                Text {
                    anchors.centerIn: parent
                    text: "Regression"
                    color: currentTab === 2 ? "#ffffff" : Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSm; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: currentTab = 2
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.resultBg
            radius: Theme.radiusMd
            clip: true
            visible: currentTab === 0

            Flickable {
                anchors.fill: parent; anchors.margins: Theme.spacingMd
                contentHeight: statsColumn.height
                ScrollIndicator.vertical: ScrollIndicator { }

                ColumnLayout {
                    id: statsColumn
                    width: parent.width
                    spacing: Theme.spacingSm

                    Text {
                        text: "Enter numbers (comma separated):"
                        color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: statInput
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "1,2,3,4,5,6,7,8,9,10"
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
                            onClicked: computeStats()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: statResult.implicitHeight + Theme.spacingMd * 2
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider
                        visible: statResult.text !== ""

                        Text {
                            id: statResult
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.resultBg
            radius: Theme.radiusMd
            clip: true
            visible: currentTab === 1

            Flickable {
                anchors.fill: parent; anchors.margins: Theme.spacingMd
                contentHeight: hypColumn.height
                ScrollIndicator.vertical: ScrollIndicator { }

                ColumnLayout {
                    id: hypColumn
                    width: parent.width
                    spacing: Theme.spacingSm

                    Text {
                        text: "One-Sample T-Test (vs mu=0):"
                        color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: ttestInput
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "1,2,3,4,5,6,7,8,9,10"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    RowLayout { spacing: Theme.spacingSm
                        Text { text: "mu:"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }
                        Rectangle {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 30
                            radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                            TextInput {
                                id: ttestMu
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                text: "0"
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
                            onClicked: computeOneSample()
                        }
                    }

                    Text { text: "Independent T-Test (two groups):"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: ttestAInput
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "5,6,7,8,9"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: ttestBInput
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "1,2,3,4,5"
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
                            onClicked: computeTwoSample()
                        }
                    }

                    Text { text: "One-Way ANOVA (groups as | separated):"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: anovaInput
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "5,6,7|3,4,5|8,9,10"
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
                            onClicked: computeAnova()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: hypResult.implicitHeight + Theme.spacingMd * 2
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider
                        visible: hypResult.text !== ""

                        Text {
                            id: hypResult
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.resultBg
            radius: Theme.radiusMd
            clip: true
            visible: currentTab === 2

            Flickable {
                anchors.fill: parent; anchors.margins: Theme.spacingMd
                contentHeight: regColumn.height
                ScrollIndicator.vertical: ScrollIndicator { }

                ColumnLayout {
                    id: regColumn
                    width: parent.width
                    spacing: Theme.spacingSm

                    Text {
                        text: "X values (comma separated):"
                        color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: regXInput
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "1,2,3,4,5,6,7,8,9,10"
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            verticalAlignment: TextInput.AlignVCenter
                        }
                    }

                    Text { text: "Y values (comma separated):"; color: Theme.textSecondary; font.pixelSize: Theme.fontSizeSm }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34
                        radius: Theme.radiusFull; color: Theme.inputBg; border.color: Theme.divider
                        TextInput {
                            id: regYInput
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                            text: "2,4,6,8,10,12,14,16,18,20"
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
                            onClicked: computeRegression()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: regResult.implicitHeight + Theme.spacingMd * 2
                        color: Theme.btnDefault; radius: Theme.radiusSm; border.color: Theme.divider
                        visible: regResult.text !== ""

                        Text {
                            id: regResult
                            anchors.fill: parent; anchors.margins: Theme.spacingMd
                            color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSm
                            font.family: Theme.fontMono; wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }
    }
}

