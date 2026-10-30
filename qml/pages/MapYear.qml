import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "../lib/YearModel.js" as YearModel
import "../components"

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: false
    property bool infoOpen: false
    property int selectedYear: new Date().getFullYear()
    readonly property var history: workspace.view ? workspace.view.history : []
    readonly property var availableYears: YearModel.years(history, Date.now())
    readonly property int yearIndex: availableYears.indexOf(selectedYear)
    readonly property var summary: YearModel.summarize(history, selectedYear)
    readonly property real largestMonth: summary.months.reduce(function(value, month) {
        return month.bytes === null ? value : Math.max(value, month.bytes);
    }, 1)
    readonly property bool historyEnabled: !!workspace.settings && workspace.settings.historyEnabled
    property int selectedMonth: new Date().getMonth()
    readonly property var selectedMonthEntry: summary.months[selectedMonth]
    readonly property bool showInsights: !workspace.prefs || workspace.prefs.showYearInsights
    property int selectedInsight: -1
    readonly property var insights: [
        {label: "year.peak", icon: "chart", sample: summary.peak,
            value: workspace.size(summary.peak ? summary.peak.bytes : null, summary.peak && summary.peak.partial)},
        {label: "year.largestApp", icon: "apps", sample: summary.largestApp,
            value: workspace.size(summary.largestApp ? summary.largestApp.bytes : null, summary.largestApp && summary.largestApp.partial)},
        {label: "year.largestCache", icon: "cache", sample: summary.largestCache,
            value: workspace.size(summary.largestCache ? summary.largestCache.bytes : null, summary.largestCache && summary.largestCache.partial)},
        {label: "year.rise", icon: "growth", sample: summary.rise,
            value: summary.rise ? workspace.strings.t("workspace.positive").arg(workspace.size(summary.rise.delta))
                : workspace.strings.t("workspace.noDelta")},
        {label: "year.fall", icon: "shrink", sample: summary.fall,
            value: summary.fall ? workspace.strings.t("workspace.negative").arg(workspace.size(-summary.fall.delta))
                : workspace.strings.t("workspace.noDelta")}
    ]
    spacing: Style.space(8)
    onImplicitHeightChanged: if (showInsights && selectedInsight >= 0 && !infoOpen)
        Qt.callLater(function() { root.workspace.reveal(insightExplanation); })

    onAvailableYearsChanged: {
        if (availableYears.indexOf(selectedYear) < 0)
            selectedYear = availableYears[availableYears.length - 1];
    }

    function toggleInfo() { infoOpen = !infoOpen; }
    function monthName(month, longName) {
        return Qt.locale(I18n.formatLocale).standaloneMonthName(month,
            longName ? Locale.LongFormat : Locale.ShortFormat);
    }
    function scopeName(mode) {
        return workspace.strings.t(mode === "deep" ? "workspace.deep" : "overview");
    }
    function observationDetail(sample) {
        if (!sample) return workspace.strings.t("year.noMeasurement");
        return sample.id ? workspace.strings.t("year.appObservation")
            .arg(sample.name || sample.id).arg(scopeName(sample.mode)).arg(workspace.date(sample.at))
            : workspace.strings.t("year.observation").arg(scopeName(sample.mode)).arg(workspace.date(sample.at));
    }
    function changeDetail(sample) {
        if (!sample) return workspace.strings.t("year.noComparableChange");
        return workspace.strings.t("year.changeObservation").arg(sample.name || sample.id)
            .arg(scopeName(sample.mode)).arg(workspace.date(sample.previousAt)).arg(workspace.date(sample.at));
    }
    function monthDetail(month) {
        return month.recorded ? workspace.strings.t("year.monthObservation")
            .arg(monthName(month.month, true)).arg(workspace.size(month.bytes, month.partial))
            .arg(workspace.date(month.at))
            : workspace.strings.t("year.monthMissing").arg(monthName(month.month, true));
    }

    RowLayout {
        Layout.fillWidth: true
        MapIconButton {
            icon: "back"
            label: root.workspace.strings.t("year.previous")
            enabled: root.yearIndex > 0
            onClicked: root.selectedYear = root.availableYears[root.yearIndex - 1]
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        MapText {
            Layout.fillWidth: true
            text: new Date(root.selectedYear, 0, 1).toLocaleDateString(Qt.locale(I18n.formatLocale), "yyyy")
            font.pixelSize: Style.font.title
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
        }
        MapIconButton {
            icon: "next"
            label: root.workspace.strings.t("year.next")
            enabled: root.yearIndex >= 0 && root.yearIndex < root.availableYears.length - 1
            onClicked: root.selectedYear = root.availableYears[root.yearIndex + 1]
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
    }

    MapSection {
        Layout.fillWidth: true
        title: root.workspace.strings.t("year.monthly")
        caption: root.workspace.strings.t("year.monthlyBasis")
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(60)
            spacing: Style.space(2)
            Repeater {
                model: root.summary.months
                Ui.Button {
                    id: monthButton
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    horizontalPadding: 0
                    verticalPadding: 0
                    foreground: Color.popups.text
                    selected: root.selectedMonth === modelData.month
                    focusable: true
                    tooltipText: root.monthDetail(modelData)
                    Accessible.name: tooltipText
                    Accessible.role: Accessible.Button
                    onClicked: root.selectedMonth = modelData.month
                    onActiveFocusChanged: if (activeFocus) {
                        root.selectedMonth = modelData.month;
                        root.workspace.reveal(this);
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Style.space(2)
                        spacing: Style.space(4)
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.max(Style.space(2), parent.width - Style.space(4))
                                height: monthButton.modelData.bytes === null ? Style.space(2)
                                    : monthButton.modelData.bytes === 0 ? 1
                                    : Math.max(Style.space(2), parent.height * monthButton.modelData.bytes / root.largestMonth)
                                radius: Style.space(1)
                                color: monthButton.modelData.bytes === null ? "transparent"
                                    : monthButton.modelData.partial ? Util.alpha(Color.urgent, 0.5) : root.workspace.heroColor
                                border.width: monthButton.modelData.bytes === null || monthButton.modelData.partial ? 1 : 0
                                border.color: monthButton.modelData.partial ? Color.urgent : Util.alpha(Color.popups.text, 0.3)
                                Behavior on height {
                                    NumberAnimation { duration: root.workspace.motionEnabled ? Style.duration(160) : 0; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                        MapText {
                            Layout.fillWidth: true
                            text: root.monthName(monthButton.modelData.month, false).slice(0, 1)
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Style.font.caption
                            color: Util.alpha(Color.popups.text, monthButton.modelData.recorded ? 0.9 : 0.45)
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            MapText {
                Layout.fillWidth: true
                text: root.monthName(root.selectedMonth, true)
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
            }
            MapText {
                text: root.selectedMonthEntry.recorded ? root.workspace.size(root.selectedMonthEntry.bytes, root.selectedMonthEntry.partial)
                    : root.workspace.strings.t("year.missing")
                font.pixelSize: Style.font.title
                font.weight: Font.DemiBold
                color: root.selectedMonthEntry.partial ? Color.urgent : root.workspace.heroColor
            }
        }
        MapText {
            Layout.fillWidth: true
            visible: root.selectedMonthEntry.recorded
            text: root.workspace.date(root.selectedMonthEntry.at)
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("year.monthLegend")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.6)
            wrapMode: Text.Wrap
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !root.summary.overviewScans || !root.historyEnabled
        MapGlyph { icon: "history"; color: Util.alpha(Color.popups.text, 0.6) }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t(!root.historyEnabled ? "year.historyOff" : "year.empty")
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }
    }

    MapSection {
        Layout.fillWidth: true
        visible: root.showInsights
        title: root.workspace.strings.t("journey.activity")
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Repeater {
                model: [
                    {label: "year.scans", icon: "history", value: root.summary.scans},
                    {label: "year.days", icon: "calendar", value: root.summary.days},
                    {label: "year.apps", icon: "apps", value: root.summary.apps}
                ]
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: Style.space(3)
                    RowLayout {
                        Layout.fillWidth: true
                        MapGlyph { icon: modelData.icon; color: root.workspace.insightColor }
                        MapText {
                            Layout.fillWidth: true
                            text: root.workspace.number(modelData.value)
                            font.pixelSize: Style.font.body
                            font.weight: Font.DemiBold
                            color: root.workspace.insightColor
                        }
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.workspace.strings.t(modelData.label)
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.65)
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("year.scanScopes").arg(root.workspace.number(root.summary.overviewScans))
                .arg(root.workspace.number(root.summary.deepScans))
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
    }
    MapSection {
        Layout.fillWidth: true
        visible: root.showInsights
        title: root.workspace.strings.t("year.insights")
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Repeater {
                model: root.insights
                Ui.Button {
                    id: insightButton
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: Math.max(Style.space(36), insightContent.implicitHeight + Style.space(12))
                    selected: root.selectedInsight === index
                    focusable: true
                    text: ""
                    Accessible.name: root.workspace.strings.t(modelData.label) + ": " + modelData.value
                    Accessible.expanded: root.selectedInsight === index
                    onClicked: {
                        root.selectedInsight = root.selectedInsight === index ? -1 : index;
                        if (root.selectedInsight >= 0)
                            Qt.callLater(function() { root.workspace.reveal(insightExplanation); });
                    }
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    RowLayout {
                        id: insightContent
                        anchors.fill: parent
                        anchors.margins: Style.space(6)
                        spacing: Style.space(7)
                        MapGlyph { icon: insightButton.modelData.icon; color: root.workspace.insightColor }
                        MapText {
                            Layout.fillWidth: true
                            text: root.workspace.strings.t(insightButton.modelData.label)
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.Wrap
                        }
                        MapText {
                            Layout.maximumWidth: insightButton.width * 0.4
                            text: insightButton.modelData.value
                            font.pixelSize: Style.font.bodySmall
                            font.weight: Font.DemiBold
                            color: root.workspace.insightColor
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
        MapText {
            id: insightExplanation
            Layout.fillWidth: true
            visible: root.selectedInsight >= 0
            text: root.selectedInsight < 0 ? "" : root.selectedInsight > 2
                ? root.changeDetail(root.insights[root.selectedInsight].sample)
                : root.observationDetail(root.insights[root.selectedInsight].sample)
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
    }

    Ui.Button {
        Layout.fillWidth: true
        text: root.workspace.strings.t("workspace.history")
        focusable: true
        fontSize: Style.font.caption
        onClicked: root.workspace.navigate("history")
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
    MapSection {
        Layout.fillWidth: true
        visible: root.infoOpen
        title: root.workspace.strings.t("year.basis")
        MapText {
            Layout.fillWidth: true
            visible: !root.summary.overviewScans || !root.historyEnabled
            text: root.workspace.strings.t(!root.historyEnabled ? "year.historyOffDetail"
                : root.summary.scans ? "year.deepOnly" : "year.emptyDetail")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("year.retention")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("year.comparisonBasis")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("year.measurementBasis")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("year.daysDetail") + "\n" + root.workspace.strings.t("year.appsDetail")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
        Repeater {
            model: [root.summary.peak, root.summary.largestApp, root.summary.largestCache,
                root.summary.rise, root.summary.fall]
            MapText {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                visible: modelData !== null
                text: root.workspace.strings.t("year.basisObservation")
                    .arg(root.workspace.strings.t(["year.peak", "year.largestApp", "year.largestCache", "year.rise", "year.fall"][index]))
                    .arg(index > 2 ? root.changeDetail(modelData) : root.observationDetail(modelData))
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
            }
        }
    }
}
