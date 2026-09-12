import { FoldMotionController } from './FoldMotionController';
import { FoldMotionModel, FoldMotionState } from './FoldMotionModel';

/** Angle-bound filters on live content. The scope never transforms or snapshots its children. */
@Component
export struct FoldMotion {
  @BuilderParam content: () => void;
  @Prop @Watch('synchronize') effectEnabled: boolean = true;
  @Prop @Watch('synchronize') maxBlurRadius: number = 42;
  @Prop maxShadeOpacity: number = 0.72;
  @Prop blurDirection: GradientDirection | undefined = undefined;
  @Prop fractionStops: FractionStop[] | undefined = undefined;
  /** @deprecated Accepted for source compatibility; content always remains flat. */
  @Prop perspectiveStrength: number = 0;
  /** @deprecated Live content needs no snapshot invalidation. */
  @Prop contentRevision: number = 0;
  @Prop @Watch('synchronize') manualAngle: number | undefined = undefined;
  @Prop @Watch('synchronize') manualCover: boolean = false;
  @State private radius: number = 0;
  @State private shade: number = 0;
  @State private cover: boolean = false;
  @State private physicalDirection: GradientDirection = GradientDirection.Right;
  private visible: boolean = true;
  private attached: boolean = false;
  private readonly controller: FoldMotionController = new FoldMotionController();

  aboutToAppear(): void {
    this.attached = true;
    this.visible = true;
    this.apply(FoldMotionModel.profile(180, false), GradientDirection.Right);
    this.controller.onVisualFrame = (state: FoldMotionState, direction: GradientDirection): void => {
      this.apply(state, direction);
    };
    this.controller.setManualAngle(this.manualAngle, this.manualCover);
    this.controller.start(this.getUIContext(), this.isEnabled());
  }

  aboutToDisappear(): void {
    this.attached = false;
    this.controller.close();
  }

  private isEnabled(): boolean {
    return this.effectEnabled && this.visible && Number.isFinite(this.maxBlurRadius) && this.maxBlurRadius > 0;
  }

  private synchronize(): void {
    if (!this.attached) { return; }
    this.controller.setEnabled(this.isEnabled());
    this.controller.setManualAngle(this.manualAngle, this.manualCover);
  }

  private gradientDirection(): GradientDirection { return this.blurDirection ?? this.physicalDirection; }

  private apply(state: FoldMotionState, direction: GradientDirection): void {
    if (!this.attached) { return; }
    this.radius = state.radius;
    this.shade = state.shade;
    this.cover = state.cover;
    this.physicalDirection = direction;
  }

  private blurRadius(): number | undefined {
    return this.isEnabled() && this.radius > 0 ?
      this.radius / FoldMotionModel.maximumRadius * Math.min(64, this.maxBlurRadius) : undefined;
  }

  private span(): number { return FoldMotionModel.blurSpan(this.radius, this.cover); }

  private stops(): FractionStop[] {
    if (this.fractionStops !== undefined) { return this.fractionStops; }
    const span: number = this.span();
    return [[1, 0], [0.98, span * 0.72], [0.38, span * 0.88], [0, span], [0, 1]];
  }

  private shadeOpacity(): number {
    return this.isEnabled() && Number.isFinite(this.maxShadeOpacity) ?
      this.shade * Math.max(0, Math.min(0.85, this.maxShadeOpacity)) * (this.cover ? 1 : 0.85) : 0;
  }

  build() {
    Stack() {
      Stack() { this.content() }
        .linearGradientBlur(this.blurRadius(), { fractionStops: this.stops(), direction: this.gradientDirection() })
      Stack() {}.width('100%').height('100%').position({ x: 0, y: 0 })
        .linearGradient({ direction: this.gradientDirection(), colors: [
          [Color.Black, 0], ['#B3000000', this.span() * 0.25],
          ['#4D000000', this.span() * 0.65], [Color.Transparent, this.span()], [Color.Transparent, 1]
        ] })
        .opacity(this.shadeOpacity()).hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
    }
    .onVisibleAreaChange([0], (visible: boolean): void => {
      this.visible = visible;
      this.synchronize();
    })
  }
}
