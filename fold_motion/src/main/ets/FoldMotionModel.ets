/** Independent visual channels; layout and navigation never depend on this state. */
export interface FoldMotionState {
  radius: number;
  shade: number;
  depth: number;
  angle: number;
  cover: boolean;
  sample: number;
}

export class FoldMotionModel {
  static readonly maximumRadius: number = 28;
  private angles: number[] = [];
  private sampleAt: number = 0;
  private movedAt: number = -1;
  private target: FoldMotionState = FoldMotionModel.profile(180, false);
  private cover: boolean = false;
  private angle: number = 180;
  private sample: number = 0;
  radius: number = 0;
  shade: number = 0;
  depth: number = 0;
  hinge: number = 0;

  static smooth(start: number, end: number, value: number): number {
    const t: number = Math.max(0, Math.min(1, (value - start) / (end - start)));
    return t * t * (3 - 2 * t);
  }

  /** Per-panel distance from its clear endpoint. Blur arrives before depth and shade. */
  static profile(angle: number, cover: boolean): FoldMotionState {
    const valid: boolean = Number.isFinite(angle) && angle >= 0 && angle <= 180;
    const distance: number = valid ? (180 - angle) / 90 : 0;
    const endpoint: boolean = !valid || angle <= 2 || angle >= 178;
    const coverProgress: number = Math.max(0, Math.min(1, (angle - 2) / 73));
    // Cover recovery changes both radius and coverage throughout the visible closure.
    // The inner curve starts softly, avoiding a large blur jump on the first few degrees.
    const blur: number = cover ? coverProgress * coverProgress :
      FoldMotionModel.smooth(2 / 90, 0.6, distance);
    return {
      radius: endpoint ? 0 : FoldMotionModel.maximumRadius * blur,
      shade: endpoint ? 0 : cover ? FoldMotionModel.smooth(4, 75, angle) :
        FoldMotionModel.smooth(0.18, 1, distance),
      depth: endpoint ? 0 : cover ? FoldMotionModel.smooth(2, 75, angle) :
        FoldMotionModel.smooth(0.06, 0.9, distance),
      angle: valid ? angle : (cover ? 0 : 180), cover, sample: 0
    };
  }

  reset(): void {
    this.angles = [];
    this.sampleAt = 0;
    this.movedAt = -1;
    this.radius = this.shade = this.depth = this.hinge = this.sample = 0;
    this.angle = this.cover ? 0 : 180;
    this.target = FoldMotionModel.profile(this.angle, this.cover);
  }

  setCover(cover: boolean): void {
    if (cover === this.cover) { return; }
    this.cover = cover;
    if (this.movedAt >= 0) { this.target = FoldMotionModel.profile(this.angle, cover); }
  }

  state(): FoldMotionState {
    return { radius: this.radius, shade: this.shade, depth: this.depth,
      angle: this.angle, cover: this.cover, sample: this.sample };
  }

  accept(angles: number[], now: number): boolean {
    if (angles.length === 0 || !angles.every((angle: number): boolean =>
      Number.isFinite(angle) && angle >= 0 && angle <= 180) || !Number.isFinite(now)) { return false; }
    if (this.angles.length !== angles.length || now < this.sampleAt) {
      this.angles = angles.slice(); this.sampleAt = now;
      // A changed sensor baseline must not leave an old transition stuck at an endpoint.
      if (this.movedAt >= 0) {
        this.hinge = Math.min(this.hinge, angles.length - 1);
        this.angle = angles[this.hinge]; this.sample += 1;
        this.target = FoldMotionModel.profile(this.angle, this.cover);
        this.movedAt = now;
        return true;
      }
      return false;
    }
    let movement: number = 0;
    let hinge: number = this.hinge;
    angles.forEach((angle: number, index: number): void => {
      const delta: number = Math.abs(angle - this.angles[index]);
      if (delta > movement) { movement = delta; hinge = index; }
    });
    // Accumulate slow movement while ignoring jitter. Never dismiss a stationary hinge.
    const nextAngle: number = angles[hinge];
    const endpointChanged: boolean = (nextAngle <= 2 || nextAngle >= 178) !==
      (this.angles[hinge] <= 2 || this.angles[hinge] >= 178);
    if (movement < 0.45 && !endpointChanged) { return false; }
    this.hinge = hinge; this.angle = angles[hinge]; this.sample += 1;
    this.target = FoldMotionModel.profile(this.angle, this.cover);
    this.angles = angles.slice(); this.sampleAt = this.movedAt = now;
    return true;
  }

  handoff(now: number): boolean {
    return this.movedAt >= 0 && now >= this.movedAt && now - this.movedAt <= 650;
  }

  /** Latch the latest sample on the next presentation frame; elapsed time adds no animation. */
  advance(now: number): number {
    if (this.movedAt < 0 || !Number.isFinite(now)) { return this.radius; }
    this.radius = this.target.radius;
    this.shade = this.target.shade;
    this.depth = this.target.depth;
    return this.radius;
  }

  /** Fraction of the surface affected from the active edge. Cover clarity advances across the page. */
  static blurSpan(radius: number, cover: boolean): number {
    if (!cover) { return 0.58; }
    const fraction: number = Number.isFinite(radius) ? Math.max(0, Math.min(1, radius / FoldMotionModel.maximumRadius)) : 0;
    return 0.94 * Math.sqrt(fraction);
  }

  needsFrame(_now: number): boolean {
    return this.radius !== this.target.radius || this.shade !== this.target.shade || this.depth !== this.target.depth;
  }

  static gradientQuarterTurns(horizontalCrease: boolean, rotation: number): number {
    return ((horizontalCrease ? 1 : 0) + rotation) % 4;
  }
}
