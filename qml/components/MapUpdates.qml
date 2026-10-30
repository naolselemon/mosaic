import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

Rectangle {
    id: root
    required property var workspace
    readonly property var updates: workspace.service ? workspace.service.updates : null
    readonly property string installedVersion: workspace.service && workspace.service.manifest
        && typeof workspace.service.manifest.version === "string" ? workspace.service.manifest.version : ""
    property bool detailsOpen: false
    property string approvalCommit: ""
    property string approvalVersion: ""
    property bool approvalRejected: false
    readonly property bool needsDetails: !!updates && (!updates.supported || updates.status === "error" || updates.status === "recovery")
    readonly property bool statusOnly: !!updates && (updates.status === "recovery" || updates.error === "response" || updates.installing)

    Layout.fillWidth: true
    implicitWidth: Style.space(320)
    implicitHeight: content.implicitHeight + Style.space(24)
    radius: Math.max(Style.cornerRadius, Style.space(8))
    color: Util.alpha(Color.popups.text, 0.035)
    border.width: 1
    border.color: Util.alpha(Color.popups.text, 0.08)

    function statusText() {
        if (!updates) return workspace.strings.t("updates.unavailable");
        if (updates.checking) return workspace.strings.t("updates.checking");
        if (updates.installing) return workspace.strings.t("updates.installing");
        if (updates.busy) return workspace.strings.t("updates.loading");
        if (updates.error === "response" || updates.error === "timeout")
            return workspace.strings.t("updates.error." + updates.error);
        var text = workspace.strings.t("updates." + updates.status);
        return ["ahead", "ready"].indexOf(updates.status) !== -1 ? text.arg(updates.latest) : text;
    }
    function checkedText() {
        if (!updates || !updates.checkedAt) return "";
        return workspace.strings.t("updates.checkedAt").arg(
            new Date(updates.checkedAt).toLocaleString(Qt.locale(I18n.formatLocale), Locale.ShortFormat));
    }
    function resetApproval() {
        approvalCommit = "";
        approvalVersion = "";
        approvalRejected = false;
    }
    Connections {
        target: root.updates
        function onCommitChanged() { root.resetApproval(); }
        function onStatusChanged() {
            if (root.updates.status !== "ready") root.resetApproval();
        }
    }
    component Action: Ui.Button {
        Layout.minimumWidth: 0
        focusable: true
        foreground: Color.popups.text
        accent: root.workspace.heroColor
        fontSize: Style.font.caption
        horizontalPadding: Style.space(10)
        verticalPadding: Style.space(8)
        radius: Math.max(Style.cornerRadius, Style.space(4))
        opacity: enabled ? 1 : 0.45
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
    component Note: MapText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.6)
        wrapMode: Text.Wrap
    }

    ColumnLayout {
        id: content
        x: Style.space(12)
        y: Style.space(12)
        width: Math.max(0, root.width - Style.space(24))
        spacing: Style.space(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(9)
            MapPreferenceLabel {
                Layout.fillWidth: true
                Layout.leftMargin: Style.space(4)
                icon: "package"
                label: root.workspace.strings.t("updates.title")
                description: root.installedVersion
                    ? root.workspace.strings.t("updates.channel").arg(root.installedVersion)
                    : root.workspace.strings.t("preferences.versionUnavailable")
                accent: root.workspace.heroColor
            }
            Action {
                id: checkButton
                readonly property string label: root.workspace.strings.t(root.statusOnly ? "updates.refreshStatus" : "updates.checkNow")
                implicitWidth: checkContent.implicitWidth + Style.space(16)
                implicitHeight: checkContent.implicitHeight + Style.space(10)
                Layout.maximumWidth: parent.width * 0.55
                radius: height / 2
                bordered: true
                background: Util.alpha(root.workspace.heroColor, 0.12)
                enabled: !!root.updates && root.updates.cacheLoaded && !root.updates.busy && !root.updates.installing
                tooltipText: root.workspace.strings.t("updates.disclosure")
                Accessible.description: tooltipText
                Accessible.name: label
                Accessible.onPressAction: clicked()
                RowLayout {
                    id: checkContent
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(6)
                    Rectangle {
                        Layout.preferredWidth: Style.space(24)
                        Layout.preferredHeight: Style.space(24)
                        radius: height / 2
                        color: Util.alpha(root.workspace.heroColor, 0.22)
                        MapGlyph {
                            id: refreshGlyph
                            anchors.centerIn: parent
                            icon: "refresh"
                            font.pixelSize: Style.font.caption
                            color: root.workspace.heroColor
                            RotationAnimation on rotation {
                                from: 0
                                to: 360
                                duration: Style.duration(900)
                                loops: Animation.Infinite
                                easing.type: Easing.Linear
                                running: refreshGlyph.visible && !!root.updates
                                    && root.updates.checking && root.workspace.presentationActive
                                    && root.workspace.motionEnabled
                                onRunningChanged: if (!running) refreshGlyph.rotation = 0
                            }
                        }
                    }
                    MapText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: checkButton.label
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        Accessible.ignored: true
                    }
                }
                onClicked: {
                    root.resetApproval();
                    if (root.statusOnly) root.updates.refresh();
                    else root.updates.check();
                }
            }
        }
        MapPreferenceLabel {
            Layout.fillWidth: true
            Layout.leftMargin: Style.space(4)
            Layout.rightMargin: Style.space(4)
            icon: root.updates && ["error", "recovery"].indexOf(root.updates.status) !== -1 ? "leftovers"
                : root.updates && ["ready", "current", "installed"].indexOf(root.updates.status) !== -1 ? "check" : "refresh"
            label: root.statusText()
            description: root.checkedText()
            accent: root.updates && ["error", "recovery"].indexOf(root.updates.status) !== -1
                ? Color.urgent : root.workspace.heroColor
        }
        Note {
            Layout.leftMargin: I18n.rightToLeft ? Style.space(4) : Style.space(29)
            Layout.rightMargin: I18n.rightToLeft ? Style.space(29) : Style.space(4)
            visible: !!root.updates && root.updates.status === "ready"
            text: root.workspace.strings.t("updates.verifiedCommit").arg(root.updates ? root.updates.commit.slice(0, 12) : "")
        }
        Note {
            Layout.leftMargin: I18n.rightToLeft ? Style.space(4) : Style.space(29)
            Layout.rightMargin: I18n.rightToLeft ? Style.space(29) : Style.space(4)
            visible: !!root.updates && root.updates.cacheLoaded && !root.updates.supported && root.updates.status !== "recovery"
            text: root.workspace.strings.t("updates.manualBuild")
        }
        Action {
            Layout.alignment: I18n.rightToLeft ? Qt.AlignRight : Qt.AlignLeft
            Layout.leftMargin: I18n.rightToLeft ? 0 : Style.space(29)
            Layout.rightMargin: I18n.rightToLeft ? Style.space(29) : 0
            visible: root.needsDetails
            selected: root.detailsOpen
            text: root.workspace.strings.t(root.detailsOpen ? "updates.hideDetails" : "updates.details")
            Accessible.expanded: root.detailsOpen
            onClicked: root.detailsOpen = !root.detailsOpen
        }
        Note {
            Layout.leftMargin: I18n.rightToLeft ? Style.space(4) : Style.space(29)
            Layout.rightMargin: I18n.rightToLeft ? Style.space(29) : Style.space(4)
            visible: root.needsDetails && (root.detailsOpen || (!!root.updates && root.updates.status === "recovery"))
            text: root.updates ? [root.updates.reason, root.updates.message].filter(function(value, index, values) {
                return value && values.indexOf(value) === index;
            }).join("\n") : ""
            wrapMode: Text.WrapAnywhere
            color: root.updates && root.updates.status === "recovery" ? Color.urgent : Util.alpha(Color.popups.text, 0.65)
        }
        Action {
            id: reviewButton
            Layout.fillWidth: true
            visible: !!root.updates && root.updates.status === "ready" && root.approvalCommit === ""
            enabled: !!root.updates && root.updates.canInstall
            text: root.workspace.strings.t("updates.reviewInstall")
            onClicked: {
                root.approvalCommit = root.updates.commit;
                root.approvalVersion = root.updates.latest;
                Qt.callLater(function () { cancelButton.forceActiveFocus(); root.workspace.reveal(approval); });
            }
        }
        Note {
            visible: !!root.updates && root.updates.status === "ready" && !root.updates.canInstall && !root.updates.busy
            text: root.workspace.strings.t("updates.waitForIdle")
        }
        ColumnLayout {
            id: approval
            Layout.fillWidth: true
            visible: root.approvalCommit !== ""
            spacing: Style.space(8)
            onHeightChanged: if (visible && root.approvalCommit !== "") Qt.callLater(function () {
                root.workspace.reveal(approval);
            })
            MapPreferenceLabel {
                Layout.fillWidth: true
                icon: "refresh"
                label: root.workspace.strings.t("updates.approveVersion").arg(root.approvalVersion)
                description: root.workspace.strings.t("updates.restartWarning")
                accent: root.workspace.heroColor
            }
            Note {
                text: root.approvalCommit
                wrapMode: Text.WrapAnywhere
            }
            Note {
                visible: root.approvalRejected
                text: root.workspace.strings.t("updates.approvalChanged")
                color: Color.urgent
            }
            Action {
                Layout.fillWidth: true
                text: root.workspace.strings.t("updates.install")
                enabled: !!root.updates && root.updates.canInstall && root.updates.commit === root.approvalCommit
                onClicked: {
                    if (root.updates.install(root.approvalCommit)) root.resetApproval();
                    else root.approvalRejected = true;
                }
            }
            Action {
                id: cancelButton
                Layout.fillWidth: true
                text: root.workspace.strings.t("cancel")
                onClicked: { root.resetApproval(); reviewButton.forceActiveFocus(); }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Util.alpha(Color.popups.text, 0.08)
        }
        MapPreferenceToggle {
            workspace: root.workspace
            icon: "download"
            label: root.workspace.strings.t("updates.automatic")
            description: root.workspace.strings.t("updates.interval")
            accent: root.workspace.heroColor
            checked: root.workspace.prefs.prepareUpdates === true
            enabled: !!root.workspace.hostWidget && !!root.updates && !root.updates.installing
                && !root.workspace.service.updateQuiesced
            onClicked: root.workspace.setPreference("prepareUpdates", !checked)
        }
        Note {
            Layout.leftMargin: I18n.rightToLeft ? Style.space(4) : Style.space(29)
            Layout.rightMargin: I18n.rightToLeft ? Style.space(29) : Style.space(4)
            text: root.workspace.strings.t("updates.privacy")
        }
    }
}
