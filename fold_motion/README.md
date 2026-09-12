# FoldMotion

根据真实铰链角度驱动实时内容的局部虚化与渐变遮暗的 ArkUI HAR 组件，支持整页、卡片和自定义效果，无运行时第三方依赖。

适用于 HarmonyOS 6.1.1 / API 24、Stage 模型和 ArkUI V1；其他 SDK 版本尚未验证。非折叠设备正常显示内容，不启用角度监听。组件作用于应用内容，系统内外屏切换由操作系统负责。

## 安装

将 HAR 文件命名为 `fold_motion.har`，放到目标模块的 `libs/`，在该模块的 `oh-package.json5` 加入：

```json
{
  "dependencies": {
    "fold-motion": "file:./libs/fold_motion.har"
  }
}
```

执行 `ohpm install`。同一工程内开发时可使用 `"file:../fold_motion"`，并把 `fold_motion` 加入工程 `build-profile.json5` 的模块列表。

## 包住页面或组件

```typescript
import { FoldMotion } from 'fold-motion';

@Component
struct Example {
  @State effectEnabled: boolean = true;

  build() {
    Column({ space: 20 }) {
      // 只有这个区域受影响；外侧按钮、标题等保持原状。
      FoldMotion({ effectEnabled: this.effectEnabled, maxBlurRadius: 20 }) {
        Column({ space: 12 }) {
          Text('随开合变化的卡片').fontSize(22)
          Text('停在中途保持效果，继续开合接着变化。')
        }.width('100%').padding(24).backgroundColor('#F3EEE4').borderRadius(20)
      }

      Button('切换效果').onClick(() => { this.effectEnabled = !this.effectEnabled; })
    }.width('100%')
  }
}
```

容器没有固定宽高、背景、内边距或圆角，也不会拦截点击。需要给 `FoldMotion` 本身设置宽高等通用属性时，用命名 `content` 参数；ArkUI 不支持在尾随闭包后直接接这些属性。整页示例：

```typescript
@Builder
private pageContent() {
  Column() {
    Text('我的页面')
  }.width('100%').height('100%')
}

build() {
  Stack() {
    FoldMotion({ content: (): void => { this.pageContent(); }, maxBlurRadius: 28 })
      .width('100%').height('100%')
  }.width('100%').height('100%')
}
```

内容引用宿主状态或其他 `@Builder` 时，命名 `content` 使用示例中的箭头函数，保留宿主的 `this`；不要直接传入 `this.pageContent`。需要全屏延伸时，由宿主设置 `expandSafeArea`。

| 参数 | 默认值 | 作用 |
| --- | --- | --- |
| `effectEnabled` | `true` | 随时启用或关闭；关闭会立即清除效果并取消角度订阅 |
| `maxBlurRadius` | `42` | ArkUI 虚化半径数值，限制为 0–64；0、负数或非有限值关闭效果 |
| `maxShadeOpacity` | `0.72` | 活动区域的最大遮暗量，限制为 0–0.85；内屏使用该值的 85% |
| `manualAngle` | 未指定 | 外部角度输入，范围 0–180°；指定后替代系统角度订阅，仍遵循生命周期与减少动态效果设置 |
| `manualCover` | `false` | 外部输入对应的屏幕：`false` 为内屏、`true` 为外屏；只在指定 `manualAngle` 时生效 |
| `blurDirection` | 未指定 | 未指定时跟随物理折痕和屏幕旋转；可传四个主方向之一固定虚化与遮暗的共同方向 |
| `fractionStops` | 渐变起点模糊、终点清晰 | 自定义 ArkUI 渐变模糊采样点，每项为 `[模糊比例, 位置比例]` |
| `content` | 必填 | 内容构建函数，也可使用示例中的尾随闭包 |

默认正常握持时，内屏左侧模糊、向右渐变清晰；外屏右侧模糊、向左渐变清晰。`blurDirection` 可覆盖自动方向。

内屏的活动范围约为从起始边算起的 58%。外屏范围随角度从最大约 94% 缩小到 0，边界柔和过渡；合拢时从左侧开始清晰，右侧的模糊逐步退去。`fractionStops` 仅覆盖虚化分布，遮暗仍使用默认活动范围。`maxShadeOpacity: 0` 可停用遮暗。

例如使用均匀虚化：`fractionStops: [[1, 0], [1, 1]]`。多个实例互相独立，关闭一个不会移除其他实例的监听；通常在希望统一变化的区域最外层包一次即可，嵌套会叠加滤镜。

## 实时内容与角度同步

容器只保留一份实时内容，虚化和遮暗直接作用于该内容，不改变文字位置、比例、倾斜角或点击区域，也不保存、覆盖快照。视频、时钟和阅读器内容可以继续更新。

- 每次有效角度输入确定该角度对应的效果；同一显示帧前收到多次输入时，仅呈现最新一次。
- 不根据经过的时间追赶角度，不安排缓动、弹簧或尾部动画。半展开停住后，效果也保持不变。
- 完全展开附近（≥178°）或合拢附近（≤2°）在下一显示帧清晰，端点变化不受小幅抖动过滤影响。
- 同一角度的目标画面与开合速度无关；实际更新频率取决于系统角度回调和设备渲染能力。没有新回调时保持最近状态，不推测铰链位置。
- 禁用、隐藏、后台、减少动态效果或卸载时清除效果，并取消自身订阅与待处理帧。

独立 Surface 能否使用 ArkUI 滤镜取决于宿主渲染组件；必要时可通过控制器在其渲染层实现。组件不接管系统双屏内容迁移，也不触发应用重排。

## 从 1.1.x 升级

1.2.0 移除了内置快照透视，避免快照出现时内容抖动、文字倾斜或交互受影响。`perspectiveStrength`（默认 `0`）和 `contentRevision`（默认 `0`）仍可传入以保持源码兼容，但不再执行任何操作，可从调用处删除。`FoldMotionState.depth` 仍保留为自定义控制器的旧通道，内置组件不使用它改变内容。

## 外部角度预览

```typescript
FoldMotion({ manualAngle: 120, manualCover: false }) {
  Text('内屏左侧：实时虚化与渐变遮暗').padding(40)
}
```

内屏的清晰端点为 180°，外屏为 0°。内屏开始折叠时柔和增加虚化，随后增加遮暗；外屏在约 75° 到合拢端点之间同时降低模糊强度与覆盖范围，清晰区域随角度逐步扩大。角度无效时输出清晰状态。省略 `manualAngle` 即恢复系统铰链输入。

## 自定义效果：使用控制器

`FoldMotionController.onVisualFrame` 提供当前角度、效果状态与方向，适用于已有容器、单独弹窗、自绘组件等不方便增加包装层的场景。原有 `onFrame(radius, direction)` 保留兼容；全通道回调在遮暗单独变化时也会更新。

```typescript
import { FoldMotionController, FoldMotionModel, FoldMotionState } from 'fold-motion';

private readonly fold = new FoldMotionController();
@State foldProgress: number = 0;

aboutToAppear(): void {
  this.fold.onVisualFrame = (state: FoldMotionState, direction: GradientDirection): void => {
    this.foldProgress = state.radius / FoldMotionModel.maximumRadius;
    // state.shade 是 0–1 的遮暗强度；state.angle 是最新有效角度。
  };
  this.fold.start(this.getUIContext(), true);
}

aboutToDisappear(): void {
  this.fold.close();
}
```

`FoldMotionState` 包含 `radius`（0–28）、`shade`（0–1）、`depth`（0–1）、`angle`（0–180°）、`cover`（是否外屏）和 `sample`（当前输入会话的有效角度采样序号，重置后重新计数）。`radius` 是模型内部单位，组件按 `maxBlurRadius` 换算实际虚化半径。

可用 `setManualAngle(angle, cover)` 输入外部角度；传 `undefined` 恢复真实铰链输入。外部输入直接求值，与真实角度输入共用同一目标曲线。

用 `setEnabled(false)` 暂停当前作用域，用 `setEnabled(true)` 恢复。手动控制器的宿主还应在页面隐藏时停用；`FoldMotion` 容器会自动处理可见性。控制器自动监听应用前后台和系统减少动态效果设置，关闭时只解绑自身回调。重复 `start` 会先释放旧的宿主绑定。

对于独立 Surface、自绘画面等，能否直接使用 ArkUI 滤镜取决于相应渲染组件；可以使用控制器回调在自己的渲染层实现效果。

`FoldMotionModel` 是无平台依赖的角度/动效状态模型，供离线测试和其他输入适配器使用。`accept(angles, time)` 输入角度，`advance(time)` 呈现最新目标，`needsFrame(time)` 判断是否需要继续刷新，`state()` 获取独立通道、`setCover(cover)` 切换屏幕配置、`reset()` 清空。静态 `profile(angle, cover)` 可直接计算目标状态。`blurSpan(radius, cover)` 计算默认活动范围。时间单位为毫秒，应使用单调时钟；时间仅用于输入校验和切屏事件关联，不参与效果插值。

## 输入与多实例

初次角度事件建立基准，避免冷启动突然出现虚化；之后按有效角度改变状态。多折轴按变化最大的轴响应，不对相反方向的变化求平均。多个实例独立启停；同一区域通常只需最外层包装一次，嵌套会叠加滤镜。

## 从源码构建

使用 DevEco Studio 6.1.1、HarmonyOS SDK API 24、Node.js 22 和 Python 3.9+，在源码工程根目录执行：

```sh
python3 scripts/harmony.py install
python3 scripts/harmony.py package
```

产物为 `dist/fold-motion-1.2.0.har` 和 `dist/SHA256SUMS`。示例应用与构建脚本位于源码工程中。

## 许可证

本项目采用 [Unlicense](LICENSE)。
