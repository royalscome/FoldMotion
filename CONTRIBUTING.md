# Contributing

Issues and pull requests are welcome. Describe the expected behavior and the actual result; for device-specific reports, include the HarmonyOS version, device model and whether the issue occurs during closing, opening or a stationary hinge position.

## Local checks

```sh
npm ci --ignore-scripts
npm test
```

With DevEco Studio and the required SDK installed:

```sh
python3 scripts/harmony.py check
```

Keep the runtime module independent of host applications and test angle/lifecycle behavior deterministically. Update the module README when changing the public API. Node tests use the production controller and share the model cases with Hypium; verify ArkTS compatibility with the SDK build as well.

For motion changes, also check an actual foldable device: pause mid-fold, reverse direction, rotate, switch foreground/background and enable reduced motion. Note which checks you performed in the pull request.

Keep generated files and local signing material outside version control. Contributions are covered by the project's [Unlicense](LICENSE).
