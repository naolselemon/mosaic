.pragma library
.import "Protocol.js" as Scan

var maxMessage = 8 * 1024 * 1024;

function array(value, maximum, valid) {
    return Array.isArray(value) && value.length <= maximum && value.every(valid);
}
function id(value) { return Scan.text(value, 256) && value.length > 8 && value.endsWith(".desktop"); }
function nullableSize(value) { return value === null || Scan.size(value); }
function signedSize(value) { return typeof value === "number" && Number.isSafeInteger(value); }
function mode(value) { return value === "overview" || value === "deep"; }
function diagnostic(value) { return Scan.text(value, 1024); }
function amounts(value) {
    return Scan.object(value) && Scan.categories.every(function (key) { return Scan.size(value[key]); });
}
function mapping(value) {
    return Scan.object(value) && id(value.id) && Scan.absolutePath(value.path)
        && Scan.categories.indexOf(value.category) >= 0;
}
function settings(value) {
    return Scan.object(value) && typeof value.historyEnabled === "boolean" && typeof value.alertsEnabled === "boolean"
        && (!value.alertsEnabled || value.historyEnabled) && Scan.size(value.thresholdBytes)
        && value.thresholdBytes >= 1048576 && value.thresholdBytes <= 1099511627776;
}
function summary(value) {
    return Scan.object(value) && id(value.id) && Scan.text(value.name, 256) && nullableSize(value.bytes)
        && typeof value.partial === "boolean" && amounts(value.categories) && Scan.text(value.signature, 256);
}
function snapshot(value) {
    return Scan.object(value) && Scan.text(value.key, 256) && value.key !== "" && Scan.timestamp(value.at)
        && mode(value.mode) && (value.mode === "overview" ? value.targetId === "" : id(value.targetId))
        && Scan.size(value.mappedBytes) && typeof value.partial === "boolean"
        && array(value.apps, 512, summary)
        && (value.mode !== "deep" || value.apps.length === 1 && value.apps[0].id === value.targetId);
}
function growth(value) {
    return Scan.object(value) && id(value.id) && Scan.text(value.name, 256) && nullableSize(value.bytes)
        && (value.delta === null || signedSize(value.delta)) && Scan.timestamp(value.previousAt) && Scan.timestamp(value.at)
        && typeof value.comparable === "boolean" && diagnostic(value.reason) && mode(value.mode)
        && (value.comparable ? value.delta !== null && value.bytes !== null && value.previousAt > 0 && value.previousAt < value.at : value.delta === null);
}
function cache(value) {
    return Scan.object(value) && id(value.id) && Scan.text(value.name, 256) && Scan.size(value.bytes)
        && typeof value.partial === "boolean";
}
function leftover(value) {
    return Scan.object(value) && mapping(value) && Scan.text(value.name, 256) && nullableSize(value.bytes)
        && ["complete", "partial", "denied", "missing", "symlink", "error"].indexOf(value.status) >= 0
        && (value.status !== "complete" || value.bytes !== null) && diagnostic(value.reason) && diagnostic(value.evidence);
}
function alert(value) {
    return Scan.object(value) && Scan.text(value.key, 256) && value.key !== "" && id(value.id)
        && Scan.text(value.name, 256) && Scan.size(value.delta) && Scan.size(value.thresholdBytes)
        && value.delta >= value.thresholdBytes && value.thresholdBytes >= 1048576 && Scan.timestamp(value.at);
}
function installationGroup(value) {
    return Scan.object(value) && Scan.text(value.key, 512) && value.key !== "" && Scan.text(value.name, 256)
        && ["pacman", "flatpak"].indexOf(value.kind) >= 0 && nullableSize(value.bytes)
        && ["known", "unknown"].indexOf(value.status) >= 0 && diagnostic(value.reason)
        && (value.status === "known" ? value.bytes !== null : value.bytes === null) && array(value.appIds, 512, id);
}
function installationApp(value) {
    return Scan.object(value) && id(value.id) && Scan.text(value.groupKey, 512)
        && ["known", "shared", "unknown"].indexOf(value.status) >= 0 && diagnostic(value.reason);
}
function installations(value) {
    if (!Scan.object(value) || !Scan.timestamp(value.scannedAt) || !array(value.groups, 512, installationGroup)
        || !array(value.apps, 512, installationApp) || !Scan.size(value.totalBytes)
        || !Scan.size(value.knownApps) || !Scan.size(value.unresolvedApps) || !array(value.issues, 64, diagnostic)) return false;
    var groups = Object.create(null);
    var total = 0;
    for (var i = 0; i < value.groups.length; ++i) {
        var group = value.groups[i];
        if (groups[group.key]) return false;
        groups[group.key] = group;
        if (group.bytes !== null) total += group.bytes;
    }
    var seen = Object.create(null);
    var known = 0;
    for (var j = 0; j < value.apps.length; ++j) {
        var app = value.apps[j];
        if (seen[app.id]) return false;
        seen[app.id] = true;
        if (app.status !== "unknown") {
            var owner = groups[app.groupKey];
            if (!owner || owner.status !== "known" || owner.appIds.indexOf(app.id) < 0) return false;
            ++known;
        }
    }
    return Scan.size(total) && total === value.totalBytes && known === value.knownApps
        && value.apps.length - known === value.unresolvedApps;
}
function view(value) {
    return Scan.object(value) && value.version === 1 && Scan.timestamp(value.refreshedAt) && settings(value.settings)
        && array(value.mappings, 128, mapping) && array(value.history, 60, snapshot)
        && array(value.growth, 1024, growth) && Scan.object(value.insights)
        && array(value.insights.cache, 512, cache) && array(value.insights.growing, 512, function (entry) {
            return growth(entry) && entry.comparable && entry.delta > 0;
        }) && array(value.leftovers, 128, leftover) && installations(value.installations)
        && array(value.alerts, 50, alert) && array(value.notifications, 50, alert) && array(value.warnings, 64, diagnostic);
}
function decode(line) {
    if (typeof line !== "string" || line.length > maxMessage) throw new Error("dashboard response size");
    var response = JSON.parse(line);
    if (!Scan.object(response) || typeof response.ok !== "boolean") throw new Error("dashboard response shape");
    if (response.ok ? !view(response.data) : !diagnostic(response.error) || response.error === "")
        throw new Error("dashboard response fields");
    return response;
}
