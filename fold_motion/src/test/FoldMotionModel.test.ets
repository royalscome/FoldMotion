import { describe, expect, it } from '@ohos/hypium';
import { FoldMotionModel } from '../main/ets/FoldMotionModel';

export default function foldMotionModelTest(): void {
  describe('FoldMotionModel', (): void => {
    it('does not blur on launch or on the first half-open sample', 0, (): void => {
      const motion = new FoldMotionModel();
      expect(motion.accept([90], 100)).assertFalse();
      expect(motion.advance(116)).assertEqual(0);
      expect(motion.handoff(120)).assertFalse();
    });
    it('responds to physical angle movement with a bounded radius', 0, (): void => {
      const motion = new FoldMotionModel(); motion.accept([180], 100);
      for (let index = 1; index <= 12; index += 1) {
        motion.accept([180 - index * 7], 100 + index * 16);
        motion.advance(100 + index * 16);
      }
      expect(motion.radius > 10 && motion.radius <= FoldMotionModel.maximumRadius).assertTrue();
    });
    it('holds the angle effect while paused and resumes without resetting progress', 0, (): void => {
      const motion = new FoldMotionModel(); motion.accept([100], 100); motion.accept([90], 120);
      motion.advance(136);
      expect(motion.radius > 0).assertTrue();
      for (let time = 152; time <= 584; time += 16) { motion.advance(time); }
      expect(motion.radius).assertEqual(FoldMotionModel.maximumRadius);
      expect(motion.needsFrame(584)).assertFalse();
      expect(motion.advance(10000)).assertEqual(FoldMotionModel.maximumRadius);
      motion.accept([140], 10020);
      expect(motion.radius).assertEqual(FoldMotionModel.maximumRadius);
      expect(motion.advance(10036) < FoldMotionModel.maximumRadius).assertTrue();
    });
    it('ignores jitter and invalid events without discarding a held angle', 0, (): void => {
      const motion = new FoldMotionModel(); motion.accept([100], 100); motion.accept([90], 120);
      motion.advance(136);
      expect(motion.accept([NaN], 200)).assertFalse();
      expect(motion.accept([-1], 200)).assertFalse();
      expect(motion.accept([181], 200)).assertFalse();
      expect(motion.accept([], 200)).assertFalse();
      expect(motion.accept([90.2], 300)).assertFalse();
      expect(motion.accept([89.8], 500)).assertFalse();
      for (let time = 152; time <= 700; time += 16) { motion.advance(time); }
      expect(motion.radius).assertEqual(FoldMotionModel.maximumRadius);
      expect(motion.needsFrame(700)).assertFalse();
    });
    it('keeps reversal continuous and settles at the endpoint', 0, (): void => {
      const motion = new FoldMotionModel(); motion.accept([180], 100); motion.accept([110], 180);
      const before = motion.advance(196);
      motion.accept([125], 210);
      expect(motion.radius).assertEqual(before);
      expect(motion.advance(226) > 0).assertTrue();
      motion.accept([180], 300);
      for (let time = 316; time <= 1100; time += 16) { motion.advance(time); }
      expect(motion.radius).assertEqual(0);
    });
    it('uses the moving hinge instead of averaging opposite movements', 0, (): void => {
      const motion = new FoldMotionModel(); motion.accept([90, 90], 100);
      motion.accept([95, 65], 120); motion.advance(136);
      expect(motion.hinge).assertEqual(1);
      expect(motion.radius > 0).assertTrue();
    });
    it('bridges a recent display handoff but ignores ordinary later resizes', 0, (): void => {
      const motion = new FoldMotionModel(); motion.accept([170], 100); motion.accept([150], 120);
      expect(motion.handoff(350)).assertTrue();
      expect(motion.advance(366) > 0).assertTrue();
      expect(motion.handoff(1200)).assertFalse();
      const held = motion.radius;
      expect(motion.advance(1200) >= held).assertTrue();
    });
    it('discards old angle and blur state when the host disables or detaches the effect', 0, (): void => {
      const motion = new FoldMotionModel(); motion.accept([170], 100); motion.accept([90], 120);
      motion.advance(136); motion.reset();
      expect(motion.radius).assertEqual(0);
      expect(motion.needsFrame(150)).assertFalse();
      expect(motion.accept([40], 200)).assertFalse();
      expect(motion.advance(216)).assertEqual(0);
    });
    it('rotates the gradient together with either physical crease orientation', 0, (): void => {
      expect(FoldMotionModel.gradientQuarterTurns(false, 0)).assertEqual(0);
      expect(FoldMotionModel.gradientQuarterTurns(false, 1)).assertEqual(1);
      expect(FoldMotionModel.gradientQuarterTurns(false, 3)).assertEqual(3);
      expect(FoldMotionModel.gradientQuarterTurns(true, 1)).assertEqual(2);
      expect(FoldMotionModel.gradientQuarterTurns(true, 3)).assertEqual(0);
    });
  });
}
