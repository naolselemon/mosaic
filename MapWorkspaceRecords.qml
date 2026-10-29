import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: false
    readonly property var view: workspace.view
    readonly property string page: workspace.page
    property bool infoOpen: false
    property string coverage: "all"
    property string packageKind: "all"
    property bool missingCacheOpen: false
    readonly property var installations: view ? view.installations : null
    readonly property var ranked: !view ? [] : page === "cache" ? view.insights.cache.slice().sort(function(a, b) { return b.bytes - a.bytes; }) : page === "growing" ? view.insights.growing.filter(function(row) { return row.comparable && row.delta > 0; }).sort(function(a, b) { return b.delta - a.delta; }) : []
    readonly property real largest: ranked.reduce(function(value, row) { return Math.max(value, root.page === "cache" ? row.bytes : row.delta); }, 1)
    readonly property var missingCache: {
        if (page !== "cache" || !workspace.service) return [];
        var known = Object.create(null);
        for (var i = 0; i < ranked.length; i++) known[ranked[i].id] = true;
        return workspace.service.apps.filter(function(app) { return !known[app.id]; });
    }
    readonly property var packageGroups: installations ? installations.groups.filter(function(group) {
        return (root.coverage === "all" || (root.coverage === "known") === (group.status === "known")) && (root.packageKind === "all" || root.packageKind === group.kind);
    }).sort(function(a, b) { return (b.bytes === null ? -1 : b.bytes) - (a.bytes === null ? -1 : a.bytes) || a.name.localeCompare(b.name); }) : []
    readonly property real largestPackage: installations ? installations.groups.reduce(function(value, group) { return Math.max(value, group.bytes === null ? 0 : group.bytes); }, 1) : 1
    readonly property var unknownApps: {
        if (!installations || coverage === "known") return [];
        var kinds = Object.create(null);
        for (var i = 0; i < installations.groups.length; i++) kinds[installations.groups[i].key] = installations.groups[i].kind;
        return installations.apps.filter(function(app) { return app.status === "unknown" && (root.packageKind === "all" || kinds[app.groupKey] === root.packageKind); });
    }
    readonly property var alerts: page === "alerts" && view ? view.alerts.slice().sort(function(a, b) { return b.at - a.at; }) : []
    function toggleInfo() { infoOpen = !infoOpen; }
    function helpKey() { return page === "cache" || page === "growing" ? "workspace.insightsHelp" : "workspace." + page + "Help"; }
    spacing: Style.space(8)

    MapText {
        Layout.fillWidth: true
        visible: root.infoOpen
        text: root.workspace.strings.t(root.helpKey())
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.7)
        wrapMode: Text.Wrap
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.page === "cache" || root.page === "growing"
        spacing: Style.space(8)
        MapMetricCard {
            Layout.fillWidth: true
            visible: !root.ranked.length
            icon: root.page === "cache" ? "cache" : "growth"
            label: root.workspace.strings.t(root.page === "cache" ? "workspace.cache" : "workspace.growing")
            value: root.ranked.length ? root.page === "cache" ? root.workspace.size(root.ranked[0].bytes, root.ranked[0].partial) : root.workspace.strings.t("workspace.positive").arg(root.workspace.size(root.ranked[0].delta)) : root.workspace.strings.t("workspace.noDelta")
            detail: root.ranked.length ? root.ranked[0].name : root.workspace.strings.t(root.page === "cache" ? "workspace.noCache" : "workspace.noComparableShort")
            tint: root.workspace.insightColor
        }
        Repeater {
            model: root.ranked
            MapSection {
                id: rankedRow
                required property var modelData
                required property int index
                property bool expanded: false
                Layout.fillWidth: true
                title: modelData.name
                RowLayout {
                    Layout.fillWidth: true
                    MapText { text: root.workspace.number(rankedRow.index + 1); font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.5) }
                    MapText {
                        Layout.fillWidth: true
                        text: root.page === "cache" ? root.workspace.size(rankedRow.modelData.bytes, rankedRow.modelData.partial) : root.workspace.strings.t("workspace.positive").arg(root.workspace.size(rankedRow.modelData.delta))
                        font.pixelSize: Style.font.heading
                        font.weight: Font.DemiBold
                        color: root.page === "cache" && rankedRow.modelData.partial ? Color.urgent : root.workspace.insightColor
                        elide: Text.ElideRight
                    }
                    MapIconButton {
                        icon: "info"
                        label: root.workspace.strings.t(rankedRow.expanded ? "workspace.hideDetails" : "workspace.details")
                        selected: rankedRow.expanded
                        onClicked: rankedRow.expanded = !rankedRow.expanded
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Style.space(5)
                    radius: height / 2
                    color: Util.alpha(root.workspace.insightColor, 0.1)
                    Rectangle {
                        anchors.left: parent.left
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(1, (root.page === "cache" ? rankedRow.modelData.bytes : rankedRow.modelData.delta) / root.largest))
                        color: root.page === "cache" && rankedRow.modelData.partial ? Color.urgent : root.workspace.insightColor
                    }
                }
                MapText {
                    Layout.fillWidth: true
                    visible: root.page === "growing"
                    text: root.workspace.strings.t(rankedRow.modelData.mode === "deep" ? "workspace.deep" : "overview")
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.65)
                }
                MapText {
                    Layout.fillWidth: true
                    visible: rankedRow.expanded
                    text: root.page === "growing" ? root.workspace.strings.t("workspace.growthScope").arg(root.workspace.strings.t(rankedRow.modelData.mode === "deep" ? "workspace.deep" : "overview")).arg(root.workspace.date(rankedRow.modelData.previousAt)).arg(root.workspace.date(rankedRow.modelData.at)) : root.workspace.strings.t("visual.cacheBasis")
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                }
                MapText { Layout.fillWidth: true; visible: rankedRow.expanded; text: rankedRow.modelData.id; font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.6); wrapMode: Text.WrapAnywhere }
                Ui.Button {
                    visible: rankedRow.expanded
                    text: root.workspace.strings.t("visual.viewApp")
                    focusable: true
                    fontSize: Style.font.caption
                    enabled: !!root.workspace.service && root.workspace.service.apps.some(function(app) { return app.id === rankedRow.modelData.id; })
                    onClicked: root.workspace.appRequested(rankedRow.modelData.id)
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
            }
        }
        Ui.Button {
            Layout.fillWidth: true
            visible: root.page === "cache" && root.missingCache.length > 0
            text: root.workspace.strings.tn("visual.outsideCacheRanking", root.missingCache.length).arg(root.workspace.number(root.missingCache.length))
            selected: root.missingCacheOpen
            focusable: true
            fontSize: Style.font.caption
            onClicked: root.missingCacheOpen = !root.missingCacheOpen
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        Repeater {
            model: root.missingCacheOpen ? root.missingCache : []
            Ui.Button {
                required property var modelData
                Layout.fillWidth: true
                text: root.workspace.strings.t("workspace.appIdentity").arg(modelData.name).arg(modelData.id)
                focusable: true
                leftAlign: true
                fontSize: Style.font.caption
                onClicked: root.workspace.appRequested(modelData.id)
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
        Ui.Button {
            Layout.fillWidth: true
            text: root.workspace.strings.t(root.page === "growing" ? "visual.allComparisons" : "workspace.history")
            focusable: true
            fontSize: Style.font.caption
            onClicked: root.workspace.navigate("history")
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.page === "installations"
        spacing: Style.space(8)
        MapMetricCard {
            Layout.fillWidth: true
            icon: "package"
            label: root.workspace.strings.t("workspace.uniquePackages")
            value: root.installations && root.installations.knownApps > 0 ? root.workspace.size(root.installations.totalBytes) : root.workspace.strings.t("size.unknown")
            detail: root.installations && root.installations.scannedAt > 0 ? root.workspace.date(root.installations.scannedAt) : root.workspace.strings.t("workspace.notRefreshed")
            tint: root.workspace.insightColor
            ratio: root.installations && root.installations.knownApps + root.installations.unresolvedApps > 0 ? root.installations.knownApps / (root.installations.knownApps + root.installations.unresolvedApps) : -1
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("workspace.packageCoverage").arg(root.workspace.number(root.installations ? root.installations.knownApps : 0)).arg(root.workspace.number(root.installations ? root.installations.unresolvedApps : 0))
            font.pixelSize: Style.font.caption
            color: root.installations && root.installations.unresolvedApps > 0 ? Color.urgent : Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["all", "known", "unknown"]
                Ui.Button {
                    required property string modelData
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("visual.coverage." + modelData)
                    selected: root.coverage === modelData
                    focusable: true
                    fontSize: Style.font.caption
                    onClicked: root.coverage = modelData
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["all", "pacman", "flatpak"]
                Ui.Button {
                    required property string modelData
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("visual.package." + modelData)
                    selected: root.packageKind === modelData
                    focusable: true
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(5)
                    onClicked: root.packageKind = modelData
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
            }
        }
        Repeater {
            model: root.page === "installations" ? root.packageGroups : []
            MapSection {
                id: packageRow
                required property var modelData
                property bool expanded: false
                Layout.fillWidth: true
                title: modelData.name
                RowLayout {
                    Layout.fillWidth: true
                    MapGlyph { icon: "package"; color: root.workspace.insightColor }
                    MapText { Layout.fillWidth: true; text: root.workspace.size(packageRow.modelData.bytes); font.pixelSize: Style.font.heading; font.weight: Font.DemiBold; color: packageRow.modelData.status === "known" ? root.workspace.insightColor : Color.urgent; elide: Text.ElideRight }
                    MapIconButton {
                        icon: "info"
                        label: root.workspace.strings.t(packageRow.expanded ? "workspace.hideDetails" : "workspace.details")
                        selected: packageRow.expanded
                        onClicked: packageRow.expanded = !packageRow.expanded
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: packageRow.modelData.bytes !== null
                    implicitHeight: Style.space(4)
                    color: Util.alpha(root.workspace.insightColor, 0.1)
                    radius: height / 2
                    Rectangle { anchors.left: parent.left; height: parent.height; radius: parent.radius; width: parent.width * Math.max(0, Math.min(1, packageRow.modelData.bytes / root.largestPackage)); color: root.workspace.insightColor }
                }
                MapText {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("workspace.packageKind").arg(root.workspace.strings.t("workspace.kind." + packageRow.modelData.kind)).arg(root.workspace.strings.tn("workspace.launchers", packageRow.modelData.appIds.length).arg(root.workspace.number(packageRow.modelData.appIds.length)))
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.7)
                    wrapMode: Text.Wrap
                }
                MapText { Layout.fillWidth: true; visible: packageRow.expanded && packageRow.modelData.appIds.length > 1; text: root.workspace.strings.t("workspace.sharedPackage"); font.pixelSize: Style.font.caption; color: root.workspace.insightColor; wrapMode: Text.Wrap }
                Repeater {
                    model: packageRow.expanded ? packageRow.modelData.appIds : []
                    MapText {
                        required property string modelData
                        Layout.fillWidth: true
                        text: root.workspace.strings.t("workspace.appIdentity").arg(root.workspace.appName(modelData)).arg(modelData)
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WrapAnywhere
                    }
                }
                MapText { Layout.fillWidth: true; visible: packageRow.expanded && text !== ""; text: packageRow.modelData.reason; font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.7); wrapMode: Text.Wrap }
            }
        }
        MapText { Layout.fillWidth: true; visible: root.unknownApps.length > 0; text: root.workspace.strings.t("workspace.unresolved"); font.weight: Font.DemiBold }
        Repeater {
            model: root.page === "installations" ? root.unknownApps : []
            MapSection {
                id: unknownRow
                required property var modelData
                property bool expanded: false
                Layout.fillWidth: true
                title: root.workspace.appName(modelData.id)
                RowLayout {
                    Layout.fillWidth: true
                    MapText { Layout.fillWidth: true; text: root.workspace.strings.t("size.unknown"); font.pixelSize: Style.font.caption; color: Color.urgent }
                    MapIconButton {
                        icon: "info"
                        label: root.workspace.strings.t(unknownRow.expanded ? "workspace.hideDetails" : "workspace.details")
                        selected: unknownRow.expanded
                        onClicked: unknownRow.expanded = !unknownRow.expanded
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                }
                MapText { Layout.fillWidth: true; visible: unknownRow.expanded; text: unknownRow.modelData.id; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere; color: Util.alpha(Color.popups.text, 0.65) }
                MapText { Layout.fillWidth: true; visible: unknownRow.expanded; text: unknownRow.modelData.reason; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
            }
        }
        MapText { Layout.fillWidth: true; visible: !root.packageGroups.length && !root.unknownApps.length; text: root.workspace.strings.t("visual.noPackages"); font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
        Repeater {
            model: root.page === "installations" && root.installations ? root.installations.issues : []
            MapText { required property string modelData; Layout.fillWidth: true; text: modelData; color: Color.urgent; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.page === "leftovers"
        spacing: Style.space(8)
        MapText {
            Layout.fillWidth: true
            visible: !root.view || !root.view.leftovers.length
            text: root.workspace.strings.t(root.view && root.view.refreshedAt > 0 ? "workspace.noLeftovers" : "workspace.notRefreshed")
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
        }
        Repeater {
            model: root.page === "leftovers" && root.view ? root.view.leftovers : []
            MapSection {
                id: leftoverRow
                required property var modelData
                property bool expanded: false
                Layout.fillWidth: true
                title: modelData.name
                RowLayout {
                    Layout.fillWidth: true
                    MapText { Layout.fillWidth: true; text: root.workspace.size(leftoverRow.modelData.bytes, leftoverRow.modelData.status !== "complete"); color: root.workspace.insightColor; font.pixelSize: Style.font.heading; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    MapIconButton {
                        icon: "folder"
                        label: root.workspace.strings.t("openFolder")
                        enabled: !!root.workspace.service && !root.workspace.service.actionBusy && (leftoverRow.modelData.status === "complete" || leftoverRow.modelData.status === "partial")
                        onClicked: root.workspace.service.openPath(leftoverRow.modelData.path)
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                    MapIconButton {
                        icon: "copy"
                        label: root.workspace.strings.t(root.workspace.service && root.workspace.service.copiedPath === leftoverRow.modelData.path ? "copied" : "copyPath")
                        enabled: !!root.workspace.service
                        onClicked: root.workspace.service.copyPath(leftoverRow.modelData.path)
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                    MapIconButton {
                        icon: "info"
                        label: root.workspace.strings.t(leftoverRow.expanded ? "workspace.hideDetails" : "workspace.details")
                        selected: leftoverRow.expanded
                        onClicked: leftoverRow.expanded = !leftoverRow.expanded
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                }
                MapText { Layout.fillWidth: true; text: root.workspace.strings.t("workspace.possibleLeftover"); color: Color.urgent; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
                MapText { Layout.fillWidth: true; text: leftoverRow.modelData.path; font.pixelSize: Style.font.caption; elide: Text.ElideMiddle; visible: !leftoverRow.expanded; color: Util.alpha(Color.popups.text, 0.65) }
                MapText { Layout.fillWidth: true; visible: leftoverRow.expanded; text: leftoverRow.modelData.path; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere }
                MapText {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("workspace.pathStatus").arg(root.workspace.strings.t("compact." + leftoverRow.modelData.category)).arg(root.workspace.strings.t("status." + leftoverRow.modelData.status))
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.7)
                    wrapMode: Text.Wrap
                }
                MapText { Layout.fillWidth: true; visible: leftoverRow.expanded; text: leftoverRow.modelData.evidence; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
                MapText { Layout.fillWidth: true; visible: leftoverRow.expanded && text !== ""; text: leftoverRow.modelData.reason; font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.7); wrapMode: Text.Wrap }
            }
        }
        MapText {
            Layout.fillWidth: true
            visible: !!root.workspace.service && root.workspace.service.actionError !== ""
            text: root.workspace.service ? root.workspace.service.actionError : ""
            color: Color.urgent
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }
        Repeater {
            model: root.page === "leftovers" && root.view ? root.view.warnings : []
            MapText { required property string modelData; Layout.fillWidth: true; text: modelData; color: Color.urgent; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.page === "alerts"
        spacing: Style.space(8)
        MapMetricCard {
            Layout.fillWidth: true
            icon: "alert"
            label: root.workspace.strings.t("workspace.threshold")
            value: root.workspace.settings ? root.workspace.size(root.workspace.settings.thresholdBytes) : root.workspace.strings.t("size.unknown")
            detail: root.workspace.strings.t(root.workspace.settings && root.workspace.settings.alertsEnabled ? "visual.alertsOn" : "visual.alertsOff")
            tint: root.workspace.insightColor
            actionable: true
            onClicked: root.workspace.navigate("settings")
            onFocused: function(item) { root.workspace.reveal(item); }
        }
        MapText { Layout.fillWidth: true; visible: !root.alerts.length; text: root.workspace.strings.t("workspace.noAlerts"); font.pixelSize: Style.font.bodySmall; wrapMode: Text.Wrap }
        Repeater {
            model: root.alerts
            RowLayout {
                id: alertRow
                required property var modelData
                property bool expanded: false
                Layout.fillWidth: true
                spacing: Style.space(8)
                Item {
                    Layout.preferredWidth: Style.space(8)
                    Layout.fillHeight: true
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 1; height: parent.height; color: Util.alpha(root.workspace.insightColor, 0.25) }
                    Rectangle { width: Style.space(7); height: width; radius: width / 2; y: Style.space(15); color: root.workspace.insightColor }
                }
                MapSection {
                    Layout.fillWidth: true
                    title: alertRow.modelData.name
                    RowLayout {
                        Layout.fillWidth: true
                        MapText { Layout.fillWidth: true; text: root.workspace.strings.t("workspace.positive").arg(root.workspace.size(alertRow.modelData.delta)); color: root.workspace.insightColor; font.pixelSize: Style.font.heading; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        MapIconButton {
                            icon: "info"
                            label: root.workspace.strings.t(alertRow.expanded ? "workspace.hideDetails" : "workspace.details")
                            selected: alertRow.expanded
                            onClicked: alertRow.expanded = !alertRow.expanded
                            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                        }
                    }
                    MapText { Layout.fillWidth: true; text: root.workspace.date(alertRow.modelData.at); font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.7); wrapMode: Text.Wrap }
                    MapText { Layout.fillWidth: true; visible: alertRow.expanded; text: root.workspace.strings.t("workspace.triggerThreshold").arg(root.workspace.size(alertRow.modelData.thresholdBytes)); font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
                    MapText { Layout.fillWidth: true; visible: alertRow.expanded; text: alertRow.modelData.id; font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.65); wrapMode: Text.WrapAnywhere }
                }
            }
        }
        Ui.Button { Layout.fillWidth: true; text: root.workspace.strings.t("workspace.alertSettings"); focusable: true; fontSize: Style.font.caption; onClicked: root.workspace.navigate("settings"); onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this) }
    }
    Repeater {
        model: root.page === "notes" && root.view ? root.view.warnings : []
        MapSection {
            id: noteRow
            required property string modelData
            Layout.fillWidth: true
            title: root.workspace.strings.t("workspace.notes")
            MapText { Layout.fillWidth: true; text: noteRow.modelData; color: Color.urgent; font.pixelSize: Style.font.bodySmall; wrapMode: Text.Wrap }
        }
    }
}
