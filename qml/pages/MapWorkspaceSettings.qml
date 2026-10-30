import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "../lib/Presentation.js" as Presentation
import "../components"

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: (customThresholdOpen && threshold.activeFocus) || heroEditor.editing || insightEditor.editing
    property bool confirmClear: false
    property bool pendingClear: false
    property string clearError: ""
    property bool customThresholdOpen: false
    property bool thresholdEdited: false
    property bool thresholdSaved: false
    property bool thresholdUnconfirmed: false
    property real pendingThreshold: -1
    property bool privacyOpen: false
    readonly property real thresholdMiB: {
        var value = Number.fromLocaleString(Qt.locale(I18n.formatLocale), threshold.text);
        return isFinite(value) ? value : 0;
    }
    readonly property bool validThreshold: thresholdMiB >= 1 && thresholdMiB <= 1048576
    readonly property bool historyEnabled: !!workspace.settings && workspace.settings.historyEnabled
    readonly property int retained: workspace.view ? workspace.view.history.length : 0
    readonly property int mappingCount: workspace.view ? workspace.view.mappings.length : 0
    spacing: Style.space(10)

    function syncThreshold() {
        if (!thresholdEdited)
            threshold.text = workspace.settings ? I18n.formatNumber(workspace.settings.thresholdBytes / 1048576, 2) : "";
    }
    function saveThreshold(value) {
        if (!workspace.ready || workspace.busy || value < 1 || value > 1048576) return;
        thresholdSaved = false;
        thresholdUnconfirmed = false;
        var bytes = Math.round(value * 1048576);
        if (workspace.service.setWorkspaceSettings({thresholdBytes: bytes})) pendingThreshold = bytes;
    }
    function settleOperations() {
        if (workspace.service.workspaceBusy) return;
        if (pendingThreshold >= 0) {
            var confirmed = !workspace.service.workspaceError && workspace.settings
                && workspace.settings.thresholdBytes === pendingThreshold;
            thresholdUnconfirmed = !workspace.service.workspaceError && !confirmed;
            if (confirmed && Math.round(thresholdMiB * 1048576) === pendingThreshold) {
                thresholdEdited = false;
                thresholdSaved = true;
                syncThreshold();
            }
            pendingThreshold = -1;
        }
        if (pendingClear) {
            clearError = workspace.service.workspaceError;
            if (!clearError) {
                confirmClear = false;
                clearButton.forceActiveFocus();
            }
            pendingClear = false;
        }
    }
    Component.onCompleted: syncThreshold()
    Connections {
        target: root.workspace
        function onSettingsChanged() { root.syncThreshold(); }
    }
    Connections {
        target: root.workspace.service
        function onWorkspaceBusyChanged() {
            if (!root.workspace.service.workspaceBusy) Qt.callLater(root.settleOperations);
        }
    }
    Connections {
        target: I18n
        function onFormatLocaleChanged() { root.syncThreshold(); }
    }

    component PreferenceGroup: Rectangle {
        id: group
        required property string title
        property string badge: ""
        property bool semanticRows: false
        default property alias content: groupBody.data
        Layout.fillWidth: true
        implicitHeight: groupLayout.implicitHeight + Style.space(24)
        radius: Math.max(Style.cornerRadius, Style.space(semanticRows ? 8 : 12))
        color: semanticRows ? Util.alpha(root.workspace.heroColor, 0.045) : Util.alpha(Color.popups.text, 0.035)
        border.width: semanticRows ? Math.max(1, Style.normalBorderWidth) : 1
        border.color: semanticRows ? Util.alpha(root.workspace.heroColor, 0.3) : Util.alpha(Color.popups.text, 0.08)
        ColumnLayout {
            id: groupLayout
            x: Style.space(group.semanticRows ? 10 : 12)
            y: Style.space(12)
            width: Math.max(0, parent.width - 2 * x)
            spacing: Style.space(8)
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: group.semanticRows ? Style.space(4) : 0
                Layout.rightMargin: group.semanticRows ? Style.space(4) : 0
                spacing: Style.space(8)
                MapText {
                    Layout.fillWidth: true
                    text: group.title
                    font.pixelSize: group.semanticRows ? Style.font.caption : Style.font.bodySmall
                    font.capitalization: group.semanticRows ? Font.AllUppercase : Font.MixedCase
                    font.letterSpacing: group.semanticRows ? Style.space(1.5) : 0
                    color: group.semanticRows ? root.workspace.heroColor : Color.popups.text
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                Rectangle {
                    visible: group.badge !== ""
                    Layout.maximumWidth: groupLayout.width / 2
                    implicitWidth: badgeLabel.implicitWidth + Style.space(14)
                    implicitHeight: badgeLabel.implicitHeight + Style.space(6)
                    radius: height / 2
                    color: Util.alpha(Color.popups.text, 0.07)
                    MapText {
                        id: badgeLabel
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(7)
                        anchors.rightMargin: Style.space(7)
                        text: group.badge
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.65)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
            Rectangle {
                visible: !group.semanticRows
                Layout.fillWidth: true
                implicitHeight: 1
                color: Util.alpha(Color.popups.text, 0.08)
            }
            ColumnLayout {
                id: groupBody
                Layout.fillWidth: true
                spacing: Style.space(group.semanticRows ? 8 : 6)
            }
        }
    }

    component PreferenceButton: Ui.Button {
        focusable: true
        fontSize: Style.font.caption
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(5)
        foreground: Color.popups.text
        radius: height / 2
        background: Util.alpha(Color.popups.text, 0.035)
        opacity: enabled ? 1 : 0.45
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
    component PreferenceToggle: MapPreferenceToggle {
        workspace: root.workspace
        accent: root.workspace.heroColor
    }
    component PreferenceNote: MapText {
        Layout.fillWidth: true
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.62)
        wrapMode: Text.Wrap
    }
    component PreferenceLabel: MapPreferenceLabel {
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(4)
        Layout.rightMargin: Style.space(4)
        accent: root.workspace.heroColor
    }
    component PreferenceDetails: ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.leftMargin: Style.space(I18n.rightToLeft ? 4 : 29)
        Layout.rightMargin: Style.space(I18n.rightToLeft ? 29 : 4)
        spacing: Style.space(6)
    }
    component ColorEditor: ColumnLayout {
        id: editor
        required property string preferenceKey
        required property string label
        property bool customOpen: false
        readonly property bool editing: customOpen && customColor.activeFocus
        readonly property string current: root.workspace.prefs[preferenceKey]
        Layout.fillWidth: true
        spacing: Style.space(5)
        function save() {
            if (/^#[0-9a-fA-F]{6}$/.test(customColor.text)
                    && root.workspace.setPreference(preferenceKey, customColor.text)) {
                customOpen = false;
                customButton.forceActiveFocus();
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: width >= Style.space(270) ? 2 : 1
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(3)
            MapText {
                Layout.fillWidth: true
                text: editor.label
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.alignment: I18n.rightToLeft ? Qt.AlignLeft : Qt.AlignRight
                spacing: Style.space(3)
                Repeater {
                    model: ["theme", "foreground", "urgent"]
                    PreferenceButton {
                        required property string modelData
                        implicitWidth: Style.space(30)
                        implicitHeight: Style.space(30)
                        selected: editor.current === modelData
                        tooltipText: root.workspace.strings.t("preferences.color." + modelData)
                        Accessible.name: root.workspace.strings.t("preferences.colorChoice").arg(editor.label).arg(tooltipText)
                        onClicked: root.workspace.setPreference(editor.preferenceKey, modelData)
                        Rectangle {
                            anchors.centerIn: parent
                            width: Style.space(15)
                            height: width
                            radius: width / 2
                            color: Presentation.tint(modelData, Color.accent, Color.popups.text, Color.urgent)
                            border.color: Util.alpha(Color.popups.text, 0.25)
                            border.width: 1
                        }
                    }
                }
                PreferenceButton {
                    id: customButton
                    text: root.workspace.strings.t("preferences.custom")
                    selected: editor.customOpen || editor.current.charAt(0) === "#"
                    foreground: editor.current.charAt(0) === "#" ? editor.current : Color.popups.text
                    Accessible.name: root.workspace.strings.t("preferences.customColor").arg(editor.label)
                    Accessible.expanded: editor.customOpen
                    onClicked: {
                        editor.customOpen = !editor.customOpen;
                        if (editor.customOpen) {
                            customColor.text = editor.current.charAt(0) === "#" ? editor.current : "";
                            Qt.callLater(function() { customColor.forceActiveFocus(); root.workspace.reveal(customColor); });
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: editor.customOpen
            Ui.TextField {
                id: customColor
                Layout.fillWidth: true
                maximumLength: 7
                placeholderText: root.workspace.strings.t("preferences.hexPlaceholder")
                Accessible.name: root.workspace.strings.t("preferences.customColor").arg(editor.label)
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                onAccepted: editor.save()
                Keys.onEscapePressed: event => {
                    editor.customOpen = false;
                    customButton.forceActiveFocus();
                    event.accepted = true;
                }
            }
            PreferenceButton {
                text: root.workspace.strings.t("workspace.save")
                enabled: /^#[0-9a-fA-F]{6}$/.test(customColor.text)
                onClicked: editor.save()
            }
        }
        PreferenceNote {
            visible: editor.customOpen && customColor.text.length > 0 && !/^#[0-9a-fA-F]{6}$/.test(customColor.text)
            text: root.workspace.strings.t("preferences.hexHelp")
            color: Color.urgent
        }
    }

    PreferenceGroup {
        Layout.fillWidth: true
        title: root.workspace.strings.t("preferences.display")
        GridLayout {
            Layout.fillWidth: true
            columns: width >= Style.space(380) ? 2 : 1
            columnSpacing: Style.space(10)
            rowSpacing: Style.space(1)
            PreferenceToggle {
                label: root.workspace.strings.t("preferences.showChart")
                checked: root.workspace.prefs.showChart
                onClicked: root.workspace.setPreference("showChart", !checked)
            }
            PreferenceToggle {
                label: root.workspace.strings.t("preferences.showHighlights")
                checked: root.workspace.prefs.showHighlights
                onClicked: root.workspace.setPreference("showHighlights", !checked)
            }
            PreferenceToggle {
                label: root.workspace.strings.t("preferences.showYearInsights")
                checked: root.workspace.prefs.showYearInsights
                onClicked: root.workspace.setPreference("showYearInsights", !checked)
            }
            PreferenceToggle {
                label: root.workspace.strings.t("preferences.motion")
                checked: root.workspace.prefs.motion
                onClicked: root.workspace.setPreference("motion", !checked)
            }
        }
    }
    PreferenceGroup {
        Layout.fillWidth: true
        title: root.workspace.strings.t("preferences.colors")
        ColorEditor { id: heroEditor; preferenceKey: "heroColor"; label: root.workspace.strings.t("preferences.heroColor") }
        ColorEditor { id: insightEditor; preferenceKey: "insightColor"; label: root.workspace.strings.t("preferences.insightColor") }
        PreferenceButton {
            Layout.alignment: I18n.rightToLeft ? Qt.AlignLeft : Qt.AlignRight
            text: root.workspace.strings.t("preferences.resetColors")
            onClicked: {
                if (root.workspace.setPreference("heroColor", "theme"))
                    root.workspace.setPreference("insightColor", "theme");
            }
        }
    }
    PreferenceGroup {
        Layout.fillWidth: true
        semanticRows: true
        title: root.workspace.strings.t("preferences.history")
        badge: root.workspace.strings.tn("preferences.retained", root.retained).arg(root.workspace.number(root.retained))
        PreferenceToggle {
            icon: "history"
            label: root.workspace.strings.t("workspace.keepHistory")
            description: root.workspace.strings.t("preferences.historyConsent")
            checked: root.historyEnabled
            enabled: root.workspace.ready && !root.workspace.busy
            onClicked: root.workspace.service.setWorkspaceSettings({historyEnabled: !checked})
        }
        PreferenceLabel {
            icon: "chart"
            label: root.workspace.strings.t("preferences.chartWindow")
            description: root.workspace.strings.t("preferences.chartWindowHint")
        }
        PreferenceDetails {
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(2)
                Repeater {
                    model: [7, 14, 30, 60]
                    PreferenceButton {
                        required property int modelData
                        Layout.fillWidth: true
                        text: root.workspace.number(modelData)
                        selected: root.workspace.prefs.chartSamples === modelData
                        Accessible.name: root.workspace.strings.tn("preferences.sampleWindow", modelData).arg(root.workspace.number(modelData))
                        onClicked: root.workspace.setPreference("chartSamples", modelData)
                    }
                }
            }
        }
        PreferenceButton {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            implicitHeight: Math.max(Style.space(42), privacyLabel.implicitHeight + Style.space(12))
            selected: root.privacyOpen
            Accessible.name: root.workspace.strings.t(root.privacyOpen ? "preferences.hidePrivacy" : "preferences.privacyDetails")
            Accessible.description: privacyLabel.description
            Accessible.expanded: root.privacyOpen
            onClicked: root.privacyOpen = !root.privacyOpen
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(9)
                MapPreferenceLabel {
                    id: privacyLabel
                    Layout.fillWidth: true
                    icon: "data"
                    label: root.workspace.strings.t("preferences.privacyDetails")
                    description: root.workspace.strings.t("preferences.privacyHint")
                    accent: root.workspace.heroColor
                    Accessible.ignored: true
                }
                MapGlyph {
                    Layout.preferredWidth: Style.space(16)
                    icon: root.privacyOpen ? "down" : "next"
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(root.workspace.heroColor, 0.7)
                    Accessible.ignored: true
                }
            }
        }
        PreferenceDetails {
            visible: root.privacyOpen
            PreferenceNote {
                text: root.workspace.strings.t("preferences.privacyHelp")
            }
        }
    }
    PreferenceGroup {
        Layout.fillWidth: true
        semanticRows: true
        title: root.workspace.strings.t("preferences.growth")
        PreferenceToggle {
            icon: "alert"
            label: root.workspace.strings.t("workspace.growthAlerts")
            description: root.workspace.strings.t(root.historyEnabled ? "preferences.alertConsent" : "preferences.alertRequiresHistory")
            checked: !!root.workspace.settings && root.workspace.settings.alertsEnabled
            enabled: root.workspace.ready && !root.workspace.busy && root.historyEnabled
            onClicked: root.workspace.service.setWorkspaceSettings({alertsEnabled: !checked})
        }
        PreferenceLabel {
            icon: "growth"
            label: root.workspace.strings.t("workspace.threshold")
            description: root.workspace.strings.t("preferences.thresholdHint")
        }
        PreferenceDetails {
            PreferenceNote {
                visible: root.pendingThreshold >= 0 || root.thresholdSaved
                text: root.workspace.strings.t(root.pendingThreshold >= 0 ? "preferences.saving" : "preferences.saved")
                color: root.workspace.insightColor
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= Style.space(300) ? 4 : 2
                columnSpacing: Style.space(2)
                rowSpacing: Style.space(2)
                Repeater {
                    model: [100, 500, 1024]
                    PreferenceButton {
                        required property int modelData
                        Layout.fillWidth: true
                        text: root.workspace.size(modelData * 1048576, false)
                        selected: !!root.workspace.settings && root.workspace.settings.thresholdBytes === modelData * 1048576
                        enabled: root.workspace.ready && !root.workspace.busy
                        horizontalPadding: Style.space(3)
                        onClicked: {
                            threshold.text = I18n.formatNumber(modelData, 2);
                            root.thresholdEdited = true;
                            root.saveThreshold(modelData);
                        }
                    }
                }
                PreferenceButton {
                    id: customThresholdButton
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("preferences.custom")
                    horizontalPadding: Style.space(3)
                    selected: root.customThresholdOpen || (!!root.workspace.settings && [100, 500, 1024].indexOf(root.workspace.settings.thresholdBytes / 1048576) < 0)
                    enabled: root.workspace.ready && !root.workspace.busy
                    Accessible.name: root.workspace.strings.t("preferences.customThreshold")
                    Accessible.expanded: root.customThresholdOpen
                    onClicked: {
                        root.customThresholdOpen = !root.customThresholdOpen;
                        if (root.customThresholdOpen)
                            Qt.callLater(function() { threshold.forceActiveFocus(); root.workspace.reveal(threshold); });
                    }
                }
            }
            PreferenceNote {
                visible: !root.customThresholdOpen && !!root.workspace.settings && [100, 500, 1024].indexOf(root.workspace.settings.thresholdBytes / 1048576) < 0
                text: root.workspace.strings.t("preferences.currentThreshold").arg(root.workspace.settings ? root.workspace.size(root.workspace.settings.thresholdBytes, false) : "")
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: root.customThresholdOpen
                spacing: Style.space(4)
                RowLayout {
                    Layout.fillWidth: true
                    Ui.TextField {
                        id: threshold
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        placeholderText: root.workspace.strings.t("workspace.thresholdPlaceholder")
                        Accessible.name: root.workspace.strings.t("workspace.thresholdPlaceholder")
                        enabled: root.workspace.ready && !root.workspace.busy
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        onTextEdited: {
                            root.thresholdEdited = true;
                            root.thresholdSaved = false;
                            root.thresholdUnconfirmed = false;
                        }
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                        onAccepted: if (root.thresholdEdited && root.validThreshold) root.saveThreshold(root.thresholdMiB)
                        Keys.onEscapePressed: event => {
                            root.customThresholdOpen = false;
                            customThresholdButton.forceActiveFocus();
                            event.accepted = true;
                        }
                    }
                    MapText { text: root.workspace.strings.t("unit.MiB"); font.pixelSize: Style.font.caption }
                }
                PreferenceButton {
                    text: root.workspace.strings.t("workspace.save")
                    enabled: root.workspace.ready && !root.workspace.busy && root.thresholdEdited && root.validThreshold
                    onClicked: root.saveThreshold(root.thresholdMiB)
                }
            }
            PreferenceNote {
                visible: root.customThresholdOpen && root.thresholdEdited && !root.validThreshold
                text: root.workspace.strings.t("workspace.thresholdRange").arg(I18n.formatNumber(1)).arg(I18n.formatNumber(1048576))
                color: Color.urgent
            }
            PreferenceNote {
                visible: root.thresholdUnconfirmed
                text: root.workspace.strings.t("preferences.thresholdUnconfirmed")
                color: Color.urgent
            }
        }
    }
    PreferenceGroup {
        Layout.fillWidth: true
        semanticRows: true
        title: root.workspace.strings.t("preferences.data")
        PreferenceButton {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            implicitHeight: Math.max(Style.space(42), mappingLabel.implicitHeight + Style.space(12))
            Accessible.name: mappingLabel.label
            Accessible.description: mappingLabel.description
            onClicked: root.workspace.navigate("mappings")
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(4)
                anchors.rightMargin: Style.space(4)
                spacing: Style.space(9)
                MapPreferenceLabel {
                    id: mappingLabel
                    Layout.fillWidth: true
                    icon: "link"
                    label: root.workspace.strings.t("workspace.mappings")
                    description: root.workspace.strings.tn("workspace.mappingCount", root.mappingCount).arg(root.workspace.number(root.mappingCount))
                    accent: root.workspace.heroColor
                    Accessible.ignored: true
                }
                MapGlyph {
                    Layout.preferredWidth: Style.space(16)
                    icon: "next"
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(root.workspace.heroColor, 0.7)
                    Accessible.ignored: true
                }
            }
        }
        PreferenceLabel {
            icon: "history"
            label: root.workspace.strings.t("preferences.savedData")
            description: root.workspace.strings.t("preferences.savedDataHint")
        }
        PreferenceDetails {
            visible: !root.confirmClear
            PreferenceButton {
                id: clearButton
                text: root.workspace.strings.t("workspace.clearHistory")
                foreground: Color.urgent
                enabled: root.workspace.ready && !root.workspace.busy
                onClicked: {
                    root.clearError = "";
                    root.confirmClear = true;
                    Qt.callLater(function() { cancelClear.forceActiveFocus(); root.workspace.reveal(clearConfirmation); });
                }
            }
        }
        PreferenceDetails {
            id: clearConfirmation
            visible: root.confirmClear
            PreferenceNote {
                text: root.workspace.strings.t("preferences.clearSafety")
                color: Color.popups.text
            }
            PreferenceNote {
                visible: root.clearError !== "" && root.clearError !== root.workspace.service.workspaceError
                text: root.clearError
                color: Color.urgent
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= Style.space(300) ? 2 : 1
                rowSpacing: Style.space(4)
                PreferenceButton {
                    id: cancelClear
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("cancel")
                    enabled: !root.pendingClear
                    onClicked: { root.confirmClear = false; clearButton.forceActiveFocus(); }
                }
                PreferenceButton {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t(root.pendingClear ? "preferences.clearing" : "workspace.clearHistory")
                    foreground: Color.urgent
                    enabled: root.workspace.ready && !root.workspace.busy && !root.pendingClear
                    onClicked: {
                        root.clearError = "";
                        if (root.workspace.service.clearWorkspaceHistory()) root.pendingClear = true;
                        else root.clearError = root.workspace.service.workspaceError;
                    }
                }
            }
        }
    }
    MapUpdates {
        Layout.fillWidth: true
        workspace: root.workspace
    }
    MapContribution {
        Layout.fillWidth: true
        workspace: root.workspace
    }
    MapAbout {
        id: aboutCard
        Layout.fillWidth: true
        workspace: root.workspace
        active: root.workspace.pagePresented && root.workspace.page === "settings"
        inView: active && height > 0 && root.workspace.viewportHeight > 0
            && Math.min(y + height, root.workspace.viewportY + root.workspace.viewportHeight)
                - Math.max(y, root.workspace.viewportY)
                >= Math.min(height, root.workspace.viewportHeight) * 0.4
    }
}
