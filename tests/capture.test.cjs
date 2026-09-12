const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const ts = require('typescript');
const { test } = require('node:test');
Module._extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, filename);
const { FoldMotionCapture } = require('../fold_motion/src/main/ets/FoldMotionCapture.ets');
const flush = () => new Promise(resolve => setImmediate(resolve));
const map = () => ({ released: 0, release() { this.released++; return Promise.resolve(); } });

test('stale captures are released and the newest display is captured without concurrent requests', async () => {
  const capture = new FoldMotionCapture(), images = [];
  capture.onImage = image => images.push(image);
  let finish; const old = map(), next = map(); let calls = 0;
  capture.request(() => { calls++; return new Promise(resolve => { finish = resolve; }); }, 1000);
  capture.clear();
  capture.request(() => { calls++; return Promise.resolve(next); }, 1010);
  assert.equal(calls, 1);
  finish(old); await flush();
  assert.equal(old.released, 1); assert.equal(calls, 2); assert.equal(images.at(-1), next);
  capture.clear(); assert.equal(next.released, 1); assert.equal(images.at(-1), undefined);
});

test('capture throttles motion samples, releases replacements and recovers from errors', async () => {
  const capture = new FoldMotionCapture(), a = map(), b = map(); let calls = 0;
  capture.request(() => { calls++; return Promise.resolve(a); }, 1000); await flush();
  capture.request(() => { calls++; return Promise.resolve(b); }, 1050); assert.equal(calls, 1);
  capture.request(() => { calls++; return Promise.resolve(b); }, 1200); await flush();
  assert.equal(a.released, 1); assert.equal(b.released, 0);
  capture.request(() => Promise.reject(new Error('unsupported surface')), 1400); await flush();
  assert.equal(b.released, 1);
  const c = map(); capture.request(() => Promise.resolve(c), 1600); await flush();
  capture.clear(); assert.equal(c.released, 1);
});

test('closing drops queued work and releases an in-flight texture without reviving the overlay', async () => {
  const capture = new FoldMotionCapture(), late = map(); let finish; let calls = 0;
  capture.request(() => new Promise(resolve => { finish = resolve; }), 1000);
  capture.request(() => { calls++; return Promise.resolve(map()); }, 1200);
  capture.clear(); finish(late); await flush();
  assert.equal(calls, 0); assert.equal(late.released, 1);
});
