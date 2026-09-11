# FoldMotion

Angle-driven motion for HarmonyOS ArkUI.

鸿蒙折叠屏动效组件。跟随真实铰链角度，让界面局部虚化；展开或合拢到端点恢复清晰，中途停下则保持当前效果。

**Unlicense · 无运行时第三方依赖 · HarmonyOS 6.1.1 / API 24 · ArkUI V1**

## 能做什么

- 整页、局部卡片和自定义内容共用同一个 `FoldMotion` 容器。
- 默认渐变方向跟随物理折痕和屏幕旋转，也可自定义方向、采样点与最大模糊半径。
- 中途暂停保持效果，稳定后停止请求帧；反向开合连续衔接。
- 自动处理前后台、可见性、减少动态效果设置和实例释放；多个作用域独立启停。
- `FoldMotionController` 暴露动效回调，可驱动透明度、蒙版或自己的渲染层。
- 普通设备保持清晰，不订阅铰链角度。

适用于 HarmonyOS 6.1.1 / API 24、Stage 模型和 ArkUI V1；其他 SDK 版本尚未验证。真实开合效果需要支持铰链角度回调的折叠设备，模拟器与普通设备可用于检查布局。组件作用于应用内容，系统内外屏切换由操作系统负责。

## 快速接入

将 HAR 文件放入目标模块的 `libs/fold_motion.har`，在该模块 `oh-package.json5` 中添加依赖后运行 `ohpm install`。从源码生成 HAR 的步骤见下方“构建与运行示例”。

```json
{
  "dependencies": {
    "fold-motion": "file:./libs/fold_motion.har"
  }
}
```

```typescript
import { FoldMotion } from 'fold-motion';

@Component
struct FoldCard {
  build() {
    Column() {
      FoldMotion({ maxBlurRadius: 24 }) {
        Column({ space: 12 }) {
          Text('随开合变化').fontSize(24)
          Text('停在中途，效果也会留下。')
        }
        .width('100%').padding(28)
        .backgroundColor('#E6EBDD').borderRadius(24)
      }
    }.width('100%')
  }
}
```

需要给容器设置宽高时使用 `content: (): void => { this.pageContent(); }`，保留宿主 `this`；不要在尾随闭包后追加通用属性。完整用法、参数表和控制器生命周期见 [HAR 接入文档](fold_motion/README.md)。

## 构建与运行示例

开发环境：DevEco Studio 6.1.1、HarmonyOS SDK API 24、Node.js 22 和 Python 3.9+。

在 DevEco Studio 中打开项目根目录，完成同步后运行 `entry` 模块。示例包含局部卡片、整页效果切换、强度滑杆和控制器回调。真机运行需要在 IDE 中配置应用签名；命令行构建默认生成未签名 HAP。

macOS 默认安装路径可直接使用下面的脚本。DevEco Studio 安装在其他位置时，先设置 `DEVECO_STUDIO_HOME` 为包含 `tools/`、`sdk/` 的目录；也可分别设置 `HVIGOR_BINARY`、`OHPM_BINARY`、`DEVECO_SDK_HOME` 和 `JAVA_HOME`。Windows 使用相应环境变量设置方式，并将 `python3` 替换为本机 Python 命令。

```sh
# 安装鸿蒙工程依赖
python3 scripts/harmony.py install

# 编译 HAR
python3 scripts/harmony.py build

# 编译示例应用
python3 scripts/harmony.py demo

# 生成带版本号的 HAR 和 SHA-256 校验文件
python3 scripts/harmony.py package
```

打包产物为 `dist/fold-motion-1.0.0.har` 和 `dist/SHA256SUMS`。接入时可将 HAR 重命名为 `fold_motion.har`。原始构建产物位于 `fold_motion/build/default/outputs/default/fold_motion.har`。

## 测试

模型与控制器测试使用 Node.js 运行，无需鸿蒙 SDK：

```sh
npm ci --ignore-scripts
npm test
```

测试覆盖角度响应、暂停保持、旋转、前后台、减少动态效果、多实例和异常清理。GitHub Actions 运行同一组 Node 测试。

安装 SDK 并完成工程依赖安装后，可运行 Hypium 模型测试：

```sh
python3 scripts/harmony.py test
```

一次完成依赖安装、Hypium 测试、示例编译和 HAR 打包：

```sh
python3 scripts/harmony.py check
```

Node 与 Hypium 共用模型测试用例。动效的设备表现需在折叠屏真机上验证。

## 目录

```text
fold_motion/   可独立使用的 HAR 模块与 API 文档
entry/         示例应用
tests/         无需鸿蒙 SDK 的 Node 测试
scripts/       构建、测试、打包工具
.github/       GitHub Actions
```

参与修改见 [贡献说明](CONTRIBUTING.md)，版本记录见 [CHANGELOG](CHANGELOG.md)。

## 许可证

本项目采用 [Unlicense](LICENSE)。
