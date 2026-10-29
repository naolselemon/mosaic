// The scanner emits bounded NDJSON records; do not pass malformed records to QML.
var categories = ["config", "cache", "data", "state"];
var pathStates = ["pending", "complete", "partial", "denied", "missing", "symlink", "error"];
var appStates = ["pending", "complete", "partial", "unmapped"];
var confidenceLevels = ["known", "possible", "shared"];
var reasons = ["rule", "app-id", "name-match", "shared", "flatpak", "user"];
var issueCodes = ["permission", "changed", "symlink", "special", "limit", "error", "hardlink", "cancelled"];

function object(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function text(value, limit) {
    if (typeof value !== "string" || value.indexOf("\u0000") >= 0 || value.length > limit * 2) return false;
    if (value.length <= limit) return true;
    var count = 0;
    for (var i = 0; i < value.length; ++i) {
        var code = value.charCodeAt(i);
        if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length
            && value.charCodeAt(i + 1) >= 0xDC00 && value.charCodeAt(i + 1) <= 0xDFFF) ++i;
        if (++count > limit) return false;
    }
    return true;
}

function size(value) {
    return typeof value === "number" && isFinite(value) && value >= 0 && value <= Number.MAX_SAFE_INTEGER && Math.floor(value) === value;
}

function list(value, limit) {
    return Array.isArray(value) && value.length <= limit && value.every(function (entry) { return text(entry, 256); });
}

function issues(value) {
    return list(value, issueCodes.length) && value.every(function (code) { return issueCodes.indexOf(code) >= 0; });
}

function timestamp(value) {
    return size(value) && value <= Date.now() + 60000;
}

function absolutePath(value) {
    return text(value, 4096) && value.length > 1 && value.charAt(0) === "/"
        && value.slice(1).split("/").every(function (part) { return part !== "" && part !== "." && part !== ".."; });
}

function childName(value) {
    return text(value, 255) && value !== "" && value !== "." && value !== ".." && value.indexOf("/") < 0;
}

function validBreakdown(path) {
    var data = path.breakdown;
    if (!object(data) || !Array.isArray(data.children) || data.children.length > 12
        || !size(data.directBytes) || !size(data.directFiles) || !size(data.otherBytes) || !size(data.otherCount)) return false;
    var total = data.directBytes + data.otherBytes;
    var names = Object.create(null);
    for (var i = 0; i < data.children.length; ++i) {
        var child = data.children[i];
        if (!object(child) || !childName(child.name) || names[child.name]
            || (child.bytes !== null && !size(child.bytes)) || pathStates.indexOf(child.status) < 0
            || child.status === "pending" || !issues(child.issues)
            || (child.status === "complete" && child.bytes === null)
            || (path.status === "complete" && child.status !== "complete")) return false;
        names[child.name] = true;
        if (child.bytes !== null) total += child.bytes;
    }
    return size(total) && total === (path.bytes === null ? 0 : path.bytes);
}

function validSkipped(path) {
    if (!object(path.skippedCounts) || !Array.isArray(path.skippedSamples) || path.skippedSamples.length > 8) return false;
    var keys = Object.keys(path.skippedCounts);
    if (!keys.every(function (key) { return issueCodes.indexOf(key) >= 0 && size(path.skippedCounts[key]); })) return false;
    return path.skippedSamples.every(function (sample) {
        return object(sample) && text(sample.relative, 512) && sample.relative !== ""
            && issueCodes.indexOf(sample.reason) >= 0 && typeof sample.truncated === "boolean"
            && path.skippedCounts[sample.reason] > 0;
    });
}

function validPath(path) {
    return object(path) && absolutePath(path.path) && text(path.label, 4096)
        && categories.indexOf(path.category) >= 0 && confidenceLevels.indexOf(path.confidence) >= 0
        && reasons.indexOf(path.reason) >= 0 && pathStates.indexOf(path.status) >= 0
        && (path.bytes === null || size(path.bytes)) && issues(path.issues)
        && timestamp(path.measuredAt) && size(path.entriesSeen) && text(path.evidence, 1024) && text(path.source, 2048)
        && (path.status !== "complete" || path.bytes !== null)
        && (path.status !== "pending" || (path.bytes === null && path.measuredAt === 0))
        && validBreakdown(path) && validSkipped(path);
}

function validApp(app) {
    if (!object(app) || !text(app.id, 256) || !app.id || !text(app.name, 256) || !text(app.icon, 4096)
        || !Array.isArray(app.paths) || app.paths.length > 24 || !app.paths.every(validPath)
        || !size(app.mappedBytes) || !object(app.categories) || appStates.indexOf(app.status) < 0 || !timestamp(app.scannedAt))
        return false;
    var sums = {config: 0, cache: 0, data: 0, state: 0};
    var seen = Object.create(null);
    for (var i = 0; i < app.paths.length; ++i) {
        var path = app.paths[i];
        if (seen[path.path]) return false;
        seen[path.path] = true;
        if (path.confidence === "known" && path.bytes !== null)
            sums[path.category] += path.bytes;
    }
    var total = 0;
    for (var c = 0; c < categories.length; ++c) {
        var key = categories[c];
        if (!size(app.categories[key]) || app.categories[key] !== sums[key]) return false;
        total += sums[key];
    }
    return size(total) && total === app.mappedBytes;
}

function decode(line) {
    if (typeof line !== "string" || line.length > 262144) throw new Error("record size");
    var record = JSON.parse(line);
    if (!object(record)) throw new Error("record shape");
    if (record.type === "begin" && record.version === 3 && size(record.totalApps) && record.totalApps <= 512
        && typeof record.inventoryComplete === "boolean"
        && size(record.totalPaths) && record.totalPaths <= record.totalApps * 24
        && ((record.mode === "overview" && record.targetId === "")
            || (record.mode === "deep" && record.totalApps === 1 && text(record.targetId, 256) && record.targetId)))
        return record;
    if (record.type === "app" && validApp(record.app) && record.app.scannedAt === 0
        && record.app.paths.every(function (path) { return path.status === "pending"; })) return record;
    if (record.type === "path" && text(record.id, 256) && record.id && validPath(record.path)
        && record.path.status !== "pending") return record;
    if (record.type === "progress" && text(record.id, 256) && record.id && absolutePath(record.path)
        && size(record.entries) && size(record.bytes)) return record;
    if (record.type === "appDone" && text(record.id, 256) && record.id && timestamp(record.scannedAt)
        && ["complete", "partial", "unmapped"].indexOf(record.status) >= 0) return record;
    if (record.type === "done" && timestamp(record.scannedAt)
        && typeof record.limited === "boolean" && list(record.warnings, 32)) return record;
    if (record.type === "error" && text(record.message, 1024)) return record;
    throw new Error("record fields");
}

function withPaths(app, paths) {
    var totals = {config: 0, cache: 0, data: 0, state: 0};
    var total = 0;
    for (var i = 0; i < paths.length; ++i) {
        var path = paths[i];
        if (path.confidence === "known" && path.bytes !== null) {
            totals[path.category] += path.bytes;
            total += path.bytes;
        }
    }
    if (!size(total)) throw new Error("total overflow");
    return Object.assign({}, app, {paths: paths, categories: totals, mappedBytes: total});
}

function replacePath(app, result) {
    var index = -1;
    for (var i = 0; i < app.paths.length; ++i)
        if (app.paths[i].path === result.path) index = i;
    if (index < 0 || app.paths[index].status !== "pending") throw new Error("unknown or repeated location");
    var original = app.paths[index];
    if (original.category !== result.category || original.confidence !== result.confidence
        || original.reason !== result.reason || original.evidence !== result.evidence || original.source !== result.source)
        throw new Error("location ownership changed");
    var paths = app.paths.slice();
    paths[index] = result;
    return withPaths(app, paths);
}

function finishApp(app, status, scannedAt) {
    if (app.paths.some(function (path) { return path.status === "pending"; })
        || (status === "unmapped" && app.paths.length)
        || (status === "complete" && (!app.paths.length || app.paths.some(function (path) { return path.status !== "complete"; }))))
        throw new Error("unfinished application");
    return Object.assign({}, app, {status: status, scannedAt: scannedAt});
}

function unfinished(app, reason, scannedAt) {
    if (app.scannedAt > 0) return app;
    if (!app.paths.length && app.status === "unmapped") return Object.assign({}, app, {scannedAt: scannedAt});
    var paths = app.paths.map(function (path) {
        if (path.status !== "pending") return path;
        var counts = Object.assign({}, path.skippedCounts);
        counts[reason] = (counts[reason] || 0) + 1;
        return Object.assign({}, path, {status: "partial", issues: [reason], skippedCounts: counts,
            skippedSamples: [{relative: ".", reason: reason, truncated: false}]});
    });
    return Object.assign({}, withPaths(app, paths), {status: "partial", scannedAt: scannedAt});
}
