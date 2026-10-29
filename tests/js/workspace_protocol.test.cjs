const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const scan = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../qml/lib/Protocol.js'), 'utf8'), scan);
const workspace = vm.createContext({Scan: scan});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../qml/lib/WorkspaceProtocol.js'), 'utf8')
  .replace(/^\.(?:pragma|import).*\n/gm, ''), workspace);
const mib = 1024 * 1024;

function view() {
  return {version: 1, refreshedAt: 100, settings: {historyEnabled: true, alertsEnabled: false, thresholdBytes: mib},
    mappings: [], history: [], growth: [], insights: {cache: [], growing: []}, leftovers: [],
    installations: {scannedAt: 100, groups: [], apps: [], totalBytes: 0, knownApps: 0, unresolvedApps: 0, issues: []},
    alerts: [], notifications: [], warnings: []};
}
function decode(data) { return workspace.decode(JSON.stringify({ok: true, data})).data; }
function growth(overrides = {}) {
  return {id: 'example.desktop', name: 'Example', bytes: 2 * mib, delta: mib, previousAt: 10, at: 20,
    comparable: true, reason: '', mode: 'overview', ...overrides};
}

test('package totals count shared installations once, not once per launcher', () => {
  const data = view();
  data.installations.groups = [{key: 'pacman:example', name: 'example', kind: 'pacman', bytes: 100,
    status: 'known', appIds: ['one.desktop', 'two.desktop'], reason: ''}];
  data.installations.apps = ['one.desktop', 'two.desktop'].map(id => ({id, groupKey: 'pacman:example', status: 'shared', reason: ''}));
  data.installations.knownApps = 2;
  data.installations.totalBytes = 100;
  assert.equal(decode(data).installations.totalBytes, 100);
  data.installations.totalBytes = 200;
  assert.throws(() => decode(data));
  data.installations.totalBytes = 100;
  data.installations.groups.push({...data.installations.groups[0]});
  data.installations.totalBytes = 200;
  assert.throws(() => decode(data));
});

test('unknown installations cannot become zero-sized or falsely attributed packages', () => {
  const data = view();
  data.installations.groups = [{key: 'pacman:unreadable', name: 'unreadable', kind: 'pacman', bytes: null,
    status: 'unknown', appIds: ['one.desktop'], reason: 'Metadata unavailable'}];
  data.installations.apps = [{id: 'one.desktop', groupKey: 'pacman:unreadable', status: 'unknown', reason: 'Metadata unavailable'}];
  data.installations.unresolvedApps = 1;
  assert.equal(decode(data).installations.groups[0].bytes, null);
  data.installations.groups[0].bytes = 0;
  assert.throws(() => decode(data));
  data.installations.groups[0].bytes = null;
  data.installations.apps[0].status = 'known';
  data.installations.knownApps = 1;
  data.installations.unresolvedApps = 0;
  assert.throws(() => decode(data));
});

test('unavailable comparisons cannot carry exact deltas or use the same scan as their baseline', () => {
  const data = view();
  data.growth = [growth({comparable: false, reason: 'incomplete', delta: null})];
  assert.equal(decode(data).growth[0].delta, null);
  data.growth[0].delta = mib;
  assert.throws(() => decode(data));
  for (const invalid of [{previousAt: 20}, {previousAt: 30}, {bytes: null}, {delta: 0.5}]) {
    data.growth = [growth(invalid)];
    assert.throws(() => decode(data));
  }
  data.growth = [growth({delta: -mib})];
  assert.equal(decode(data).growth[0].delta, -mib);
});

test('alerts require history consent and a real threshold crossing', () => {
  const data = view();
  data.settings.historyEnabled = false;
  data.settings.alertsEnabled = true;
  assert.throws(() => decode(data));
  data.settings.historyEnabled = true;
  data.notifications = [{key: 'event', id: 'example.desktop', name: 'Example', delta: mib, at: 20, thresholdBytes: mib}];
  assert.equal(decode(data).notifications[0].delta, mib);
  data.notifications[0].delta = mib - 1;
  assert.throws(() => decode(data));
});

test('unsafe action paths are rejected before reaching the dashboard', () => {
  for (const unsafe of ['relative', '/home/../etc', '/home//data', '/', '/home/null\0data']) {
    const data = view();
    data.mappings = [{id: 'example.desktop', path: unsafe, category: 'data'}];
    assert.throws(() => decode(data));
    data.mappings = [];
    data.leftovers = [{id: 'example.desktop', name: 'Example', path: unsafe, category: 'data', bytes: 10,
      status: 'complete', reason: 'launcher-missing', evidence: 'Known mapping'}];
    assert.throws(() => decode(data));
  }
});

test('history cannot mix a deep snapshot with another app or an unknown scope', () => {
  const data = view();
  data.history = [{key: 'deep:20', at: 20, mode: 'deep', targetId: 'example.desktop', mappedBytes: 0, partial: true,
    apps: [{id: 'other.desktop', name: 'Other', bytes: null, partial: true,
      categories: {config: 0, cache: 0, data: 0, state: 0}, signature: 'unknown'}]}];
  assert.throws(() => decode(data));
  data.history[0].apps[0].id = 'example.desktop';
  assert.equal(decode(data).history[0].apps[0].bytes, null);
  data.history[0].mode = 'combined';
  assert.throws(() => decode(data));
});

test('oversized and malformed worker output fails rather than becoming an empty dashboard', () => {
  assert.throws(() => workspace.decode(' '.repeat(workspace.maxMessage + 1)));
  assert.throws(() => workspace.decode('{"ok":true,"data":{}}'));
  assert.throws(() => workspace.decode('{"ok":false,"error":null}'));
  const data = view();
  data.warnings = Array(65).fill('Unknown state');
  assert.throws(() => decode(data));
});
