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
      motion.accept([170], 10020);
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
    it('starts softly and stages blur before shade at both visible endpoints', 0, (): void => {
      const inner = FoldMotionModel.profile(170, false);
      const cover = FoldMotionModel.profile(10, true);
      expect(inner.radius > 0 && inner.radius < 2).assertTrue();
      expect(inner.shade).assertEqual(0);
      expect(inner.depth > 0 && inner.depth < 0.05).assertTrue();
      expect(cover.radius > 0 && cover.shade < 0.03 && cover.depth < 0.04).assertTrue();
      expect(FoldMotionModel.profile(120, false).radius).assertEqual(FoldMotionModel.maximumRadius);
      expect(FoldMotionModel.profile(150, false).shade < 0.2).assertTrue();
      expect(FoldMotionModel.profile(90, false).shade).assertEqual(1);
      expect(FoldMotionModel.profile(NaN, false).radius).assertEqual(0);
    });
    it('keeps all cover channels changing from handoff through the remaining closure', 0, (): void => {
      let previous = FoldMotionModel.profile(70, true);
      for (const angle of [60, 50, 40, 30, 20, 10, 2]) {
        const next = FoldMotionModel.profile(angle, true);
        expect(next.radius < previous.radius).assertTrue();
        expect(next.shade < previous.shade).assertTrue();
        expect(next.depth < previous.depth).assertTrue();
        previous = next;
      }
      expect(previous.radius + previous.shade + previous.depth).assertEqual(0);
    });
    it('holds all channels without idle frames and clears every endpoint and reset', 0, (): void => {
      const model = new FoldMotionModel(); model.accept([180], 100); model.accept([100], 120);
      for (let time = 136; time < 1200; time += 16) { model.advance(time); }
      const held = model.state();
      expect(held.radius > 0 && held.shade > 0 && held.depth > 0).assertTrue();
      expect(model.needsFrame(1200)).assertFalse();
      model.advance(10000);
      expect(model.shade).assertEqual(held.shade); expect(model.depth).assertEqual(held.depth);
      model.accept([180], 10020);
      for (let time = 10036; time < 11500; time += 16) { model.advance(time); }
      expect(model.radius + model.shade + model.depth).assertEqual(0);
      model.reset(); expect(model.state().sample).assertEqual(0);
    });
    it('retargets panel channels continuously during a display handoff', 0, (): void => {
      const model = new FoldMotionModel(); model.accept([180], 100); model.accept([60], 120);
      for (let time = 136; time < 1200; time += 16) { model.advance(time); }
      const shade = model.shade; const radius = model.radius;
      model.setCover(true);
      expect(model.shade).assertEqual(shade); expect(model.radius).assertEqual(radius);
      model.advance(1216);
      expect(model.shade < shade && model.shade > 0).assertTrue();
      expect(model.state().cover).assertTrue();
      model.reset(); model.setCover(false);
      expect(model.radius + model.shade + model.depth).assertEqual(0);
    });
    it('settles an active transition after hinge count or clock baseline changes', 0, (): void => {
      const model = new FoldMotionModel(); model.accept([180, 180], 100);
      model.accept([180, 100], 120); model.advance(136);
      expect(model.depth > 0).assertTrue();
      expect(model.accept([180], 150)).assertTrue();
      expect(model.hinge).assertEqual(0);
      for (let time = 166; time < 1200; time += 16) { model.advance(time); }
      expect(model.radius + model.shade + model.depth).assertEqual(0);
      model.accept([90], 1300); model.advance(1316);
      expect(model.accept([180], 100)).assertTrue();
      for (let time = 116; time < 1200; time += 16) { model.advance(time); }
      expect(model.radius + model.shade + model.depth).assertEqual(0);
      expect(model.needsFrame(1200)).assertFalse();
    });
    it('uses the same visual state for fast and slow motion without timed convergence', 0, (): void => {
      const fast = new FoldMotionModel(); const slow = new FoldMotionModel();
      fast.accept([180], 100); slow.accept([180], 100);
      fast.accept([145], 110); slow.accept([145], 5000);
      fast.advance(111); slow.advance(10000);
      const target = FoldMotionModel.profile(145, false);
      expect(fast.radius).assertEqual(target.radius);
      expect(fast.shade).assertEqual(target.shade);
      expect(fast.radius).assertEqual(slow.radius);
      expect(fast.shade).assertEqual(slow.shade);
      expect(fast.needsFrame(112)).assertFalse();
      expect(slow.needsFrame(10001)).assertFalse();
      expect(fast.advance(50000)).assertEqual(target.radius);
    });
    it('clears fast reopening on its first frame and never replays intermediate angles', 0, (): void => {
      const model = new FoldMotionModel(); model.accept([180], 100);
      model.accept([70], 116); model.advance(117); model.setCover(true);
      model.advance(118); expect(model.radius > 0).assertTrue();
      model.accept([10], 120); model.setCover(false);
      model.accept([95], 125); model.accept([179], 130);
      model.advance(131);
      expect(model.radius + model.shade + model.depth).assertEqual(0);
      expect(model.needsFrame(132)).assertFalse();
      expect(model.advance(5000)).assertEqual(0);
    });
    it('never filters out a terminal sample that falls within the jitter tolerance', 0, (): void => {
      const inner = new FoldMotionModel(); inner.accept([170], 100);
      inner.accept([177.9], 110); inner.advance(111);
      expect(inner.radius > 0).assertTrue();
      expect(inner.accept([178.1], 120)).assertTrue();
      inner.advance(121); expect(inner.radius + inner.shade + inner.depth).assertEqual(0);
      const cover = new FoldMotionModel(); cover.setCover(true); cover.accept([10], 100);
      cover.accept([2.1], 110); cover.advance(111);
      expect(cover.radius > 0).assertTrue();
      expect(cover.accept([1.9], 120)).assertTrue();
      cover.advance(121); expect(cover.radius + cover.shade + cover.depth).assertEqual(0);
    });
    it('reveals most of the cover well before closure instead of keeping a full-page blur', 0, (): void => {
      const start = FoldMotionModel.profile(70, true);
      const middle = FoldMotionModel.profile(40, true);
      const end = FoldMotionModel.profile(20, true);
      expect(FoldMotionModel.blurSpan(start.radius, true) > 0.85).assertTrue();
      expect(FoldMotionModel.blurSpan(middle.radius, true) < 0.5).assertTrue();
      expect(FoldMotionModel.blurSpan(end.radius, true) < 0.25).assertTrue();
      expect(middle.radius < start.radius * 0.4).assertTrue();
      expect(end.radius < FoldMotionModel.maximumRadius * 0.07).assertTrue();
      expect(FoldMotionModel.blurSpan(0, true)).assertEqual(0);
      expect(FoldMotionModel.blurSpan(NaN, true)).assertEqual(0);
      expect(FoldMotionModel.blurSpan(start.radius, false)).assertEqual(0.58);
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
