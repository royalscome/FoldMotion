const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const Module = require('node:module');
const ts = require('typescript');
let failCreation = false;
global.HitTestMode = { None: 3 };
class RenderNode {
  disposed = false;
  children = [];
  invalidate() { assert.equal(this.disposed, false, 'disposed surfaces cannot be invalidated'); }
  isDisposed() { return this.disposed; }
  dispose() { this.disposed = true; }
  appendChild(child) { this.children.push(child); }
}
class FrameNode {
  root = new RenderNode();
  commonAttribute = {
    width() { return this; }, height() { return this; },
    hitTestBehavior(mode) { assert.equal(mode, HitTestMode.None); this.hitTest = mode; return this; }
  };
  constructor() { if (failCreation) throw Error('detached UI context'); }
  getRenderNode() { return this.root; }
  dispose() { this.root.children.forEach(child => child.dispose()); this.root.dispose(); }
}
const originalLoad = Module._load;
Module._load = function(name, ...args) {
  if (name === '@kit.ArkUI') return { RenderNode, FrameNode, NodeController: class {} };
  if (name === '@kit.ImageKit') return {};
  if (name === '@kit.ArkGraphics2D') return { drawing: { Brush: class {} } };
  return originalLoad.call(this, name, ...args);
};
Module._extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, filename);
const { FoldMotionSurface } = require('../fold_motion/src/main/ets/FoldMotionSurface.ets');

test('mesh overlay releases its host and retains new state when reattached', () => {
  const surface = new FoldMotionSurface();
  const first = surface.makeNode({}); const firstNode = first.root.children[0];
  assert.equal(first.commonAttribute.hitTest, HitTestMode.None, 'the native child must also pass touches through');
  surface.aboutToResize({ width: 400, height: 500 });
  surface.setImage({ id: 'old' }); surface.update(0, false, 1, 1);
  let calls = 0;
  const context = { sizeInPixel: { width: 800, height: 1000 }, canvas: { attachBrush() { this.attached = true; }, detachBrush() { this.attached = false; }, drawPixelMapMesh(map, cols, rows, vertices) {
    calls++; assert.ok(this.attached, 'mesh requires an attached brush'); assert.equal(map.id, 'old'); assert.equal(vertices.length, (cols + 1) * (rows + 1) * 2);
    assert.ok(vertices.every(Number.isFinite)); assert.equal(vertices[0], 0); assert.ok(vertices[2] > 800 / cols);
  } } };
  firstNode.draw(context); assert.equal(calls, 1);
  surface.close(); assert.ok(firstNode.isDisposed()); assert.equal(firstNode.map, undefined);
  surface.aboutToResize({ width: 0, height: 0 }); // A late callback after teardown.
  surface.update(2, true, 0.8, 0.7); surface.setImage({ id: 'new' });
  const nextNode = surface.makeNode({}).root.children[0];
  assert.notEqual(nextNode, firstNode);
  assert.equal(nextNode.map.id, 'new'); assert.equal(nextNode.turn, 2); assert.equal(nextNode.cover, true);
  surface.setImage(undefined);
  nextNode.draw(context); assert.equal(calls, 1, 'cleared overlays never draw a stale image');
  surface.close();
});

test('unavailable surface and draw failures leave the live content path available', () => {
  const surface = new FoldMotionSurface();
  failCreation = true; assert.equal(surface.makeNode({}), null); failCreation = false;
  const node = surface.makeNode({}).root.children[0];
  surface.update(0, false, 1, 1); surface.setImage({});
  let calls = 0;
  const context = { sizeInPixel: { width: 800, height: 1000 }, canvas: { attachBrush() { this.attached = true; }, detachBrush() { this.attached = false; }, drawPixelMapMesh() { calls++; throw Error('surface lost'); } } };
  assert.doesNotThrow(() => node.draw(context));
  assert.equal(node.map, undefined); node.draw(context); assert.equal(calls, 1);
  surface.close();
});
