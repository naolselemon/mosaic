import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "../lib/ViewModel.js" as Model
import "../components"

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: false
    property bool infoOpen: false
    readonly property var view: workspace.view
    readonly property var service: workspace.service
    readonly property var cache: view ? view.insights.cache : []
    readonly property var growing: view ? view.insights.growing : []
    readonly property bool measured: !!service && service.ready && ((!service.apps.length && !incomplete) || service.apps.some(function(app) {
        return (app.paths || []).some(function(path) { return path.confidence === "known" && path.bytes !== null && path.bytes !== undefined; });
    }))
    readonly property bool incomplete: !!service && (service.partial || service.limited || service.busy)
    readonly property var categories: ["config", "cache", "data", "state"]
    function toggleInfo() { infoOpen = !infoOpen; }
    spacing: Style.space(9)

    MapText {
        Layout.fillWidth: true
        visible: root.infoOpen
        text: root.workspace.strings.t("visual.dashboardHelp")
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.7)
        wrapMode: Text.Wrap
    }
    MapSection {
        Layout.fillWidth: true
        title: root.workspace.strings.t("workspace.mappedData")
        RowLayout {
            Layout.fillWidth: true
            MapText {
                Layout.fillWidth: true
                text: root.measured ? root.workspace.size(root.service.mappedBytes, root.incomplete) : root.workspace.strings.t("size.unknown")
                font.pixelSize: Style.font.heading * 1.45
                font.weight: Font.DemiBold
                color: root.workspace.heroColor
                elide: Text.ElideRight
            }
            MapGlyph { icon: "chart"; font.pixelSize: Style.font.heading; color: root.workspace.heroColor }
        }
        MapText {
            Layout.fillWidth: true
            visible: root.incomplete
            text: root.workspace.strings.t("visual.partialCoverage")
            color: Color.urgent
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(7)
            Rectangle { anchors.fill: parent; color: Util.alpha(Color.popups.text, 0.08); radius: Style.space(3) }
            Row {
                anchors.fill: parent
                Repeater {
                    model: root.categories
                    Rectangle {
                        required property string modelData
                        required property int index
                        height: parent.height
                        width: root.measured && root.service.mappedBytes > 0 ? parent.width * root.service.categories[modelData] / root.service.mappedBytes : 0
                        color: root.workspace.palette[Model.categoryKeys.indexOf(modelData)]
                    }
                }
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(3)
            Repeater {
                model: root.categories
                RowLayout {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Style.space(4)
                    Rectangle { implicitWidth: Style.space(5); implicitHeight: Style.space(5); radius: width / 2; color: root.workspace.palette[Model.categoryKeys.indexOf(modelData)] }
                    MapText { Layout.fillWidth: true; text: root.workspace.strings.t("compact." + modelData); font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                    MapText { text: root.measured ? root.workspace.size(root.service.categories[modelData], root.incomplete) : root.workspace.strings.t("size.unknown"); font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.7) }
                }
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.service ? root.workspace.strings.t("visual.scanCoverage").arg(root.workspace.number(root.service.completedApps)).arg(root.workspace.number(root.service.apps.length)) : root.workspace.strings.t("size.unknown")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.6)
            wrapMode: Text.Wrap
        }
    }
    RowLayout {
        Layout.fillWidth: true
        MapText { Layout.fillWidth: true; text: root.workspace.strings.t("workspace.recentScans"); font.weight: Font.DemiBold }
        Ui.Button {
            text: root.workspace.strings.t("visual.yearEntry").arg(new Date().toLocaleDateString(Qt.locale(I18n.formatLocale), "yyyy"))
            focusable: true
            fontSize: Style.font.caption
            horizontalPadding: Style.space(6)
            onClicked: root.workspace.navigate("year")
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        MapIconButton {
            icon: "history"
            label: root.workspace.strings.t("workspace.history")
            onClicked: root.workspace.navigate("history")
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
    }
    MapHistoryChart { Layout.fillWidth: true; workspace: root.workspace; allowDetails: false; compact: true }
    GridLayout {
        Layout.fillWidth: true
        visible: !root.workspace.prefs || root.workspace.prefs.showHighlights
        columns: 2
        columnSpacing: Style.space(7)
        rowSpacing: Style.space(7)
        Repeater {
            model: ["cache", "growing", "installations", "leftovers"]
            MapMetricCard {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                icon: modelData === "growing" ? "growth" : modelData === "installations" ? "package" : modelData
                label: root.workspace.strings.t("workspace." + modelData)
                value: modelData === "cache" ? root.cache.length ? root.workspace.size(root.cache[0].bytes, root.cache[0].partial) : root.workspace.strings.t("size.unknown")
                    : modelData === "growing" ? root.growing.length ? root.workspace.strings.t("workspace.positive").arg(root.workspace.size(root.growing[0].delta)) : root.workspace.strings.t("workspace.noDelta")
                    : modelData === "installations" ? root.view && root.view.installations.knownApps > 0 ? root.workspace.size(root.view.installations.totalBytes) : root.workspace.strings.t("size.unknown")
                    : root.workspace.ready && root.view && (!root.view.warnings.length || root.view.leftovers.length > 0) ? root.workspace.number(root.view.leftovers.length) : root.workspace.strings.t("size.unknown")
                detail: modelData === "cache" ? root.cache.length ? root.cache[0].name : root.workspace.strings.t("workspace.noCache")
                    : modelData === "growing" ? root.growing.length ? root.growing[0].name : root.workspace.strings.t("workspace.noComparableShort")
                    : root.workspace.strings.t(modelData === "installations" ? "workspace.uniquePackages" : "workspace.noLauncher")
                tint: root.workspace.insightColor
                actionable: true
                onClicked: root.workspace.navigate(modelData)
                onFocused: function(item) { root.workspace.reveal(item); }
            }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: Style.space(4)
        rowSpacing: Style.space(4)
        Repeater {
            model: root.workspace.prefs && !root.workspace.prefs.showHighlights ? ["cache", "growing", "installations", "leftovers", "mappings", "alerts"] : ["history", "mappings", "alerts"]
            Ui.Button {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: root.workspace.strings.t("visual.nav." + modelData)
                focusable: true
                fontSize: Style.font.caption
                horizontalPadding: Style.space(4)
                onClicked: root.workspace.navigate(modelData)
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
    }
    Ui.Button {
        Layout.fillWidth: true
        visible: !!root.view && root.view.warnings.length > 0
        text: root.workspace.strings.tn("workspace.warningCount", root.view ? root.view.warnings.length : 0).arg(root.workspace.number(root.view ? root.view.warnings.length : 0))
        focusable: true
        fontSize: Style.font.caption
        onClicked: root.workspace.navigate("notes")
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
}
