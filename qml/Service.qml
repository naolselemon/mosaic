import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "lib/Protocol.js" as Protocol
import "lib/WorkspaceProtocol.js" as WorkspaceProtocol

Item {
    id: root
    property var shell: null
    property var manifest: null
    property var apps: []
    property bool busy: false
    property bool ready: false
    property bool attempted: false
    property double scannedAt: 0
    property string error: ""
    property bool limited: false
    property var warnings: []
    property int totalApps: 0
    property string actionError: ""
    property bool actionBusy: false
    property string copiedPath: ""
    property string scanMode: "overview"
    property string scanTargetId: ""
    property int scanTotalPaths: 0
    property int scanCompletedPaths: 0
    property string scanPath: ""
    property double scanEntries: 0
    property double scanBytes: 0
    property var scanWarnings: []
    property bool scanLimited: false
    property var deepResult: null
    property bool inventoryComplete: false
    property bool scanInventoryComplete: false
    property double scanFinishedAt: 0
    property var workspace: null
    property bool workspaceBusy: false
    property bool workspaceReady: false
    property string workspaceError: ""
    property string workspaceOperation: ""
    property string workspaceInput: ""
    property var workspaceResponse: null
    property int workspaceGeneration: 0
    property bool rescanAfterWorkspace: false
    property bool pendingInitialScan: false
    property int pendingNotices: 0

    readonly property var summary: {
        var totals = {config: 0, cache: 0, data: 0, state: 0};
        var bytes = 0;
        var completed = 0;
        var incomplete = root.limited;
        for (var i = 0; i < root.apps.length; ++i) {
            var app = root.apps[i];
            bytes += app.mappedBytes;
            for (var c = 0; c < Protocol.categories.length; ++c) {
                var key = Protocol.categories[c];
                totals[key] += app.categories[key];
            }
            if (app.status !== "pending") ++completed;
            if (app.status === "partial" || app.status === "pending") incomplete = true;
        }
        return {categories: totals, bytes: bytes, completed: completed, partial: incomplete};
    }
    readonly property double mappedBytes: summary.bytes
    readonly property var categories: summary.categories
    readonly property bool partial: summary.partial
    readonly property int completedApps: summary.completed
    readonly property real progress: scanTotalPaths > 0 ? Math.min(1, scanCompletedPaths / scanTotalPaths) : (busy ? 0 : 1)
    readonly property string scannerPath: decodeURIComponent(Qt.resolvedUrl("../backend/scanner.py").toString().slice(7))
    readonly property string actionPath: decodeURIComponent(Qt.resolvedUrl("../backend/actions.py").toString().slice(7))
    readonly property string workspacePath: decodeURIComponent(Qt.resolvedUrl("../backend/workspace.py").toString().slice(7))
    readonly property string iconPath: decodeURIComponent(Qt.resolvedUrl("../assets/mosaic.png").toString().slice(7))

    property var records: ({})
    property var order: []
    property bool began: false
    property bool sawDone: false
    property int eventCount: 0

    property int expectedApps: 0
    property int inventoryPaths: 0
    property var finishedIds: ({})
    property int generation: 0
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("../i18n") }
    Component.onCompleted: Qt.callLater(function () { root.requestWorkspace({op: "load"}); })

    function ensureScan() {
        if (attempted) return;
        if (workspaceBusy) pendingInitialScan = true;
        else rescan();
    }

    function rescan() {
        return startScan("overview", "");
    }

    function deepScan(id) {
        if (typeof id !== "string" || !apps.some(function (app) { return app.id === id; })) return false;
        return startScan("deep", id);
    }

    function startScan(mode, id) {
        if (busy || scanner.running || workspaceBusy || workspaceWorker.running) return false;
        ++generation;
        scanMode = mode;
        scanTargetId = id;
        deepResult = null;
        scanInventoryComplete = false;
        scanFinishedAt = 0;
        if (mode === "overview") {
            attempted = true;
            inventoryComplete = false;
            ready = false;
            apps = [];
            totalApps = 0;
            scannedAt = 0;
            limited = false;
            warnings = [];
        }
        records = Object.create(null);
        order = [];
        finishedIds = Object.create(null);
        began = false;
        sawDone = false;
        eventCount = 0;
        expectedApps = 0;
        inventoryPaths = 0;
        scanTotalPaths = 0;
        scanCompletedPaths = 0;
        scanPath = "";
        scanEntries = 0;
        scanBytes = 0;
        scanWarnings = [];
        scanLimited = false;
        error = "";
        actionError = "";
        scanner.command = ["python3", "-B", scannerPath, "scan"].concat(mode === "deep" ? ["--app", id] : []);
        busy = true;
        deadline.restart();
        scanner.running = true;
        return true;
    }

    function publish() {
        if (scanMode === "deep") deepResult = records[scanTargetId] || null;
        else apps = order.map(function (id) { return root.records[id]; });
    }

    function fail(key) {
        if (!busy) return;
        error = strings.t(key);
        scanLimited = true;
        var stamp = Date.now();
        var reason = key === "service.cancelled" ? "cancelled" : key === "service.timeout" ? "limit" : "error";
        for (var i = 0; i < order.length; ++i)
            records[order[i]] = Protocol.unfinished(records[order[i]], reason, stamp);
        if (scanMode === "overview") {
            limited = true;
            scannedAt = stamp;
        }
        publishTimer.stop();
        publish();
        busy = false;
        deadline.stop();
        if (scanner.running) scanner.signal(9);
    }

    function cancelScan() {
        fail("service.cancelled");
    }

    function receive(line) {
        if (!busy || !line.trim()) return;
        try {
            if (++eventCount > 20000 || sawDone) throw new Error("event order");
            var event = Protocol.decode(line);
            if (event.type === "error") {
                console.warn("Mosaic scanner:", event.message);
                fail("service.failed");
                return;
            }
            if (event.type === "begin") {
                if (began || event.mode !== scanMode || event.targetId !== scanTargetId) throw new Error("scan identity");
                began = true;
                expectedApps = event.totalApps;
                scanTotalPaths = event.totalPaths;
                scanInventoryComplete = event.inventoryComplete;
                if (scanMode === "overview") {
                    ready = true;
                    totalApps = event.totalApps;
                    inventoryComplete = event.inventoryComplete;
                }
                return;
            }
            if (!began) throw new Error("missing begin");
            if (event.type === "app") {
                var app = event.app;
                if (Object.prototype.hasOwnProperty.call(records, app.id) || order.length >= expectedApps
                    || (scanMode === "deep" && app.id !== scanTargetId)) throw new Error("inventory identity");
                inventoryPaths += app.paths.length;
                if (inventoryPaths > scanTotalPaths) throw new Error("path inventory overflow");
                order.push(app.id);
                records[app.id] = app;
            } else if (event.type === "path" || event.type === "progress" || event.type === "appDone") {
                if (!records[event.id] || finishedIds[event.id]) throw new Error("unknown or finished app");
                if (event.type === "path") {
                    records[event.id] = Protocol.replacePath(records[event.id], event.path);
                    ++scanCompletedPaths;
                    scanPath = event.path.path;
                    scanEntries = event.path.entriesSeen;
                    scanBytes = event.path.bytes || 0;
                } else if (event.type === "progress") {
                    if (!records[event.id].paths.some(function (path) {
                        return path.path === event.path && path.status === "pending";
                    })) throw new Error("unknown progress location");
                    scanPath = event.path;
                    scanEntries = event.entries;
                    scanBytes = event.bytes;
                    return;
                } else {
                    records[event.id] = Protocol.finishApp(records[event.id], event.status, event.scannedAt);
                    finishedIds[event.id] = true;
                }
            } else if (event.type === "done") {
                if (order.length !== expectedApps || inventoryPaths !== scanTotalPaths
                    || scanCompletedPaths !== scanTotalPaths || Object.keys(finishedIds).length !== expectedApps)
                    throw new Error("incomplete snapshot");
                sawDone = true;
                scanLimited = event.limited;
                scanWarnings = event.warnings;
                scanFinishedAt = event.scannedAt;
                if (scanMode === "overview") {
                    limited = event.limited;
                    warnings = event.warnings;
                    scannedAt = event.scannedAt;
                }
                publishTimer.stop();
                publish();
                return;
            }
            if (!publishTimer.running) publishTimer.start();
        } catch (e) {
            console.warn("Mosaic protocol:", String(e));
            fail("service.protocol");
        }
    }

    function finish(exitCode) {
        if (!busy) return;
        if (exitCode !== 0 || !sawDone) {
            fail("service.failed");
            return;
        }
        busy = false;
        deadline.stop();
        var result = scanMode === "deep" ? [deepResult] : apps;
        requestWorkspace({op: "record", snapshot: {
            mode: scanMode, targetId: scanTargetId, scannedAt: scanFinishedAt,
            inventoryComplete: scanInventoryComplete, limited: scanLimited,
            partial: scanMode === "deep" ? scanLimited || !deepResult || deepResult.status !== "complete" : partial,
            apps: result
        }});
    }

    function detailsFor(id) {
        if (deepResult && deepResult.id === id) return deepResult;
        for (var i = 0; i < apps.length; ++i)
            if (apps[i].id === id) return apps[i];
        return null;
    }

    function findPath(value) {
        if (!Protocol.absolutePath(value)) return null;
        var snapshots = deepResult ? [deepResult].concat(apps) : apps;
        for (var i = 0; i < snapshots.length; ++i) {
            var paths = snapshots[i].paths;
            for (var j = 0; j < paths.length; ++j) {
                var path = paths[j];
                if (path.path === value) return path;
                for (var k = 0; k < path.breakdown.children.length; ++k) {
                    var child = path.breakdown.children[k];
                    if (path.path + "/" + child.name === value) return child;
                }
            }
        }
        if (workspace) {
            for (var n = 0; n < workspace.leftovers.length; ++n)
                if (workspace.leftovers[n].path === value) return workspace.leftovers[n];
            for (var m = 0; m < workspace.mappings.length; ++m)
                if (workspace.mappings[m].path === value) return workspace.mappings[m];
        }
        return null;
    }

    function copyPath(value) {
        actionError = "";
        if (!findPath(value)) {
            actionError = strings.t("service.actionInvalid");
            return false;
        }
        Quickshell.clipboardText = value;
        copiedPath = value;
        copyFeedback.restart();
        return true;
    }

    function openPath(value) {
        if (actionBusy) return false;
        actionError = "";
        var path = findPath(value);
        if (!path || ["missing", "symlink", "denied", "error"].indexOf(path.status) >= 0) {
            actionError = strings.t("service.actionInvalid");
            return false;
        }
        opener.command = ["python3", "-B", actionPath, value];
        actionBusy = true;
        actionDeadline.restart();
        opener.running = true;
        return true;
    }

    function statusJson() {
        return JSON.stringify({busy: busy, ready: ready, completedApps: completedApps, totalApps: totalApps,
            mappedBytes: mappedBytes, categories: categories, partial: partial, scannedAt: scannedAt,
            limited: limited, warnings: warnings, error: error, actionError: actionError,
            scanMode: scanMode, scanTargetId: scanTargetId, scanTotalPaths: scanTotalPaths,
            scanCompletedPaths: scanCompletedPaths, scanPath: scanPath, scanEntries: scanEntries, scanBytes: scanBytes,
            scanLimited: scanLimited, scanWarnings: scanWarnings,
            deepId: deepResult ? deepResult.id : "", deepScannedAt: deepResult ? deepResult.scannedAt : 0,
            deepStatus: deepResult ? deepResult.status : ""});
    }

    function overviewSnapshot() {
        if (!ready || !scannedAt || busy) return null;
        return {mode: "overview", targetId: "", scannedAt: scannedAt,
            inventoryComplete: inventoryComplete, limited: limited, partial: partial, apps: apps};
    }

    function requestWorkspace(request, scanAfter) {
        if (busy || workspaceBusy || workspaceWorker.running) {
            workspaceError = strings.t("workspace.busy");
            return false;
        }
        if (!request.snapshot && request.op !== "load" && request.op !== "clear-history") {
            var current = overviewSnapshot();
            if (current) request.snapshot = current;
        }
        if (request.op === "record" && request.snapshot.mode === "deep") {
            var overview = overviewSnapshot();
            if (overview) request.overview = overview;
        }
        var input = JSON.stringify(request) + "\n";
        if (input.length > WorkspaceProtocol.maxMessage) {
            workspaceError = strings.t("workspace.protocol");
            return false;
        }
        ++workspaceGeneration;
        workspaceOperation = request.op;
        workspaceInput = input;
        workspaceResponse = null;
        workspaceError = "";
        rescanAfterWorkspace = !!scanAfter;
        workspaceBusy = true;
        workspaceWorker.command = ["python3", "-B", workspacePath];
        workspaceDeadline.restart();
        workspaceWorker.running = true;
        return true;
    }

    function ensureWorkspace() {
        if (busy || workspaceBusy) return;
        refreshWorkspace();
    }
    function refreshWorkspace() { return requestWorkspace({op: "view"}); }
    function setWorkspaceSettings(patch) { return requestWorkspace({op: "settings", patch: patch}); }
    function saveMapping(id, path, category) {
        return requestWorkspace({op: "mapping-save", mapping: {id: id, path: path, category: category}}, true);
    }
    function removeMapping(id, path) {
        return requestWorkspace({op: "mapping-remove", id: id, path: path}, true);
    }
    function clearWorkspaceHistory() { return requestWorkspace({op: "clear-history"}); }

    function receiveWorkspace(line) {
        if (!workspaceBusy || !line.trim()) return;
        try {
            if (workspaceResponse) throw new Error("multiple dashboard responses");
            workspaceResponse = WorkspaceProtocol.decode(line);
        } catch (e) {
            console.warn("Mosaic dashboard:", String(e));
            workspaceError = strings.t("workspace.protocol");
            workspaceBusy = false;
            workspaceInput = "";
            rescanAfterWorkspace = false;
            workspaceDeadline.stop();
            if (workspaceWorker.running) workspaceWorker.signal(9);
        }
    }

    function finishWorkspace(exitCode) {
        if (!workspaceBusy) return;
        workspaceDeadline.stop();
        workspaceBusy = false;
        workspaceInput = "";
        var shouldScan = rescanAfterWorkspace || pendingInitialScan;
        rescanAfterWorkspace = false;
        pendingInitialScan = false;
        if (exitCode !== 0 || !workspaceResponse || !workspaceResponse.ok) {
            workspaceError = workspaceResponse && !workspaceResponse.ok
                ? workspaceResponse.error : strings.t("workspace.failed");
            return;
        }
        workspace = workspaceResponse.data;
        workspaceReady = workspace.refreshedAt > 0;
        workspaceError = "";
        if (workspace.notifications.length) {
            pendingNotices += workspace.notifications.length;
            sendNotices();
        }
        if (shouldScan) Qt.callLater(function () { root.rescan(); });
        else if (workspaceOperation === "settings" || workspaceOperation === "clear-history")
            Qt.callLater(function () { root.refreshWorkspace(); });
    }

    function sendNotices() {
        if (!pendingNotices || notifier.running) return;
        var count = pendingNotices;
        pendingNotices = 0;
        // Only plugin-owned text and a validated count enter notification markup.
        notifier.command = ["notify-send", "--app-name=Mosaic", "--icon=" + root.iconPath,
            strings.t("workspace.notificationTitle"),
            strings.tn("workspace.notificationBody", count).arg(Commons.I18n.formatNumber(count))];
        notifier.running = true;
    }

    function workspaceStatusJson() {
        return JSON.stringify({busy: workspaceBusy, ready: workspaceReady, error: workspaceError, data: workspace});
    }

    Process {
        id: workspaceWorker
        stdinEnabled: true
        onStarted: {
            write(root.workspaceInput);
            root.workspaceInput = "";
        }
        stdout: SplitParser { onRead: data => root.receiveWorkspace(data) }
        stderr: SplitParser { onRead: data => console.warn("Mosaic dashboard:", data.slice(0, 1024)) }
        onExited: (exitCode, exitStatus) => root.finishWorkspace(exitCode)
        onRunningChanged: {
            if (!running && root.workspaceBusy) {
                var stoppedGeneration = root.workspaceGeneration;
                Qt.callLater(function () {
                    if (stoppedGeneration === root.workspaceGeneration && !workspaceWorker.running && root.workspaceBusy)
                        root.finishWorkspace(root.workspaceResponse && root.workspaceResponse.ok ? 0 : 1);
                });
            }
        }
    }
    Timer {
        id: workspaceDeadline
        interval: 60000
        onTriggered: {
            root.workspaceBusy = false;
            root.workspaceInput = "";
            root.rescanAfterWorkspace = false;
            root.pendingInitialScan = false;
            root.workspaceError = strings.t("workspace.timeout");
            if (workspaceWorker.running) workspaceWorker.signal(9);
        }
    }
    Process {
        id: notifier
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.workspaceError = strings.t("workspace.notificationFailed");
            Qt.callLater(function () { root.sendNotices(); });
        }
        stderr: SplitParser { onRead: data => console.warn("Mosaic notification:", data.slice(0, 512)) }
    }

    Process {
        id: scanner
        // The producer bounds each line before writing it; no whole-scan collector.
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: SplitParser { onRead: data => console.warn("Mosaic:", data.slice(0, 1024)) }
        onExited: (exitCode, exitStatus) => root.finish(exitCode)
        onRunningChanged: {
            if (!running && root.busy) {
                var stoppedGeneration = root.generation;
                Qt.callLater(function () {
                    if (stoppedGeneration === root.generation && !scanner.running && root.busy)
                        root.finish(root.sawDone ? 0 : 1);
                });
            }
        }
    }
    Timer { id: publishTimer; interval: 80; onTriggered: root.publish() }
    Timer { id: deadline; interval: root.scanMode === "deep" ? 110000 : 40000; onTriggered: root.fail("service.timeout") }
    Timer { id: copyFeedback; interval: 1800; onTriggered: root.copiedPath = "" }

    Process {
        id: opener
        stdout: SplitParser { onRead: data => {} }
        stderr: SplitParser { onRead: data => console.warn("Mosaic open:", data.slice(0, 512)) }
        onExited: (exitCode, exitStatus) => {
            actionDeadline.stop();
            if (root.actionBusy && exitCode !== 0) root.actionError = strings.t("service.actionFailed");
            root.actionBusy = false;
        }
        onRunningChanged: {
            if (!running && root.actionBusy) Qt.callLater(function () {
                if (!opener.running && root.actionBusy) {
                    actionDeadline.stop();
                    root.actionBusy = false;
                    root.actionError = strings.t("service.actionFailed");
                }
            });
        }
    }
    Timer {
        id: actionDeadline
        interval: 12000
        onTriggered: {
            root.actionBusy = false;
            root.actionError = strings.t("service.actionTimeout");
            if (opener.running) opener.signal(9);
        }
    }

    IpcHandler {
        target: "naolselemon.mosaic"
        function scan(): bool { return root.rescan(); }
        function deepScan(id: string): bool { return root.deepScan(id); }
        function detail(id: string): string { return JSON.stringify(root.detailsFor(id)); }
        function cancel(): void { root.cancelScan(); }
        function status(): string { return root.statusJson(); }
        function snapshot(): string { return JSON.stringify(root.apps); }
        function workspaceStatus(): string { return root.workspaceStatusJson(); }
        function workspaceRefresh(): bool { return root.refreshWorkspace(); }
        function workspaceSettings(value: string): bool {
            try {
                if (value.length > WorkspaceProtocol.maxMessage) throw new Error("settings size");
                return root.setWorkspaceSettings(JSON.parse(value));
            } catch (e) {
                root.workspaceError = strings.t("workspace.protocol");
                return false;
            }
        }
        function mappingSave(id: string, path: string, category: string): bool { return root.saveMapping(id, path, category); }
        function mappingRemove(id: string, path: string): bool { return root.removeMapping(id, path); }
        function historyClear(): bool { return root.clearWorkspaceHistory(); }
    }
}
