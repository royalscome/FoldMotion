import { FoldMotionController } from './FoldMotionController';
import { FoldMotionModel } from './FoldMotionModel';

/** A content-sized scope: wrap a whole page or just one component. */
@Component
export struct FoldMotion {
  @BuilderParam content: () => void;
  @Prop @Watch('synchronize') effectEnabled: boolean = true;
  @Prop @Watch('synchronize') maxBlurRadius: number = 28;
  @Prop blurDirection: GradientDirection | undefined = undefined;
  @Prop fractionStops: FractionStop[] = [[1, 0], [0.95, 0.28], [0.28, 0.52], [0, 0.72], [0, 1]];
  @State private radius: number = 0;
  @State private physicalDirection: GradientDirection = GradientDirection.Right;
  private visible: boolean = true;
  private readonly controller: FoldMotionController = new FoldMotionController();

  aboutToAppear(): void {
    this.controller.onFrame = (radius: number, direction: GradientDirection): void => {
      this.radius = radius; this.physicalDirection = direction;
    };
    this.controller.start(this.getUIContext(), this.isEnabled());
  }

  aboutToDisappear(): void { this.controller.close(); }

  private isEnabled(): boolean {
    return this.effectEnabled && this.visible && Number.isFinite(this.maxBlurRadius) && this.maxBlurRadius > 0;
  }

  private synchronize(): void { this.controller.setEnabled(this.isEnabled()); }

  private blurRadius(): number | undefined {
    if (!this.isEnabled() || this.radius <= 0) { return undefined; }
    return this.radius / FoldMotionModel.maximumRadius * Math.min(64, this.maxBlurRadius);
  }

  build() {
    Stack() {
      this.content()
    }
    .linearGradientBlur(this.blurRadius(), {
      fractionStops: this.fractionStops,
      direction: this.blurDirection ?? this.physicalDirection
    })
    .onVisibleAreaChange([0], (visible: boolean): void => {
      this.visible = visible; this.synchronize();
    })
  }
}
