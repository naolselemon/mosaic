const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const geometry = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../DonutGeometry.js'), 'utf8')
  .replace(/^\.pragma.*\n/gm, ''), geometry);
const plain = value => JSON.parse(JSON.stringify(value));

function point(angle, radius, cx = 58, cy = 58) {
  return [cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius];
}
function hit(segment, angle, distance, radius = 48, stroke = 12, cx = 58, cy = 58) {
  const [x, y] = point(angle, distance, cx, cy);
  return geometry.contains(segment, x, y, cx, cy, radius, stroke);
}

test('shares use only finite nonnegative measurements while keeping legend indices', () => {
  const result = geometry.build([20, null, 0, 60, -4, Infinity, NaN, '12']);
  assert.deepEqual(plain(result.shares), [0.25, null, 0, 0.75, null, null, null, null]);
  assert.deepEqual(plain(result.segments.map(segment => segment.drawable)),
    [true, false, false, true, false, false, false, false]);
  assert.ok(result.segments[0].end < result.segments[3].start);
  assert.ok(Math.abs(result.segments[3].end - (1.5 * Math.PI - 0.0175)) < 1e-12);
});

test('empty and wholly unmeasured data never invent a percentage or a hit target', () => {
  for (const input of [[], null, [0, 0], [null, NaN, -1]]) {
    const result = geometry.build(input);
    assert.ok(result.shares.every(share => share === null));
    assert.ok(result.segments.every(segment => !segment.drawable));
    assert.ok(result.segments.every(segment => !hit(segment, 0, 48)));
  }
});

test('large finite measurements cannot overflow the normalized total', () => {
  assert.deepEqual(plain(geometry.build([Number.MAX_VALUE, Number.MAX_VALUE]).shares), [0.5, 0.5]);
});

test('the hole, outside edge and visible angular gaps are never hover targets', () => {
  const result = geometry.build([1, 1, 1, 1]);
  for (const segment of result.segments) {
    assert.equal(hit(segment, segment.middle, 48), true);
    assert.equal(hit(segment, segment.middle, 41.9), false);
    assert.equal(hit(segment, segment.middle, 54.1), false);
    assert.equal(hit(segment, segment.middle, 0), false);
    assert.equal(hit(segment, segment.start - 0.001, 48), false);
    assert.equal(hit(segment, segment.end + 0.001, 48), false);
  }
  for (const boundary of [-Math.PI / 2, 0, Math.PI / 2, Math.PI])
    assert.equal(result.segments.some(segment => hit(segment, boundary, 48)), false);
});

test('single-category seam and small slices preserve their actual painted gaps', () => {
  const full = geometry.build([1]).segments[0];
  assert.equal(hit(full, 0, 48), true);
  assert.equal(hit(full, -Math.PI / 2, 48), false);
  const tiny = geometry.build([0.000001, 1]).segments[0];
  assert.equal(tiny.drawable, true);
  assert.equal(hit(tiny, tiny.middle, 48), true);
  assert.equal(hit(tiny, -Math.PI / 2, 48), false);
});

test('hit geometry follows resized centers, radii and stroke widths', () => {
  const segment = geometry.build([3, 1]).segments[0];
  assert.equal(hit(segment, segment.middle, 70, 70, 16, 100, 80), true);
  assert.equal(hit(segment, segment.middle, 60, 70, 16, 100, 80), false);
  assert.equal(geometry.contains(segment, 58, 58, 58, 58, 0, 12), false);
});
