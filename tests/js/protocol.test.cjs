const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const protocol = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../qml/lib/Protocol.js'), 'utf8'), protocol);

function location(overrides = {}) {
  return {path: '/home/example/.config/example', label: '~/.config/example', category: 'config',
    confidence: 'known', reason: 'rule', evidence: 'Exact desktop ID example.desktop', source: '',
    status: 'complete', bytes: 7, issues: [], measuredAt: 10, entriesSeen: 4,
    breakdown: {children: [{name: 'extensions', bytes: 5, status: 'complete', issues: []}],
      directBytes: 2, directFiles: 1, otherBytes: 0, otherCount: 0},
    skippedCounts: {}, skippedSamples: [], ...overrides};
}
function pending(entry = location()) {
  return {...entry, status: 'pending', bytes: null, measuredAt: 0, entriesSeen: 0,
    breakdown: {children: [], directBytes: 0, directFiles: 0, otherBytes: 0, otherCount: 0},
    skippedCounts: {}, skippedSamples: []};
}
function app(paths = [location()]) {
  const input = {id: 'example.desktop', name: '<img src="https://example.invalid/track">', icon: '',
    paths, mappedBytes: 0, categories: {config: 0, cache: 0, data: 0, state: 0}, status: 'pending', scannedAt: 0};
  return protocol.withPaths(input, paths);
}
function decode(value) { return protocol.decode(JSON.stringify(value)); }
function pathEvent(entry) { return {type: 'path', id: 'example.desktop', path: entry}; }

test('v3 begin requires explicit inventory completeness and rejects older versions', () => {
  const begin = {type: 'begin', version: 3, totalApps: 1, totalPaths: 1,
    mode: 'overview', targetId: '', inventoryComplete: true};
  assert.equal(decode(begin).inventoryComplete, true);
  assert.equal(decode({...begin, inventoryComplete: false}).inventoryComplete, false);
  assert.equal(decode({...begin, mode: 'deep', targetId: 'example.desktop'}).mode, 'deep');
  for (const version of [1, 2, 4, '3']) assert.throws(() => decode({...begin, version}));
  for (const inventoryComplete of [undefined, null, 0, 1, 'true'])
    assert.throws(() => decode({...begin, inventoryComplete}));
  assert.throws(() => decode({...begin, mode: 'deep', targetId: ''}));
  assert.throws(() => decode({...begin, mode: 'deep', targetId: 'example.desktop', totalApps: 2}));
});

test('user assignments count once only when ownership remains exclusive', () => {
  const assigned = location({reason: 'user', evidence: 'User assignment to example.desktop'});
  const shared = location({path: '/home/example/shared', reason: 'shared', confidence: 'shared',
    evidence: 'Shared root; User assignment to example.desktop'});
  let input = app([pending(assigned), pending(shared)]);
  assert.equal(decode({type: 'app', app: input}).app.paths[0].reason, 'user');
  input = protocol.replacePath(input, decode(pathEvent(assigned)).path);
  input = protocol.replacePath(input, decode(pathEvent(shared)).path);
  assert.equal(input.mappedBytes, 7);
  assert.equal(input.categories.config, 7);
  assert.equal(protocol.validApp(input), true);
  assert.throws(() => protocol.replacePath(app([pending(assigned)]), {...assigned, reason: 'rule'}));
});

test('actual scanner v3 stream preserves mapping accounting and private metadata boundaries', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mosaic-protocol-'));
  try {
    const applications = path.join(root, 'applications');
    const configuration = path.join(root, '.config');
    const settings = path.join(configuration, 'omarchy/mosaic');
    fs.mkdirSync(applications);
    fs.mkdirSync(settings, {recursive: true, mode: 0o700});
    for (const id of ['example', 'other'])
      fs.writeFileSync(path.join(applications, `${id}.desktop`),
        `[Desktop Entry]\nType=Application\nName=${id}\n`);
    const assigned = path.join(root, 'assigned');
    const shared = path.join(root, 'shared');
    fs.writeFileSync(assigned, '1234567');
    fs.writeFileSync(shared, '12345');
    fs.writeFileSync(path.join(settings, 'settings.json'), JSON.stringify({
      historyEnabled: false, alertsEnabled: false, thresholdBytes: 268435456,
      customMappings: [
        {id: 'example.desktop', path: assigned, category: 'cache'},
        {id: 'example.desktop', path: shared, category: 'data'},
        {id: 'other.desktop', path: shared, category: 'state'}
      ]
    }), {mode: 0o600});
    const script = 'import scanner,sys; scanner.scan(application_dirs=[sys.argv[1]], rules={})';
    for (const incomplete of [false, true]) {
      if (incomplete) fs.writeFileSync(path.join(applications, 'broken.desktop'), 'invalid metadata');
      const result = spawnSync('python3', ['-B', '-c', script, applications], {
        cwd: path.join(__dirname, '../../backend'),
        env: {...process.env, HOME: root, XDG_CONFIG_HOME: configuration,
          XDG_CACHE_HOME: path.join(root, '.cache'), XDG_DATA_HOME: path.join(root, '.local/share'),
          XDG_STATE_HOME: path.join(root, '.local/state')},
        encoding: 'utf8', timeout: 10000, maxBuffer: 8 * 1024 * 1024
      });
      assert.equal(result.status, 0, result.stderr || String(result.error || ''));
      const records = result.stdout.trim().split('\n').map(line => protocol.decode(line));
      assert.equal(records[0].version, 3);
      assert.equal(records[0].inventoryComplete, !incomplete);
      assert.equal(records[0].totalApps, 2);
      assert.equal(records[0].totalPaths, 3);
      const apps = new Map();
      let paths = 0;
      for (const record of records) {
        if (record.type === 'app') {
          assert.equal(Object.keys(record.app).some(key => key.startsWith('_')), false);
          apps.set(record.app.id, record.app);
        } else if (record.type === 'path') {
          apps.set(record.id, protocol.replacePath(apps.get(record.id), record.path));
          ++paths;
        } else if (record.type === 'appDone') {
          apps.set(record.id, protocol.finishApp(apps.get(record.id), record.status, record.scannedAt));
        }
      }
      assert.equal(paths, records[0].totalPaths);
      assert.equal(records.at(-1).type, 'done');
      assert.equal(apps.get('example.desktop').mappedBytes, 7);
      assert.equal(apps.get('example.desktop').categories.cache, 7);
      assert.equal(apps.get('other.desktop').mappedBytes, 0);
      assert.equal(apps.get('example.desktop').paths[0].reason, 'user');
      assert.equal(apps.get('other.desktop').paths[0].confidence, 'shared');
      for (const app of apps.values()) {
        assert.equal(protocol.validApp(app), true);
        assert.notEqual(app.status, 'pending');
      }
    }
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('shared and possible measurements cannot inflate mapped totals', () => {
  const input = app([location(), location({path: '/home/example/shared', confidence: 'shared'}),
    location({path: '/home/example/guess', confidence: 'possible'})]);
  assert.equal(input.mappedBytes, 7);
  assert.equal(input.categories.config, 7);
  assert.equal(protocol.validApp({...input, mappedBytes: 21, categories: {...input.categories, config: 21}}), false);
});

test('unsafe root and child paths are rejected before folder actions', () => {
  for (const invalid of ['relative', '/home/../etc', '/home/./other', '/home/null\0suffix', '/home//other']) {
    assert.throws(() => decode(pathEvent(location({path: invalid}))));
  }
  for (const name of ['../escape', '.', '..', '/absolute', 'nested/child', 'null\0suffix']) {
    const entry = location();
    entry.breakdown.children[0].name = name;
    assert.throws(() => decode(pathEvent(entry)));
  }
});

test('oversized messages and unsafe byte amounts are rejected', () => {
  assert.throws(() => protocol.decode(' '.repeat(262145)));
  for (const bytes of [-1, 0.5, 1e20, null]) {
    assert.throws(() => decode(pathEvent(location({bytes}))));
  }
});

test('breakdown contributions must exactly partition measured root bytes', () => {
  const entry = location();
  entry.breakdown.otherBytes = 3;
  entry.breakdown.otherCount = 2;
  assert.throws(() => decode(pathEvent(entry)));
  entry.bytes = 10;
  assert.equal(decode(pathEvent(entry)).path.bytes, 10);
  entry.breakdown.children.push({...entry.breakdown.children[0]});
  entry.bytes = 15;
  assert.throws(() => decode(pathEvent(entry)));
});

test('streamed locations update totals once and cannot change ownership', () => {
  let input = app([pending(), pending(location({path: '/home/example/guess', confidence: 'possible'}))]);
  input = protocol.replacePath(input, location());
  input = protocol.replacePath(input, location({path: '/home/example/guess', confidence: 'possible'}));
  assert.equal(input.mappedBytes, 7);
  assert.throws(() => protocol.replacePath(input, location()));
  assert.throws(() => protocol.replacePath(app([pending()]), location({confidence: 'possible'})));
  assert.throws(() => protocol.replacePath(app([pending()]), location({path: '/home/example/not-in-inventory'})));
});

test('completion cannot label pending or partially measured paths complete', () => {
  assert.throws(() => protocol.finishApp(app([pending()]), 'complete', 30));
  const partial = app([location({status: 'partial', issues: ['limit']})]);
  assert.throws(() => protocol.finishApp(partial, 'complete', 30));
  assert.throws(() => protocol.finishApp(partial, 'unmapped', 30));
  const completed = protocol.finishApp(partial, 'partial', 30);
  assert.equal(completed.status, 'partial');
  assert.equal(completed.scannedAt, 30);
});

test('cancellation retains completed paths and timestamps without inventing unfinished bytes', () => {
  const input = app([location(), pending(location({path: '/home/example/.cache/example', category: 'cache'}))]);
  const result = protocol.unfinished(input, 'cancelled', 40);
  assert.equal(result.status, 'partial');
  assert.equal(result.mappedBytes, 7);
  assert.equal(result.scannedAt, 40);
  assert.equal(result.paths[0].measuredAt, 10);
  assert.equal(result.paths[1].status, 'partial');
  assert.equal(result.paths[1].bytes, null);
  assert.equal(result.paths[1].measuredAt, 0);
  assert.equal(result.paths[1].skippedCounts.cancelled, 1);
  assert.equal(result.paths[1].skippedSamples[0].reason, 'cancelled');
  assert.equal(input.paths[1].status, 'pending');
});

test('cancelling other work does not relabel a discovered unmapped app as incomplete', () => {
  const input = {...app([]), status: 'unmapped'};
  assert.equal(protocol.unfinished(input, 'cancelled', 40).status, 'unmapped');
});

test('a denied child cannot be presented as a completely measured root', () => {
  const entry = location();
  entry.breakdown.children[0] = {name: 'private', bytes: null, status: 'denied', issues: ['permission']};
  entry.bytes = 2;
  assert.throws(() => decode(pathEvent(entry)));
  entry.status = 'partial';
  assert.equal(decode(pathEvent(entry)).path.breakdown.children[0].bytes, null);
});

test('skipped samples are bounded and must have corresponding reason counts', () => {
  const entry = location({status: 'partial', issues: ['permission']});
  entry.skippedSamples = [{relative: 'private', reason: 'permission', truncated: false}];
  assert.throws(() => decode(pathEvent(entry)));
  entry.skippedCounts.permission = 1;
  assert.equal(decode(pathEvent(entry)).path.skippedSamples[0].relative, 'private');
  entry.skippedSamples = Array(9).fill(entry.skippedSamples[0]);
  assert.throws(() => decode(pathEvent(entry)));
});

test('bounded Unicode labels are not rejected solely for UTF-16 surrogate pairs', () => {
  const entry = location({status: 'partial', issues: ['limit'], skippedCounts: {limit: 1},
    skippedSamples: [{relative: '\u{1F4C1}'.repeat(512), reason: 'limit', truncated: true}]});
  assert.equal(decode(pathEvent(entry)).path.skippedSamples[0].relative, entry.skippedSamples[0].relative);
  entry.skippedSamples[0].relative += 'x';
  assert.throws(() => decode(pathEvent(entry)));
});
