import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "../components"

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: false
    property bool infoOpen: false
    readonly property var view: workspace.view
    readonly property var cache: view ? view.insights.cache : []
    readonly property var growing: view ? view.insights.growing : []
    readonly property var pulse: {
        var result = {grew: 0, shrank: 0, stable: 0, compared: 0, unavailable: 0};
        var rows = view ? view.growth : [];
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            if (row.mode !== "overview") continue;
            if (!row.comparable) { result.unavailable++; continue; }
            result.compared++;
            if (row.delta > 0) result.grew++;
            else if (row.delta < 0) result.shrank++;
            else result.stable++;
        }
        return result;
    }
    readonly property var directions: [
        {key: "grew", icon: "growth", count: pulse.grew, tint: workspace.insightColor},
        {key: "shrank", icon: "shrink", count: pulse.shrank, tint: workspace.heroColor},
        {key: "stable", icon: "check", count: pulse.stable, tint: Util.alpha(Color.popups.text, 0.65)}
    ]
    readonly property bool showHighlights: !workspace.prefs || workspace.prefs.showHighlights
    function toggleInfo() { infoOpen = !infoOpen; }
    spacing: Style.space(8)

    component Route: Ui.Button {
        id: route
        required property string destination
        required property string label
        required property string symbol
        property string value: ""
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: Math.max(Style.space(40), routeContent.implicitHeight + Style.space(16))
        text: ""
        focusable: true
        radius: Style.space(10)
        background: Util.alpha(root.workspace.insightColor, 0.065)
        foreground: Color.popups.text
        accent: root.workspace.insightColor
        Accessible.name: label
        Accessible.description: value
        onClicked: root.workspace.navigate(destination)
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        RowLayout {
            id: routeContent
            anchors.centerIn: parent
            width: parent.width - Style.space(16)
            spacing: Style.space(6)
            MapGlyph { icon: route.symbol; color: root.workspace.insightColor; font.pixelSize: Style.font.caption }
            MapText {
                Layout.fillWidth: true
                text: route.label
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
            }
            MapText {
                visible: route.value !== ""
                text: route.value
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
                color: root.workspace.insightColor
            }
        }
    }

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
        radius: Style.space(12)
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            MapText {
                Layout.fillWidth: true
                text: root.workspace.strings.t("dashboard.changes")
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            MapIconButton {
                icon: "history"
                label: root.workspace.strings.t("workspace.history")
                onClicked: root.workspace.navigate("history")
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
            MapIconButton {
                icon: "calendar"
                label: root.workspace.strings.t("visual.yearInsights")
                onClicked: root.workspace.navigate("year")
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Repeater {
                model: root.directions
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Style.space(3)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(5)
                        MapGlyph { icon: modelData.icon; color: modelData.tint; font.pixelSize: Style.font.caption }
                        MapText {
                            Layout.fillWidth: true
                            text: root.pulse.compared ? root.workspace.number(modelData.count) : root.workspace.strings.t("workspace.noDelta")
                            font.pixelSize: Style.font.heading * 1.2
                            font.weight: Font.DemiBold
                            color: modelData.tint
                        }
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.workspace.strings.t("dashboard." + modelData.key)
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.7)
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
        MapText {
            Layout.fillWidth: true
            text: !root.view ? root.workspace.strings.t("dashboard.awaiting")
                : root.pulse.compared ? root.workspace.strings.tn("dashboard.compared", root.pulse.compared).arg(root.workspace.number(root.pulse.compared))
                : root.workspace.strings.t(root.view.settings.historyEnabled ? "dashboard.noComparison" : "dashboard.historyOff")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.6)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            visible: root.infoOpen && root.pulse.unavailable > 0
            text: root.workspace.strings.tn("dashboard.unavailable", root.pulse.unavailable).arg(root.workspace.number(root.pulse.unavailable))
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
    }
    GridLayout {
        Layout.fillWidth: true
        visible: root.showHighlights
        columns: 2
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)
        Repeater {
            model: ["cache", "growing", "installations", "leftovers"]
            MapMetricCard {
                required property string modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignVCenter
                radius: Style.space(10)
                icon: modelData === "growing" ? "growth" : modelData === "installations" ? "package" : modelData
                label: root.workspace.strings.t("workspace." + modelData)
                value: modelData === "cache" ? root.cache.length ? root.workspace.size(root.cache[0].bytes, root.cache[0].partial) : root.workspace.strings.t("size.unknown")
                    : modelData === "growing" ? root.growing.length ? root.workspace.strings.t("workspace.positive").arg(root.workspace.size(root.growing[0].delta)) : root.workspace.strings.t("workspace.noDelta")
                    : modelData === "installations" ? root.view && root.view.installations.knownApps > 0 ? root.workspace.size(root.view.installations.totalBytes) : root.workspace.strings.t("size.unknown")
                    : root.view && (root.view.leftovers.length > 0 || root.view.refreshedAt > 0 && !root.view.warnings.length) ? root.workspace.number(root.view.leftovers.length) : root.workspace.strings.t("size.unknown")
                detail: modelData === "cache" ? root.cache.length ? root.cache[0].name : root.workspace.strings.t("dashboard.noCache")
                    : modelData === "growing" ? root.growing.length ? root.workspace.strings.t("dashboard.growthSource").arg(root.growing[0].name).arg(root.workspace.strings.t(root.growing[0].mode === "deep" ? "workspace.deep" : "overview")) : root.workspace.strings.t("workspace.noComparableShort")
                    : root.workspace.strings.t(modelData === "installations" ? "dashboard.packageBasis" : "dashboard.reviewOnly")
                tint: root.workspace.insightColor
                actionable: true
                onClicked: root.workspace.navigate(modelData)
                onFocused: function(item) { root.workspace.reveal(item); }
            }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        visible: !root.showHighlights
        columns: 2
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)
        Repeater {
            model: ["cache", "growing", "installations", "leftovers"]
            Route {
                required property string modelData
                destination: modelData
                symbol: modelData === "growing" ? "growth" : modelData === "installations" ? "package" : modelData
                label: root.workspace.strings.t("workspace." + modelData)
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)
        Route {
            destination: "mappings"
            symbol: "link"
            label: root.workspace.strings.t("dashboard.mappings")
            value: root.view ? root.workspace.number(root.view.mappings.length) : root.workspace.strings.t("workspace.noDelta")
        }
        Route {
            destination: "alerts"
            symbol: "alert"
            label: root.workspace.strings.t("dashboard.alerts")
            value: root.view ? root.workspace.number(root.view.alerts.length) : root.workspace.strings.t("workspace.noDelta")
        }
    }
    Route {
        visible: !!root.view && root.view.warnings.length > 0
        destination: "notes"
        symbol: "info"
        label: root.workspace.strings.t("dashboard.notes")
        value: root.view ? root.workspace.number(root.view.warnings.length) : ""
    }
}
