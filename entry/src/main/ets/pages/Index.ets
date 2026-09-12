import { FoldMotion, FoldMotionController, FoldMotionModel, FoldMotionState } from 'fold-motion';

@Entry
@Component
struct Index {
  @State private effectOn: boolean = true;
  @State private strength: number = 42;
  @State private fullPage: boolean = false;
  @State private intensity: number = 0;
  @State private previewOn: boolean = false;
  @State private previewCover: boolean = false;
  @State private previewAngle: number = 150;
  @State private shade: number = 0;
  @State private depth: number = 0;
  private readonly controller: FoldMotionController = new FoldMotionController();

  aboutToAppear(): void {
    this.controller.onVisualFrame = (state: FoldMotionState): void => {
      this.intensity = state.radius / FoldMotionModel.maximumRadius;
      this.shade = state.shade; this.depth = state.depth;
    };
    this.controller.start(this.getUIContext(), this.effectOn);
  }

  aboutToDisappear(): void { this.controller.close(); }

  private previewValue(): number | undefined { return this.previewOn ? this.previewAngle : undefined; }

  private updatePreview(): void {
    this.controller.setManualAngle(this.previewValue(), this.previewCover);
  }

  @Builder
  private card(title: string, subtitle: string, color: string) {
    Column({ space: 16 }) {
      Row() {
        Text('FOLD / MOTION').fontSize(12).fontColor('#FFFFFFB3').letterSpacing(2)
        Blank()
        Text('↗').fontSize(28).fontColor('#FFFFFF')
      }.width('100%')
      Blank().height(24)
      Text(title).fontSize(30).fontWeight(FontWeight.Medium).fontColor('#FFFFFF').width('100%')
      Text(subtitle).fontSize(14).fontColor('#FFFFFFCE').lineHeight(23).width('100%')
    }.width('100%').padding(28).backgroundColor(color).borderRadius(26)
  }

  @Builder
  private pageContent() {
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 10 }) {
          Text('ARKUI · OPEN SOURCE').fontSize(11).letterSpacing(2).fontColor('#718176')
          Text('FoldMotion').fontSize(42).fontWeight(FontWeight.Medium).fontColor('#213C31')
          Text('让界面，跟随开合。').fontSize(18).fontColor('#607065')
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 20, bottom: 8 })

        Text('慢慢开合，观察虚化、遮暗与透视依次变化。停在中途，效果也会留下。普通设备可打开角度预览。')
          .fontSize(14).fontColor('#607065').lineHeight(24).width('100%')

        Column({ space: 18 }) {
          Row() {
            Text('启用动效').fontSize(16).fontColor('#213C31')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.effectOn })
              .selectedColor('#315B49')
              .onChange((value: boolean): void => {
                this.effectOn = value;
                this.controller.setEnabled(value);
              })
          }.width('100%')
          Row() {
            Text('手动角度预览').fontSize(16).fontColor('#213C31')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.previewOn }).selectedColor('#315B49')
              .onChange((value: boolean): void => { this.previewOn = value; this.updatePreview(); })
          }.width('100%')
          if (this.previewOn) {
            Row({ space: 10 }) {
              Button(this.previewCover ? '外屏 · 右侧变化' : '内屏 · 左侧变化')
                .height(38).backgroundColor('#E8EBE4').fontColor('#315B49')
                .onClick((): void => {
                  this.previewCover = !this.previewCover;
                  this.previewAngle = 180 - this.previewAngle; this.updatePreview();
                })
              Blank()
              Text(`${Math.round(this.previewAngle)}°`).fontSize(18).fontColor('#315B49')
            }.width('100%')
            Slider({ value: this.previewAngle, min: 0, max: 180, step: 1 })
              .selectedColor('#315B49').blockColor('#315B49')
              .onChange((value: number): void => { this.previewAngle = value; this.updatePreview(); })
          }
          Row() {
            Text('模糊强度').fontSize(14).fontColor('#607065')
            Blank()
            Text(`${Math.round(this.strength)}`).fontSize(14).fontColor('#315B49')
          }.width('100%')
          Slider({ value: this.strength, min: 0, max: 48, step: 1 })
            .selectedColor('#315B49').blockColor('#315B49')
            .onChange((value: number): void => { this.strength = value; })
          Row({ space: 10 }) {
            Button('局部卡片')
              .layoutWeight(1).height(42)
              .backgroundColor(this.fullPage ? '#E8EBE4' : '#315B49')
              .fontColor(this.fullPage ? '#315B49' : '#FFFFFF')
              .onClick((): void => { this.fullPage = false; })
            Button('整个页面')
              .layoutWeight(1).height(42)
              .backgroundColor(this.fullPage ? '#315B49' : '#E8EBE4')
              .fontColor(this.fullPage ? '#FFFFFF' : '#315B49')
              .onClick((): void => { this.fullPage = true; })
          }.width('100%')
        }.width('100%').padding(22).backgroundColor('#FFFFFF').borderRadius(24)

        FoldMotion({ effectEnabled: this.effectOn && !this.fullPage, maxBlurRadius: this.strength,
          manualAngle: this.previewValue(), manualCover: this.previewCover }) {
          this.card('随角度，轻轻变化', '活动侧先虚化，再压缩、变暗；稳定的一侧保留细节。方向跟随真实折痕与屏幕旋转。', '#315B49')
        }
        FoldMotion({ effectEnabled: this.effectOn && !this.fullPage, maxBlurRadius: this.strength,
          manualAngle: this.previewValue(), manualCover: this.previewCover,
          blurDirection: GradientDirection.Bottom }) {
          this.card('停下来，也留在当下', '这张卡片固定使用竖向渐变。多个实例可独立设置、独立启停。', '#8B7158')
        }

        Row({ space: 14 }) {
          Circle().width(14).height(14).fill('#315B49').opacity(1 - this.intensity * 0.7)
          Column({ space: 5 }) {
            Text('自定义控制器').fontSize(15).fontColor('#213C31')
            Text(`虚化 ${Math.round(this.intensity * 100)}% · 遮暗 ${Math.round(this.shade * 100)}% · 透视 ${Math.round(this.depth * 100)}%`).fontSize(12).fontColor('#718176')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(`${Math.round(this.intensity * 100)}%`).fontSize(18).fontColor('#315B49')
        }.width('100%').padding(8)
        Text('FoldMotion · Unlicense').fontSize(12).fontColor('#869087').margin({ bottom: 16 })
      }.width('100%').constraintSize({ maxWidth: 760 }).padding(24)
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      FoldMotion({ effectEnabled: this.effectOn && this.fullPage, maxBlurRadius: this.strength,
          manualAngle: this.previewValue(), manualCover: this.previewCover,
        content: (): void => { this.pageContent(); } })
        .width('100%').height('100%')
    }.width('100%').height('100%').backgroundColor('#F6F3EC')
  }
}
