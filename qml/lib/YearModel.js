.pragma library

function years(history, now) {
    var found = Object.create(null);
    found[new Date(now === undefined ? Date.now() : now).getFullYear()] = true;
    (history || []).forEach(function(snapshot) {
        found[new Date(snapshot.at).getFullYear()] = true;
    });
    return Object.keys(found).map(Number).sort(function(a, b) { return a - b; });
}

function known(value) {
    return typeof value === "number" && isFinite(value) && value >= 0;
}

// Journal totals use zero for unavailable apps. Do not turn an entirely
// unmeasured, partial overview into a measured zero in the year chart.
function footprint(snapshot) {
    if (!known(snapshot.mappedBytes)) return null;
    if (!snapshot.apps.some(function(app) { return known(app.bytes); })
            && (snapshot.apps.length > 0 || snapshot.partial)) return null;
    return snapshot.mappedBytes;
}

// Keep this ordering in step with journal.py comparisons(). The signatures
// encode root ownership, whole-scan accounting and the preceding-safe bit;
// a complete app alone is not proof that its byte accounting is comparable.
function comparisons(current, previous) {
    if (previous && (current.mode !== previous.mode || current.targetId !== previous.targetId))
        previous = null;
    var before = Object.create(null);
    if (previous) previous.apps.forEach(function(app) { before[app.id] = app; });
    return current.apps.map(function(app) {
        var old = before[app.id];
        var reason = "no-baseline", delta = null;
        if (old) {
            var own = String(app.signature).split(":"), prior = String(old.signature).split(":");
            if (current.at <= previous.at) reason = "non-increasing-time";
            else if (!known(app.bytes) || !known(old.bytes)) reason = "unmapped";
            else if (app.partial || old.partial) reason = "incomplete";
            else if (own[0] !== prior[0]) reason = "ownership-changed";
            else if (own[1] !== prior[1]) reason = "accounting-changed";
            else if (!/^[0-9a-f]{64}:[0-9a-f]{64}:1$/.test(app.signature)
                    || !/^[0-9a-f]{64}:[0-9a-f]{64}:1$/.test(old.signature)) reason = "accounting-uncertain";
            else { reason = "comparable"; delta = app.bytes - old.bytes; }
        } else if (!known(app.bytes)) reason = "unmapped";
        return {id: app.id, name: app.name, bytes: app.bytes, delta: delta,
            previousAt: previous ? previous.at : 0, at: current.at,
            comparable: delta !== null, reason: reason, mode: current.mode, targetId: current.targetId};
    });
}

function measurement(snapshot, bytes, partial, app) {
    return {bytes: bytes, partial: !!partial, at: snapshot.at, mode: snapshot.mode,
        targetId: snapshot.targetId, id: app ? app.id : "", name: app ? app.name : ""};
}

function maximum(previous, candidate) {
    if (!previous || candidate.bytes > previous.bytes
            || candidate.bytes === previous.bytes && previous.partial && !candidate.partial)
        return candidate;
    return previous;
}

function summarize(history, year) {
    var result = {year: year, months: [], peak: null, largestApp: null, largestCache: null,
        rise: null, fall: null, scans: 0, overviewScans: 0, deepScans: 0,
        days: 0, apps: 0, measuredMonths: 0, partialScans: 0, unknownApps: 0,
        firstAt: null, lastAt: null, comparisons: 0};
    for (var month = 0; month < 12; ++month)
        result.months.push({month: month, at: null, bytes: null, partial: false, recorded: false});
    var days = Object.create(null), apps = Object.create(null), unknownApps = Object.create(null);
    var previous = Object.create(null);
    // Sorting a copy preserves the service's retained history and ensures that
    // each scope uses its adjacent snapshot, even when other scopes interleave.
    var snapshots = (history || []).slice().sort(function(a, b) { return a.at - b.at; });
    snapshots.forEach(function(snapshot) {
        var date = new Date(snapshot.at), inYear = date.getFullYear() === year;
        var scope = snapshot.mode + ":" + snapshot.targetId;
        var baseline = previous[scope];
        previous[scope] = snapshot;
        if (!inYear) return;
        ++result.scans;
        if (snapshot.mode === "overview") ++result.overviewScans;
        else ++result.deepScans;
        if (snapshot.partial) ++result.partialScans;
        if (result.firstAt === null) result.firstAt = snapshot.at;
        result.lastAt = snapshot.at;
        days[date.getMonth() + ":" + date.getDate()] = true;
        if (snapshot.mode === "overview") {
            var bytes = footprint(snapshot);
            result.months[date.getMonth()] = {month: date.getMonth(), at: snapshot.at,
                bytes: bytes, partial: !!snapshot.partial, recorded: true};
            if (bytes !== null)
                result.peak = maximum(result.peak, measurement(snapshot, bytes, snapshot.partial));
        }
        snapshot.apps.forEach(function(app) {
            apps[app.id] = true;
            if (!known(app.bytes)) { unknownApps[app.id] = true; return; }
            result.largestApp = maximum(result.largestApp, measurement(snapshot, app.bytes, app.partial, app));
            // Category totals contain zero even when no app paths were measured.
            // Only a measured app can contribute a cache observation; partial
            // app categories remain lower bounds, including a recorded zero.
            if (known(app.categories.cache))
                result.largestCache = maximum(result.largestCache,
                    measurement(snapshot, app.categories.cache, app.partial, app));
        });
        // A January change cannot borrow a December baseline for this year's
        // rise/fall, and missing/partial intermediate scans are never skipped.
        if (!baseline || new Date(baseline.at).getFullYear() !== year) return;
        comparisons(snapshot, baseline).forEach(function(row) {
            if (!row.comparable) return;
            ++result.comparisons;
            if (row.delta > 0 && (!result.rise || row.delta > result.rise.delta)) result.rise = row;
            if (row.delta < 0 && (!result.fall || row.delta < result.fall.delta)) result.fall = row;
        });
    });
    result.days = Object.keys(days).length;
    result.apps = Object.keys(apps).length;
    result.unknownApps = Object.keys(unknownApps).length;
    result.measuredMonths = result.months.filter(function(month) { return month.bytes !== null; }).length;
    return result;
}
