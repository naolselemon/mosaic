import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: filter.activeFocus
    property bool infoOpen: false
    property bool pickerOpen: false
    property bool showUnavailable: false
    property string appId: ""
    property string selectedName: ""
    property string mode: "overview"
    property string query: ""
    readonly property var choices: {
        var seen = Object.create(null), result = [];
        var current = workspace.service ? workspace.service.apps : [];
        var history = workspace.view ? workspace.view.history : [];
        var add = function(app) {
            if (seen[app.id]) return;
            seen[app.id] = true;
            if (!query || (app.name + " " + app.id).toLowerCase().indexOf(query.toLowerCase()) >= 0)
                result.push({id: app.id, name: app.name});
        };
        for (var c = 0; c < current.length; c++) add(current[c]);
        for (var i = history.length - 1; i >= 0; i--)
            for (var j = 0; j < history[i].apps.length; j++) add(history[i].apps[j]);
        return result.sort(function(a, b) { return a.name.localeCompare(b.name); });
    }
    readonly property var allGrowth: workspace.view ? workspace.view.growth.filter(function(row) { return row.mode === root.mode && (!root.appId || row.id === root.appId); }) : []
    readonly property var growth: allGrowth.filter(function(row) { return row.comparable || root.showUnavailable || root.appId !== ""; })
    readonly property int unavailableCount: allGrowth.filter(function(row) { return !row.comparable; }).length
    function toggleInfo() { infoOpen = !infoOpen; }
    function choose(id, name) {
        appId = id;
        selectedName = name;
        query = "";
        filter.text = "";
        pickerOpen = false;
        pickerButton.forceActiveFocus();
    }
    function delta(row) {
        if (!row.comparable || row.delta === null) return workspace.strings.t("workspace.noDelta");
        return row.delta > 0 ? workspace.strings.t("workspace.positive").arg(workspace.size(row.delta))
            : row.delta < 0 ? workspace.strings.t("workspace.negative").arg(workspace.size(-row.delta)) : workspace.size(0);
    }
    spacing: Style.space(8)

    MapText {
        Layout.fillWidth: true
        visible: root.infoOpen
        text: root.workspace.strings.t("workspace.historyBasis") + "\n" + root.workspace.strings.t("visual.historyWindow")
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.7)
        wrapMode: Text.Wrap
    }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["overview", "deep"]
            Ui.Button {
                required property string modelData
                Layout.fillWidth: true
                text: root.workspace.strings.t(modelData === "overview" ? "overview" : "workspace.deep")
                selected: root.mode === modelData
                focusable: true
                onClicked: { root.mode = modelData; if (modelData === "deep" && !root.appId) root.pickerOpen = true; }
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
    }
    Ui.Button {
        id: pickerButton
        Layout.fillWidth: true
        text: root.appId ? root.workspace.strings.t("workspace.selectedApp").arg(root.selectedName || root.workspace.appName(root.appId)) : root.workspace.strings.t(root.mode === "deep" ? "workspace.chooseApp" : "workspace.allApps")
        selected: root.pickerOpen
        focusable: true
        leftAlign: true
        onClicked: root.pickerOpen = !root.pickerOpen
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.pickerOpen
        spacing: Style.space(3)
        Ui.TextField {
            id: filter
            Layout.fillWidth: true
            placeholderText: root.workspace.strings.t("visual.filterApps")
            onTextEdited: root.query = text
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        Ui.Button {
            Layout.fillWidth: true
            visible: root.mode === "overview"
            text: root.workspace.strings.t("workspace.allApps")
            selected: !root.appId
            focusable: true
            fontSize: Style.font.caption
            onClicked: root.choose("", "")
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        Repeater {
            model: root.pickerOpen ? root.choices : []
            Ui.Button {
                required property var modelData
                Layout.fillWidth: true
                text: root.workspace.strings.t("workspace.appIdentity").arg(modelData.name).arg(modelData.id)
                selected: root.appId === modelData.id
                focusable: true
                fontSize: Style.font.caption
                leftAlign: true
                onClicked: root.choose(modelData.id, modelData.name)
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
        MapText { Layout.fillWidth: true; visible: !root.choices.length; text: root.workspace.strings.t("compact.noMatches"); wrapMode: Text.Wrap; font.pixelSize: Style.font.caption }
    }
    MapText {
        Layout.fillWidth: true
        visible: root.mode === "deep" && !root.appId
        text: root.workspace.strings.t("workspace.chooseDeepApp")
        color: root.workspace.insightColor
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    MapHistoryChart {
        Layout.fillWidth: true
        visible: root.mode !== "deep" || root.appId !== ""
        workspace: root.workspace
        appId: root.appId
        mode: root.mode
    }
    RowLayout {
        Layout.fillWidth: true
        Ui.Button {
            Layout.fillWidth: true
            text: root.workspace.strings.t(root.mode === "deep" ? "workspace.scanSelected" : "scan")
            enabled: !!root.workspace.service && !root.workspace.busy && (root.mode !== "deep" || root.appId !== "" && root.workspace.service.apps.some(function(app) { return app.id === root.appId; }))
            focusable: true
            fontSize: Style.font.caption
            onClicked: root.mode === "deep" ? root.workspace.service.deepScan(root.appId) : root.workspace.service.rescan()
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        MapIconButton {
            icon: "calendar"
            label: root.workspace.strings.t("visual.yearInsights")
            onClicked: root.workspace.navigate("year")
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        MapIconButton {
            icon: "settings"
            label: root.workspace.strings.t("workspace.settings")
            onClicked: root.workspace.navigate("settings")
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
    }
    MapText { Layout.fillWidth: true; text: root.workspace.strings.t("workspace.comparisons"); font.weight: Font.DemiBold }
    MapText {
        Layout.fillWidth: true
        visible: !root.growth.length
        text: root.workspace.strings.t("workspace.noComparableShort")
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        color: Util.alpha(Color.popups.text, 0.7)
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.space(7)
        rowSpacing: Style.space(7)
        Repeater {
            model: root.growth
            ColumnLayout {
                id: comparison
                required property var modelData
                property bool expanded: false
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: Style.space(4)
                MapMetricCard {
                    Layout.fillWidth: true
                    icon: comparison.modelData.comparable ? comparison.modelData.delta < 0 ? "shrink" : "growth" : "info"
                    label: comparison.modelData.name
                    value: root.delta(comparison.modelData)
                    detail: root.workspace.strings.t(comparison.modelData.comparable ? "visual.comparable" : "visual.notComparable")
                    tint: comparison.modelData.comparable ? root.workspace.insightColor : Util.alpha(Color.popups.text, 0.65)
                    actionable: true
                    onClicked: comparison.expanded = !comparison.expanded
                    onFocused: function(item) { root.workspace.reveal(item); }
                }
                MapText {
                    Layout.fillWidth: true
                    visible: comparison.expanded
                    text: comparison.modelData.comparable ? root.workspace.strings.t("workspace.comparedDates").arg(root.workspace.date(comparison.modelData.previousAt)).arg(root.workspace.date(comparison.modelData.at)) : root.workspace.strings.t("workspace.reason." + comparison.modelData.reason)
                    wrapMode: Text.Wrap
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.7)
                }
            }
        }
    }
    Ui.Button {
        Layout.fillWidth: true
        visible: !root.appId && root.unavailableCount > 0
        text: root.workspace.strings.tn("visual.unavailableComparisons", root.unavailableCount).arg(root.workspace.number(root.unavailableCount))
        selected: root.showUnavailable
        focusable: true
        fontSize: Style.font.caption
        onClicked: root.showUnavailable = !root.showUnavailable
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
}
