import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui as Ui
import "ViewModel.js" as Model
import "Presentation.js" as Presentation

Item {
    id: root
    required property var service
    required property var strings
    property var hostWidget: null
    property string page: "dashboard"
    property string categoryKey: "data"
    readonly property var categoryTabs: ["config", "data", "cache", "state"]
    property var trail: []
    readonly property var view: service ? service.workspace : null
    readonly property bool busy: !service || service.busy || service.workspaceBusy
    readonly property bool ready: !!view && !!service && service.workspaceReady
    readonly property bool typing: !!pageLoader.item && pageLoader.item.typing
    readonly property var settings: view ? view.settings : null
    readonly property var prefs: hostWidget ? hostWidget.uiPrefs : Presentation.preferences({})
    readonly property color heroColor: Presentation.tint(prefs.heroColor, Color.accent, Color.popups.text, Color.urgent)
    readonly property color insightColor: Presentation.tint(prefs.insightColor, Color.accent, Color.popups.text, Color.urgent)
    readonly property var palette: [heroColor, Qt.tint(heroColor, Util.alpha(Color.popups.text, 0.7)), Qt.tint(heroColor, Util.alpha(Color.urgent, 0.7)), Color.urgent]
    readonly property bool motionEnabled: prefs.motion && Style.duration(180) > 0
    readonly property string preferenceError: hostWidget ? hostWidget.preferenceError : ""
    readonly property bool hasInfo: !!pageLoader.item && typeof pageLoader.item.toggleInfo === "function"
    property int entryDirection: 1
    signal backRequested
    signal closeRequested
    signal appRequested(string id)

    function size(value, partial) {
        var result = Model.bytes(value, strings, I18n);
        return partial && value !== null ? strings.t("size.lowerBound").arg(result) : result;
    }
    function date(at) { return Model.timestamp(at, Qt.locale(I18n.formatLocale), Locale.ShortFormat); }
    function number(value) { return I18n.formatNumber(value); }
    function appName(id) {
        var app = service ? Model.findApp(service.apps, id) : null;
        return app ? app.name : id;
    }
    function setPreference(key, value) {
        return !!hostWidget && hostWidget.setUiPreference(key, value);
    }
    function selectCategory(key) {
        var index = categoryTabs.indexOf(key);
        if (index < 0) return false;
        if (page === "category" && categoryKey === key) return true;
        var direction = index >= categoryTabs.indexOf(categoryKey) ? 1 : -1;
        categoryKey = key;
        if (page !== "category") navigate("category");
        else enter(direction);
        return true;
    }
    function refreshView() {
        if (!service || service.workspaceBusy) return;
        if (service.busy) service.cancelScan();
        else if (page === "category" || page === "diagnostics") service.rescan();
        else service.refreshWorkspace();
    }
    function pageIcon() {
        if (page === "category") return categoryKey === "state" ? "history" : categoryKey;
        var icons = {dashboard: "chart", history: "history", year: "calendar", settings: "settings",
            mappings: "link", cache: "cache", growing: "growth", installations: "package",
            leftovers: "leftovers", alerts: "alert", notes: "info", diagnostics: "scan", shortcuts: "keyboard"};
        return icons[page] || "chart";
    }
    function enter(direction) {
        pageEntrance.stop();
        scroll.contentY = 0;
        entryDirection = direction * (I18n.rightToLeft ? -1 : 1);
        if (motionEnabled) pageEntrance.start();
        else { pageLoader.x = 0; pageLoader.opacity = 1; }
        logo.play();
        forceActiveFocus();
    }
    function openPage(target) {
        trail = [];
        page = target || "dashboard";
        enter(1);
    }
    function navigate(target) {
        if (target === page) return;
        var previous = trail.slice();
        var ancestor = previous.indexOf(target);
        if (ancestor >= 0) previous = previous.slice(0, ancestor);
        else previous.push(page);
        trail = previous;
        page = target;
        enter(ancestor >= 0 ? -1 : 1);
    }
    function goBack() {
        if (!trail.length) return false;
        var previous = trail.slice();
        page = previous.pop();
        trail = previous;
        enter(-1);
        return true;
    }
    function reveal(item) {
        var y = item.mapToItem(scroll.contentItem, 0, 0).y;
        var maximum = Math.max(0, scroll.contentHeight - scroll.height);
        if (y < scroll.contentY) scroll.contentY = Math.max(0, y);
        else if (y + item.height > scroll.contentY + scroll.height)
            scroll.contentY = Math.min(maximum, Math.max(0, y + item.height - scroll.height));
    }
    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (pageLoader.item && pageLoader.item.infoOpen && hasInfo) pageLoader.item.toggleInfo();
            else backRequested();
            return true;
        }
        if (typing) return false;
        if (event.key === Qt.Key_H && !(event.modifiers & Qt.AltModifier)) { backRequested(); return true; }
        if (event.key === Qt.Key_Question) { navigate("shortcuts"); return true; }
        if (event.key === Qt.Key_Backspace || (event.modifiers & Qt.AltModifier) && Util.readingKey(event) === Qt.Key_Left) { backRequested(); return true; }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_R) {
            if (!busy) refreshView();
            return true;
        }
        var dy = event.key === Qt.Key_Down ? Style.space(36) : event.key === Qt.Key_Up ? -Style.space(36)
            : event.key === Qt.Key_PageDown ? scroll.height * 0.8 : event.key === Qt.Key_PageUp ? -scroll.height * 0.8 : 0;
        if (dy) { scroll.contentY = Math.max(0, Math.min(Math.max(0, scroll.contentHeight - scroll.height), scroll.contentY + dy)); return true; }
        if (event.key === Qt.Key_Home) { scroll.contentY = 0; return true; }
        if (event.key === Qt.Key_End) { scroll.contentY = Math.max(0, scroll.contentHeight - scroll.height); return true; }
        return false;
    }
    onMotionEnabledChanged: if (!motionEnabled) {
        pageEntrance.stop();
        pageLoader.x = 0;
        pageLoader.opacity = 1;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(6)
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(3)
            MapLogoButton {
                id: logo
                icon: root.pageIcon()
                label: root.strings.t("back")
                foreground: root.page === "category" ? root.palette[Model.categoryKeys.indexOf(root.categoryKey)] : root.heroColor
                motionEnabled: root.motionEnabled
                onClicked: root.backRequested()
            }
            MapText {
                Layout.fillWidth: true
                text: root.strings.t(root.page === "category" ? "compact." + root.categoryKey : "workspace." + root.page)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            MapIconButton {
                visible: root.hasInfo
                icon: "info"
                label: root.strings.t("common.explanation")
                selected: !!pageLoader.item && !!pageLoader.item.infoOpen
                onClicked: if (root.hasInfo) pageLoader.item.toggleInfo()
            }
            MapIconButton {
                visible: root.page !== "settings"
                icon: "settings"
                label: root.strings.t("workspace.settings")
                onClicked: root.navigate("settings")
            }
            MapIconButton {
                icon: root.service && root.service.busy ? "stop" : "refresh"
                label: root.strings.t(root.service && root.service.busy ? "cancel" : root.page === "category" || root.page === "diagnostics" ? "rescan" : "workspace.refresh")
                enabled: !!root.service && !root.service.workspaceBusy
                onClicked: root.refreshView()
            }
            MapIconButton { icon: "triangle-back"; label: root.strings.t("back"); onClicked: root.backRequested() }
            MapIconButton { icon: "close"; label: root.strings.t("close"); onClicked: root.closeRequested() }
        }
        MapText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.preferenceError || (root.service ? root.service.workspaceError || root.service.error || (root.service.workspaceBusy ? root.strings.t("workspace.loading") : root.service.busy ? root.strings.t("compact.working") : "") : root.strings.t("unavailableTitle"))
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            color: root.preferenceError || root.service && (root.service.workspaceError || root.service.error) ? Color.urgent : root.insightColor
        }
        Flickable {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
            Loader {
                id: pageLoader
                width: scroll.width - Style.space(8)
                sourceComponent: root.page === "dashboard" ? dashboardPage : root.page === "history" ? historyPage
                    : root.page === "year" ? yearPage : root.page === "mappings" ? mappingsPage
                    : root.page === "settings" ? settingsPage : root.page === "diagnostics" ? diagnosticsPage
                    : root.page === "shortcuts" ? shortcutsPage : root.page === "category" ? categoryPage : recordsPage
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.strings.t("compact.local")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.56)
            horizontalAlignment: Text.AlignHCenter
        }
    }
    ParallelAnimation {
        id: pageEntrance
        NumberAnimation { target: pageLoader; property: "x"; from: root.entryDirection * Style.space(48); to: 0; duration: Style.duration(180); easing.type: Easing.OutCubic }
        NumberAnimation { target: pageLoader; property: "opacity"; from: 0; to: 1; duration: Style.duration(140); easing.type: Easing.OutCubic }
    }
    Component { id: dashboardPage; MapWorkspaceOverview { workspace: root } }
    Component { id: historyPage; MapHistory { workspace: root } }
    Component { id: yearPage; MapYear { workspace: root } }
    Component { id: mappingsPage; MapWorkspaceMappings { workspace: root } }
    Component { id: settingsPage; MapWorkspaceSettings { workspace: root } }
    Component { id: diagnosticsPage; MapScanDetails { workspace: root } }
    Component { id: shortcutsPage; MapShortcuts { workspace: root } }
    Component { id: categoryPage; MapCategory { workspace: root } }
    Component { id: recordsPage; MapWorkspaceRecords { workspace: root } }
}
