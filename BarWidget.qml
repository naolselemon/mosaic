import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "Presentation.js" as Presentation

Ui.BarWidget {
    id: root
    moduleName: "naolselemon.mosaic"
    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(root.moduleName) : null
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
    readonly property var uiPrefs: Presentation.preferences(root.settings)
    property string preferenceError: ""
    property bool settingsDelivered: false

    onSettingsChanged: settingsDelivered = true

    function setUiPreference(key, value) {
        if (!Presentation.valid(key, value)) {
            preferenceError = strings.t("preferences.invalid");
            return false;
        }
        if (!settingsDelivered || !root.bar || !root.bar.shell
                || typeof root.bar.shell.updateEntryInline !== "function") {
            preferenceError = strings.t("preferences.unavailable");
            return false;
        }
        if (root.settings[key] === value) {
            preferenceError = "";
            return true;
        }
        // Native updates replace the whole entry, so retain every delivered key.
        var entry = {id: root.moduleName};
        for (var name in root.settings)
            if (name !== "id" && Object.prototype.hasOwnProperty.call(root.settings, name))
                entry[name] = root.settings[name];
        entry[key] = value;
        try {
            if (!root.bar.shell.updateEntryInline(root.moduleName, entry)) {
                preferenceError = strings.t("preferences.rejected");
                return false;
            }
        } catch (error) {
            preferenceError = strings.t("preferences.rejected");
            return false;
        }
        // Do not present session-only changes as saved when the native API rejects them.
        root.settings = entry;
        preferenceError = "";
        return true;
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    function injectPanel() {
        if (!panelLoader.item) return;
        panelLoader.item.bar = root.bar;
        panelLoader.item.anchorItem = button;
        panelLoader.item.hostWidget = root;
    }
    function open() { if (panelLoader.item) panelLoader.item.open(); }
    function close() { if (panelLoader.item) panelLoader.item.close(); }
    function toggle() { if (panelLoader.item) panelLoader.item.toggle(); }
    function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }

    onBarChanged: injectPanel()

    Loader {
        id: panelLoader
        active: true
        visible: false
        source: Qt.resolvedUrl("Panel.qml")
        onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel); }
    }

    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        iconComponent: MosaicMark { foreground: button.foreground }
        tooltipText: strings.t("app.name")
        foreground: root.service && root.service.busy ? Commons.Color.accent : (root.bar ? root.bar.barForeground : Commons.Color.foreground)
        onPressed: buttonCode => {
            if (buttonCode === Qt.LeftButton) root.toggle();
        }
    }
}
