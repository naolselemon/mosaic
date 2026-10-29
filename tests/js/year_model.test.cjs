const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../qml/lib/YearModel.js'), 'utf8')
  .replace(/^\.pragma library\s*\n/, ''), model);

const own = 'a'.repeat(64);
const accounting = 'b'.repeat(64);
const signature = `${own}:${accounting}:1`;
const at = (year, month = 0, day = 1, hour = 12) => new Date(year, month, day, hour).getTime();
function app(bytes, overrides = {}) {
  return {id: 'example.desktop', name: 'Example', bytes, partial: false,
    categories: {config: 0, cache: bytes === null ? 0 : bytes, data: 0, state: 0}, signature, ...overrides};
}
function scan(time, apps = [app(10)], overrides = {}) {
  return {key: String(time), at: time, mode: 'overview', targetId: '',
    mappedBytes: apps.reduce((sum, row) => sum + (row.bytes || 0), 0),
    partial: apps.some(row => row.partial || row.bytes === null), apps, ...overrides};
}
function deep(time, bytes, id = 'example.desktop', overrides = {}) {
  return scan(time, [app(bytes, {id})], {mode: 'deep', targetId: id, ...overrides});
}
function plain(value) { return JSON.parse(JSON.stringify(value)); }

test('year navigation includes the current local year and distinct retained years from both scopes', () => {
  assert.deepEqual(plain(model.years([], at(2026))), [2026]);
  assert.deepEqual(plain(model.years([
    deep(at(2023), 10), scan(at(2025)), scan(at(2025, 11)), scan(at(2027))
  ], at(2026))), [2023, 2025, 2026, 2027]);
});

test('monthly bars use the last overview, never totals, peaks, deep scans or neighboring months', () => {
  const history = [scan(at(2026, 0, 1), [app(100)]), scan(at(2026, 0, 2), [app(40)]),
    deep(at(2026, 0, 3), 900), scan(at(2026, 2, 1), [app(30)])];
  const summary = model.summarize(history, 2026);
  assert.equal(summary.months.length, 12);
  assert.equal(summary.months[0].bytes, 40);
  assert.equal(summary.months[0].at, at(2026, 0, 2));
  assert.equal(summary.months[1].bytes, null);
  assert.equal(summary.months[1].recorded, false);
  assert.equal(summary.months[2].bytes, 30);
  assert.equal(summary.peak.bytes, 100);
  assert.equal(summary.peak.mode, 'overview');
  assert.equal(summary.measuredMonths, 2);
  assert.equal(summary.largestApp.bytes, 900);
  assert.equal(summary.largestApp.mode, 'deep');
});

test('a last unknown overview replaces an earlier known month without fabricating measured zero', () => {
  const summary = model.summarize([
    scan(at(2026, 0, 1), [app(80)]), scan(at(2026, 0, 2), [app(null)]),
    scan(at(2026, 1), [], {partial: true}), scan(at(2026, 2), [app(0)]),
    scan(at(2026, 3), [], {partial: false})
  ], 2026);
  assert.equal(summary.months[0].bytes, null);
  assert.equal(summary.months[0].recorded, true);
  assert.equal(summary.months[0].at, at(2026, 0, 2));
  assert.equal(summary.months[1].bytes, null);
  assert.equal(summary.months[2].bytes, 0);
  assert.equal(summary.months[3].bytes, 0);
  assert.equal(summary.peak.bytes, 80);
  assert.equal(summary.measuredMonths, 2);
  const unknown = model.summarize([scan(at(2026), [app(null)])], 2026);
  assert.equal(unknown.peak, null);
  assert.equal(unknown.largestApp, null);
  assert.equal(unknown.largestCache, null);
  assert.equal(unknown.apps, 1);
  assert.equal(unknown.unknownApps, 1);
});

test('partial monthly, peak, app and cache measurements remain lower bounds', () => {
  const summary = model.summarize([scan(at(2026), [app(300, {partial: true})])], 2026);
  assert.equal(summary.months[0].bytes, 300);
  assert.equal(summary.months[0].partial, true);
  assert.equal(summary.peak.partial, true);
  assert.equal(summary.largestApp.partial, true);
  assert.equal(summary.largestCache.partial, true);
  assert.equal(summary.partialScans, 1);
  assert.equal(summary.rise, null);
});

test('comparison safeguards match journal reason ordering and never coerce unknowns', () => {
  const baseline = scan(at(2026), [app(10)]);
  const cases = [
    [app(20), {at: baseline.at}, 'non-increasing-time'],
    [app(20), {at: baseline.at - 1}, 'non-increasing-time'],
    [app(null), {}, 'unmapped'],
    [app(20, {partial: true}), {}, 'incomplete'],
    [app(20, {signature: `${'c'.repeat(64)}:${accounting}:1`}), {}, 'ownership-changed'],
    [app(20, {signature: `${own}:${'d'.repeat(64)}:1`}), {}, 'accounting-changed'],
    [app(20, {signature: `${own}:${accounting}:0`}), {}, 'accounting-uncertain']
  ];
  for (const [currentApp, overrides, reason] of cases) {
    const row = model.comparisons(scan(at(2026, 0, 2), [currentApp], overrides), baseline)[0];
    assert.equal(row.reason, reason);
    assert.equal(row.delta, null);
    assert.equal(row.comparable, false);
  }
  for (const previousApp of [app(null), app(10, {partial: true}),
    app(10, {signature: `${own}:${accounting}:0`})]) {
    assert.equal(model.comparisons(scan(at(2026, 0, 2), [app(20)]),
      scan(at(2026), [previousApp]))[0].delta, null);
  }
});

test('unsafe, unknown, absent and mapping-changed intermediate scans are never skipped', () => {
  for (const middleApps of [[app(20, {partial: true})], [app(null)], [],
    [app(20, {signature: `${own}:${accounting}:0`})],
    [app(20, {signature: `${'c'.repeat(64)}:${accounting}:1`})],
    [app(20, {signature: `${own}:${'d'.repeat(64)}:1`})]]) {
    const summary = model.summarize([scan(at(2026, 0, 1), [app(10)]),
      scan(at(2026, 0, 2), middleApps), scan(at(2026, 0, 3), [app(100)])], 2026);
    assert.equal(summary.rise, null);
    assert.equal(summary.comparisons, 0);
  }
});

test('overview and each deep target have independent adjacent baselines', () => {
  const history = [scan(at(2026, 0, 1), [app(100)]), deep(at(2026, 0, 2), 900),
    deep(at(2026, 0, 3), 5000, 'other.desktop'), scan(at(2026, 0, 4), [app(110)]),
    deep(at(2026, 0, 5), 850), deep(at(2026, 0, 6), 5020, 'other.desktop')];
  const summary = model.summarize(history, 2026);
  assert.equal(summary.rise.delta, 20);
  assert.equal(summary.rise.id, 'other.desktop');
  assert.equal(summary.rise.targetId, 'other.desktop');
  assert.equal(summary.rise.mode, 'deep');
  assert.equal(summary.fall.delta, -50);
  assert.equal(summary.fall.previousAt, at(2026, 0, 2));
  assert.equal(summary.fall.at, at(2026, 0, 5));
  assert.equal(summary.comparisons, 3);
  assert.equal(model.comparisons(history[1], history[0])[0].delta, null);
  assert.equal(model.comparisons(history[2], history[1])[0].delta, null);
});

test('comparisons cannot borrow another app baseline and duplicates cannot generate changes', () => {
  const first = scan(at(2026), [app(100)]);
  const second = scan(at(2026, 0, 2), [app(900, {id: 'other.desktop'})]);
  assert.equal(model.summarize([first, second], 2026).rise, null);
  const duplicateTime = scan(at(2026), [app(900)]);
  assert.equal(model.summarize([first, duplicateTime], 2026).rise, null);
});

test('local year boundaries keep January changes out unless both endpoints belong to the year', () => {
  const december = scan(new Date(2025, 11, 31, 23, 59, 59, 999).getTime(), [app(100)]);
  const january = scan(new Date(2026, 0, 1, 0, 0, 0, 0).getTime(), [app(900)]);
  const nextYear = scan(new Date(2027, 0, 1, 0, 0, 0, 0).getTime(), [app(9000)]);
  const history = [december, january, nextYear];
  const year = model.summarize(history, 2026);
  assert.equal(year.scans, 1);
  assert.equal(year.days, 1);
  assert.equal(year.months[0].at, january.at);
  assert.equal(year.months[11].bytes, null);
  assert.equal(year.rise, null);
  assert.equal(model.summarize(history, 2025).months[11].bytes, 100);
  assert.equal(model.summarize(history, 2027).rise, null);
  history.push(scan(at(2026, 0, 2), [app(880)]));
  assert.equal(model.summarize(history, 2026).fall.delta, -20);
});

test('biggest fall is signed shrinkage, not freed space or a sum; unchanged pairs stay zero', () => {
  const summary = model.summarize([100, 100, 70, 90, 20].map((bytes, index) =>
    scan(at(2026, 0, index + 1), [app(bytes)])), 2026);
  assert.equal(summary.rise.delta, 20);
  assert.equal(summary.fall.delta, -70);
  assert.equal(summary.fall.previousAt, at(2026, 0, 4));
  assert.equal(summary.comparisons, 4);
  const unchanged = model.summarize([scan(at(2026)), scan(at(2026, 0, 2))], 2026);
  assert.equal(unchanged.rise, null);
  assert.equal(unchanged.fall, null);
  assert.equal(unchanged.comparisons, 1);
});

test('counts deduplicate local calendar days and app identities without inventing annual coverage', () => {
  const history = [scan(at(2026, 1, 3, 9)), deep(at(2026, 1, 3, 18), 10),
    scan(at(2026, 2, 3), [app(null), app(5, {id: 'other.desktop'})]), scan(at(2025))];
  const summary = model.summarize(history, 2026);
  assert.equal(summary.scans, 3);
  assert.equal(summary.overviewScans, 2);
  assert.equal(summary.deepScans, 1);
  assert.equal(summary.days, 2);
  assert.equal(summary.apps, 2);
  assert.equal(summary.firstAt, at(2026, 1, 3, 9));
  assert.equal(summary.lastAt, at(2026, 2, 3));
  const empty = model.summarize([], 2026);
  assert.equal(empty.scans, 0);
  assert.equal(empty.days, 0);
  assert.equal(empty.apps, 0);
  assert.equal(empty.peak, null);
  assert.equal(empty.firstAt, null);
  assert.equal(empty.months.every(month => month.bytes === null && !month.recorded), true);
});

test('unsorted retained input is not mutated and deep-only years have no overview footprint', () => {
  const history = [deep(at(2026, 0, 3), 90), deep(at(2026, 0, 1), 30), deep(at(2026, 0, 2), 60)];
  const original = JSON.stringify(history);
  const summary = model.summarize(history, 2026);
  assert.equal(JSON.stringify(history), original);
  assert.equal(summary.rise.delta, 30);
  assert.equal(summary.peak, null);
  assert.equal(summary.months.every(month => !month.recorded), true);
  assert.equal(summary.largestCache.bytes, 90);
  assert.equal(summary.deepScans, 3);
});
