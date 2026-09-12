import { describe, expect, it } from '@ohos/hypium';
import { FoldMotionGeometry } from '../main/ets/FoldMotionGeometry';

export default function foldMotionGeometryTest(): void {
  describe('FoldMotionGeometry', (): void => {
    it('leaves the stable region unchanged and transparent in all orientations', 0, (): void => {
      for (let turn: number = 0; turn < 4; turn += 1) {
        for (let panel: number = 0; panel < 2; panel += 1) {
          const cover: boolean = panel === 1;
          const mesh = FoldMotionGeometry.build(1200, 1800, turn, cover, 1, 1);
          for (let row: number = 0; row <= FoldMotionGeometry.rows; row += 1) {
            for (let col: number = 0; col <= FoldMotionGeometry.columns; col += 1) {
              const x: number = col / FoldMotionGeometry.columns; const y: number = row / FoldMotionGeometry.rows;
              const u: number = turn === 0 ? x : turn === 1 ? y : turn === 2 ? 1 - x : 1 - y;
              const index: number = row * (FoldMotionGeometry.columns + 1) + col;
              expect(mesh.vertices[index * 2] >= 0 && mesh.vertices[index * 2] <= 1200).assertTrue();
              expect(mesh.vertices[index * 2 + 1] >= 0 && mesh.vertices[index * 2 + 1] <= 1800).assertTrue();
              if (col === 0 || col === FoldMotionGeometry.columns) {
                expect(mesh.vertices[index * 2]).assertEqual(x * 1200);
              }
              if (row === 0 || row === FoldMotionGeometry.rows) {
                expect(mesh.vertices[index * 2 + 1]).assertEqual(y * 1800);
              }
              if (u >= FoldMotionGeometry.span(cover) - 0.16) {
                expect(Math.abs(mesh.vertices[index * 2] - x * 1200) < 0.00001).assertTrue();
                expect(Math.abs(mesh.vertices[index * 2 + 1] - y * 1800) < 0.00001).assertTrue();
              }
              if (u >= FoldMotionGeometry.span(cover)) {
                expect(mesh.colors[index] >>> 24).assertEqual(0);
              }
            }
          }
        }
      }
    });
    it('is invisible at rest and contracts toward the stable boundary without inverted cells', 0, (): void => {
      const flat = FoldMotionGeometry.build(1200, 1800, 0, false, 0, 1);
      expect(flat.colors.every((color: number): boolean => (color >>> 24) === 0)).assertTrue();
      const mesh = FoldMotionGeometry.build(1200, 1800, 0, false, 1, 1);
      expect(mesh.vertices[0]).assertEqual(0);
      expect(mesh.vertices[2] > 1200 / FoldMotionGeometry.columns).assertTrue();
      for (let row: number = 0; row <= FoldMotionGeometry.rows; row += 1) {
        for (let col: number = 1; col <= FoldMotionGeometry.columns; col += 1) {
          const index: number = (row * (FoldMotionGeometry.columns + 1) + col) * 2;
          expect(mesh.vertices[index] > mesh.vertices[index - 2]).assertTrue();
        }
      }
      const invalid = FoldMotionGeometry.build(1200, 1800, 0, false, NaN, 1);
      expect(invalid.colors.every((color: number): boolean => (color >>> 24) === 0)).assertTrue();
    });
  });
}
