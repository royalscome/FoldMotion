const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

test('the built-in scope never snapshots, transforms or intercepts its live content', () => {
  const source = fs.readFileSync(path.join(__dirname, '../fold_motion/src/main/ets/FoldMotion.ets'), 'utf8');
  assert.equal((source.match(/this\.content\(\)/g) ?? []).length, 1, 'content stays mounted exactly once');
  assert.doesNotMatch(source, /getComponentSnapshot|PixelMap|NodeContainer|\.(?:scale|rotate|transform|translate)\(/);
  assert.doesNotMatch(source, /onTouch\(|setTimeout|setInterval|animateTo|\.animation\(/);
  assert.doesNotMatch(source, /FoldMotion(?:Capture|Surface|Geometry)/);
});
