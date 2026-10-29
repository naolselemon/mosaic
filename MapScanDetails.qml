import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: false
    readonly property var service: workspace.service
    readonly property bool scanning: !!service && service.busy && service.scanMode === "overview"
    readonly property bool incomplete: !!service && (service.partial || service.limited || scanning)
    readonly property var summary: {
        var result = { total: 0, complete: 0, incomplete: 0, pending: 0, excluded: 0,
            measured: false, reasons: service ? service.warnings.slice() : [], counts: {} };
        var apps = service ? service.apps : [];
        for (var i = 0; i < apps.length; ++i) {
            var paths = apps[i].paths || [];
            for (var j = 0; j < paths.length; ++j) {
                var path = paths[j];
                ++result.total;
                if (path.confidence !== "known") ++result.excluded;
                else {
                    if (path.status === "complete") ++result.complete;
                    else if (path.status === "pending") ++result.pending;
                    else ++result.incomplete;
                    if (path.bytes !== null && path.bytes !== undefined) result.measured = true;
                }
                var issues = path.issues || [];
                for (var k = 0; k < issues.length; ++k)
                    if (result.reasons.indexOf(issues[k]) < 0) result.reasons.push(issues[k]);
                var counts = path.skippedCounts || {};
                for (var code in counts) {
                    result.counts[code] = (result.counts[code] || 0) + counts[code];
                    if (counts[code] > 0 && result.reasons.indexOf(code) < 0) result.reasons.push(code);
                }
            }
        }
        return result;
    }
    readonly property var coverage: [
        { label: "scan.coverage.complete", count: summary.complete, tint: workspace.heroColor },
        { label: "scan.coverage.incomplete", count: summary.incomplete, tint: Color.urgent },
        { label: "scan.coverage.pending", count: summary.pending, tint: Util.alpha(Color.popups.text, 0.5) },
        { label: "scan.coverage.excluded", count: summary.excluded, tint: Util.alpha(Color.popups.text, 0.22) }
    ]
    readonly property string measuredSize: !service || !summary.measured
        ? workspace.strings.t("size.unknown") : workspace.size(service.mappedBytes, incomplete)
    property bool notesOpen: false
    property bool detailsOpen: false
    property string technicalHelpKey: ""
    readonly property var technicalTopics: [
        {icon: "folder", label: "scan.rule.scope", value: "scan.rule.known", help: "scan.scopeHelp"},
        {icon: "apps", label: "scan.rule.coverage", value: "scan.rule.matches", help: "scan.coverageHelp"},
        {icon: "data", label: "scan.rule.size", value: "scan.logicalBytes", help: "scan.bytesHelp"},
        {icon: "leftovers", label: "scan.rule.unknown", value: "scan.rule.notEstimated", help: "scan.unknownHelp"}
    ]
    spacing: Style.space(10)

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: health.implicitHeight + Style.space(24)
        radius: Style.space(12)
        color: Util.alpha(root.workspace.heroColor, 0.065)
        ColumnLayout {
            id: health
            x: Style.space(12)
            y: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(10)
            RowLayout {
                Layout.fillWidth: true
                MapText {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("scan.measured")
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.7)
                    wrapMode: Text.Wrap
                }
                MapGlyph {
                    icon: root.scanning ? "scan" : root.incomplete ? "leftovers" : "check"
                    color: root.incomplete ? Color.urgent : root.workspace.heroColor
                    Accessible.name: root.workspace.strings.t(root.scanning ? "compact.working"
                        : !root.service || !root.service.ready ? "compact.notScanned"
                        : root.incomplete ? "scan.partialSnapshot" : "scan.snapshot")
                }
            }
            MapText {
                Layout.fillWidth: true
                text: root.measuredSize
                font.pixelSize: Style.font.heading * 1.65
                font.weight: Font.DemiBold
                color: root.workspace.heroColor
                wrapMode: Text.WrapAnywhere
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Util.alpha(Color.popups.text, 0.1)
            }
            RowLayout {
                Layout.fillWidth: true
                MapText {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("scan.coverage.title")
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                MapText {
                    text: root.workspace.number(root.summary.total)
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                }
            }
            // Segment widths describe candidate records, never a share of unknown disk contents.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(10)
                color: Util.alpha(Color.popups.text, 0.08)
                radius: Math.min(Style.cornerRadius, Style.space(3))
                Row {
                    anchors.fill: parent
                    layoutDirection: I18n.rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
                    Repeater {
                        model: root.coverage
                        Rectangle {
                            required property var modelData
                            width: root.summary.total > 0 ? parent.width * modelData.count / root.summary.total : 0
                            height: parent.height
                            color: modelData.tint
                        }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Style.space(12)
                rowSpacing: Style.space(8)
                Repeater {
                    model: root.coverage
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: Style.space(6)
                        Rectangle {
                            Layout.preferredWidth: Style.space(5)
                            Layout.preferredHeight: Style.space(5)
                            radius: width / 2
                            color: modelData.tint
                        }
                        MapText {
                            Layout.fillWidth: true
                            text: root.workspace.strings.t(modelData.label)
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.Wrap
                        }
                        MapText {
                            text: root.workspace.number(modelData.count)
                            font.pixelSize: Style.font.bodySmall
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
            MapText {
                Layout.fillWidth: true
                text: root.workspace.strings.t(root.summary.total ? "scan.coverage.caveat" : "scan.coverage.empty")
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.6)
                wrapMode: Text.Wrap
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("scan.overviewScope")
            font.pixelSize: Style.font.bodySmall
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.service && root.service.scannedAt > 0
                ? root.workspace.strings.t("scan.snapshotTime").arg(root.workspace.date(root.service.scannedAt))
                : root.workspace.strings.t("scan.awaitingSnapshot")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t(root.incomplete ? "scan.lowerBoundHelp" : "scan.unknown")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
    }
    Ui.Button {
        Layout.fillWidth: true
        visible: root.summary.reasons.length > 0
        text: root.workspace.strings.tn(root.notesOpen ? "scan.hideNotesCount" : "scan.notesCount", root.summary.reasons.length)
            .arg(root.workspace.number(root.summary.reasons.length))
        fontSize: Style.font.caption
        focusable: visible
        selected: root.notesOpen
        onClicked: {
            root.notesOpen = !root.notesOpen;
            if (root.notesOpen) Qt.callLater(function() {
                var first = noteCards.itemAt(0);
                if (first) root.workspace.reveal(first);
            });
        }
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.notesOpen && root.summary.reasons.length > 0
        spacing: Style.space(6)
        Repeater {
            id: noteCards
            model: root.summary.reasons
            Rectangle {
                required property string modelData
                Layout.fillWidth: true
                implicitHeight: note.implicitHeight + Style.space(16)
                radius: Style.space(8)
                color: Util.alpha(Color.popups.text, 0.035)
                ColumnLayout {
                    id: note
                    x: Style.space(8)
                    y: Style.space(8)
                    width: parent.width - Style.space(16)
                    spacing: Style.space(4)
                    RowLayout {
                        Layout.fillWidth: true
                        MapGlyph {
                            icon: ["hardlink", "symlink", "special"].indexOf(modelData) >= 0 ? "info" : "leftovers"
                            color: root.workspace.insightColor
                            font.pixelSize: Style.font.caption
                        }
                        MapText {
                            Layout.fillWidth: true
                            text: root.workspace.strings.t("scan.reason." + modelData, modelData)
                            font.pixelSize: Style.font.bodySmall
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        MapText {
                            text: root.summary.counts[modelData] > 0 ? root.workspace.number(root.summary.counts[modelData]) : "—"
                            font.pixelSize: Style.font.bodySmall
                            color: root.workspace.insightColor
                        }
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.workspace.strings.t("issue." + modelData, root.workspace.strings.t("issue.error"))
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.65)
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("scan.countsHelp")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.6)
            wrapMode: Text.Wrap
        }
    }
    MapText {
        Layout.fillWidth: true
        visible: !root.summary.reasons.length && !!root.service && root.service.ready && !root.scanning
        text: root.workspace.strings.t("scan.noNotes")
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.6)
        wrapMode: Text.Wrap
    }
    Ui.Button {
        Layout.fillWidth: true
        text: root.workspace.strings.t(root.detailsOpen ? "scan.hideTechnical" : "scan.technical")
        fontSize: Style.font.caption
        focusable: true
        selected: root.detailsOpen
        onClicked: {
            root.detailsOpen = !root.detailsOpen;
            if (root.detailsOpen) Qt.callLater(function() { root.workspace.reveal(technicalChoices); });
        }
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
    Rectangle {
        Layout.fillWidth: true
        visible: root.detailsOpen
        implicitHeight: technical.implicitHeight + Style.space(16)
        radius: Style.space(8)
        color: Util.alpha(Color.popups.text, 0.025)
        ColumnLayout {
            id: technical
            x: Style.space(8)
            y: Style.space(8)
            width: parent.width - Style.space(16)
            spacing: Style.space(8)
            GridLayout {
                id: technicalChoices
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Style.space(6)
                rowSpacing: Style.space(6)
                Repeater {
                    model: root.technicalTopics
                    Ui.Button {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: choiceBody.implicitHeight + Style.space(18)
                        radius: Style.space(8)
                        accent: root.workspace.heroColor
                        background: Util.alpha(root.workspace.heroColor, 0.045)
                        selected: root.technicalHelpKey === modelData.help
                        focusable: true
                        Accessible.name: root.workspace.strings.t(modelData.label)
                        Accessible.description: root.workspace.strings.t(modelData.value)
                        Accessible.expanded: selected
                        onClicked: {
                            root.technicalHelpKey = selected ? "" : modelData.help;
                            if (root.technicalHelpKey) Qt.callLater(function() { root.workspace.reveal(technicalHint); });
                        }
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                        ColumnLayout {
                            id: choiceBody
                            anchors.centerIn: parent
                            width: parent.width - Style.space(16)
                            spacing: Style.space(4)
                            RowLayout {
                                Layout.fillWidth: true
                                MapGlyph { icon: modelData.icon; color: root.workspace.heroColor; font.pixelSize: Style.font.body }
                                MapText {
                                    Layout.fillWidth: true
                                    text: root.workspace.strings.t(modelData.label)
                                    font.pixelSize: Style.font.caption
                                    color: Util.alpha(Color.popups.text, 0.68)
                                    wrapMode: Text.Wrap
                                }
                            }
                            MapText {
                                Layout.fillWidth: true
                                text: root.workspace.strings.t(modelData.value)
                                font.pixelSize: Style.font.bodySmall
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
            MapText {
                id: technicalHint
                Layout.fillWidth: true
                visible: root.technicalHelpKey !== ""
                text: root.technicalHelpKey ? root.workspace.strings.t(root.technicalHelpKey) : ""
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.72)
                wrapMode: Text.Wrap
            }
            MapText {
                Layout.fillWidth: true
                visible: root.scanning && !!root.service.scanPath
                text: root.workspace.strings.t("scan.currentPath")
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                color: root.workspace.insightColor
                wrapMode: Text.Wrap
            }
            MapText {
                Layout.fillWidth: true
                visible: root.scanning && text !== ""
                text: root.scanning ? root.service.scanPath : ""
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.7)
                wrapMode: Text.WrapAnywhere
                LayoutMirroring.enabled: false
                horizontalAlignment: Text.AlignLeft
            }
        }
    }
}
