import { FoldMotionModel } from './FoldMotionModel';

export interface FoldMotionMesh { vertices: number[]; colors: number[]; }

/** A feathered, bounded mesh; the stable part is both undeformed and transparent. */
export class FoldMotionGeometry {
  static readonly columns: number = 24;
  static readonly rows: number = 12;

  static span(cover: boolean): number { return cover ? 0.94 : 0.58; }

  static weight(position: number, span: number): number {
    return 1 - FoldMotionModel.smooth(Math.max(0, span - 0.16), span, position);
  }

  static build(width: number, height: number, turn: number, cover: boolean,
    depth: number, strength: number): FoldMotionMesh {
    const mesh: FoldMotionMesh = { vertices: [], colors: [] };
    const span: number = FoldMotionGeometry.span(cover);
    const warpSpan: number = span - 0.16;
    const amount: number = Number.isFinite(depth) && Number.isFinite(strength) ?
      Math.max(0, Math.min(1, depth)) * Math.max(0, Math.min(1, strength)) : 0;
    for (let row: number = 0; row <= FoldMotionGeometry.rows; row += 1) {
      for (let column: number = 0; column <= FoldMotionGeometry.columns; column += 1) {
        const x: number = column / FoldMotionGeometry.columns; const y: number = row / FoldMotionGeometry.rows;
        const u: number = turn === 0 ? x : turn === 1 ? y : turn === 2 ? 1 - x : 1 - y;
        const v: number = turn % 2 === 0 ? y : x;
        const weight: number = FoldMotionGeometry.weight(u, span);
        const distance: number = Math.max(0, 1 - u / warpSpan);
        // Pin the perimeter so compression cannot expose a second copy underneath.
        // Finish deformation before alpha feathering to avoid doubled text at the seam.
        const mappedU: number = u + amount * 0.18 * u * distance;
        const mappedV: number = v + (0.5 - v) * amount * 0.1 * distance * 4 * v * (1 - v);
        const px: number = turn === 0 ? mappedU : turn === 2 ? 1 - mappedU : mappedV;
        const py: number = turn === 1 ? mappedU : turn === 3 ? 1 - mappedU : mappedV;
        mesh.vertices.push(px * width, py * height);
        const alpha: number = Math.round(255 * weight * FoldMotionModel.smooth(0, 0.06, amount));
        mesh.colors.push((alpha * 0x1000000 + 0xFFFFFF) >>> 0);
      }
    }
    return mesh;
  }
}
