# Changelog

## 1.2.0 — 2026-09-12

- Keep content flat and live: remove the snapshot mesh, perspective rendering and associated image lifecycle code.
- Retain `perspectiveStrength` and `contentRevision` as deprecated no-op props for source compatibility.
- Present the latest hinge angle on the next frame without time-based interpolation or trailing animation.
- Honor endpoint samples even within the jitter threshold, including fast reopening.
- Soften the initial inner-display blur and progressively shrink cover blur coverage during closure.
- Keep inner/cover orientation handling, independent scopes, reduced motion and lifecycle cleanup.
- Replace obsolete snapshot tests with fast/slow equivalence, endpoint, cover-coverage and live-content regressions.

## 1.1.0 — 2026-09-12

- Add independent, staged blur, regional shade and local perspective channels driven by hinge angle.
- Keep cover channels responsive throughout the remaining closure after display handoff.
- Keep the stable region undeformed and clear; preserve the inner and cover display directions.
- Hold all channels at stationary angles and stop scheduling frames after settling.
- Render perspective with a bounded in-memory snapshot mesh; discard stale images after resize, handoff, touch and teardown.
- Add `onVisualFrame`, `FoldMotionState`, external angle input, shade/perspective controls and content invalidation.
- Add manual angle and panel previews to the demo, including separate channel readouts.
- Raise the default blur radius from 28 to 42; set shade and perspective strength to zero for a blur-only scope.
- Expand regression coverage for channel timing, mesh bounds, manual input and asynchronous capture cleanup.

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
