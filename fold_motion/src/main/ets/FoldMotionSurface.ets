import { DrawContext, FrameNode, NodeController, RenderNode, UIContext, Size } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { drawing } from '@kit.ArkGraphics2D';
import { FoldMotionGeometry } from './FoldMotionGeometry';

class FoldMotionRenderNode extends RenderNode {
  private readonly brush: drawing.Brush = new drawing.Brush();
  map: image.PixelMap | undefined = undefined;
  turn: number = 0;
  cover: boolean = false;
  depth: number = 0;
  strength: number = 1;

  draw(context: DrawContext): void {
    if (this.map === undefined || this.depth <= 0 || this.strength <= 0) { return; }
    const size: Size = context.sizeInPixel;
    if (size.width <= 0 || size.height <= 0) { return; }
    const mesh = FoldMotionGeometry.build(size.width, size.height, this.turn, this.cover, this.depth, this.strength);
    try {
      context.canvas.attachBrush(this.brush);
      context.canvas.drawPixelMapMesh(this.map, FoldMotionGeometry.columns, FoldMotionGeometry.rows,
        mesh.vertices, 0, mesh.colors, 0);
    } catch (_error) {
      // An unavailable drawing surface must leave the live blur and shade usable.
      this.map = undefined;
    } finally { context.canvas.detachBrush(); }
  }
}

/** Overlay only: never reparent, duplicate or resize the application's live content. */
export class FoldMotionSurface extends NodeController {
  private node: FoldMotionRenderNode = new FoldMotionRenderNode();
  private frame: FrameNode | undefined = undefined;

  makeNode(context: UIContext): FrameNode | null {
    try {
      this.ensureNode();
      this.frame = new FrameNode(context);
      this.frame.commonAttribute.width('100%').height('100%').hitTestBehavior(HitTestMode.None);
      this.node.clipToFrame = true;
      this.frame.getRenderNode()?.appendChild(this.node);
      return this.frame;
    } catch (_error) { return null; }
  }

  private ensureNode(): void {
    if (this.node.isDisposed()) { this.node = new FoldMotionRenderNode(); }
  }

  aboutToResize(size: Size): void {
    if (!this.node.isDisposed()) { this.node.size = size; this.node.invalidate(); }
  }

  setImage(map: image.PixelMap | undefined): void {
    if (map !== undefined) { this.ensureNode(); }
    this.node.map = map;
    if (!this.node.isDisposed()) { this.node.invalidate(); }
  }

  update(turn: number, cover: boolean, depth: number, strength: number): void {
    this.ensureNode();
    this.node.turn = turn; this.node.cover = cover; this.node.depth = depth;
    this.node.strength = strength;
    if (!this.node.isDisposed()) { this.node.invalidate(); }
  }

  close(): void {
    this.node.map = undefined;
    this.frame?.dispose(); this.frame = undefined;
    this.node.dispose();
  }
}
