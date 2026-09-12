# FoldMotion

根据真实铰链角度驱动局部虚化、遮暗和透视压缩的 ArkUI HAR 组件，支持整页、卡片和自定义效果，无运行时第三方依赖。

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
| `perspectiveStrength` | `1` | 透视强度，限制为 0–1；0 或非有限值停用快照透视层 |
| `contentRevision` | `0` | 内容变化时递增，清除旧快照并在动效有效时重新抓取 |
| `manualAngle` | 未指定 | 外部角度输入，范围 0–180°；指定后替代系统角度订阅，仍遵循生命周期与减少动态效果设置 |
| `manualCover` | `false` | 外部输入对应的屏幕：`false` 为内屏、`true` 为外屏；只在指定 `manualAngle` 时生效 |
| `blurDirection` | 未指定 | 未指定时跟随物理折痕和屏幕旋转；可传四个主方向之一固定虚化、遮暗与透视的共同方向 |
| `fractionStops` | 渐变起点模糊、终点清晰 | 自定义 ArkUI 渐变模糊采样点，每项为 `[模糊比例, 位置比例]` |
| `content` | 必填 | 内容构建函数，也可使用示例中的尾随闭包 |

默认正常握持时，内屏左侧模糊、向右渐变清晰；外屏右侧模糊、向左渐变清晰。`blurDirection` 可覆盖自动方向。

默认内屏的活动范围约为从起始边算起的 58%，外屏为 94%，边界柔和过渡。`fractionStops` 仅改变虚化分布，遮暗与透视仍使用默认活动范围。透视强度和遮暗量为 0 时退化为单独虚化，例如 `maxShadeOpacity: 0, perspectiveStrength: 0`。

例如使用均匀虚化：`fractionStops: [[1, 0], [1, 1]]`。多个实例互相独立，关闭一个不会移除其他实例的监听；通常在希望统一变化的区域最外层包一次即可，嵌套会叠加滤镜。

## 透视层与动态内容

内容只构建一次。实时内容接受渐变虚化，其上方的局部快照通过网格压缩形成透视，再叠加渐变遮暗。稳定侧没有形变，透视层在稳定侧完全透明。网格不会改变宿主布局、命中区域或触发重排。

快照来自 ArkUI 的公开组件快照接口，仅在内存中保留，不落盘；单张图像不超过约 150 万像素。角度运动时，抓取请求最多约每 160 ms 一次；每个作用域只有一个抓取任务和一张保留图像，异步任务期间仅合并最新请求。网格形变仍跟随逐帧平滑后的角度状态。多个独立作用域会分别产生这部分开销。

- 半展开停住后保持画面和效果，平滑结束后停止请求帧与快照。视频、时钟或持续更新的内容在透视覆盖区域可能暂时定格；可设置 `perspectiveStrength: 0` 保留实时虚化与遮暗。
- 宿主内容改变时递增 `contentRevision`，使快照失效并抓取新画面。持续高频变化的内容更适合停用快照透视，或用控制器在自身渲染层实现。
- 触摸开始立即移除快照，实时内容正常响应。透视在后续角度变化或显式 `contentRevision` 更新时恢复。手动整页预览中的控件也遵守这一规则。
- 尺寸、屏幕或方向改变会丢弃旧快照；退后台、隐藏、禁用、卸载时释放图像，晚到的旧结果不会覆盖新页面。
- 抓取或网格绘制失败时保留实时虚化与遮暗。独立 Surface、受保护画面等是否能被快照捕获，取决于宿主渲染组件；无法保证这类内容的透视效果，可关闭透视或使用控制器。

组件使用应用公开 API，不接管系统双屏内容迁移，也不重排应用的 UI。手动角度用于预览效果曲线，不模拟真实屏幕尺寸切换。

## 外部角度预览

```typescript
FoldMotion({ manualAngle: 120, manualCover: false }) {
  Text('内屏左侧：虚化、压缩与遮暗').padding(40)
}
```

内屏的清晰端点为 180°，外屏为 0°。内屏保留先虚化、后恢复细节的分阶段曲线；外屏在约 75° 到合拢端点之间连续降低三种强度，并把最后的细节恢复集中在 20° 以下，避免切屏后出现长时间不变的平台。角度无效时输出清晰状态。省略 `manualAngle` 即恢复系统铰链输入。

## 自定义效果：使用控制器

`FoldMotionController.onVisualFrame` 提供独立的三个通道与方向，适用于已有容器、单独弹窗、自绘组件等不方便增加包装层的场景。原有 `onFrame(radius, direction)` 保留兼容；全通道回调在遮暗或透视单独变化时也会更新。

```typescript
import { FoldMotionController, FoldMotionModel, FoldMotionState } from 'fold-motion';

private readonly fold = new FoldMotionController();
@State foldProgress: number = 0;

aboutToAppear(): void {
  this.fold.onVisualFrame = (state: FoldMotionState, direction: GradientDirection): void => {
    this.foldProgress = state.radius / FoldMotionModel.maximumRadius;
    // state.shade 与 state.depth 分别是 0–1 的遮暗和透视强度。
  };
  this.fold.start(this.getUIContext(), true);
}

aboutToDisappear(): void {
  this.fold.close();
}
```

`FoldMotionState` 包含 `radius`（0–28）、`shade`（0–1）、`depth`（0–1）、`angle`（0–180°）、`cover`（是否外屏）和 `sample`（当前输入会话的有效角度采样序号，重置后重新计数）。`radius` 是模型内部单位，组件按 `maxBlurRadius` 换算实际虚化半径。

可用 `setManualAngle(angle, cover)` 输入外部角度；传 `undefined` 恢复真实铰链输入。外部输入直接求值，不额外安排平滑帧。

用 `setEnabled(false)` 暂停当前作用域，用 `setEnabled(true)` 恢复。手动控制器的宿主还应在页面隐藏时停用；`FoldMotion` 容器会自动处理可见性。控制器自动监听应用前后台和系统减少动态效果设置，关闭时只解绑自身回调。重复 `start` 会先释放旧的宿主绑定。

对于独立 Surface、自绘画面等，能否直接使用 ArkUI 滤镜取决于相应渲染组件；可以使用控制器回调在自己的渲染层实现效果。

`FoldMotionModel` 是无平台依赖的角度/动效状态模型，供离线测试和其他输入适配器使用。`accept(angles, time)` 输入角度，`advance(time)` 平滑追踪，`needsFrame(time)` 判断是否需要继续刷新，`state()` 获取独立通道、`setCover(cover)` 切换屏幕配置、`reset()` 清空。静态 `profile(angle, cover)` 可直接计算目标状态。时间单位为毫秒，应使用单调时钟。

## 保持与复位

- 初次角度事件建立基准，避免冷启动闪一下。
- 虚化在离开清晰端点后先加强并保持平台，透视与遮暗随后加强；接近清晰端点时先减弱遮暗与形变，最后恢复细节。
- 运动中根据角度变化；半展开停住时保持效果，达到当前目标后停止请求帧。
- 完全展开附近（≥178°）或合拢附近（≤2°）恢复清晰。
- 禁用、隐藏、后台、减少动态效果或组件卸载时复位。
- 多折轴按变化最大的轴响应；不改变布局、路由、内容或触摸区域。

## 从源码构建

使用 DevEco Studio 6.1.1、HarmonyOS SDK API 24、Node.js 22 和 Python 3.9+，在源码工程根目录执行：

```sh
python3 scripts/harmony.py install
python3 scripts/harmony.py package
```

产物为 `dist/fold-motion-1.1.0.har` 和 `dist/SHA256SUMS`。示例应用与构建脚本位于源码工程中。

## 许可证

本项目采用 [Unlicense](LICENSE)。
