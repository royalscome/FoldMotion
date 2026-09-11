# Changelog

## 1.0.1 — 2026-09-11

- Keep the gradient axis stable during inner/cover display handoffs, including staggered display notifications.
- Keep the original left-edge blur on the inner display and reverse it only on the cover display.
- Remove temporary angle and display diagnostics and their bookkeeping state.
- Add regression coverage for display handoffs, cover cold starts and clamshell panel identification.

## 1.0.0 — 2026-09-11

- Initial release of the FoldMotion HarmonyOS HAR, with no third-party runtime dependencies.
- Provide a content-sized ArkUI component for pages and individual cards.
- Drive directional blur from physical hinge angles, following crease orientation and display rotation.
- Preserve the effect while the hinge is stationary; stop frame scheduling after settling.
- Expose a controller and platform-independent model for custom effects.
- Handle application lifecycle, reduced motion, visibility and independent instances.
- Include a sample application, portable Node tests, Hypium tests and release packaging tools.
- Release the library and sample under the standard Unlicense.
