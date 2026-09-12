import { image } from '@kit.ImageKit';
import { systemDateTime } from '@kit.BasicServicesKit';
import { FoldMotionController } from './FoldMotionController';
import { FoldMotionModel, FoldMotionState } from './FoldMotionModel';
import { FoldMotionGeometry } from './FoldMotionGeometry';
import { FoldMotionCapture } from './FoldMotionCapture';
import { FoldMotionSurface } from './FoldMotionSurface';

/** A live content scope with independent blur, shade and local perspective channels. */
@Component
export struct FoldMotion {
  @BuilderParam content: () => void;
  @Prop @Watch('synchronize') effectEnabled: boolean = true;
  @Prop @Watch('synchronize') maxBlurRadius: number = 42;
  @Prop @Watch('synchronize') maxShadeOpacity: number = 0.72;
  @Prop @Watch('synchronize') perspectiveStrength: number = 1;
  @Prop @Watch('synchronize') blurDirection: GradientDirection | undefined = undefined;
  @Prop fractionStops: FractionStop[] | undefined = undefined;
  @Prop @Watch('invalidateContent') contentRevision: number = 0;
  // An optional external angle source, also useful for previewing on non-foldable devices.
  @Prop @Watch('synchronize') manualAngle: number | undefined = undefined;
  @Prop @Watch('synchronize') manualCover: boolean = false;
  @State private radius: number = 0;
  @State private shade: number = 0;
  @State private cover: boolean = false;
  @State private physicalDirection: GradientDirection = GradientDirection.Right;
  private visible: boolean = true;
  private attached: boolean = false;
  private touching: boolean = false;
  private sample: number = -1;
  private contentWidth: number = 0;
  private contentHeight: number = 0;
  private depth: number = 0;
  private renderedTurn: number = 0;
  private readonly sourceId: string = `fold-motion-content-${this.getUniqueId()}`;
  private readonly controller: FoldMotionController = new FoldMotionController();
  private readonly capture: FoldMotionCapture = new FoldMotionCapture();
  private readonly surface: FoldMotionSurface = new FoldMotionSurface();

  aboutToAppear(): void {
    this.attached = true; this.visible = true; this.touching = false; this.sample = -1;
    this.apply(FoldMotionModel.profile(180, false), GradientDirection.Right);
    this.capture.onImage = (map: image.PixelMap | undefined): void => { this.surface.setImage(map); };
    this.controller.onVisualFrame = (state: FoldMotionState, direction: GradientDirection): void => {
      this.apply(state, direction);
    };
    this.controller.setManualAngle(this.manualAngle, this.manualCover);
    this.controller.start(this.getUIContext(), this.isEnabled());
    this.synchronize();
  }

  aboutToDisappear(): void {
    this.attached = false; this.controller.close(); this.capture.clear(); this.surface.close();
  }

  private isEnabled(): boolean {
    return this.effectEnabled && this.visible && Number.isFinite(this.maxBlurRadius) && this.maxBlurRadius > 0;
  }

  private synchronize(): void {
    if (!this.attached) { return; }
    const enabled: boolean = this.isEnabled();
    this.controller.setEnabled(enabled);
    this.controller.setManualAngle(this.manualAngle, this.manualCover);
    if (!enabled) {
      this.apply(FoldMotionModel.profile(180, false), this.physicalDirection);
    } else {
      if (this.renderedTurn !== this.turn() || this.strength() === 0) { this.capture.clear(); }
      this.renderedTurn = this.turn();
      this.surface.update(this.renderedTurn, this.cover, this.depth, this.strength());
      this.requestCapture();
    }
  }

  private gradientDirection(): GradientDirection { return this.blurDirection ?? this.physicalDirection; }

  private turn(): number {
    const direction: GradientDirection = this.gradientDirection();
    return direction === GradientDirection.Bottom ? 1 : direction === GradientDirection.Left ? 2 :
      direction === GradientDirection.Top ? 3 : 0;
  }

  private strength(): number {
    return Number.isFinite(this.perspectiveStrength) ? Math.max(0, Math.min(1, this.perspectiveStrength)) : 0;
  }

  private apply(state: FoldMotionState, direction: GradientDirection): void {
    if (!this.attached) { return; }
    const changedPanel: boolean = this.cover !== state.cover || this.physicalDirection !== direction;
    if (changedPanel) { this.capture.clear(); }
    const moved: boolean = state.sample !== this.sample;
    this.sample = state.sample; this.cover = state.cover; this.physicalDirection = direction;
    this.radius = state.radius; this.shade = state.shade; this.depth = state.depth;
    this.renderedTurn = this.turn();
    this.surface.update(this.renderedTurn, this.cover, this.depth, this.strength());
    if (this.radius <= 0 || this.depth <= 0 || this.strength() === 0) { this.capture.clear(); return; }
    if (moved || changedPanel) { this.requestCapture(); }
  }

  private requestCapture(): void {
    if (!this.attached || !this.isEnabled() || this.contentWidth <= 0 || this.contentHeight <= 0 ||
      this.depth <= 0 || this.strength() === 0 || this.touching) { return; }
    // Bound full-screen textures to ~1.5 MP, also on expanded displays.
    const pixels: number = this.getUIContext().vp2px(this.contentWidth) * this.getUIContext().vp2px(this.contentHeight);
    const scale: number = Math.min(1, Math.sqrt(1500000 / Math.max(1, pixels)));
    this.capture.request((): Promise<image.PixelMap> => this.getUIContext().getComponentSnapshot().get(
      this.sourceId, { scale, waitUntilRenderFinished: true }),
      systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false));
  }

  private invalidateContent(): void {
    this.capture.clear(); this.requestCapture();
  }

  private blurRadius(): number | undefined {
    return this.isEnabled() && this.radius > 0 ?
      this.radius / FoldMotionModel.maximumRadius * Math.min(64, this.maxBlurRadius) : undefined;
  }

  private stops(): FractionStop[] {
    if (this.fractionStops !== undefined) { return this.fractionStops; }
    const span: number = FoldMotionGeometry.span(this.cover);
    return [[1, 0], [0.98, span * 0.72], [0.38, span * 0.88], [0, span], [0, 1]];
  }

  private shadeOpacity(): number {
    return this.isEnabled() && Number.isFinite(this.maxShadeOpacity) ?
      this.shade * Math.max(0, Math.min(0.85, this.maxShadeOpacity)) * (this.cover ? 1 : 0.85) : 0;
  }

  build() {
    Stack() {
      Stack() {
        Stack() { this.content() }.id(this.sourceId)
      }
      .linearGradientBlur(this.blurRadius(), { fractionStops: this.stops(), direction: this.gradientDirection() })
      NodeContainer(this.surface)
        .width('100%').height('100%').position({ x: 0, y: 0 })
        .linearGradientBlur(this.blurRadius(), { fractionStops: this.stops(), direction: this.gradientDirection() })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
      Stack() {}.width('100%').height('100%').position({ x: 0, y: 0 })
        .linearGradient({ direction: this.gradientDirection(), colors: [
          [Color.Black, 0], ['#B3000000', FoldMotionGeometry.span(this.cover) * 0.25],
          ['#4D000000', FoldMotionGeometry.span(this.cover) * 0.65],
          [Color.Transparent, FoldMotionGeometry.span(this.cover)], [Color.Transparent, 1]
        ] })
        .opacity(this.shadeOpacity()).hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
    }
    .onAreaChange((_old: Area, area: Area): void => {
      const width: number = Number(area.width); const height: number = Number(area.height);
      if (width !== this.contentWidth || height !== this.contentHeight) {
        this.contentWidth = width; this.contentHeight = height; this.capture.clear(); this.requestCapture();
      }
    })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.touching = true; this.capture.clear();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.touching = false; }
    })
    .onVisibleAreaChange([0], (visible: boolean): void => {
      this.visible = visible; this.synchronize();
    })
  }
}
