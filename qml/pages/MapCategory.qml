import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Ui as Ui
import "../lib/CategoryModel.js" as CategoryModel
import "../lib/ViewModel.js" as Model
import "../components"

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: false
    readonly property var service: workspace.service
    readonly property var strings: workspace.strings
    readonly property string categoryKey: workspace.categoryKey
    readonly property var summary: CategoryModel.summary(service ? service.apps : [], categoryKey)
    readonly property bool scanning: !!service && service.busy && service.scanMode === "overview"
    readonly property bool incomplete: summary.partial || !service || !service.inventoryComplete || scanning
    readonly property color categoryColor: workspace.palette[Model.categoryKeys.indexOf(categoryKey)]
    readonly property real measuredTotal: service ? service.mappedBytes : 0
    readonly property real share: summary.bytes !== null && measuredTotal > 0 ? Math.min(1, Math.max(0, summary.bytes / measuredTotal)) : 0
    readonly property var tileRows: CategoryModel.tiles(summary.apps, treemap.width, treemap.height, 7)
    readonly property var otherIds: {
        for (var i = 0; i < tileRows.length; ++i)
            if (tileRows[i].kind === "other") return tileRows[i].members;
        return [];
    }
    readonly property var pickerRows: otherOnly ? summary.apps.filter(function(app) { return root.otherIds.indexOf(app.id) !== -1; }) : summary.apps
    readonly property var selectedApp: {
        for (var i = 0; i < summary.apps.length; ++i)
            if (summary.apps[i].id === selectedAppId) return summary.apps[i];
        return null;
    }
    property string selectedAppId: ""
    property string selectedPath: ""
    property var inspectedTile: null
    property bool pickerOpen: false
    property bool otherOnly: false
    property bool excludedOpen: false
    property bool infoOpen: false
    spacing: Style.space(8)

    function toggleInfo() { infoOpen = !infoOpen; }
    function chooseApp(id) {
        selectedAppId = id;
        selectedPath = "";
        pickerOpen = false;
        otherOnly = false;
        Qt.callLater(function() {
            var first = locationCards.itemAt(0);
            if (first) workspace.reveal(first);
        });
    }
    function reconcileSelection() {
        if (selectedAppId && !selectedApp && service && service.inventoryComplete && !scanning) {
            selectedAppId = "";
            selectedPath = "";
        }
        if (otherOnly && !otherIds.length) otherOnly = false;
        inspectedTile = null;
    }
    onCategoryKeyChanged: {
        selectedAppId = "";
        selectedPath = "";
        inspectedTile = null;
        pickerOpen = false;
        otherOnly = false;
        excludedOpen = false;
        infoOpen = false;
    }
    onSummaryChanged: Qt.callLater(reconcileSelection)
    onScanningChanged: Qt.callLater(reconcileSelection)

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(3)
        Repeater {
            model: root.workspace.categoryTabs
            Ui.Button {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: Style.space(29)
                text: root.strings.t("compact." + modelData)
                selected: root.categoryKey === modelData
                accent: root.workspace.palette[Model.categoryKeys.indexOf(modelData)]
                foreground: Color.popups.text
                fontSize: Style.font.caption
                horizontalPadding: Style.space(5)
                focusable: true
                onClicked: root.workspace.selectCategory(modelData)
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
    }
    MapText {
        Layout.fillWidth: true
        visible: root.infoOpen
        text: root.strings.t("category.help")
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        color: Util.alpha(Color.popups.text, 0.72)
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(3)
        MapText {
            Layout.fillWidth: true
            text: root.workspace.size(root.summary.bytes, root.incomplete)
            color: root.categoryColor
            font.pixelSize: Style.font.heading * 1.8
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(9)
            MapText {
                Layout.fillWidth: true
                text: root.strings.t(root.incomplete ? "measurement.lowerBound" : "category.measuredBytes")
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.68)
                elide: Text.ElideRight
            }
            MapText {
                text: root.strings.tn("category.appCount", root.summary.apps.length).arg(root.workspace.number(root.summary.apps.length))
                font.pixelSize: Style.font.caption
            }
            MapText {
                text: root.strings.tn("category.locationCount", root.summary.knownPaths).arg(root.workspace.number(root.summary.knownPaths))
                font.pixelSize: Style.font.caption
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(4)
            radius: height / 2
            color: Util.alpha(Color.popups.text, 0.08)
            Rectangle {
                width: parent.width * root.share
                height: parent.height
                x: I18n.rightToLeft ? parent.width - width : 0
                radius: height / 2
                color: root.categoryColor
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.summary.bytes !== null && root.measuredTotal > 0
                ? root.strings.t("category.measuredShare").arg(I18n.formatNumber(root.share * 100, 1))
                : root.strings.t("category.noShare")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.68)
            wrapMode: Text.Wrap
        }
    }
    Item {
        id: treemap
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(174)
        LayoutMirroring.enabled: false
        Rectangle {
            anchors.fill: parent
            radius: Style.space(6)
            color: Util.alpha(Color.popups.text, 0.025)
        }
        Repeater {
            model: root.tileRows
            MapCategoryTile {
                required property var modelData
                required property int index
                x: I18n.rightToLeft ? treemap.width - modelData.x - modelData.width : modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                tile: modelData
                workspace: root.workspace
                tint: index % 2 ? Qt.tint(root.categoryColor, Util.alpha(Color.popups.text, 0.16)) : root.categoryColor
                selected: modelData.kind === "app" ? root.selectedAppId === modelData.appId : root.pickerOpen && root.otherOnly
                onActivated: {
                    if (modelData.kind === "app") root.chooseApp(modelData.appId);
                    else {
                        root.otherOnly = true;
                        root.pickerOpen = true;
                        Qt.callLater(function() { root.workspace.reveal(picker); });
                    }
                }
                onInspected: function(inspecting) {
                    if (inspecting) root.inspectedTile = modelData;
                    else if (root.inspectedTile === modelData) root.inspectedTile = null;
                }
            }
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(30)
            visible: !root.tileRows.length
            spacing: Style.space(7)
            MapGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.categoryKey === "state" ? "history" : root.categoryKey
                font.pixelSize: Style.font.heading
                color: root.categoryColor
            }
            MapText {
                width: parent.width
                text: root.strings.t(!root.summary.knownPaths ? "category.empty" : root.summary.bytes === null ? "category.unmeasured" : "category.zero")
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
    MapText {
        Layout.fillWidth: true
        text: root.inspectedTile
            ? root.strings.t("category.tileCaption").arg(root.inspectedTile.kind === "other" ? root.strings.t("category.other") : root.inspectedTile.name).arg(root.workspace.size(root.inspectedTile.bytes, root.inspectedTile.partial))
            : root.strings.t("category.mapHint")
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.7)
        elide: Text.ElideRight
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(5)
        Ui.Button {
            id: allAppsButton
            Layout.fillWidth: true
            text: root.strings.t(root.pickerOpen && !root.otherOnly ? "category.hideApps" : "category.allApps")
            selected: root.pickerOpen && !root.otherOnly
            enabled: root.summary.apps.length > 0
            fontSize: Style.font.caption
            focusable: true
            onClicked: {
                root.pickerOpen = root.otherOnly || !root.pickerOpen;
                root.otherOnly = false;
                if (root.pickerOpen) Qt.callLater(function() { root.workspace.reveal(picker); });
            }
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        Ui.Button {
            visible: root.summary.excluded.length > 0
            text: root.strings.tn("category.excludedCount", root.summary.excluded.length).arg(root.workspace.number(root.summary.excluded.length))
            selected: root.excludedOpen
            fontSize: Style.font.caption
            foreground: Color.urgent
            focusable: true
            onClicked: root.excludedOpen = !root.excludedOpen
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.pickerOpen
        spacing: Style.space(4)
        MapText {
            Layout.fillWidth: true
            text: root.strings.t(root.otherOnly ? "category.otherHelp" : "category.pickerHelp")
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            color: Util.alpha(Color.popups.text, 0.7)
        }
        Flickable {
            id: picker
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(pickerBody.implicitHeight, Style.space(160))
            contentHeight: pickerBody.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
            function revealRow(item) {
                var rowY = item.mapToItem(contentItem, 0, 0).y;
                if (rowY < contentY) contentY = rowY;
                else if (rowY + item.height > contentY + height) contentY = rowY + item.height - height;
                root.workspace.reveal(item);
            }
            Column {
                id: pickerBody
                width: picker.width - Style.space(8)
                Repeater {
                    model: root.pickerOpen ? root.pickerRows : []
                    Ui.Button {
                        id: appChoice
                        required property var modelData
                        width: pickerBody.width
                        implicitHeight: Style.space(36)
                        selected: root.selectedAppId === modelData.id
                        accent: root.categoryColor
                        foreground: Color.popups.text
                        focusable: true
                        Accessible.name: modelData.name
                        Accessible.description: root.workspace.size(modelData.bytes, modelData.partial)
                        onClicked: {
                            root.chooseApp(modelData.id);
                            allAppsButton.forceActiveFocus();
                        }
                        onActiveFocusChanged: if (activeFocus) picker.revealRow(this)
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Style.space(6)
                            spacing: Style.space(8)
                            Item {
                                Layout.preferredWidth: Style.space(20)
                                Layout.preferredHeight: Style.space(20)
                                Image {
                                    id: choiceIcon
                                    anchors.fill: parent
                                    source: /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(appChoice.modelData.icon || "") ? Quickshell.iconPath(appChoice.modelData.icon, true) : ""
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                                MapText {
                                    anchors.centerIn: parent
                                    visible: !choiceIcon.visible
                                    text: appChoice.modelData.name.slice(0, 1).toLocaleUpperCase()
                                    color: root.categoryColor
                                }
                            }
                            MapText {
                                Layout.fillWidth: true
                                text: appChoice.modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: Style.font.bodySmall
                            }
                            MapText {
                                text: root.workspace.size(appChoice.modelData.bytes, appChoice.modelData.partial)
                                font.pixelSize: Style.font.caption
                                color: Util.alpha(Color.popups.text, 0.75)
                            }
                        }
                    }
                }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: !!root.selectedApp
        spacing: Style.space(4)
        RowLayout {
            Layout.fillWidth: true
            MapText {
                Layout.fillWidth: true
                text: root.selectedApp ? root.strings.t("category.appLocations").arg(root.selectedApp.name).arg(root.strings.t("compact." + root.categoryKey)) : ""
                font.weight: Font.DemiBold
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
            }
            MapIconButton {
                icon: "close"
                label: root.strings.t("category.closeLocations")
                onClicked: { root.selectedAppId = ""; root.selectedPath = ""; allAppsButton.forceActiveFocus(); }
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
        Repeater {
            id: locationCards
            model: root.selectedApp ? root.selectedApp.paths : []
            MapPathCard {
                required property var modelData
                Layout.fillWidth: true
                entry: modelData
                strings: root.strings
                service: root.service
                categoryColor: root.categoryColor
                current: root.selectedPath === entry.path
                onSelected: function(actionPath) { root.selectedPath = actionPath; }
                onActionFocused: function(item) { root.workspace.reveal(item); }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.excludedOpen
        spacing: Style.space(4)
        MapText {
            Layout.fillWidth: true
            text: root.strings.t("category.excludedHelp")
            font.pixelSize: Style.font.caption
            color: Color.urgent
            wrapMode: Text.Wrap
        }
        Repeater {
            model: root.excludedOpen ? root.summary.excluded : []
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 0
                MapText {
                    Layout.fillWidth: true
                    text: root.strings.t("category.candidateApp").arg(modelData.appName)
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }
                MapPathCard {
                    Layout.fillWidth: true
                    entry: modelData.entry
                    strings: root.strings
                    service: root.service
                    categoryColor: Color.urgent
                    current: false
                    onActionFocused: function(item) { root.workspace.reveal(item); }
                }
            }
        }
    }
}
