import QtQuick
import Quickshell.Io

Item {
    id: root
    property var service: null
    property string installedVersion: ""
    property bool automatic: false
    property string status: "idle"
    property string latest: ""
    property string commit: ""
    property double checkedAt: 0
    property double lastAttempt: 0
    property string error: ""
    property string message: ""
    property string reason: ""
    property bool supported: false
    property bool busy: false
    readonly property bool checking: busy && operation === "check"
    readonly property bool installing: status === "installing"
    readonly property bool canInstall: cacheLoaded && !busy && status === "ready" && supported
        && !!commit && !!service && service.workspace !== null && !service.updateQuiesced
        && !service.busy && !service.workspaceBusy && !service.actionBusy
    readonly property string backendPath: decodeURIComponent(Qt.resolvedUrl("../../backend/updates.py").toString().slice(7))
    property bool loadStarted: false
    property bool cacheLoaded: false
    property string operation: ""
    property var response: null
    property int generation: 0
    property bool pendingStatus: false

    function loadCache() {
        if (loadStarted || !installedVersion) return;
        loadStarted = true;
        refresh();
    }
    function refresh() { return start("load"); }
    function check() {
        if (!cacheLoaded || installing || status === "recovery") return false;
        return start("check");
    }
    function install(approvedCommit) {
        if (!canInstall || approvedCommit !== commit) return false;
        return start("install", approvedCommit);
    }
    function checkIfDue() {
        if (automatic && cacheLoaded && !installing && status !== "recovery"
                && (lastAttempt === 0 || Date.now() < lastAttempt || Date.now() - lastAttempt >= 86400000))
            check();
    }
    function start(command, approvedCommit) {
        if (!installedVersion || busy || worker.running) return false;
        ++generation;
        operation = command;
        response = null;
        pendingStatus = false;
        error = "";
        if (command === "check") lastAttempt = Date.now();
        var args = ["python3", "-B", backendPath, command];
        if (command === "install") {
            args.push("--commit", approvedCommit);
            status = "installing";
        }
        worker.command = args;
        busy = true;
        // Preparation includes a bounded Git fetch and the trusted validator.
        // Installation itself runs independently; this process only launches it.
        deadline.interval = command === "check" ? 360000 : 20000;
        deadline.restart();
        worker.running = true;
        return true;
    }
    function validTime(value) {
        return typeof value === "number" && isFinite(value) && value >= 0
            && value <= 8640000000000000 && Math.floor(value) === value;
    }
    function receive(line) {
        if (!busy) return;
        try {
            if (response !== null || line.length > 16384) throw new Error("response");
            var value = JSON.parse(line);
            if (!value || typeof value !== "object" || Array.isArray(value)
                    || typeof value.ok !== "boolean" || typeof value.supported !== "boolean"
                    || ["idle", "noRelease", "current", "ahead", "ready", "installing", "installed", "error", "recovery"].indexOf(value.status) === -1
                    || typeof value.latest !== "string" || value.latest.length > 128
                    || (value.latest !== "" && !/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/.test(value.latest))
                    || typeof value.commit !== "string" || !/^([0-9a-f]{40})?$/.test(value.commit)
                    || !validTime(value.checkedAt) || !validTime(value.lastAttempt)
                    || typeof value.error !== "string" || !/^[a-zA-Z_0-9]{0,64}$/.test(value.error)
                    || typeof value.message !== "string" || value.message.length > 4096
                    || typeof value.reason !== "string" || value.reason.length > 4096
                    || (value.status === "ready" && (!value.supported || !value.commit || !value.latest)))
                throw new Error("response");
            response = value;
        } catch (ignored) {
            fail("response");
        }
    }
    function fail(code) {
        if (!busy) return;
        var wasLoad = operation === "load";
        // A lost launcher response cannot prove that the independent worker did
        // not start. Read persisted status once; never repeat approval or install.
        pendingStatus = operation === "install";
        status = "error";
        error = code;
        message = "";
        busy = false;
        deadline.stop();
        if (worker.running) worker.signal(9);
        if (wasLoad) cacheLoaded = true;
    }
    function finish(exitCode) {
        if (!busy) return;
        if (!response || (response.ok && exitCode !== 0) || (!response.ok && exitCode !== 0 && exitCode !== 1)) {
            fail("response");
            return;
        }
        var wasLoad = operation === "load";
        latest = response.latest;
        commit = response.commit;
        checkedAt = response.checkedAt;
        lastAttempt = wasLoad ? response.lastAttempt : Math.max(lastAttempt, response.lastAttempt);
        status = response.status;
        error = response.error;
        message = response.message;
        reason = response.reason;
        supported = response.supported;
        busy = false;
        deadline.stop();
        if (wasLoad && !cacheLoaded) {
            cacheLoaded = true;
            Qt.callLater(root.checkIfDue);
        }
    }
    function afterExit(exitCode) {
        finish(exitCode);
        if (pendingStatus) {
            pendingStatus = false;
            Qt.callLater(root.refresh);
        }
    }

    onInstalledVersionChanged: Qt.callLater(root.loadCache)
    onAutomaticChanged: if (automatic) Qt.callLater(root.checkIfDue)
    Component.onCompleted: Qt.callLater(root.loadCache)

    Process {
        id: worker
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: SplitParser { onRead: data => {} }
        onExited: (exitCode, exitStatus) => root.afterExit(exitCode)
        onRunningChanged: {
            if (!running) {
                var stoppedGeneration = root.generation;
                Qt.callLater(function () {
                    if (stoppedGeneration === root.generation && !worker.running)
                        root.afterExit(-1);
                });
            }
        }
    }
    Timer {
        id: deadline
        onTriggered: root.fail("timeout")
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.automatic && root.cacheLoaded
        onTriggered: root.checkIfDue()
    }
    Timer {
        interval: 2500
        repeat: true
        running: root.installing && root.cacheLoaded
        onTriggered: root.refresh()
    }
}
