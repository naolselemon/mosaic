import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "ViewModel.js" as Model

ColumnLayout {
    id: root
    required property var entry
    required property var strings
    property bool detailsOpen: false
    readonly property var counts: Model.skippedReasons(entry.skippedCounts)
    readonly property bool included: entry.confidence === "known"
    signal actionFocused(var item)
    spacing: Style.space(7)

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: summary.implicitHeight + Style.space(16)
        color: Util.alpha(root.included ? Color.accent : Color.urgent, 0.07)
        radius: Style.cornerRadius
        ColumnLayout {
            id: summary
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)
                MapGlyph { icon: root.entry.reason === "user" ? "edit" : "link"; color: root.included ? Color.accent : Color.urgent }
                MapText {
                    Layout.fillWidth: true
                    text: root.strings.t("evidence.reason." + root.entry.reason)
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                MapText {
                    text: root.strings.t(root.included ? "evidence.included" : "compact.excluded")
                    font.pixelSize: Style.font.caption
                    color: root.included ? Color.accent : Color.urgent
                }
            }
            RowLayout {
                Layout.fillWidth: true
                MapText {
                    Layout.fillWidth: true
                    text: root.strings.t(root.entry.status === "partial" ? "measurement.lowerBound" : "status." + root.entry.status)
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                    color: Util.alpha(Color.popups.text, 0.72)
                }
                MapText {
                    text: root.entry.measuredAt > 0 ? new Date(root.entry.measuredAt).toLocaleTimeString(Qt.locale(I18n.formatLocale), Locale.ShortFormat) : "—"
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.62)
                }
            }
            MapText {
                Layout.fillWidth: true
                visible: root.entry.reason === "user"
                text: root.strings.t("evidence.userNotice")
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.62)
                wrapMode: Text.Wrap
            }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        visible: root.counts.length > 0
        columns: 2
        columnSpacing: Style.space(5)
        rowSpacing: Style.space(5)
        Repeater {
            model: root.counts
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: counter.implicitHeight + Style.space(12)
                radius: Style.cornerRadius
                color: Util.alpha(Color.popups.text, 0.035)
                RowLayout {
                    id: counter
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    MapText {
                        text: I18n.formatNumber(modelData.count)
                        font.pixelSize: Style.font.body
                        font.weight: Font.DemiBold
                        color: Color.accent
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.strings.t("scan.reason." + modelData.reason)
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
    Ui.Button {
        Layout.fillWidth: true
        text: root.strings.t(root.detailsOpen ? "evidence.hideDetails" : "evidence.details")
        focusable: true
        fontSize: Style.font.caption
        selected: root.detailsOpen
        onClicked: root.detailsOpen = !root.detailsOpen
        onActiveFocusChanged: if (activeFocus) root.actionFocused(this)
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.detailsOpen
        spacing: Style.space(7)
        MapText {
            Layout.fillWidth: true
            text: root.entry.path
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
            LayoutMirroring.enabled: false
            horizontalAlignment: Text.AlignLeft
        }
        MapText {
            Layout.fillWidth: true
            visible: root.entry.measuredAt > 0
            text: Model.timestamp(root.entry.measuredAt, Qt.locale(I18n.formatLocale), Locale.ShortFormat)
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.6)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.entry.evidence
            visible: text !== ""
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
            color: Util.alpha(Color.popups.text, 0.7)
        }
        MapText {
            Layout.fillWidth: true
            text: root.entry.source || ""
            visible: text !== ""
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
            color: Util.alpha(Color.popups.text, 0.6)
            LayoutMirroring.enabled: false
            horizontalAlignment: Text.AlignLeft
        }
        Repeater {
            model: root.entry.issues || []
            MapText {
                required property string modelData
                Layout.fillWidth: true
                text: root.strings.t("issue." + modelData, root.strings.t("issue.error"))
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                color: Util.alpha(Color.popups.text, 0.7)
            }
        }
        MapText {
            Layout.fillWidth: true
            visible: root.counts.length > 0
            text: root.strings.t("evidence.encounters")
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            color: Util.alpha(Color.popups.text, 0.6)
        }
        Repeater {
            model: root.entry.skippedSamples || []
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.space(2)
                MapText {
                    Layout.fillWidth: true
                    text: modelData.relative + (modelData.truncated ? "…" : "")
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WrapAnywhere
                    LayoutMirroring.enabled: false
                    horizontalAlignment: Text.AlignLeft
                }
                MapText {
                    text: root.strings.t("scan.reason." + modelData.reason)
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.6)
                }
            }
        }
    }
}
