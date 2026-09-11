import { display, FrameCallback, UIContext } from '@kit.ArkUI';
import { accessibility } from '@kit.AccessibilityKit';
import { common, ApplicationStateChangeCallback } from '@kit.AbilityKit';
import { systemDateTime } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FoldMotionModel } from './FoldMotionModel';

class FoldMotionFrameCallback extends FrameCallback {
  private readonly action: () => void;
  constructor(action: () => void) { super(); this.action = action; }
  onFrame(_time: number): void { this.action(); }
  onIdle(_time: number): void {}
}

/** Owns a scoped fold effect; it has no knowledge of application routes or data. */
export class FoldMotionController {
  onFrame: (radius: number, direction: GradientDirection) => void = (): void => {};
  private readonly motion: FoldMotionModel = new FoldMotionModel();
  private context: UIContext | undefined = undefined;
  private applicationContext: common.ApplicationContext | undefined = undefined;
  private foreground: boolean = true;
  private enabled: boolean = false;
  private reducedMotion: boolean = false;
  private observingAngles: boolean = false;
  private observingDisplayMode: boolean = false;
  private observingDisplay: boolean = false;
  private observingAccessibility: boolean = false;
  private framePending: boolean = false;
  private generation: number = 0;
  private direction: GradientDirection = GradientDirection.Right;
  private lastRadius: number = 0;
  private lastDirection: GradientDirection = GradientDirection.Right;
  private lastDiagnosticAt: number = 0;
  private readonly anglesChanged = (angles: number[]): void => {
    if (!this.enabled || !this.foreground || this.reducedMotion) { return; }
    const now: number = this.now();
    const previousHinge: number = this.motion.hinge;
    if (!this.motion.accept(angles, now)) { return; }
    if (previousHinge !== this.motion.hinge) { this.updateDirection(); }
    if (now - this.lastDiagnosticAt > 750) {
      this.lastDiagnosticAt = now;
      hilog.info(0xD004201, 'FoldMotionModel', 'angles=%{public}s hinge=%{public}d',
        angles.map((angle: number): number => Math.round(angle)).join(','), this.motion.hinge);
    }
    this.requestFrame();
  };
  private readonly modeChanged = (_mode: display.FoldDisplayMode): void => {
    this.updateDirection();
    if (this.lastRadius > 0 || this.motion.handoff(this.now())) { this.requestFrame(); }
  };
  private readonly displayChanged = (_id: number): void => {
    this.updateDirection();
    if (this.lastRadius > 0) { this.requestFrame(); }
  };
  private readonly accessibilityChanged = (reduced: boolean): void => {
    this.reducedMotion = reduced; this.synchronize();
  };
  private readonly applicationStateChanged: ApplicationStateChangeCallback = {
    onApplicationForeground: (): void => { this.foreground = true; this.synchronize(); },
    onApplicationBackground: (): void => { this.foreground = false; this.synchronize(); }
  };

  start(context: UIContext, enabled: boolean): void {
    // Reattachment must release callbacks and pending frames from the old host.
    if (this.context !== undefined) { this.close(); }
    this.context = context;
    this.enabled = enabled;
    this.foreground = true;
    try {
      const applicationContext: common.ApplicationContext | undefined = context.getHostContext()?.getApplicationContext();
      applicationContext?.on('applicationStateChange', this.applicationStateChanged);
      this.applicationContext = applicationContext;
    } catch (_error) {}
    try { this.reducedMotion = accessibility.isAnimationReduceEnabledSync(); } catch (_error) {}
    try {
      accessibility.onAnimationReduceStateChange(this.accessibilityChanged);
      this.observingAccessibility = true;
    } catch (_error) {}
    this.synchronize();
  }

  setEnabled(enabled: boolean): void {
    if (enabled === this.enabled) { return; }
    this.enabled = enabled; this.synchronize();
  }

  close(): void {
    this.enabled = false; this.synchronize();
    if (this.observingAccessibility) {
      try { accessibility.offAnimationReduceStateChange(this.accessibilityChanged); } catch (_error) {}
      this.observingAccessibility = false;
    }
    if (this.applicationContext !== undefined) {
      try { this.applicationContext.off('applicationStateChange', this.applicationStateChanged); } catch (_error) {}
      this.applicationContext = undefined;
    }
    this.context = undefined;
  }

  private synchronize(): void {
    if (!this.enabled || !this.foreground || this.reducedMotion || this.context === undefined) {
      this.stopObserving(); return;
    }
    if (this.observingAngles) { return; }
    try {
      if (!display.isFoldable()) { return; }
      display.on('foldAngleChange', this.anglesChanged); this.observingAngles = true;
      display.on('foldDisplayModeChange', this.modeChanged); this.observingDisplayMode = true;
      display.on('change', this.displayChanged); this.observingDisplay = true;
      this.updateDirection();
      hilog.info(0xD004201, 'FoldMotionModel', 'angle listener ready');
    } catch (_error) {
      this.stopObserving();
      hilog.warn(0xD004201, 'FoldMotionModel', 'angle listener unavailable');
    }
  }

  private stopObserving(): void {
    if (this.observingAngles) {
      try { display.off('foldAngleChange', this.anglesChanged); } catch (_error) {}
    }
    if (this.observingDisplayMode) {
      try { display.off('foldDisplayModeChange', this.modeChanged); } catch (_error) {}
    }
    if (this.observingDisplay) {
      try { display.off('change', this.displayChanged); } catch (_error) {}
    }
    this.observingAngles = this.observingDisplayMode = this.observingDisplay = false;
    this.generation += 1; this.framePending = false;
    this.motion.reset(); this.lastRadius = 0;
    this.onFrame(0, this.direction);
  }

  private now(): number {
    return systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false);
  }

  private updateDirection(): void {
    try {
      const screen: display.Display = display.getDefaultDisplaySync();
      const creases: display.Rect[] = display.getCurrentFoldCreaseRegion()?.creaseRects ?? [];
      const crease: display.Rect | undefined = creases[Math.min(this.motion.hinge, creases.length - 1)];
      const horizontal: boolean = crease !== undefined && crease.width > crease.height;
      const turn: number = FoldMotionModel.gradientQuarterTurns(horizontal, screen.rotation);
      const directions: GradientDirection[] = [GradientDirection.Right, GradientDirection.Bottom,
        GradientDirection.Left, GradientDirection.Top];
      this.direction = directions[turn];
    } catch (_error) {}
  }

  private requestFrame(): void {
    if (this.framePending || this.context === undefined || !this.enabled || !this.foreground || this.reducedMotion) { return; }
    this.framePending = true;
    const generation: number = this.generation;
    this.context.postFrameCallback(new FoldMotionFrameCallback((): void => {
      if (generation !== this.generation || !this.enabled || !this.foreground || this.reducedMotion) { return; }
      this.framePending = false;
      const now: number = this.now();
      const radius: number = this.motion.advance(now);
      if (Math.abs(radius - this.lastRadius) > 0.025 || radius === 0 || this.direction !== this.lastDirection) {
        this.lastRadius = radius;
        this.lastDirection = this.direction;
        this.onFrame(radius, this.direction);
      }
      if (this.motion.needsFrame(now)) { this.requestFrame(); }
    }));
  }
}
