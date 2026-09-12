import { FoldMotionModel } from './FoldMotionModel';

export interface FoldMotionDisplayFrame {
  id: number;
  mode: number;
  width: number;
  height: number;
  rotation: number;
}

export interface FoldMotionCrease {
  displayId: number;
  left: number;
  top: number;
  width: number;
  height: number;
}

interface DirectionBasis {
  key: string;
  rotation: number;
  turn: number;
  axis: number | undefined;
}

interface PanelRole {
  key: string;
  cover: boolean;
}

/** Keep rotations relative to the native coordinate system of each panel. */
export class FoldMotionDirectionModel {
  private bases: DirectionBasis[] = [];
  private panels: PanelRole[] = [];
  private turn: number = 0;
  private cover: boolean = false;
  private visualTurn: number = 0;

  isCover(): boolean { return this.cover; }

  reset(): void {
    this.bases = []; this.panels = []; this.turn = this.visualTurn = 0; this.cover = false;
  }

  resolveForDisplay(frame: FoldMotionDisplayFrame, crease: FoldMotionCrease | undefined): number {
    if (!this.validFrame(frame)) { return this.visualTurn; }
    const turn: number = this.resolve(frame, crease);
    // Panel identity must not change when its rotation or mode notification
    // arrives before its new bounds. Keep the role with the physical size.
    const key: string = `${frame.id}:${Math.min(frame.width, frame.height)}x${Math.max(frame.width, frame.height)}`;
    const panel: PanelRole | undefined = this.panels.find((item: PanelRole): boolean => item.key === key);
    if (panel !== undefined) {
      this.cover = panel.cover;
    } else {
      const rotated: boolean = frame.rotation % 2 !== 0;
      const axis: number | undefined = this.creaseAxis(frame.id,
        rotated ? frame.height : frame.width, rotated ? frame.width : frame.height, crease);
      // MAIN (2) is the cover on book-style devices, but the inner panel on
      // clamshells. A crease belonging to the active panel identifies the latter.
      // SUB (3) is the clamshell cover. Unknown/transitional data keeps its role.
      if (frame.mode === 3 || axis !== undefined || frame.mode === 2) {
        this.cover = frame.mode === 3 || (frame.mode === 2 && axis === undefined);
        this.panels.push({ key, cover: this.cover });
        if (this.panels.length > 16) { this.panels.shift(); }
      }
    }
    this.visualTurn = (turn + (this.cover ? 2 : 0)) % 4;
    return this.visualTurn;
  }

  resolve(frame: FoldMotionDisplayFrame, crease: FoldMotionCrease | undefined): number {
    if (!this.validFrame(frame)) { return this.turn; }
    const rotated: boolean = frame.rotation % 2 !== 0;
    const width: number = rotated ? frame.height : frame.width;
    const height: number = rotated ? frame.width : frame.height;
    // A display ID may be reused by the inner and cover panels. Including the
    // native size also separates intermediate snapshots during a handoff.
    const key: string = `${frame.id}:${frame.mode}:${width}x${height}`;
    const axis: number | undefined = this.creaseAxis(frame.id, width, height, crease);
    let basis: DirectionBasis | undefined = this.bases.find((item: DirectionBasis): boolean => item.key === key);
    if (basis === undefined) {
      if (this.bases.length === 0) {
        this.turn = FoldMotionModel.gradientQuarterTurns(axis === 1, frame.rotation);
      }
      // Changing coordinate systems does not mean the user rotated the device.
      // Calibrate the incoming panel to the outgoing visual direction.
      basis = { key, rotation: frame.rotation, turn: this.turn, axis };
      this.bases.push(basis);
      if (this.bases.length > 16) { this.bases.shift(); }
    } else {
      const axisDelta: number = axis !== undefined && basis.axis !== undefined ? axis - basis.axis : 0;
      this.turn = (basis.turn + frame.rotation - basis.rotation + axisDelta + 8) % 4;
      basis.rotation = frame.rotation;
      basis.turn = this.turn;
      if (axis !== undefined) { basis.axis = axis; }
    }
    return this.turn;
  }

  private validFrame(frame: FoldMotionDisplayFrame): boolean {
    return Number.isFinite(frame.width) && Number.isFinite(frame.height) &&
      frame.width > 0 && frame.height > 0 && Number.isInteger(frame.rotation) &&
      frame.rotation >= 0 && frame.rotation <= 3;
  }

  private creaseAxis(id: number, width: number, height: number,
    crease: FoldMotionCrease | undefined): number | undefined {
    if (crease === undefined || crease.displayId !== id ||
      ![crease.left, crease.top, crease.width, crease.height].every((value: number): boolean => Number.isFinite(value)) ||
      crease.left < 0 || crease.top < 0 || crease.width <= 0 || crease.height <= 0 ||
      crease.width === crease.height || crease.left + crease.width > width ||
      crease.top + crease.height > height) { return undefined; }
    return crease.width > crease.height ? 1 : 0;
  }
}
