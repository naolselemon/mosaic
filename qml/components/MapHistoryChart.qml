import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui
import "../lib/YearModel.js" as YearModel

ColumnLayout {
    id: root
    required property var workspace
    property string appId: ""
    property string mode: "overview"
    property int maximumRows: workspace.prefs ? workspace.prefs.chartSamples : 14
    property bool allowDetails: true
    property bool compact: false
    property bool detailsOpen: false
    property int selectedIndex: -1
    readonly property var allSamples: {
        var history = workspace.view ? workspace.view.history : [];
        var result = [];
        for (var i = 0; i < history.length; i++) {
            var snapshot = history[i];
            if (snapshot.mode !== mode || mode === "deep" && snapshot.targetId !== appId) continue;
            if (!appId) {
                if (mode === "overview") result.push({at: snapshot.at, bytes: YearModel.footprint(snapshot), partial: snapshot.partial});
            } else {
                for (var j = 0; j < snapshot.apps.length; j++) {
                    var app = snapshot.apps[j];
                    if (app.id === appId) {
                        result.push({at: snapshot.at, bytes: app.bytes, partial: app.partial});
                        break;
                    }
                }
            }
        }
        return result.sort(function(a, b) { return a.at - b.at; });
    }
    readonly property var samples: allSamples.slice(-Math.max(1, maximumRows))
    readonly property real largest: samples.reduce(function(value, sample) { return Math.max(value, sample.bytes === null ? 0 : sample.bytes); }, 1)
    readonly property var selectedSample: samples.length ? samples[selectedIndex >= 0 && selectedIndex < samples.length ? selectedIndex : samples.length - 1] : null
    onSamplesChanged: selectedIndex = -1
    spacing: Style.space(5)

    RowLayout {
        Layout.fillWidth: true
        visible: root.samples.length > 0
        MapText {
            Layout.fillWidth: true
            text: root.selectedSample ? root.workspace.date(root.selectedSample.at) : ""
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            color: Util.alpha(Color.popups.text, 0.7)
        }
        MapText {
            text: root.selectedSample ? root.workspace.size(root.selectedSample.bytes, root.selectedSample.partial) : ""
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
            color: root.selectedSample && root.selectedSample.partial ? Color.urgent : root.workspace.insightColor
        }
    }
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(root.compact ? 68 : 98)
        visible: root.samples.length > 0
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: parent.width
                height: 1
                y: index * (parent.height - 1) / 2
                color: Util.alpha(Color.popups.text, 0.09)
            }
        }
        RowLayout {
            anchors.fill: parent
            spacing: Style.space(2)
            Repeater {
                model: root.samples
                Item {
                    id: sampleBar
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: root.workspace.strings.t("visual.snapshotIdentity").arg(root.workspace.date(modelData.at)).arg(root.workspace.size(modelData.bytes, modelData.partial))
                    Accessible.onPressAction: root.selectedIndex = index
                    onActiveFocusChanged: if (activeFocus) { root.selectedIndex = index; root.workspace.reveal(this); }
                    Keys.onSpacePressed: root.selectedIndex = index
                    Keys.onReturnPressed: root.selectedIndex = index
                    Rectangle {
                        anchors.fill: parent
                        color: sampleBar.activeFocus || root.selectedIndex === sampleBar.index ? Util.alpha(root.workspace.insightColor, 0.12) : "transparent"
                        border.width: sampleBar.activeFocus ? 1 : 0
                        border.color: root.workspace.insightColor
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(2, Math.min(Style.space(18), parent.width - Style.space(2)))
                        height: sampleBar.modelData.bytes === null ? Style.space(3) : Math.max(Style.space(2), (parent.height - Style.space(4)) * sampleBar.modelData.bytes / root.largest)
                        color: sampleBar.modelData.bytes === null ? "transparent" : sampleBar.modelData.partial ? Util.alpha(Color.urgent, 0.22) : root.workspace.insightColor
                        border.width: sampleBar.modelData.bytes === null || sampleBar.modelData.partial ? 1 : 0
                        border.color: sampleBar.modelData.bytes === null ? Util.alpha(Color.popups.text, 0.5) : Color.urgent
                        radius: Style.space(2)
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedIndex = sampleBar.index; sampleBar.forceActiveFocus(); } }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: root.samples.length > 0
        MapText { Layout.fillWidth: true; text: root.workspace.strings.t("visual.oldest"); font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.55) }
        MapText { text: root.workspace.strings.t("visual.newest"); font.pixelSize: Style.font.caption; color: Util.alpha(Color.popups.text, 0.55) }
    }
    MapText {
        Layout.fillWidth: true
        visible: root.samples.length > 0 && !root.compact
        text: root.workspace.strings.t("visual.snapshotLegend")
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.65)
        wrapMode: Text.Wrap
    }
    MapText {
        Layout.fillWidth: true
        visible: !root.samples.length
        text: root.workspace.strings.t(root.workspace.settings && root.workspace.settings.historyEnabled ? "workspace.noHistory" : "workspace.historyOff")
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
        color: Util.alpha(Color.popups.text, 0.7)
    }
    Ui.Button {
        visible: root.allowDetails && root.allSamples.length > 0
        text: root.workspace.strings.tn("visual.snapshotCount", root.allSamples.length).arg(root.workspace.number(root.allSamples.length))
        selected: root.detailsOpen
        focusable: true
        fontSize: Style.font.caption
        onClicked: root.detailsOpen = !root.detailsOpen
        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
    }
    Repeater {
        model: root.detailsOpen && root.allowDetails ? root.allSamples.slice().reverse() : []
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            MapText { Layout.fillWidth: true; text: root.workspace.date(modelData.at); font.pixelSize: Style.font.caption; wrapMode: Text.Wrap }
            MapText { text: root.workspace.size(modelData.bytes, modelData.partial); font.pixelSize: Style.font.caption; color: modelData.partial ? Color.urgent : Color.popups.text }
        }
    }
}
