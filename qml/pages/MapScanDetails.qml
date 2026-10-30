import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "../components"

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
    readonly property string statusKey: scanning ? "compact.working"
        : !service || !service.ready ? "compact.notScanned"
        : incomplete ? "scan.partialSnapshot" : "scan.snapshot"
    readonly property string statusIcon: scanning ? "scan"
        : !service || !service.ready ? "history" : incomplete ? "leftovers" : "check"
    readonly property color statusColor: incomplete && !scanning ? Color.urgent : workspace.heroColor
    property bool notesOpen: false
    property bool detailsOpen: false
    property string selectedNote: ""
    property string technicalHelpKey: ""
    readonly property var technicalTopics: [
        {icon: "folder", label: "scan.rule.scope", value: "scan.rule.known", help: "scan.scopeHelp"},
        {icon: "apps", label: "scan.rule.coverage", value: "scan.rule.matches", help: "scan.coverageHelp"},
        {icon: "data", label: "scan.rule.size", value: "scan.logicalBytes", help: "scan.bytesHelp"},
        {icon: "leftovers", label: "scan.rule.unknown", value: "scan.unknown", help: "scan.unknownHelp"}
    ]
    onNotesOpenChanged: {
        if (notesOpen) detailsOpen = false;
        else selectedNote = "";
    }
    onDetailsOpenChanged: if (detailsOpen) notesOpen = false
    onSummaryChanged: {
        if (!summary.reasons.length) notesOpen = false;
        if (summary.reasons.indexOf(selectedNote) < 0) selectedNote = "";
    }
    // Reveal after the page grows; a click can still see the old scroll range.
    onImplicitHeightChanged: Qt.callLater(function() {
        if (root.notesOpen && root.selectedNote) root.workspace.reveal(noteHint);
        else if (root.detailsOpen && root.technicalHelpKey) root.workspace.reveal(technicalHint);
    })
    spacing: Style.space(8)

    function openTechnical(key) {
        technicalHelpKey = key;
        detailsOpen = true;
        Qt.callLater(function() { root.workspace.reveal(technicalHint); });
    }
    function noteIcon(code) {
        var icons = {permission: "leftovers", changed: "refresh", symlink: "link",
            special: "config", limit: "stop", error: "leftovers", hardlink: "link",
            cancelled: "close", metadata: "apps"};
        return icons[code] || "info";
    }

    component Disclosure: Ui.Button {
        id: disclosure
        required property string label
        required property string symbol
        property string count: ""
        Layout.fillWidth: true
        implicitHeight: Math.max(Style.space(40), disclosureBody.implicitHeight + Style.space(16))
        radius: Style.space(10)
        foreground: Color.popups.text
        accent: root.workspace.heroColor
        background: Util.alpha(Color.popups.text, 0.035)
        focusable: true
        opacity: enabled ? 1 : 0.55
        Accessible.name: label
        Accessible.expanded: selected
        Accessible.onPressAction: if (enabled) clicked()
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        RowLayout {
            id: disclosureBody
            x: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(20)
            spacing: Style.space(9)
            MapGlyph {
                icon: disclosure.symbol
                Layout.preferredWidth: Style.space(16)
                font.pixelSize: Style.font.bodySmall
                color: root.workspace.heroColor
            }
            MapText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: disclosure.label
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
                Accessible.ignored: true
            }
            Rectangle {
                visible: disclosure.count !== ""
                implicitWidth: Math.max(Style.space(24), countLabel.implicitWidth + Style.space(12))
                implicitHeight: Style.space(24)
                radius: height / 2
                color: Util.alpha(root.workspace.heroColor, 0.13)
                MapText {
                    id: countLabel
                    anchors.centerIn: parent
                    text: disclosure.count
                    font.pixelSize: Style.font.caption
                    font.weight: Font.DemiBold
                    color: root.workspace.heroColor
                    Accessible.ignored: true
                }
            }
            MapGlyph {
                icon: disclosure.selected ? "triangle-up" : "triangle-down"
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.6)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: health.implicitHeight + Style.space(24)
        radius: Style.space(12)
        color: Util.alpha(root.workspace.heroColor, 0.065)
        border.width: 1
        border.color: Util.alpha(root.workspace.heroColor, 0.12)
        ColumnLayout {
            id: health
            x: Style.space(12)
            y: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(6)
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)
                MapText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.workspace.strings.t("scan.measured")
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.7)
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                }
                Rectangle {
                    Layout.maximumWidth: health.width * 0.62
                    implicitWidth: statusBody.implicitWidth + Style.space(12)
                    implicitHeight: statusBody.implicitHeight + Style.space(8)
                    radius: height / 2
                    color: Util.alpha(root.statusColor, 0.1)
                    RowLayout {
                        id: statusBody
                        x: Style.space(6)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(12)
                        spacing: Style.space(5)
                        MapGlyph {
                            icon: root.statusIcon
                            color: root.statusColor
                            font.pixelSize: Style.font.caption
                        }
                        MapText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: root.workspace.strings.t(root.statusKey)
                            font.pixelSize: Style.font.caption
                            color: root.statusColor
                            horizontalAlignment: Text.AlignLeft
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
            MapText {
                Layout.fillWidth: true
                text: root.measuredSize
                font.pixelSize: Style.font.heading * 1.55
                font.weight: Font.DemiBold
                color: root.workspace.heroColor
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.WrapAnywhere
                Accessible.description: root.workspace.strings.t(root.incomplete ? "scan.lowerBoundHelp" : "scan.scopeHelp")
            }
            RowLayout {
                Layout.fillWidth: true
                visible: root.scanning || !!root.service && root.service.scannedAt > 0
                spacing: Style.space(6)
                MapGlyph {
                    icon: root.scanning ? "scan" : "history"
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.5)
                }
                MapText {
                    Layout.fillWidth: true
                    text: root.scanning
                        ? root.service.scanTotalPaths > 0
                            ? root.workspace.strings.t("compact.progress")
                                .arg(root.workspace.number(root.service.scanCompletedPaths)).arg(root.workspace.number(root.service.scanTotalPaths))
                            : root.workspace.strings.t("scan.inventory")
                        : root.service && root.service.scannedAt > 0
                            ? root.workspace.strings.t("scan.snapshotTime").arg(root.workspace.date(root.service.scannedAt))
                            : ""
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(Color.popups.text, 0.6)
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                }
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: matchBody.implicitHeight + Style.space(24)
        radius: Style.space(12)
        color: Util.alpha(Color.popups.text, 0.025)
        border.width: 1
        border.color: Util.alpha(Color.popups.text, 0.08)
        ColumnLayout {
            id: matchBody
            x: Style.space(12)
            y: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(8)
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)
                MapText {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("scan.coverage.title")
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.Wrap
                }
                MapText {
                    text: root.workspace.number(root.summary.total)
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                }
                MapIconButton {
                    icon: "info"
                    label: root.workspace.strings.t("scan.rule.coverage")
                    onClicked: root.openTechnical("scan.coverageHelp")
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
            }
            // Widths represent match records, not unique paths or disk coverage.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.space(8)
                radius: height / 2
                color: Util.alpha(Color.popups.text, 0.06)
                Row {
                    anchors.fill: parent
                    spacing: Style.space(2)
                    Repeater {
                        id: coverageSegments
                        model: root.coverage.filter(function(part) { return part.count > 0; })
                        Rectangle {
                            required property var modelData
                            width: root.summary.total > 0
                                ? Math.max(0, parent.width - parent.spacing * (coverageSegments.count - 1)) * modelData.count / root.summary.total : 0
                            height: parent.height
                            radius: height / 2
                            color: modelData.tint
                        }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                visible: root.summary.total > 0
                columns: 2
                columnSpacing: Style.space(6)
                rowSpacing: Style.space(6)
                Repeater {
                    model: root.coverage
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        implicitHeight: Math.max(Style.space(40), metricBody.implicitHeight + Style.space(12))
                        radius: Style.space(8)
                        color: Util.alpha(modelData.tint, modelData.count > 0 ? 0.09 : 0.035)
                        RowLayout {
                            id: metricBody
                            x: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Style.space(16)
                            spacing: Style.space(8)
                            MapText {
                                text: root.workspace.number(modelData.count)
                                font.pixelSize: Style.font.heading
                                font.weight: Font.DemiBold
                                color: modelData.count > 0 ? Color.popups.text : Util.alpha(Color.popups.text, 0.4)
                            }
                            MapText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: root.workspace.strings.t(modelData.label)
                                font.pixelSize: Style.font.caption
                                color: Util.alpha(Color.popups.text, 0.7)
                                horizontalAlignment: Text.AlignLeft
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
            MapText {
                Layout.fillWidth: true
                visible: root.summary.total === 0
                text: root.workspace.strings.t("scan.coverage.empty")
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.6)
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
            }
        }
    }
    Disclosure {
        label: root.workspace.strings.t("scan.notesTitle")
        symbol: "info"
        count: root.summary.reasons.length > 0 ? root.workspace.number(root.summary.reasons.length)
            : root.service && root.service.ready && !root.scanning ? root.workspace.number(0) : "—"
        enabled: root.summary.reasons.length > 0
        selected: root.notesOpen
        Accessible.description: root.workspace.strings.tn("scan.notesCount", root.summary.reasons.length)
            .arg(root.workspace.number(root.summary.reasons.length))
        onClicked: {
            root.notesOpen = !root.notesOpen;
            if (root.notesOpen) Qt.callLater(function() {
                var first = noteCards.itemAt(0);
                if (first) root.workspace.reveal(first);
            });
        }
    }
    Disclosure {
        label: root.workspace.strings.t("scan.technical")
        symbol: "config"
        selected: root.detailsOpen
        onClicked: {
            root.detailsOpen = !root.detailsOpen;
            if (root.detailsOpen) Qt.callLater(function() { root.workspace.reveal(technicalChoices); });
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.notesOpen && root.summary.reasons.length > 0
        spacing: Style.space(8)
        RowLayout {
            Layout.fillWidth: true
            MapText {
                Layout.fillWidth: true
                text: root.workspace.strings.t("scan.countsTitle")
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.6)
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
            }
            MapIconButton {
                icon: "info"
                label: root.workspace.strings.t("scan.countsTitle")
                onClicked: root.openTechnical("scan.countsHelp")
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(6)
            rowSpacing: Style.space(6)
            Repeater {
                id: noteCards
                model: root.summary.reasons
                Ui.Button {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    implicitHeight: note.implicitHeight + Style.space(20)
                    radius: Style.space(10)
                    foreground: Color.popups.text
                    accent: root.workspace.insightColor
                    background: Util.alpha(root.workspace.insightColor, 0.055)
                    selected: root.selectedNote === modelData
                    focusable: true
                    Accessible.name: root.workspace.strings.t("scan.reason." + modelData, modelData)
                    Accessible.description: root.summary.counts[modelData] > 0
                        ? root.workspace.strings.tn("scan.encounters", root.summary.counts[modelData]).arg(root.workspace.number(root.summary.counts[modelData]))
                        : root.workspace.strings.t("scan.countUnavailable")
                    Accessible.expanded: selected
                    Accessible.onPressAction: clicked()
                    onClicked: {
                        root.selectedNote = selected ? "" : modelData;
                        if (root.selectedNote) Qt.callLater(function() { root.workspace.reveal(noteHint); });
                    }
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    ColumnLayout {
                        id: note
                        x: Style.space(10)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(20)
                        spacing: Style.space(5)
                        RowLayout {
                            Layout.fillWidth: true
                            MapGlyph {
                                icon: root.noteIcon(modelData)
                                color: root.workspace.insightColor
                                font.pixelSize: Style.font.bodySmall
                            }
                            Item { Layout.fillWidth: true }
                            MapText {
                                text: root.summary.counts[modelData] > 0 ? root.workspace.number(root.summary.counts[modelData]) : "—"
                                font.pixelSize: Style.font.heading
                                font.weight: Font.DemiBold
                                color: root.workspace.insightColor
                                Accessible.ignored: true
                            }
                        }
                        MapText {
                            Layout.fillWidth: true
                            text: root.workspace.strings.t("scan.reason." + modelData, modelData)
                            font.pixelSize: Style.font.caption
                            horizontalAlignment: Text.AlignLeft
                            wrapMode: Text.Wrap
                            Accessible.ignored: true
                        }
                    }
                }
            }
        }
        Rectangle {
            id: noteHint
            Layout.fillWidth: true
            visible: root.selectedNote !== ""
            implicitHeight: noteExplanation.implicitHeight + Style.space(20)
            radius: Style.space(10)
            color: Util.alpha(root.workspace.insightColor, 0.055)
            MapText {
                id: noteExplanation
                x: Style.space(10)
                y: Style.space(10)
                width: parent.width - Style.space(20)
                text: root.selectedNote ? root.workspace.strings.t("issue." + root.selectedNote, root.workspace.strings.t("issue.error")) : ""
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.75)
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        visible: root.detailsOpen
        implicitHeight: technical.implicitHeight + Style.space(16)
        radius: Style.space(10)
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
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        implicitHeight: choiceBody.implicitHeight + Style.space(18)
                        radius: Style.space(8)
                        foreground: Color.popups.text
                        accent: root.workspace.heroColor
                        background: Util.alpha(root.workspace.heroColor, 0.045)
                        selected: root.technicalHelpKey === modelData.help
                        focusable: true
                        Accessible.name: root.workspace.strings.t(modelData.label)
                        Accessible.description: root.workspace.strings.t(modelData.value)
                        Accessible.expanded: selected
                        Accessible.onPressAction: clicked()
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
                                    horizontalAlignment: Text.AlignLeft
                                    wrapMode: Text.Wrap
                                }
                            }
                            MapText {
                                Layout.fillWidth: true
                                text: root.workspace.strings.t(modelData.value)
                                font.pixelSize: Style.font.bodySmall
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignLeft
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
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
            }
            MapText {
                Layout.fillWidth: true
                visible: root.scanning && !!root.service.scanPath
                text: root.workspace.strings.t("scan.currentPath")
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                color: root.workspace.insightColor
                horizontalAlignment: Text.AlignLeft
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
