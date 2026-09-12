import { image } from '@kit.ImageKit';

/** One in-flight capture and one retained texture per scope. No disk storage or idle polling. */
export class FoldMotionCapture {
  onImage: (map: image.PixelMap | undefined) => void = (): void => {};
  private current: image.PixelMap | undefined = undefined;
  private pending: boolean = false;
  private generation: number = 0;
  private lastRequest: number = -Infinity;
  private queued: (() => Promise<image.PixelMap>) | undefined = undefined;
  private queuedAt: number = 0;

  request(capture: () => Promise<image.PixelMap>, now: number): void {
    if (now - this.lastRequest < 160) { return; }
    if (this.pending) { this.queued = capture; this.queuedAt = now; return; }
    this.pending = true; this.lastRequest = now;
    const generation: number = this.generation;
    this.read(capture, generation);
  }

  clear(): void {
    this.generation += 1; this.lastRequest = -Infinity;
    this.queued = undefined;
    const old: image.PixelMap | undefined = this.current;
    this.current = undefined; this.onImage(undefined);
    this.release(old);
  }

  private release(map: image.PixelMap | undefined): void {
    if (map !== undefined) { map.release().catch((): void => {}); }
  }

  private async read(capture: () => Promise<image.PixelMap>, generation: number): Promise<void> {
    try {
      const map: image.PixelMap = await capture();
      if (generation !== this.generation) { this.release(map); return; }
      const old: image.PixelMap | undefined = this.current;
      this.current = map; this.onImage(map); this.release(old);
    } catch (_error) {
      if (generation === this.generation) {
        const old: image.PixelMap | undefined = this.current;
        this.current = undefined; this.onImage(undefined); this.release(old);
      }
    } finally {
      this.pending = false;
      const next: (() => Promise<image.PixelMap>) | undefined = this.queued;
      this.queued = undefined;
      if (next !== undefined) { this.request(next, this.queuedAt); }
    }
  }
}
