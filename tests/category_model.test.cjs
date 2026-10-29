const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../CategoryModel.js'), 'utf8')
  .replace(/^\.pragma.*\n/gm, ''), model);
const plain = value => JSON.parse(JSON.stringify(value));

function entry(bytes, options = {}) {
  return { category: 'cache', confidence: 'known', status: 'complete', bytes,
    path: '/home/example/.cache/app', ...options };
}
function app(id, paths, options = {}) {
  return { id, name: id, icon: 'application-x-executable', status: 'complete', paths, ...options };
}
function row(id, bytes, options = {}) {
  return { id, name: id, icon: 'application-x-executable', bytes, partial: false, paths: [], ...options };
}
function freeze(value) {
  if (value && typeof value === 'object') {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}
function close(actual, expected, relative = 1e-10) {
  assert.ok(Math.abs(actual - expected) <= Math.max(Number.MIN_VALUE, Math.abs(expected) * relative),
    `${actual} differs from ${expected}`);
}
function geometry(cells, width, height) {
  const total = cells.reduce((sum, cell) => sum + cell.bytes, 0);
  const epsilon = Math.max(width, height) * 1e-12;
  for (const cell of cells) {
    for (const key of ['x', 'y', 'width', 'height']) assert.ok(Number.isFinite(cell[key]));
    assert.ok(cell.width > 0 && cell.height > 0);
    assert.ok(cell.x >= 0 && cell.y >= 0);
    assert.ok(cell.x + cell.width <= width + epsilon);
    assert.ok(cell.y + cell.height <= height + epsilon);
    close((cell.width / width) * (cell.height / height), cell.bytes / total);
  }
  for (let i = 0; i < cells.length; ++i) {
    for (let j = i + 1; j < cells.length; ++j) {
      const a = cells[i];
      const b = cells[j];
      const overlapX = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
      const overlapY = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
      assert.ok(overlapX <= epsilon || overlapY <= epsilon, `tiles ${i} and ${j} overlap`);
    }
  }
  close(cells.reduce((sum, cell) => sum + (cell.width / width) * (cell.height / height), 0), 1);
}

test('summary measures only assigned category paths and discloses excluded candidate matches', () => {
  const known = entry(40);
  const possible = entry(900, { confidence: 'possible' });
  const shared = entry(700, { confidence: 'shared' });
  const apps = [
    app('alpha', [known, possible, entry(800, { category: 'data' })], { mappedBytes: 840 }),
    app('beta', [shared]),
    app('gamma', [entry(null, { category: 'config', status: 'pending' })]),
  ];
  const result = model.summary(apps, 'cache');
  assert.equal(result.bytes, 40);
  assert.equal(result.partial, false);
  assert.equal(result.knownPaths, 1);
  assert.equal(result.measuredPaths, 1);
  assert.equal(result.completePaths, 1);
  assert.equal(result.unknownPaths, 0);
  assert.deepEqual(plain(result.apps.map(item => item.id)), ['alpha']);
  assert.equal(result.excluded.length, 2);
});

test('completeness ignores unrelated categories, app status and excluded matches', () => {
  const result = model.summary([
    app('alpha', [entry(12), entry(null, { category: 'data', status: 'pending' }),
      entry(null, { confidence: 'possible', status: 'denied' })], { status: 'partial' }),
    app('beta', [entry(3, { category: 'state', status: 'partial' })], { status: 'partial' }),
  ], 'cache');
  assert.equal(result.bytes, 12);
  assert.equal(result.partial, false);
  assert.equal(result.apps[0].partial, false);
  assert.equal(result.apps.length, 1);
});

test('empty or excluded-only categories remain unknown rather than measured zero', () => {
  for (const apps of [null, [], [app('empty', [])], [app('other', [entry(12, { category: 'data' })])],
    [app('candidate', [entry(12, { confidence: 'possible' })])]]) {
    const result = model.summary(apps, 'cache');
    assert.equal(result.bytes, null);
    assert.equal(result.partial, false);
    assert.equal(result.knownPaths, 0);
    assert.equal(result.measuredPaths, 0);
    assert.equal(result.completePaths, 0);
    assert.equal(result.unknownPaths, 0);
    assert.equal(result.apps.length, 0);
  }
});

test('measured zero is complete and distinct from unmeasured paths', () => {
  const result = model.summary([app('zero', [entry(0)])], 'cache');
  assert.equal(result.bytes, 0);
  assert.equal(result.partial, false);
  assert.equal(result.apps[0].bytes, 0);
  assert.equal(result.apps[0].partial, false);
  assert.equal(result.knownPaths, 1);
  assert.equal(result.measuredPaths, 1);
  assert.equal(result.completePaths, 1);
  assert.equal(result.unknownPaths, 0);
});

test('unmeasured null and absent bytes stay unknown even on a complete path', () => {
  const absent = entry(undefined);
  delete absent.bytes;
  const result = model.summary([app('unknown', [entry(null, { status: 'pending' }), absent])], 'cache');
  assert.equal(result.bytes, null);
  assert.equal(result.apps[0].bytes, null);
  assert.equal(result.partial, true);
  assert.equal(result.apps[0].partial, true);
  assert.equal(result.knownPaths, 2);
  assert.equal(result.measuredPaths, 0);
  assert.equal(result.completePaths, 1);
  assert.equal(result.unknownPaths, 2);
});

test('mixed measurements retain lower bounds and category-local app completeness', () => {
  const result = model.summary([
    app('partial', [entry(25), entry(5, { status: 'partial' }), entry(null, { status: 'denied' })]),
    app('complete', [entry(10)]),
    app('unknown', [entry(undefined, { status: 'pending' })]),
  ], 'cache');
  assert.equal(result.bytes, 40);
  assert.equal(result.partial, true);
  assert.equal(result.knownPaths, 5);
  assert.equal(result.measuredPaths, 3);
  assert.equal(result.completePaths, 2);
  assert.equal(result.unknownPaths, 2);
  assert.deepEqual(plain(result.apps.map(item => [item.id, item.bytes, item.partial])),
    [['partial', 30, true], ['complete', 10, false], ['unknown', null, true]]);
});

test('every incomplete path status marks even a measured-zero app partial', () => {
  for (const status of ['pending', 'partial', 'denied', 'missing', 'symlink', 'error']) {
    const result = model.summary([app('zero', [entry(0, { status })])], 'cache');
    assert.equal(result.bytes, 0);
    assert.equal(result.apps[0].bytes, 0);
    assert.equal(result.partial, true);
    assert.equal(result.apps[0].partial, true);
    assert.equal(result.measuredPaths, 1);
    assert.equal(result.completePaths, 0);
  }
});

test('all four categories use their own measurements and confidence exclusions', () => {
  const categories = ['config', 'data', 'cache', 'state'];
  const paths = categories.flatMap((category, index) => [
    entry(index * 10, { category }), entry(999, { category, confidence: 'shared' }),
  ]);
  for (const [index, category] of categories.entries()) {
    const result = model.summary([app('multi', paths)], category);
    assert.equal(result.bytes, index * 10);
    assert.equal(result.apps[0].paths.length, 1);
    assert.equal(result.apps[0].paths[0].category, category);
    assert.equal(result.excluded.length, 1);
    assert.equal(result.excluded[0].entry.category, category);
  }
});

test('candidate counts retain repeated physical paths as matches, not independent owners', () => {
  const result = model.summary([
    app('a', [entry(100, { confidence: 'shared' })]),
    app('b', [entry(100, { confidence: 'shared' })]),
  ], 'cache');
  assert.equal(result.excluded.length, 2);
  assert.equal(result.excluded[0].entry.path, result.excluded[1].entry.path);
  assert.equal(result.bytes, null);
  assert.equal(result.apps.length, 0);
});

test('summary orders bytes, name and id consistently with known zeros before unknowns', () => {
  const apps = [app('unknown', [entry(null)]), app('zero', [entry(0)]),
    app('b', [entry(10)], { name: 'same' }), app('a', [entry(10)], { name: 'same' }),
    app('first', [entry(10)], { name: 'alpha' }), app('largest', [entry(30)])];
  const expected = ['largest', 'first', 'a', 'b', 'zero', 'unknown'];
  assert.deepEqual(plain(model.summary(apps, 'cache').apps.map(item => item.id)), expected);
  assert.deepEqual(plain(model.summary(apps.slice().reverse(), 'cache').apps.map(item => item.id)), expected);
});

test('tiles include only finite positive numeric measurements in stable ranked order', () => {
  const rows = [row('zero', 0), row('unknown', null), row('missing', undefined), row('negative', -1),
    row('infinite', Infinity), row('nan', NaN), row('string', '4'), row('b', 2), row('a', 2), row('big', 9)];
  const cells = model.tiles(rows, 300, 180);
  assert.deepEqual(plain(cells.map(cell => cell.appId)), ['big', 'a', 'b']);
  assert.deepEqual(plain(cells[0].members), ['big']);
  assert.equal(cells[0].kind, 'app');
  geometry(cells, 300, 180);
});

test('bounded tiles aggregate exactly the remaining positive members', () => {
  const rows = Array.from({ length: 12 }, (_, i) => row(`app-${i}`, 12 - i, { partial: i === 10 }));
  rows.push(row('zero', 0), row('unknown', null, { partial: true }));
  const cells = model.tiles(rows.slice().reverse(), 420, 240, 7);
  assert.equal(cells.length, 8);
  assert.deepEqual(plain(cells.slice(0, 7).map(cell => cell.appId)), rows.slice(0, 7).map(item => item.id));
  const other = cells[7];
  assert.equal(other.kind, 'other');
  assert.equal(other.bytes, 15);
  assert.equal(other.partial, true);
  assert.deepEqual(plain(other.members), rows.slice(7, 12).map(item => item.id));
  const members = cells.flatMap(cell => Array.from(cell.members));
  assert.equal(members.length, 12);
  assert.equal(new Set(members).size, 12);
  assert.equal(cells.reduce((sum, cell) => sum + cell.bytes, 0), 78);
  geometry(cells, 420, 240);
});

test('Other partial flag includes only its own positive members', () => {
  const cells = model.tiles([row('big', 100, { partial: true }), row('small', 4),
    row('zero', 0, { partial: true }), row('unknown', null, { partial: true })], 100, 100, 1);
  assert.equal(cells[0].partial, true);
  assert.equal(cells[1].partial, false);
  assert.deepEqual(plain(cells[1].members), ['small']);
  assert.equal(cells[1].bytes, 4);
});

test('explicit app limits produce no empty Other and permit an all-Other view', () => {
  const rows = [row('a', 3), row('b', 2), row('c', 1)];
  for (const limit of [3, 7, 100]) {
    const cells = model.tiles(rows, 200, 100, limit);
    assert.equal(cells.length, 3);
    assert.ok(cells.every(cell => cell.kind === 'app'));
  }
  for (const limit of [0, -1]) {
    const cells = model.tiles(rows, 200, 100, limit);
    assert.equal(cells.length, 1);
    assert.equal(cells[0].kind, 'other');
    assert.equal(cells[0].bytes, 6);
    assert.deepEqual(plain(cells[0].members), ['a', 'b', 'c']);
    geometry(cells, 200, 100);
  }
  assert.equal(model.tiles(rows, 200, 100, 1.9).length, 2);
});

test('empty and nonpositive inputs return no areas', () => {
  for (const rows of [null, [], [row('zero', 0)], [row('unknown', null)],
    [row('zero', 0), row('unknown', undefined), row('bad', NaN)]]) {
    assert.deepEqual(plain(model.tiles(rows, 320, 180)), []);
  }
});

test('unusable dimensions do not produce rectangles or mutate rows', () => {
  const rows = freeze([row('a', 10)]);
  for (const bad of [0, -1, NaN, Infinity, -Infinity, undefined, null, '100']) {
    assert.deepEqual(plain(model.tiles(rows, bad, 100)), []);
    assert.deepEqual(plain(model.tiles(rows, 100, bad)), []);
  }
});

test('tiling is deterministic across input order and never mutates snapshots', () => {
  const rows = freeze([row('c', 4), row('b', 7, { name: 'same' }), row('a', 7, { name: 'same' }), row('d', 1)]);
  const before = plain(rows);
  const first = model.tiles(rows, 480, 213, 2);
  const second = model.tiles(rows, 480, 213, 2);
  assert.deepEqual(plain(first), plain(second));
  assert.deepEqual(plain(first), plain(model.tiles(rows.slice().reverse(), 480, 213, 2)));
  assert.deepEqual(plain(rows), before);
  first[0].members.push('not-an-app');
  assert.equal(second[0].members.length, 1);
});

for (const [width, height] of [[400, 240], [240, 400], [256, 256], [1200, 40], [40, 1200], [0.25, 0.125]]) {
  test(`rectangles preserve area, bounds and non-overlap at ${width} x ${height}`, () => {
    const rows = [83, 47, 31, 19, 11, 7, 3, 2, 1].map((bytes, i) => row(`app-${i}`, bytes));
    geometry(model.tiles(rows, width, height), width, height);
    geometry(model.tiles(rows, width, height, 100), width, height);
    geometry(model.tiles(rows, width, height, 2), width, height);
  });
}

test('one app fills the rectangle exactly without margins or minimum sizing', () => {
  const cell = model.tiles([row('only', 1)], 137, 83)[0];
  assert.deepEqual(plain([cell.x, cell.y, cell.width, cell.height]), [0, 0, 137, 83]);
});

test('dominant app and tiny positive values keep their exact weight without minimum areas', () => {
  const rows = [row('dominant', Number.MAX_SAFE_INTEGER), row('tiny-a', 1), row('tiny-b', 2), row('tiny-c', 3)];
  for (const [width, height] of [[400, 240], [40, 1200], [1200, 40]]) {
    const cells = model.tiles(rows, width, height);
    geometry(cells, width, height);
    for (const cell of cells.slice(1)) assert.ok(cell.width * cell.height < 1e-8);
    geometry(model.tiles(rows, width, height, 1), width, height);
  }
});
