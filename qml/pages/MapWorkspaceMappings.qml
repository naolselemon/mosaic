import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui as Ui
import "../lib/ViewModel.js" as Model
import "../components"

ColumnLayout {
    id: root
    required property var workspace
    readonly property bool typing: formOpen && (appFilter.activeFocus || pathInput.activeFocus)
    property bool infoOpen: false
    property bool formOpen: false
    property bool editingMapping: false
    property bool pickerOpen: true
    property string appId: ""
    property string query: ""
    property string category: "data"
    property string removeId: ""
    property string removePath: ""
    property var pending: null
    property string operationError: ""
    readonly property bool inlineError: operationError !== "" && (!workspace.service || operationError !== workspace.service.workspaceError)
    readonly property var apps: workspace.service ? Model.appsFor(workspace.service.apps, query) : []
    readonly property bool knownApp: !!workspace.service && !!Model.findApp(workspace.service.apps, appId)
    readonly property var mappings: workspace.view ? workspace.view.mappings : []
    spacing: Style.space(8)

    function toggleInfo() { infoOpen = !infoOpen; }
    function openForm(mapping) {
        editingMapping = !!mapping;
        removeId = "";
        removePath = "";
        appId = mapping ? mapping.id : "";
        category = mapping ? mapping.category : "data";
        pathInput.text = mapping ? mapping.path : "";
        query = "";
        appFilter.text = "";
        pickerOpen = !mapping;
        operationError = "";
        formOpen = true;
        Qt.callLater(function() {
            if (root.editingMapping) pathInput.forceActiveFocus();
            else appFilter.forceActiveFocus();
            root.workspace.reveal(form);
        });
    }
    function save() {
        var request = {kind: "save", id: appId, path: pathInput.text, category: category};
        operationError = "";
        if (workspace.service.saveMapping(request.id, request.path, request.category)) pending = request;
        else operationError = workspace.service.workspaceError || workspace.strings.t("workspace.failed");
    }
    function remove() {
        var request = {kind: "remove", id: removeId, path: removePath};
        operationError = "";
        if (workspace.service.removeMapping(request.id, request.path)) pending = request;
        else operationError = workspace.service.workspaceError || workspace.strings.t("workspace.failed");
    }
    function settle() {
        if (!pending || workspace.service.workspaceBusy) return;
        var request = pending;
        pending = null;
        if (workspace.service.workspaceError) {
            operationError = workspace.service.workspaceError;
            return;
        }
        var found = mappings.find(function(row) { return row.id === request.id && row.path === request.path; });
        if ((request.kind === "save" && (!found || found.category !== request.category))
                || (request.kind === "remove" && found)) {
            operationError = workspace.strings.t("preferences.mappingNotSaved");
            return;
        }
        if (request.kind === "save") formOpen = false;
        else { removeId = ""; removePath = ""; }
        addButton.forceActiveFocus();
    }
    Connections {
        target: root.workspace.service
        function onWorkspaceBusyChanged() {
            if (!root.workspace.service.workspaceBusy) Qt.callLater(root.settle);
        }
    }
    onInlineErrorChanged: if (inlineError)
        Qt.callLater(function() { root.workspace.reveal(mappingFailure); })

    RowLayout {
        Layout.fillWidth: true
        MapText {
            Layout.fillWidth: true
            text: root.workspace.view
                ? root.workspace.strings.tn("journey.customMappings", root.mappings.length).arg(root.workspace.number(root.mappings.length))
                : root.workspace.strings.t("journey.mappingsPending")
            font.pixelSize: Style.font.bodySmall
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }
        Ui.Button {
            id: addButton
            text: root.workspace.strings.t("preferences.add")
            focusable: true
            enabled: root.workspace.ready && !root.workspace.busy && !root.formOpen
            onClicked: root.openForm(null)
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
    }
    MapText {
        Layout.fillWidth: true
        visible: root.infoOpen
        text: root.workspace.strings.t("workspace.mappingHelp") + "\n" + root.workspace.strings.t("workspace.removeHelp")
        font.pixelSize: Style.font.caption
        color: Util.alpha(Color.popups.text, 0.7)
        wrapMode: Text.Wrap
    }
    MapText {
        id: mappingFailure
        Layout.fillWidth: true
        visible: root.inlineError
        text: root.operationError
        color: Color.urgent
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    MapSection {
        Layout.fillWidth: true
        visible: !!root.workspace.view && !root.mappings.length && !root.formOpen
        RowLayout {
            Layout.fillWidth: true
            MapGlyph { icon: "link"; color: Color.accent }
            MapText {
                Layout.fillWidth: true
                text: root.workspace.strings.t("journey.mappingEmpty")
                font.pixelSize: Style.font.bodySmall
                color: Util.alpha(Color.popups.text, 0.7)
                wrapMode: Text.Wrap
            }
        }
    }
    Repeater {
        model: root.mappings
        MapSection {
            id: mappingCard
            required property var modelData
            readonly property bool confirming: root.removeId === modelData.id && root.removePath === modelData.path
            property bool expanded: false
            Layout.fillWidth: true
            RowLayout {
                Layout.fillWidth: true
                MapGlyph {
                    icon: mappingCard.modelData.category === "state" ? "history" : mappingCard.modelData.category
                    color: Color.accent
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(2)
                    MapText {
                        Layout.fillWidth: true
                        text: root.workspace.appName(mappingCard.modelData.id)
                        font.pixelSize: Style.font.bodySmall
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }
                    MapText {
                        Layout.fillWidth: true
                        text: root.workspace.strings.t("compact." + mappingCard.modelData.category)
                        font.pixelSize: Style.font.caption
                        color: Util.alpha(Color.popups.text, 0.65)
                        wrapMode: Text.Wrap
                    }
                }
                MapIconButton {
                    icon: "info"
                    label: root.workspace.strings.t("journey.mappingDetails")
                    selected: mappingCard.expanded || mappingCard.confirming
                    enabled: !mappingCard.confirming
                    onClicked: mappingCard.expanded = !mappingCard.expanded
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
            }
            MapText {
                Layout.fillWidth: true
                text: mappingCard.modelData.path
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WrapAnywhere
                maximumLineCount: mappingCard.expanded || mappingCard.confirming ? 1000 : 2
                elide: Text.ElideMiddle
            }
            MapText {
                Layout.fillWidth: true
                visible: mappingCard.expanded || mappingCard.confirming
                text: mappingCard.modelData.id
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.6)
                wrapMode: Text.WrapAnywhere
            }
            MapText {
                Layout.fillWidth: true
                visible: mappingCard.expanded
                text: root.workspace.strings.t("journey.mappingEvidence")
                font.pixelSize: Style.font.caption
                color: Util.alpha(Color.popups.text, 0.65)
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                visible: mappingCard.expanded && !mappingCard.confirming
                Ui.Button {
                    text: root.workspace.strings.t("workspace.edit")
                    focusable: true
                    enabled: !root.workspace.busy && !root.formOpen
                    fontSize: Style.font.caption
                    onClicked: root.openForm(mappingCard.modelData)
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
                Ui.Button {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("preferences.removeAssociation")
                    focusable: true
                    enabled: root.workspace.ready && !root.workspace.busy && !root.formOpen
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(4)
                    onClicked: {
                        root.removeId = mappingCard.modelData.id;
                        root.removePath = mappingCard.modelData.path;
                        root.operationError = "";
                        Qt.callLater(function() { root.workspace.reveal(mappingCard); });
                    }
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
                MapIconButton {
                    icon: "copy"
                    label: root.workspace.strings.t("copyPath")
                    onClicked: root.workspace.service.copyPath(mappingCard.modelData.path)
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: mappingCard.confirming
                MapText {
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("preferences.removeConfirm")
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.Wrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    Ui.Button {
                        Layout.fillWidth: true
                        text: root.workspace.strings.t("preferences.removeAssociation")
                        foreground: Color.urgent
                        fontSize: Style.font.caption
                        focusable: true
                        enabled: root.workspace.ready && !root.workspace.busy
                        onClicked: root.remove()
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                    Ui.Button {
                        text: root.workspace.strings.t("cancel")
                        focusable: true
                        enabled: !root.pending
                        onClicked: { root.removeId = ""; root.removePath = ""; }
                        onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                    }
                }
            }
        }
    }
    MapSection {
        id: form
        Layout.fillWidth: true
        visible: root.formOpen
        title: root.workspace.strings.t(root.editingMapping ? "preferences.editMapping" : "workspace.addMapping")
        MapText {
            Layout.fillWidth: true
            visible: root.editingMapping
            text: root.workspace.strings.t("preferences.mappingIdentity")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            MapText {
                Layout.fillWidth: true
                text: root.appId ? root.workspace.appName(root.appId) : root.workspace.strings.t("workspace.chooseApp")
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Ui.Button {
                visible: !root.editingMapping && !root.pickerOpen && root.appId !== ""
                text: root.workspace.strings.t("preferences.changeApp")
                focusable: true
                enabled: !root.pending
                onClicked: { root.pickerOpen = true; appFilter.forceActiveFocus(); }
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
        MapText {
            Layout.fillWidth: true
            visible: root.appId !== ""
            text: root.appId
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.WrapAnywhere
        }
        Ui.TextField {
            id: appFilter
            Layout.fillWidth: true
            visible: root.pickerOpen && !root.editingMapping
            enabled: !root.pending
            placeholderText: root.workspace.strings.t("search")
            onTextEdited: root.query = text
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(Math.min(3, root.apps.length) * 34)
            visible: root.pickerOpen && !root.editingMapping
            enabled: !root.pending
            clip: true
            model: root.apps
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
            delegate: Ui.Button {
                required property var modelData
                required property int index
                width: appList.width - Style.space(8)
                height: Style.space(34)
                text: root.workspace.strings.t("workspace.appIdentity").arg(modelData.name).arg(modelData.id)
                selected: root.appId === modelData.id
                leftAlign: true
                focusable: true
                fontSize: Style.font.caption
                onClicked: { root.appId = modelData.id; root.pickerOpen = false; pathInput.forceActiveFocus(); }
                onActiveFocusChanged: if (activeFocus) {
                    appList.positionViewAtIndex(index, ListView.Contain);
                    root.workspace.reveal(appList);
                }
            }
        }
        MapText {
            Layout.fillWidth: true
            visible: root.pickerOpen && !root.apps.length
            text: root.workspace.strings.t("compact.noMatches")
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
        }
        Ui.TextField {
            id: pathInput
            Layout.fillWidth: true
            placeholderText: root.workspace.strings.t("workspace.pathPlaceholder")
            enabled: root.workspace.ready && !root.pending
            readOnly: root.editingMapping
            maximumLength: 4096
            onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
        }
        MapText {
            Layout.fillWidth: true
            visible: pathInput.text !== ""
            text: pathInput.text
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.7)
            wrapMode: Text.WrapAnywhere
        }
        RowLayout {
            id: categoryRow
            Layout.fillWidth: true
            spacing: Style.space(2)
            Repeater {
                model: ["config", "cache", "data", "state"]
                Ui.Button {
                    required property string modelData
                    Layout.fillWidth: true
                    text: root.workspace.strings.t("compact." + modelData)
                    selected: root.category === modelData
                    enabled: !root.pending
                    focusable: true
                    fontSize: Style.font.caption
                    horizontalPadding: Style.space(4)
                    onClicked: root.category = modelData
                    onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
                }
            }
        }
        MapText {
            Layout.fillWidth: true
            visible: root.appId !== "" && !root.knownApp
            text: root.workspace.strings.t("preferences.appUnavailable")
            font.pixelSize: Style.font.caption
            color: Color.urgent
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.Button {
                Layout.fillWidth: true
                text: root.workspace.strings.t(root.editingMapping ? "workspace.saveMapping" : "workspace.addMapping")
                enabled: root.workspace.ready && !root.workspace.busy && root.knownApp && pathInput.text.charAt(0) === "/"
                focusable: true
                onClicked: root.save()
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
            Ui.Button {
                text: root.workspace.strings.t("cancel")
                enabled: !root.pending
                focusable: true
                onClicked: { root.formOpen = false; addButton.forceActiveFocus(); }
                onActiveFocusChanged: if (activeFocus) root.workspace.reveal(this)
            }
        }
        MapText {
            Layout.fillWidth: true
            text: root.workspace.strings.t("preferences.mappingSafety")
            font.pixelSize: Style.font.caption
            color: Util.alpha(Color.popups.text, 0.65)
            wrapMode: Text.Wrap
        }
    }
}
