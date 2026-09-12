// Run the same production model and Hypium cases in portable Node CI.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const { describe, it } = require('node:test');
const ts = require('typescript');
const hypium = {
  describe,
  it: (name, _level, body) => it(name, body),
  expect: value => ({
    assertTrue: () => assert.equal(value, true),
    assertFalse: () => assert.equal(value, false),
    assertEqual: expected => assert.equal(value, expected)
  })
};
const originalLoad = Module._load;
Module._load = function (name, ...args) {
  return name === '@ohos/hypium' ? hypium : originalLoad.call(this, name, ...args);
};
Module._extensions['.ets'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS }
}).outputText, filename);
require('../fold_motion/src/test/FoldMotionModel.test.ets').default();
require('../fold_motion/src/test/FoldMotionDirectionModel.test.ets').default();

require('../fold_motion/src/test/FoldMotionGeometry.test.ets').default();
