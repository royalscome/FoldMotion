/** Angle-driven visual motion. Layout and navigation never depend on this state. */
export class FoldMotionModel {
  static readonly maximumRadius: number = 28;
  private angles: number[] = [];
  private sampleAt: number = 0;
  private movedAt: number = -1;
  private frameAt: number = 0;
  private target: number = 0;
  radius: number = 0;
  hinge: number = 0;

  reset(): void {
    this.angles = [];
    this.sampleAt = this.frameAt = 0;
    this.movedAt = -1;
    this.target = this.radius = this.hinge = 0;
  }

  accept(angles: number[], now: number): boolean {
    if (angles.length === 0 || !angles.every((angle: number): boolean =>
      Number.isFinite(angle) && angle >= 0 && angle <= 180) || !Number.isFinite(now)) { return false; }
    if (this.angles.length !== angles.length || now < this.sampleAt) {
      this.angles = angles.slice(); this.sampleAt = now;
      return false;
    }
    let movement: number = 0;
    let hinge: number = 0;
    angles.forEach((angle: number, index: number): void => {
      const delta: number = Math.abs(angle - this.angles[index]);
      if (delta > movement) { movement = delta; hinge = index; }
    });
    // Accumulate slow movement without letting sensor jitter move the held effect.
    if (movement < 0.45) { return false; }
    const openness: number = Math.sin(angles[hinge] * Math.PI / 180);
    this.target = FoldMotionModel.maximumRadius * openness;
    if (angles[hinge] <= 2 || angles[hinge] >= 178) { this.target = 0; }
    this.hinge = hinge;
    this.angles = angles.slice(); this.sampleAt = this.movedAt = now;
    return true;
  }

  handoff(now: number): boolean {
    // A display switch may interrupt angle delivery. Bridge only a recent
    // physical movement, never a cold start, ordinary resize, or rotation.
    if (this.movedAt < 0 || now - this.movedAt > 650) { return false; }
    return true;
  }

  advance(now: number): number {
    if (this.movedAt < 0) { return 0; }
    const elapsed: number = this.frameAt > 0 ? Math.max(1, Math.min(64, now - this.frameAt)) : 16;
    this.frameAt = now;
    const blend: number = 1 - Math.exp(-elapsed / (this.target > this.radius ? 42 : 65));
    this.radius += (this.target - this.radius) * blend;
    // The hinge owns progress. Holding an angle preserves the visual state,
    // while snapping to the target lets the UI stop scheduling idle frames.
    if (Math.abs(this.radius - this.target) < 0.04) { this.radius = this.target; }
    return this.radius;
  }

  needsFrame(_now: number): boolean {
    return Math.abs(this.radius - this.target) > 0.025;
  }

  static gradientQuarterTurns(horizontalCrease: boolean, rotation: number): number {
    return ((horizontalCrease ? 1 : 0) + rotation) % 4;
  }
}
