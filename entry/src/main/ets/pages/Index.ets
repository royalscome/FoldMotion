import { FoldMotion, FoldMotionController, FoldMotionModel } from 'fold-motion';

@Entry
@Component
struct Index {
  @State private effectOn: boolean = true;
  @State private strength: number = 28;
  @State private fullPage: boolean = false;
  @State private intensity: number = 0;
  private readonly controller: FoldMotionController = new FoldMotionController();

  aboutToAppear(): void {
    this.controller.onFrame = (radius: number): void => {
      this.intensity = radius / FoldMotionModel.maximumRadius;
    };
    this.controller.start(this.getUIContext(), this.effectOn);
  }

  aboutToDisappear(): void { this.controller.close(); }

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

        Text('慢慢折叠或展开设备，停在中途观察效果保持。普通设备会保持清晰。')
          .fontSize(14).fontColor('#607065').lineHeight(24).width('100%')

        Column({ space: 18 }) {
          Row() {
            Text('跟随铰链角度').fontSize(16).fontColor('#213C31')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.effectOn })
              .selectedColor('#315B49')
              .onChange((value: boolean): void => {
                this.effectOn = value;
                this.controller.setEnabled(value);
              })
          }.width('100%')
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

        FoldMotion({ effectEnabled: this.effectOn && !this.fullPage, maxBlurRadius: this.strength }) {
          this.card('随角度，轻轻变化', '默认方向随折痕与屏幕旋转，局部内容模糊，另一侧保持清晰。', '#315B49')
        }
        FoldMotion({ effectEnabled: this.effectOn && !this.fullPage, maxBlurRadius: this.strength,
          blurDirection: GradientDirection.Bottom }) {
          this.card('停下来，也留在当下', '这张卡片固定使用竖向渐变。多个实例可独立设置、独立启停。', '#8B7158')
        }

        Row({ space: 14 }) {
          Circle().width(14).height(14).fill('#315B49').opacity(1 - this.intensity * 0.7)
          Column({ space: 5 }) {
            Text('自定义控制器').fontSize(15).fontColor('#213C31')
            Text('同一动效模型，也能驱动透明度等自定义效果。').fontSize(12).fontColor('#718176')
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
        content: (): void => { this.pageContent(); } })
        .width('100%').height('100%')
    }.width('100%').height('100%').backgroundColor('#F6F3EC')
  }
}
