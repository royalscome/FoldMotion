// Exercise the production controller with deterministic display events and vsync.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');
const { test } = require('node:test');
let now = 1000, reduced = false, foldable = true, rotation = 0, failMode = false;
let screenOverride, displayMode = 1;
let creaseRegion = { displayId: 0, creaseRects: [{ left: 596, top: 0, width: 8, height: 1800 }] };
const accessibilityCallbacks = new Set(), applicationCallbacks = new Set();
const listeners = new Map(), frames = [], values = [];
global.GradientDirection = { Right: 0, Bottom: 1, Left: 2, Top: 3 };
const display = {
  isFoldable: () => foldable,
  getDefaultDisplaySync: () => screenOverride ?? ({ id: 0, rotation, width: rotation % 2 ? 1800 : 1200, height: rotation % 2 ? 1200 : 1800 }),
  getFoldDisplayMode: () => displayMode,
  getCurrentFoldCreaseRegion: () => creaseRegion,
  on: (type, callback) => {
    if (failMode && type === 'foldDisplayModeChange') throw new Error('unsupported');
    if (!listeners.has(type)) listeners.set(type, new Set());
    assert.equal(listeners.get(type).has(callback), false, 'duplicate listener'); listeners.get(type).add(callback);
  },
  off: (type, callback) => { assert.ok(listeners.get(type)?.delete(callback)); if (!listeners.get(type).size) listeners.delete(type); }
};
const mocks = {
  '@kit.AbilityKit': {},
  '@kit.ArkUI': { display, FrameCallback: class {} },
  '@kit.AccessibilityKit': { accessibility: {
    isAnimationReduceEnabledSync: () => reduced,
    onAnimationReduceStateChange: cb => { assert.ok(!accessibilityCallbacks.has(cb)); accessibilityCallbacks.add(cb); },
    offAnimationReduceStateChange: cb => { assert.ok(accessibilityCallbacks.delete(cb)); }
  } },
  '@kit.BasicServicesKit': { systemDateTime: { TimeType: { ACTIVE: 0 }, getUptime: () => now } },
  '@kit.PerformanceAnalysisKit': { hilog: { info() {}, warn() {} } }
};
const originalLoad = Module._load;
Module._load = function(name, ...args) { return mocks[name] ?? originalLoad.call(this, name, ...args); };
Module._extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, filename);
const { FoldMotionController } = require(path.resolve(__dirname,
  '../fold_motion/src/main/ets/FoldMotionController.ets'));
const controller = new FoldMotionController();
const application = {
  on: (type, cb) => { assert.equal(type, 'applicationStateChange'); assert.ok(!applicationCallbacks.has(cb)); applicationCallbacks.add(cb); },
  off: (type, cb) => { assert.equal(type, 'applicationStateChange'); assert.ok(applicationCallbacks.delete(cb)); }
};
const ui = { postFrameCallback: frame => frames.push(frame), getHostContext: () => ({ getApplicationContext: () => application }) };
controller.onFrame = (radius, direction) => values.push({ radius, direction });
function tick() { now += 16; frames.splice(0).forEach(frame => frame.onFrame(now)); }
function event(type, value) { for (const cb of [...(listeners.get(type) ?? [])]) cb(value); }
function emit(angles) { event('foldAngleChange', angles); }
function move() { emit([180]); now += 20; emit([120]); tick(); }

test('controller lifecycle, paused motion and independent scopes', () => {
  controller.start(ui, true);
  assert.equal(listeners.size, 3);
  emit([90]); tick(); assert.equal(values.length, 0, 'no cold-start blur');
  now += 20; emit([70]); tick();
  assert.ok(values.at(-1).radius > 0);
  for (let i = 0; i < 40; i++) tick();
  assert.ok(values.at(-1).radius > 0, 'holding an angle preserves its effect');
  assert.equal(frames.length, 0, 'held effect stops scheduling frames');
  const heldRadius = values.at(-1).radius;
  for (let i = 0; i < 40; i++) tick();
  assert.equal(values.at(-1).radius, heldRadius, 'pause does not advance or dismiss the transition');
  rotation = 1; event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Bottom, 'held gradient follows rotation');
  assert.equal(values.at(-1).radius, heldRadius);

  now += 20; emit([100]); tick();
  const staleAngleCallback = [...listeners.get('foldAngleChange')][0];
  controller.setEnabled(false); // The host explicitly disables this scope.
  assert.equal(listeners.size, 0); assert.equal(values.at(-1).radius, 0);
  staleAngleCallback([30]); tick();
  assert.equal(values.at(-1).radius, 0, 'queued work cannot blur a disabled scope');
  controller.setEnabled(true); move();
  assert.ok(values.at(-1).radius > 0);
  rotation = 1; event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Bottom);

  reduced = true; accessibilityCallbacks.forEach(cb => cb(true));
  assert.equal(listeners.size, 0); tick(); assert.equal(values.at(-1).radius, 0);
  reduced = false; accessibilityCallbacks.forEach(cb => cb(false)); assert.equal(listeners.size, 3);
  move(); controller.close(); tick();
  assert.equal(listeners.size, 0); assert.equal(accessibilityCallbacks.size, 0); assert.equal(applicationCallbacks.size, 0);
  assert.equal(values.at(-1).radius, 0);

  failMode = true; controller.start(ui, true);
  assert.equal(listeners.size, 0, 'partial subscription is rolled back'); controller.close();
  failMode = false; foldable = false; controller.start(ui, true);
  assert.equal(listeners.size, 0, 'flat devices have no angle work'); controller.close();
  foldable = true;
  controller.start(ui, true); move();
  applicationCallbacks.forEach(cb => cb.onApplicationBackground()); tick();
  assert.equal(listeners.size, 0); assert.equal(values.at(-1).radius, 0, 'package handles background without app storage');
  applicationCallbacks.forEach(cb => cb.onApplicationForeground());
  assert.equal(listeners.size, 3); move();
  controller.start(ui, true); // Attaching the same public controller twice is safe.
  assert.equal(applicationCallbacks.size, 1); assert.equal(accessibilityCallbacks.size, 1);
  assert.equal(listeners.get('foldAngleChange').size, 1);
  const second = new FoldMotionController(); second.start(ui, true);
  assert.equal(listeners.get('foldAngleChange').size, 2);
  controller.close(); assert.equal(listeners.get('foldAngleChange').size, 1, 'one scope cannot remove another scope');
  const secondValues = []; second.onFrame = radius => secondValues.push(radius); move();
  assert.ok(secondValues.at(-1) > 0); second.close(); tick();
  assert.equal(listeners.size, 0); assert.equal(applicationCallbacks.size, 0); assert.equal(accessibilityCallbacks.size, 0);
});

test('inner and cover screens keep the same gradient through staggered display events', () => {
  screenOverride = { id: 0, rotation: 3, width: 2584, height: 1828 };
  creaseRegion = { displayId: 0, creaseRects: [{ left: 0, top: 1194, width: 1828, height: 196 }] };
  displayMode = 1;
  controller.start(ui, true); move();
  for (let i = 0; i < 40; i++) tick();
  assert.equal(values.at(-1).direction, GradientDirection.Right);
  const held = values.at(-1).radius;
  // Rotation arrives before the new panel dimensions and mode.
  screenOverride = { id: 0, rotation: 0, width: 2584, height: 1828 };
  event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Right, 'a partial handoff is not a physical rotation');
  screenOverride = { id: 0, rotation: 0, width: 1264, height: 1848 };
  displayMode = 2;
  event('foldDisplayModeChange', 2); event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Right, 'inner crease coordinates must not rotate the cover effect');
  assert.equal(values.at(-1).radius, held);
  // An ordinary rotation on the cover still changes the visual direction.
  screenOverride = { id: 0, rotation: 1, width: 1848, height: 1264 };
  event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Bottom);
  screenOverride = { id: 0, rotation: 0, width: 1264, height: 1848 };
  event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Right);
  // On reopening, mode and rotation can precede the inner screen bounds.
  displayMode = 1;
  event('foldDisplayModeChange', 1); tick();
  screenOverride = { id: 0, rotation: 3, width: 1264, height: 1848 };
  event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Right);
  screenOverride = { id: 0, rotation: 3, width: 2584, height: 1828 };
  event('change', 0); tick();
  assert.equal(values.at(-1).direction, GradientDirection.Right);
  assert.equal(values.at(-1).radius, held);
  assert.equal(frames.length, 0);
  controller.close(); tick();
});
