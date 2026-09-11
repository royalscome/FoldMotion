# FoldMotion

根据真实铰链角度驱动渐变模糊的 ArkUI HAR 组件，支持整页、卡片和自定义效果，无运行时第三方依赖。

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
| `maxBlurRadius` | `28` | ArkUI 虚化半径数值，限制为 0–64；0、负数或非有限值关闭效果 |
| `blurDirection` | 未指定 | 未指定时跟随物理折痕和屏幕旋转；可传 `GradientDirection` 固定方向 |
| `fractionStops` | 一侧模糊、另一侧清晰 | 自定义 ArkUI 渐变模糊采样点，每项为 `[模糊比例, 位置比例]` |
| `content` | 必填 | 内容构建函数，也可使用示例中的尾随闭包 |

例如使用均匀虚化：`fractionStops: [[1, 0], [1, 1]]`。多个实例互相独立，关闭一个不会移除其他实例的监听；通常在希望统一变化的区域最外层包一次即可，嵌套会叠加滤镜。

## 自定义效果：使用控制器

`FoldMotionController` 提供原始半径与方向回调，适用于已有容器、单独弹窗、自绘组件等不方便增加包装层的场景：

```typescript
import { FoldMotionController, FoldMotionModel } from 'fold-motion';

private readonly fold = new FoldMotionController();
@State foldProgress: number = 0;

aboutToAppear(): void {
  this.fold.onFrame = (radius: number, direction: GradientDirection): void => {
    this.foldProgress = radius / FoldMotionModel.maximumRadius;
    // 用 0–1 的强度控制自己的透明度、蒙版或着色器。
  };
  this.fold.start(this.getUIContext(), true);
}

aboutToDisappear(): void {
  this.fold.close();
}
```

用 `setEnabled(false)` 暂停当前作用域，用 `setEnabled(true)` 恢复。手动控制器的宿主还应在页面隐藏时停用；`FoldMotion` 容器会自动处理可见性。控制器自动监听应用前后台和系统减少动态效果设置，关闭时只解绑自身回调。重复 `start` 会先释放旧的宿主绑定。

对于独立 Surface、自绘画面等，能否直接使用 ArkUI 滤镜取决于相应渲染组件；可以使用控制器回调在自己的渲染层实现效果。

`FoldMotionModel` 是无平台依赖的角度/动效状态模型，供离线测试和其他输入适配器使用。`accept(angles, time)` 输入角度，`advance(time)` 平滑追踪，`needsFrame(time)` 判断是否需要继续刷新，`reset()` 清空。时间单位为毫秒，应使用单调时钟。

## 保持与复位

- 初次角度事件建立基准，避免冷启动闪一下。
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

产物为 `dist/fold-motion-1.0.0.har` 和 `dist/SHA256SUMS`。示例应用与构建脚本位于源码工程中。

## 许可证

本项目采用 [Unlicense](LICENSE)。
