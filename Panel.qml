import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui as Ui
import "ViewModel.js" as Model
import "Presentation.js" as Presentation

Ui.Panel {
    id: root
    moduleName: "naolselemon.mosaic"
    manageIpc: false
    property var anchorItem: null
    property var hostWidget: null
    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(root.moduleName) : null
    readonly property var translations: strings
    readonly property var apps: service ? service.apps : []
    readonly property bool busy: !!service && service.busy
    readonly property bool mutationBusy: busy || !!service && service.workspaceBusy
    property bool workspaceOpen: false
    property int workspaceSide: -1
    property real workspaceReveal: workspaceOpen ? 1 : 0
    readonly property var uiPrefs: hostWidget ? hostWidget.uiPrefs : Presentation.preferences({})
    readonly property color heroColor: Presentation.tint(uiPrefs.heroColor, Color.accent, Color.popups.text, Color.urgent)
    readonly property bool motionEnabled: uiPrefs.motion && Style.duration(200) > 0
    onMotionEnabledChanged: if (!motionEnabled) workspaceSlide.complete()
    Behavior on workspaceReveal {
        NumberAnimation {
            id: workspaceSlide
            duration: root.motionEnabled ? Style.duration(root.workspaceOpen ? 200 : 140) : 0
            easing.type: Easing.OutCubic
            onRunningChanged: if (!running) {
                content.forceActiveFocus();
                if (!root.workspaceOpen) homeLogo.play();
            }
        }
    }
    readonly property var filteredApps: Model.appsFor(apps, query)
    readonly property var coverage: Model.coverage(apps)
    readonly property var palette: [heroColor, Qt.tint(heroColor, Util.alpha(Color.popups.text, 0.7)), Qt.tint(heroColor, Util.alpha(Color.urgent, 0.7)), Color.urgent]
    property string query: ""
    property bool searching: false
    property bool expanded: false
    property int legendHoverIndex: -1
    property int legendFocusIndex: -1
    property string cursorId: ""
    property string selectedId: ""
    property var selectedSnapshot: null
    readonly property bool showingDeep: !!service && !!service.deepResult && service.deepResult.id === selectedId
    readonly property var selectedApp: selectedId ? (showingDeep ? service.deepResult : Model.findApp(apps, selectedId) || selectedSnapshot) : null
    readonly property var paths: selectedApp ? Model.orderedPaths(selectedApp.paths) : []
    property string cursorPath: ""
    property string cursorActionPath: ""
    readonly property int appIndex: Model.indexFor(filteredApps, cursorId)
    readonly property int pathIndex: Model.indexFor(paths, cursorPath, "path")
    readonly property var currentPath: pathIndex >= 0 ? paths[pathIndex] : null
    readonly property bool detail: selectedId !== ""
    readonly property bool overviewBusy: busy && service.scanMode === "overview"
    readonly property bool overviewPartial: !!service && (service.partial || service.limited || overviewBusy)
    readonly property bool overviewMeasured: apps.some(function(app) {
        return (app.paths || []).some(function(path) { return path.confidence === "known" && path.bytes !== null && path.bytes !== undefined; });
    })
    readonly property bool previousSnapshot: detail && !showingDeep && !Model.findApp(apps, selectedId)
    readonly property string overviewSize: {
        if (!service || !service.ready && !apps.length) return strings.t(overviewBusy ? "measuring" : "size.unknown");
        if (!overviewMeasured && (coverage.mapped > 0 || overviewBusy)) return strings.t("size.unknown");
        return overviewPartial ? strings.t("size.lowerBound").arg(size(service.mappedBytes)) : size(service.mappedBytes);
    }
    readonly property string scanError: {
        if (!service || !service.error) return "";
        if (service.scanMode !== "deep") return service.error;
        var app = Model.findApp(apps, service.scanTargetId);
        return strings.t("deepScanError").arg(app ? app.name : service.scanTargetId).arg(service.error);
    }
    readonly property string actionStatus: service ? service.actionError || (service.actionBusy ? strings.t("actionWorking") : "") : ""
    readonly property string jobProgress: {
        if (!service) return "";
        var progress = service.scanTotalPaths > 0
            ? strings.t("compact.progress").arg(I18n.formatNumber(service.scanCompletedPaths)).arg(I18n.formatNumber(service.scanTotalPaths))
            : strings.t("compact.working");
        if (service.scanMode !== "deep") return progress;
        var app = Model.findApp(apps, service.scanTargetId);
        return strings.t("compact.scoped").arg(app ? app.name : service.scanTargetId).arg(progress);
    }

    Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    function open() {
        if (service) service.ensureScan();
        controller.show();
    }
    function selectApp(id) {
        var app = Model.findApp(apps, id);
        if (!app) return;
        selectedSnapshot = app;
        selectedId = id;
        cursorId = id;
        cursorPath = "";
        cursorActionPath = "";
        detailList.positionViewAtBeginning();
        content.forceActiveFocus();
    }
    function search(value) {
        selectedId = "";
        searching = true;
        query = String(value || "");
        cursorId = "";
        overview.positionViewAtBeginning();
        searchField.forceActiveFocus();
        searchField.selectAll();
    }
    function closeSearch() {
        searching = false;
        query = "";
        cursorId = "";
        overview.positionViewAtBeginning();
        content.forceActiveFocus();
    }
    function toggleSearch() {
        if (searching) closeSearch();
        else search(query);
    }
    function showWorkspace(target) {
        workspaceSide = target === "settings" ? 1 : -1;
        workspaceView.openPage(target || "dashboard");
        workspaceOpen = true;
        if (service && ["category", "diagnostics", "shortcuts"].indexOf(target) < 0) service.ensureWorkspace();
        content.forceActiveFocus();
    }
    function showCategory(key) {
        if (Model.categoryKeys.indexOf(key) < 0) return;
        workspaceView.categoryKey = key;
        showWorkspace("category");
    }
    function back() {
        if (workspaceOpen) {
            if (workspaceView.goBack()) return;
            workspaceOpen = false;
        }
        else selectedId = "";
        content.forceActiveFocus();
        Qt.callLater(function() { if (!root.detail && root.appIndex >= 0) overview.positionViewAtIndex(root.appIndex, ListView.Contain); });
    }
    function handleEscape() {
        if (workspaceOpen || detail) back();
        else if (searching && query) {
            query = "";
            cursorId = "";
            searchField.forceActiveFocus();
        } else if (searching) closeSearch();
        else close();
    }
    function moveCursor(delta) {
        if (detail) {
            if (!paths.length) return;
            var nextPath = Math.max(0, Math.min(paths.length - 1, pathIndex + delta));
            cursorPath = paths[nextPath].path;
            cursorActionPath = "";
            detailList.positionViewAtIndex(nextPath, ListView.Contain);
        } else {
            if (!filteredApps.length) return;
            var nextApp = Math.max(0, Math.min(filteredApps.length - 1, appIndex + delta));
            cursorId = filteredApps[nextApp].id;
            overview.positionViewAtIndex(nextApp, ListView.Contain);
        }
        content.forceActiveFocus();
    }
    function activate() {
        if (!detail && appIndex >= 0) selectApp(filteredApps[appIndex].id);
        else if (detail && pathIndex >= 0) {
            cursorActionPath = "";
            var item = detailList.itemAtIndex(pathIndex);
            if (item) item.toggleBreakdown();
        }
    }
    function openCurrent() {
        if (service && currentPath && !service.actionBusy) service.openPath(cursorActionPath || currentPath.path);
    }
    function copyCurrent() {
        if (service && currentPath) service.copyPath(cursorActionPath || currentPath.path);
    }
    function size(value) { return Model.bytes(value, strings, I18n); }
    function categorySize(key) {
        if (!service || !service.ready || !overviewMeasured && (coverage.mapped > 0 || overviewBusy))
            return strings.t("size.unknown");
        var result = size(service.categories[key] || 0);
        return overviewPartial ? strings.t("size.lowerBound").arg(result) : result;
    }
    function deepScan() {
        if (service && !mutationBusy && selectedApp && Model.findApp(apps, selectedId)) service.deepScan(selectedId);
    }
    function time(value) { return value > 0 ? new Date(value).toLocaleTimeString(Qt.locale(I18n.formatLocale), Locale.ShortFormat) : strings.t("compact.notScanned"); }
    function revealAction(item) {
        var y = item.mapToItem(detailList.contentItem, 0, 0).y;
        if (y < detailList.contentY) detailList.contentY = y;
        else if (y + item.height > detailList.contentY + detailList.height)
            detailList.contentY = y + item.height - detailList.height;
    }
    function scrollView(view, direction) {
        var start = view.originY;
        var end = Math.max(start, start + view.contentHeight - view.height);
        view.contentY = Math.max(start, Math.min(end, view.contentY + direction * view.height * 0.8));
    }
    function page(direction) {
        if (detail) scrollView(detailList, direction);
        else moveCursor(direction * Math.max(1, Math.floor(overview.height / Style.space(36))));
    }

    onFilteredAppsChanged: Qt.callLater(function() {
        if (!root.detail && root.appIndex >= 0) overview.positionViewAtIndex(root.appIndex, ListView.Contain);
    })
    Connections {
        target: root.service
        function onAppsChanged() {
            var app = Model.findApp(root.apps, root.selectedId);
            if (app) root.selectedSnapshot = app;
        }
    }

    Ui.KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        popoutSwitching: root.popoutSwitching
        popoutSwitchClosing: root.popoutSwitchClosing
        focusTarget: content
        contentWidth: fittedContentWidth(Style.space(360))
        contentHeight: root.workspaceOpen || root.workspaceReveal > 0
            ? fittedContentHeight(Style.space(480), Style.space(480))
            : fittedContentHeight(layout.implicitHeight, root.expanded && !root.detail ? 0 : Style.space(480))

        Item {
            id: content
            anchors.fill: parent
            clip: true
            LayoutMirroring.enabled: I18n.rightToLeft
            LayoutMirroring.childrenInherit: true
            Keys.onPressed: function(event) {
                if (root.workspaceOpen) {
                    event.accepted = workspaceView.handleKey(event);
                    return;
                }
                if (event.key === Qt.Key_Escape) root.handleEscape();
                else if (event.key === Qt.Key_H && !searchField.activeFocus && !(event.modifiers & Qt.AltModifier)) root.showWorkspace();
                else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) root.search(root.query);
                else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_R) {
                    if (root.service && !root.mutationBusy) root.service.rescan();
                } else if (root.detail && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) root.deepScan();
                else if (root.detail && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_C) root.copyCurrent();
                else if (root.detail && event.key === Qt.Key_O && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) root.openCurrent();
                else if (event.key === Qt.Key_PageDown) root.page(1);
                else if (event.key === Qt.Key_PageUp) root.page(-1);
                else if (event.key === Qt.Key_Down) root.moveCursor(1);
                else if (event.key === Qt.Key_Up) root.moveCursor(-1);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate();
                else if (event.key === Qt.Key_Question) root.showWorkspace("shortcuts");
                else if (event.key === Qt.Key_Slash && !root.detail) root.search(root.query);
                else return;
                event.accepted = true;
            }

            MapWorkspace {
                id: workspaceView
                width: parent.width
                height: parent.height
                x: root.workspaceSide * (I18n.rightToLeft ? -1 : 1) * (1 - root.workspaceReveal) * parent.width
                visible: root.workspaceOpen || root.workspaceReveal > 0
                enabled: root.workspaceOpen && !workspaceSlide.running
                service: root.service
                strings: root.translations
                hostWidget: root.hostWidget
                onAppRequested: function(id) { root.workspaceOpen = false; root.selectApp(id); }
                onBackRequested: root.back()
                onCloseRequested: root.close()
            }
            ColumnLayout {
                id: layout
                width: parent.width
                height: parent.height
                x: -root.workspaceSide * (I18n.rightToLeft ? -1 : 1) * root.workspaceReveal * parent.width * 0.12
                opacity: 1 - root.workspaceReveal
                visible: !root.workspaceOpen || root.workspaceReveal < 1
                enabled: !root.workspaceOpen && !workspaceSlide.running
                spacing: Style.space(6)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(3)
                    MapLogoButton {
                        id: homeLogo
                        visible: !root.detail
                        brand: true
                        foreground: root.heroColor
                        motionEnabled: root.motionEnabled
                        label: strings.t("workspace.open")
                        onClicked: root.showWorkspace("dashboard")
                    }
                    MapIconButton {
                        visible: root.detail
                        icon: "back"
                        label: strings.t("back")
                        onClicked: root.back()
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.detail && root.selectedApp ? root.selectedApp.name : strings.t("title")
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MapIconButton {
                        visible: !root.detail
                        icon: "search"
                        label: strings.t(root.searching ? "search.close" : "search")
                        selected: root.searching
                        onClicked: root.toggleSearch()
                    }
                    MapIconButton {
                        visible: root.detail
                        icon: "deep"
                        label: strings.t("deepScan")
                        enabled: !!root.service && !root.mutationBusy && !!Model.findApp(root.apps, root.selectedId)
                        onClicked: root.deepScan()
                    }
                    MapIconButton {
                        icon: root.busy ? "stop" : "refresh"
                        label: strings.t(root.busy ? "cancel" : "rescan")
                        enabled: !!root.service && !root.service.workspaceBusy
                        onClicked: root.busy ? root.service.cancelScan() : root.service.rescan()
                    }
                    MapIconButton {
                        icon: "settings"
                        label: strings.t("workspace.settings")
                        onClicked: root.showWorkspace("settings")
                    }
                    MapIconButton {
                        icon: root.detail ? "triangle-back" : root.expanded ? "triangle-up" : "triangle-down"
                        label: strings.t(root.detail ? "back" : root.expanded ? "overview.condense" : "overview.expand")
                        onClicked: {
                            if (root.detail) root.back();
                            else {
                                root.expanded = !root.expanded;
                                content.forceActiveFocus();
                                Qt.callLater(function() {
                                    if (root.appIndex >= 0) overview.positionViewAtIndex(root.appIndex, ListView.Contain);
                                });
                            }
                        }
                    }
                    MapIconButton {
                        icon: "close"
                        label: strings.t("close")
                        onClicked: root.close()
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.busy
                    spacing: Style.space(3)
                    MapText {
                        Layout.fillWidth: true
                        text: root.jobProgress
                        font.pixelSize: Style.font.caption
                        color: Color.accent
                        elide: Text.ElideRight
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.service ? strings.tn("compact.entries", root.service.scanEntries).arg(I18n.formatNumber(root.service.scanEntries)).arg(root.size(root.service.scanBytes)) : ""
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.74)
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(2)
                        color: Util.alpha(Color.accent, 0.12)
                        Rectangle {
                            width: parent.width * (root.service ? Math.max(0, Math.min(1, root.service.progress)) : 0)
                            height: parent.height
                            color: Color.accent
                            Behavior on width { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
                        }
                    }
                }
                MapText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.scanError || (root.detail ? root.actionStatus : "")
                    color: root.scanError || root.service && root.service.actionError ? Color.urgent : Color.accent
                    font.pixelSize: Style.font.caption
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }
                Ui.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    visible: root.searching && !root.detail
                    text: root.query
                    placeholderText: strings.t("search")
                    onTextEdited: { root.query = text; root.cursorId = ""; }
                    Keys.onReturnPressed: function(event) { root.activate(); event.accepted = true; }
                    Keys.onEnterPressed: function(event) { root.activate(); event.accepted = true; }
                    Keys.onDownPressed: function(event) { root.moveCursor(root.cursorId ? 1 : 0); event.accepted = true; }
                    Keys.onUpPressed: function(event) { root.moveCursor(-1); event.accepted = true; }
                    Keys.onEscapePressed: function(event) { root.handleEscape(); event.accepted = true; }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.uiPrefs.showChart && !root.detail && !root.searching
                    spacing: Style.space(18)
                    MapDonut {
                        id: donut
                        Layout.preferredWidth: Style.space(116)
                        Layout.preferredHeight: Style.space(116)
                        palette: root.palette
                        values: Model.categoryKeys.map(function(key) { return root.service ? root.service.categories[key] || 0 : 0; })
                        centerText: root.overviewSize
                        caption: strings.t("mapped")
                        labels: Model.categoryKeys.map(function(key) { return strings.t("compact." + key); })
                        valueTexts: Model.categoryKeys.map(function(key) { return root.categorySize(key); })
                        emphasizedIndex: root.legendHoverIndex >= 0 ? root.legendHoverIndex : root.legendFocusIndex
                        presentationActive: root.opened && !root.workspaceOpen && visible
                        onPresentationActiveChanged: if (!presentationActive) {
                            root.legendHoverIndex = -1;
                            root.legendFocusIndex = -1;
                        }
                        motionEnabled: root.motionEnabled
                        onActivated: function(index) { root.showCategory(Model.categoryKeys[index]); }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(7)
                        Repeater {
                            model: ["config", "cache", "data", "state"]
                            RowLayout {
                                required property string modelData
                                readonly property int categoryIndex: Model.categoryKeys.indexOf(modelData)
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: strings.t("category.open").arg(strings.t("compact." + modelData))
                                Accessible.description: root.categorySize(modelData)
                                Keys.onReturnPressed: function(event) { event.accepted = true; root.showCategory(modelData); }
                                Keys.onEnterPressed: function(event) { event.accepted = true; root.showCategory(modelData); }
                                Keys.onSpacePressed: function(event) { event.accepted = true; root.showCategory(modelData); }
                                TapHandler { onTapped: root.showCategory(parent.modelData) }
                                opacity: donut.activeIndex < 0 || donut.activeIndex === categoryIndex ? 1 : 0.45
                                onActiveFocusChanged: {
                                    if (activeFocus) root.legendFocusIndex = categoryIndex;
                                    else if (root.legendFocusIndex === categoryIndex) root.legendFocusIndex = -1;
                                }
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onHoveredChanged: {
                                        if (hovered) root.legendHoverIndex = parent.categoryIndex;
                                        else if (root.legendHoverIndex === parent.categoryIndex) root.legendHoverIndex = -1;
                                    }
                                }
                                Layout.fillWidth: true
                                spacing: Style.space(6)
                                Rectangle {
                                    Layout.preferredWidth: Style.space(6)
                                    Layout.preferredHeight: Style.space(6)
                                    radius: width / 2
                                    color: root.palette[Model.categoryKeys.indexOf(modelData)]
                                }
                                MapText {
                                    Layout.fillWidth: true
                                    text: strings.t("compact." + modelData)
                                    font.pixelSize: Style.font.bodySmall
                                    elide: Text.ElideRight
                                }
                                MapText {
                                    text: root.categorySize(modelData)
                                    font.pixelSize: Style.font.caption
                                    color: Util.alpha(Color.popups.text, 0.74)
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.detail && !root.searching
                    spacing: Style.space(4)
                    MapText {
                        Layout.fillWidth: true
                        text: root.time(root.service ? root.service.scannedAt : 0)
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.62)
                        elide: Text.ElideRight
                    }
                    MapText {
                        visible: root.overviewPartial
                        text: strings.t("measurement.lowerBound")
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.62)
                    }
                    MapIconButton {
                        icon: "info"
                        label: strings.t("workspace.diagnostics")
                        onClicked: root.showWorkspace("diagnostics")
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Util.alpha(Color.popups.text, 0.1)
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.detail
                    MapText { text: strings.t("compact.apps"); font.weight: Font.DemiBold; Layout.fillWidth: true }
                    MapText {
                        text: strings.t("compact.coverage").arg(I18n.formatNumber(root.coverage.mapped)).arg(I18n.formatNumber(root.apps.length))
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.62)
                    }
                }
                ListView {
                    id: overview
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    Layout.preferredHeight: Style.space(root.filteredApps.length ? (root.expanded ? root.filteredApps.length : Math.min(5, root.filteredApps.length)) * 36 : 72)
                    visible: !root.detail
                    clip: true
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredApps
                    currentIndex: root.appIndex
                    keyNavigationEnabled: false
                    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                    delegate: MapAppRow {
                        required property var modelData
                        required property int index
                        width: overview.width
                        app: modelData
                        strings: root.translations
                        palette: root.palette
                        largestBytes: root.filteredApps.length ? root.filteredApps[0].mappedBytes : 0
                        hasCursor: index === root.appIndex
                        onCursorRequested: root.cursorId = modelData.id
                        onClicked: root.selectApp(modelData.id)
                    }
                    MapText {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: !root.filteredApps.length
                        text: strings.t(!root.service ? "unavailableTitle" : root.query ? "compact.noMatches" : root.busy ? "compact.working" : !root.service.ready ? "compact.notScanned" : "compact.noApps")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: Style.font.bodySmall
                        color: Util.alpha(Color.popups.text, 0.74)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.detail
                    spacing: Style.space(3)
                    RowLayout {
                        Layout.fillWidth: true
                        MapText {
                            Layout.fillWidth: true
                            text: root.selectedApp ? Model.appSize(root.selectedApp, strings, I18n) : strings.t("size.unknown")
                            font.pixelSize: Style.font.heading
                            font.weight: Font.DemiBold
                            color: Color.accent
                            elide: Text.ElideRight
                        }
                        MapText {
                            text: strings.t(root.selectedApp && root.selectedApp.status === "partial" ? "measurement.lowerBound" : "mapped")
                            font.pixelSize: Style.font.caption
                            color: Util.alpha(Color.popups.text, 0.74)
                        }
                    }
                    MapText {
                        Layout.fillWidth: true
                        visible: root.showingDeep || root.previousSnapshot
                        text: strings.t(root.showingDeep ? "compact.deep" : "compact.previous")
                        color: root.previousSnapshot ? Color.urgent : Color.accent
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.time(root.selectedApp ? root.selectedApp.scannedAt : 0)
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.62)
                        elide: Text.ElideRight
                    }
                }
                ListView {
                    id: detailList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    Layout.preferredHeight: contentHeight
                    visible: root.detail
                    clip: true
                    spacing: Style.space(4)
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.paths
                    currentIndex: root.pathIndex
                    keyNavigationEnabled: false
                    Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
                    delegate: Column {
                        required property var modelData
                        required property int index
                        function toggleBreakdown() { pathCard.breakdownExpanded = !pathCard.breakdownExpanded; }
                        width: detailList.width
                        spacing: Style.space(4)
                        MapText {
                            width: parent.width
                            visible: index === 0 || root.paths[index - 1].confidence === "known" && modelData.confidence !== "known"
                            text: strings.t(modelData.confidence === "known" ? "compact.folders" : "compact.excluded")
                            font.weight: Font.DemiBold
                            font.pixelSize: Style.font.bodySmall
                            color: modelData.confidence === "known" ? Color.popups.text : Color.urgent
                        }
                        MapPathCard {
                            id: pathCard
                            width: parent.width
                            entry: modelData
                            strings: root.translations
                            service: root.service
                            current: index === root.pathIndex
                            categoryColor: root.palette[Math.max(0, Model.categoryKeys.indexOf(modelData.category))]
                            onSelected: function(actionPath) {
                                root.cursorPath = modelData.path;
                                root.cursorActionPath = actionPath;
                            }
                            onActionFocused: function(item) { root.revealAction(item); }
                        }
                    }
                    MapText {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: !root.paths.length
                        text: strings.t("compact.noPaths")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Style.font.bodySmall
                        color: Util.alpha(Color.popups.text, 0.74)
                        wrapMode: Text.WordWrap
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item {
                        visible: !root.detail
                        Layout.preferredWidth: shortcutsButton.implicitWidth
                        Layout.preferredHeight: 1
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: strings.t("compact.local")
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.56)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    MapIconButton {
                        id: shortcutsButton
                        visible: !root.detail
                        implicitHeight: Style.space(22)
                        icon: "keyboard"
                        label: strings.t("shortcuts.open")
                        onClicked: root.showWorkspace("shortcuts")
                    }
                }
            }
        }
    }
}
