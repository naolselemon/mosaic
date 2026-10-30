const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../qml/lib/Presentation.js'), 'utf8')
  .replace(/^\.pragma.*\n/gm, ''), model);
const plain = value => JSON.parse(JSON.stringify(value));

test('only exact presentation values are accepted, not truthy strings or arbitrary keys', () => {
  const raw = {
    showChart: false, showHighlights: 'false', showYearInsights: 0, motion: false,
    chartSamples: 100000, heroColor: 'transparent', insightColor: '<img src="x">',
    id: 'widget', nestedShellSetting: {untouched: true}
  };
  const before = structuredClone(raw);
  const normalized = plain(model.preferences(raw));
  const fallback = plain(model.preferences({}));
  assert.equal(normalized.showChart, false);
  assert.equal(normalized.motion, false);
  for (const key of ['showHighlights', 'showYearInsights', 'chartSamples', 'heroColor', 'insightColor'])
    assert.deepEqual(normalized[key], fallback[key]);
  for (const key of ['id', 'nestedShellSetting'])
    assert.equal(Object.hasOwn(normalized, key), false);
  assert.deepEqual(raw, before);
  for (const key of ['id', '__proto__', 'historyEnabled', 'alertsEnabled', 'nestedShellSetting'])
    assert.equal(model.valid(key, true), false);
  for (const key of ['showChart', 'showHighlights', 'showYearInsights', 'motion']) {
    assert.equal(model.valid(key, false), true);
    assert.equal(model.valid(key, 'false'), false);
  }
});

test('background code preparation requires fresh explicit boolean consent', () => {
  for (const raw of [null, [], {}, {updateChecks: true}, {prepareUpdates: 'true'}, {prepareUpdates: 1},
      {prepareUpdates: {}}, Object.create({prepareUpdates: true})])
    assert.equal(model.preferences(raw).prepareUpdates, false);
  assert.equal(model.preferences({prepareUpdates: true}).prepareUpdates, true);
  assert.equal(model.preferences({prepareUpdates: false}).prepareUpdates, false);
  assert.equal(model.valid('prepareUpdates', true), true);
  assert.equal(model.valid('prepareUpdates', 'true'), false);
  assert.equal(model.valid('updateChecks', true), false);
});

test('chart windows remain bounded to the supported retained-sample choices', () => {
  for (const value of [7, 14, 30, 60]) {
    assert.equal(model.valid('chartSamples', value), true);
    assert.equal(model.preferences({chartSamples: value}).chartSamples, value);
  }
  for (const value of [0, -1, 6, 61, 14.5, '14', Infinity, NaN]) {
    assert.equal(model.valid('chartSamples', value), false);
    assert.equal(model.preferences({chartSamples: value}).chartSamples, model.preferences({}).chartSamples);
  }
});

test('colors follow theme tokens or strict opaque six-digit custom colors', () => {
  const accent = '#112233', foreground = '#aabbcc', urgent = '#ee3344';
  assert.equal(model.tint('theme', accent, foreground, urgent), accent);
  assert.equal(model.tint('foreground', accent, foreground, urgent), foreground);
  assert.equal(model.tint('urgent', accent, foreground, urgent), urgent);
  for (const value of ['#012abc', '#ABCDEF']) {
    assert.equal(model.valid('heroColor', value), true);
    assert.equal(model.preferences({insightColor: value}).insightColor, value);
    assert.equal(model.tint(value, accent, foreground, urgent), value);
  }
  for (const value of ['#abc', '#00112233', '#abcdeG', 'red', '', null, {}, 'url(x)']) {
    assert.equal(model.valid('heroColor', value), false);
    assert.equal(model.tint(value, accent, foreground, urgent), accent);
  }
  assert.equal(model.preferences(Object.create({motion: false})).motion, model.preferences({}).motion);
});
