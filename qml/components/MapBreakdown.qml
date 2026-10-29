import QtQuick
import QtQuick.Layouts
import qs.Commons
import "../lib/ViewModel.js" as Model

ColumnLayout {
    id: root
    required property var entry
    required property var strings
    required property var service
    property color categoryColor: Color.accent
    readonly property var breakdown: entry.breakdown
    readonly property bool measured: entry.bytes !== null && entry.bytes !== undefined
    signal selected(string actionPath)
    signal actionFocused(var item)
    spacing: Style.space(3)

    MapText {
        Layout.fillWidth: true
        text: root.measured && root.breakdown ? root.strings.t("compact.topFolders") : root.strings.t("compact.noBreakdown")
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.65)
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: root.breakdown ? root.breakdown.children : []
        Item {
            id: childRow
            required property var modelData
            readonly property string childPath: root.entry.path + "/" + modelData.name
            readonly property bool measured: modelData.bytes !== null && modelData.bytes !== undefined
            Layout.fillWidth: true
            implicitHeight: Style.space(38)

            RowLayout {
                anchors.fill: parent
                spacing: Style.space(4)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.space(5)
                        MapText {
                            Layout.fillWidth: true
                            text: childRow.modelData.name
                            elide: Text.ElideMiddle
                            font.pixelSize: Style.font.bodySmall
                            LayoutMirroring.enabled: false
                            horizontalAlignment: Text.AlignLeft
                        }
                        MapText {
                            text: Model.pathSize(childRow.modelData, root.strings, I18n)
                            font.pixelSize: Style.font.bodySmall
                            color: ["denied", "missing", "error"].indexOf(childRow.modelData.status) !== -1 ? Color.urgent : Color.popups.text
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Style.space(3)
                        radius: height / 2
                        color: Util.alpha(Color.popups.text, 0.08)
                        visible: childRow.measured && root.entry.bytes > 0
                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: childRow.measured && root.entry.bytes > 0
                                ? parent.width * Math.min(1, Math.max(0, childRow.modelData.bytes / root.entry.bytes)) : 0
                            radius: height / 2
                            color: root.categoryColor
                        }
                    }
                }
                MapIconButton {
                    icon: "folder"
                    label: root.strings.t("openFolder")
                    enabled: !!root.service && !root.service.actionBusy
                    onActiveFocusChanged: if (activeFocus) { root.selected(childRow.childPath); root.actionFocused(this); }
                    onClicked: { root.selected(childRow.childPath); root.service.openPath(childRow.childPath); }
                }
                MapIconButton {
                    icon: "copy"
                    label: root.strings.t(root.service && root.service.copiedPath === childRow.childPath ? "copied" : "copyPath")
                    enabled: !!root.service
                    onActiveFocusChanged: if (activeFocus) { root.selected(childRow.childPath); root.actionFocused(this); }
                    onClicked: { root.selected(childRow.childPath); root.service.copyPath(childRow.childPath); }
                }
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        visible: root.measured && !!root.breakdown
        implicitHeight: 1
        color: Util.alpha(Color.popups.text, 0.08)
    }
    RowLayout {
        Layout.fillWidth: true
        visible: root.measured && !!root.breakdown
        Layout.topMargin: Style.space(3)
        MapText {
            Layout.fillWidth: true
            text: root.breakdown ? root.strings.tn("compact.direct", root.breakdown.directFiles).arg(I18n.formatNumber(root.breakdown.directFiles)) : ""
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            color: Util.alpha(Color.popups.text, 0.74)
        }
        MapText {
            text: root.breakdown ? Model.bytes(root.breakdown.directBytes, root.strings, I18n) : ""
            font.pixelSize: Style.font.caption
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: root.measured && !!root.breakdown
        MapText {
            Layout.fillWidth: true
            text: root.breakdown ? root.strings.tn("compact.other", root.breakdown.otherCount).arg(I18n.formatNumber(root.breakdown.otherCount)) : ""
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            color: Util.alpha(Color.popups.text, 0.74)
        }
        MapText {
            text: root.breakdown ? Model.bytes(root.breakdown.otherBytes, root.strings, I18n) : ""
            font.pixelSize: Style.font.caption
        }
    }
}
