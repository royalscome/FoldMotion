import { describe, expect, it } from '@ohos/hypium';
import { FoldMotionCrease, FoldMotionDirectionModel, FoldMotionDisplayFrame } from '../main/ets/FoldMotionDirectionModel';

function innerCrease(): FoldMotionCrease {
  return { displayId: 0, left: 0, top: 1194, width: 1828, height: 196 };
}

function innerFrame(): FoldMotionDisplayFrame {
  return { id: 0, mode: 1, width: 2584, height: 1828, rotation: 3 };
}

export default function foldMotionDirectionModelTest(): void {
  describe('FoldMotionDirectionModel', (): void => {
    it('uses the original inner edge and the reversed cover edge through repeated handoffs', 0, (): void => {
      const model = new FoldMotionDirectionModel();
      const frame = innerFrame();
      expect(model.resolveForDisplay(frame, innerCrease())).assertEqual(0);
      frame.mode = 2; frame.width = 1264; frame.height = 1848; frame.rotation = 0;
      expect(model.resolveForDisplay(frame, innerCrease())).assertEqual(2);
      const orders: number[][] = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]];
      orders.forEach((order: number[]): void => {
        order.forEach((field: number): void => {
          if (field === 0) { frame.rotation = 3; }
          if (field === 1) { frame.width = 2584; frame.height = 1828; }
          if (field === 2) { frame.mode = 1; }
          expect(model.resolveForDisplay(frame, innerCrease())).assertEqual(frame.width === 2584 ? 0 : 2);
        });
        order.forEach((field: number): void => {
          if (field === 0) { frame.rotation = 0; }
          if (field === 1) { frame.width = 1264; frame.height = 1848; }
          if (field === 2) { frame.mode = 2; }
          expect(model.resolveForDisplay(frame, innerCrease())).assertEqual(frame.width === 1264 ? 2 : 0);
        });
      });
    });

    it('starts on the cover with its reversed edge and restores the inner edge after opening', 0, (): void => {
      const model = new FoldMotionDirectionModel();
      expect(model.resolveForDisplay({ id: 0, mode: 2, rotation: 0, width: 1264, height: 1848 }, innerCrease())).assertEqual(2);
      expect(model.resolveForDisplay({ id: 0, mode: 2, rotation: 1, width: 1848, height: 1264 }, innerCrease())).assertEqual(3);
      expect(model.resolveForDisplay({ id: 0, mode: 2, rotation: 0, width: 1264, height: 1848 }, innerCrease())).assertEqual(2);
      expect(model.resolveForDisplay({ id: 0, mode: 1, rotation: NaN, width: 0, height: 0 }, undefined)).assertEqual(2);
      expect(model.resolveForDisplay(innerFrame(), innerCrease())).assertEqual(0);
      model.reset();
      expect(model.resolveForDisplay(innerFrame(), innerCrease())).assertEqual(0);
    });

    it('does not reverse a clamshell inner MAIN panel with a live crease', 0, (): void => {
      const model = new FoldMotionDirectionModel();
      expect(model.resolveForDisplay({ id: 0, mode: 2, rotation: 0, width: 1200, height: 2400 },
        { displayId: 0, left: 0, top: 1190, width: 1200, height: 20 })).assertEqual(1);
      expect(model.resolveForDisplay({ id: 5, mode: 3, rotation: 0, width: 600, height: 800 }, undefined)).assertEqual(3);
      expect(model.resolveForDisplay({ id: 0, mode: 2, rotation: 0, width: 1200, height: 2400 }, undefined)).assertEqual(1);
    });

    it('keeps every ordering of rotation, size and mode notifications continuous', 0, (): void => {
      const orders: number[][] = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]];
      orders.forEach((closing: number[]): void => {
        orders.forEach((opening: number[]): void => {
          const model = new FoldMotionDirectionModel();
          const frame = innerFrame();
          expect(model.resolve(frame, innerCrease())).assertEqual(0);
          for (let cycle = 0; cycle < 2; cycle += 1) {
            closing.forEach((field: number): void => {
              if (field === 0) { frame.rotation = 0; }
              if (field === 1) { frame.width = 1264; frame.height = 1848; }
              if (field === 2) { frame.mode = 2; }
              expect(model.resolve(frame, innerCrease())).assertEqual(0);
            });
            opening.forEach((field: number): void => {
              if (field === 0) { frame.rotation = 3; }
              if (field === 1) { frame.width = 2584; frame.height = 1828; }
              if (field === 2) { frame.mode = 1; }
              expect(model.resolve(frame, innerCrease())).assertEqual(0);
            });
          }
        });
      });
    });

    it('tracks all physical rotations on the cover and when returning to the inner screen', 0, (): void => {
      const model = new FoldMotionDirectionModel();
      model.resolve(innerFrame(), innerCrease());
      for (let rotation = 0; rotation < 4; rotation += 1) {
        const rotated: boolean = rotation % 2 !== 0;
        expect(model.resolve({ id: 0, mode: 2, rotation,
          width: rotated ? 1848 : 1264, height: rotated ? 1264 : 1848 }, innerCrease())).assertEqual(rotation);
        const innerRotation: number = (rotation + 3) % 4;
        expect(model.resolve({ id: 0, mode: 1, rotation: innerRotation,
          width: innerRotation % 2 !== 0 ? 2584 : 1828,
          height: innerRotation % 2 !== 0 ? 1828 : 2584 }, innerCrease())).assertEqual(rotation);
      }
    });

    it('handles real rotations when size and rotation arrive separately', 0, (): void => {
      for (let sizeFirst = 0; sizeFirst < 2; sizeFirst += 1) {
        const model = new FoldMotionDirectionModel();
        model.resolve(innerFrame(), innerCrease());
        model.resolve({ id: 0, mode: 1, rotation: sizeFirst === 1 ? 3 : 0,
          width: sizeFirst === 1 ? 1828 : 2584, height: sizeFirst === 1 ? 2584 : 1828 }, innerCrease());
        expect(model.resolve({ id: 0, mode: 1, rotation: 0, width: 1828, height: 2584 }, innerCrease())).assertEqual(1);
      }
    });

    it('rejects another panel or out-of-bounds crease at a cover-screen cold start', 0, (): void => {
      const cover: FoldMotionDisplayFrame = { id: 0, mode: 2, rotation: 0, width: 1264, height: 1848 };
      const model = new FoldMotionDirectionModel();
      expect(model.resolve(cover, innerCrease())).assertEqual(0);
      model.reset();
      expect(model.resolve(cover, { displayId: 5, left: 0, top: 600, width: 1264, height: 20 })).assertEqual(0);
    });

    it('preserves a horizontal hinge on a separate cover display and across missing crease data', 0, (): void => {
      const model = new FoldMotionDirectionModel();
      expect(model.resolve({ id: 0, mode: 2, rotation: 0, width: 1200, height: 2400 },
        { displayId: 0, left: 0, top: 1190, width: 1200, height: 20 })).assertEqual(1);
      expect(model.resolve({ id: 5, mode: 3, rotation: 0, width: 600, height: 800 }, undefined)).assertEqual(1);
      expect(model.resolve({ id: 5, mode: 3, rotation: 1, width: 800, height: 600 }, undefined)).assertEqual(2);
      expect(model.resolve({ id: 5, mode: 3, rotation: 1, width: 800, height: 600 },
        { displayId: 0, left: 0, top: 100, width: 600, height: 20 })).assertEqual(2);
    });

    it('updates a moving hinge axis without accepting invalid geometry or frames', 0, (): void => {
      const model = new FoldMotionDirectionModel();
      const frame: FoldMotionDisplayFrame = { id: 0, mode: 1, rotation: 0, width: 1200, height: 1800 };
      expect(model.resolve(frame, { displayId: 0, left: 590, top: 0, width: 20, height: 1800 })).assertEqual(0);
      expect(model.resolve(frame, { displayId: 0, left: 0, top: 890, width: 1200, height: 20 })).assertEqual(1);
      expect(model.resolve(frame, { displayId: 0, left: 0, top: 0, width: 0, height: 0 })).assertEqual(1);
      expect(model.resolve({ id: 0, mode: 1, rotation: NaN, width: 1200, height: 1800 }, undefined)).assertEqual(1);
      expect(model.resolve({ id: 0, mode: 1, rotation: 0, width: 0, height: 1800 }, undefined)).assertEqual(1);
      model.reset();
      expect(model.resolve(frame, undefined)).assertEqual(0);
    });
  });
}
