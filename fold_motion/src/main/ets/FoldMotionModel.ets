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
  private frameAt: number = 0;
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
    // Cover handoff happens well before the physical endpoint. Keep every remaining
    // angle responsive, with the final detail recovery concentrated near closure.
    const blur: number = cover ? 0.6 * FoldMotionModel.smooth(2, 20, angle) +
      0.4 * FoldMotionModel.smooth(20, 75, angle) : FoldMotionModel.smooth(2 / 90, 0.24, distance);
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
    this.sampleAt = this.frameAt = 0;
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
        this.movedAt = now; this.frameAt = 0;
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
    if (movement < 0.45) { return false; }
    this.hinge = hinge; this.angle = angles[hinge]; this.sample += 1;
    this.target = FoldMotionModel.profile(this.angle, this.cover);
    this.angles = angles.slice(); this.sampleAt = this.movedAt = now;
    return true;
  }

  handoff(now: number): boolean {
    return this.movedAt >= 0 && now >= this.movedAt && now - this.movedAt <= 650;
  }

  private follow(value: number, target: number, elapsed: number, attack: number, release: number,
    threshold: number): number {
    const next: number = value + (target - value) * (1 - Math.exp(-elapsed / (target > value ? attack : release)));
    return Math.abs(next - target) < threshold ? target : next;
  }

  advance(now: number): number {
    if (this.movedAt < 0 || !Number.isFinite(now)) { return this.radius; }
    const elapsed: number = this.frameAt > 0 ? Math.max(1, Math.min(64, now - this.frameAt)) : 16;
    this.frameAt = now;
    this.radius = this.follow(this.radius, this.target.radius, elapsed, 32, 72, 0.025);
    this.shade = this.follow(this.shade, this.target.shade, elapsed, 54, 48, 0.0005);
    this.depth = this.follow(this.depth, this.target.depth, elapsed, 42, 58, 0.0005);
    return this.radius;
  }

  needsFrame(_now: number): boolean {
    return this.radius !== this.target.radius || this.shade !== this.target.shade || this.depth !== this.target.depth;
  }

  static gradientQuarterTurns(horizontalCrease: boolean, rotation: number): number {
    return ((horizontalCrease ? 1 : 0) + rotation) % 4;
  }
}
