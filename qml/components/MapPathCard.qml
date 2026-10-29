import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../lib/ViewModel.js" as Model

Rectangle {
    id: root
    required property var entry
    required property var strings
    required property var service
    property bool current: false
    property color categoryColor: Color.accent
    property bool breakdownExpanded: false
    property bool evidenceExpanded: false
    signal selected(string actionPath)
    signal actionFocused(var item)

    function focusAction(item) {
        selected(entry.path);
        actionFocused(item);
    }

    onBreakdownExpandedChanged: if (breakdownExpanded) evidenceExpanded = false
    onEvidenceExpandedChanged: if (evidenceExpanded) breakdownExpanded = false

    implicitHeight: body.implicitHeight + Style.space(12)
    radius: Style.space(5)
    color: current ? Util.alpha(Color.accent, 0.07) : "transparent"
    TapHandler { onTapped: root.selected(root.entry.path) }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(6)
        spacing: Style.space(2)

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Rectangle {
                Layout.preferredWidth: Style.space(5)
                Layout.preferredHeight: Style.space(5)
                radius: width / 2
                color: root.categoryColor
            }
            MapText {
                Layout.fillWidth: true
                text: root.strings.t("compact." + root.entry.category)
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            MapText {
                text: Model.pathSize(root.entry, root.strings, I18n)
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
                color: ["denied", "missing", "error"].indexOf(root.entry.status) !== -1 ? Color.urgent : Color.popups.text
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.entry.label || root.entry.path
            elide: Text.ElideMiddle
            font.pixelSize: Style.font.bodySmall
            LayoutMirroring.enabled: false
            horizontalAlignment: Text.AlignLeft
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            MapText {
                text: root.strings.t(root.entry.reason === "user" ? "compact.user" : "compact." + root.entry.confidence)
                font.pixelSize: Style.font.caption
                color: root.entry.confidence === "known" ? Util.alpha(Color.popups.text, 0.7) : Color.urgent
            }
            MapText {
                visible: root.entry.confidence !== "known"
                text: root.strings.t("compact.excluded")
                Layout.leftMargin: Style.space(4)
                font.pixelSize: Style.font.caption
                color: Color.urgent
            }
            Item { Layout.fillWidth: true }
            MapIconButton {
                icon: "folder"
                label: root.strings.t("openFolder")
                enabled: !!root.service && !root.service.actionBusy
                onActiveFocusChanged: if (activeFocus) root.focusAction(this)
                onClicked: { root.selected(root.entry.path); root.service.openPath(root.entry.path); }
            }
            MapIconButton {
                icon: "copy"
                label: root.strings.t(root.service && root.service.copiedPath === root.entry.path ? "copied" : "copyPath")
                enabled: !!root.service
                onActiveFocusChanged: if (activeFocus) root.focusAction(this)
                onClicked: { root.selected(root.entry.path); root.service.copyPath(root.entry.path); }
            }
            MapIconButton {
                icon: "info"
                label: root.strings.t(root.evidenceExpanded ? "hideEvidence" : "showEvidence")
                selected: root.evidenceExpanded
                onActiveFocusChanged: if (activeFocus) root.focusAction(this)
                onClicked: { root.selected(root.entry.path); root.evidenceExpanded = !root.evidenceExpanded; }
            }
            MapIconButton {
                icon: root.breakdownExpanded ? "down" : "next"
                label: root.strings.t(root.breakdownExpanded ? "hideBreakdown" : "showBreakdown")
                selected: root.breakdownExpanded
                onActiveFocusChanged: if (activeFocus) root.focusAction(this)
                onClicked: { root.selected(root.entry.path); root.breakdownExpanded = !root.breakdownExpanded; }
            }
        }
        Loader {
            Layout.fillWidth: true
            Layout.topMargin: active ? Style.space(5) : 0
            active: root.breakdownExpanded
            visible: active
            sourceComponent: MapBreakdown {
                entry: root.entry
                strings: root.strings
                service: root.service
                categoryColor: root.categoryColor
                onSelected: function(actionPath) { root.selected(actionPath); }
                onActionFocused: function(item) { root.actionFocused(item); }
            }
        }
        MapEvidence {
            Layout.fillWidth: true
            Layout.topMargin: visible ? Style.space(5) : 0
            visible: root.evidenceExpanded
            entry: root.entry
            strings: root.strings
            onActionFocused: function(item) { root.focusAction(item); }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Util.alpha(Color.popups.text, 0.08)
    }
}
