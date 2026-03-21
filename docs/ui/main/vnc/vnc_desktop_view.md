# vnc_desktop_view.dart

> 路径：`lib/ui/main/vnc/vnc_desktop_view.dart`

## 职责

VNC 远程桌面渲染视图。基于 `VncManager` 实现完整的 VNC 桌面显示，处理键盘和鼠标/触摸输入，支持 Android 和 Windows 平台。

## 核心内容

### `VncDesktopView` (StatefulWidget + AutomaticKeepAliveClientMixin)

- `wantKeepAlive: true` — 标签页切换时保持 VNC 连接活跃。
- `initState` 中创建 `VncManager`，监听状态流和帧更新流。
- `dispose` 中释放 VNC 连接和 `ui.Image` 资源。

### 帧缓冲渲染

- `_updateImage()`：将 `VncManager.frameBuffer`（BGRA）转换为 RGBA，通过 `ui.decodeImageFromPixels` 创建 `ui.Image`。
- `_VncPainter`（`CustomPainter`）：等比缩放居中绘制 `ui.Image`，使用 `FilterQuality.medium`。

### 键盘输入

- `Focus` + `onKeyEvent` 处理物理键盘事件。
- `_logicalKeyToKeysym()`：将 Flutter `LogicalKeyboardKey` 映射为 X11 keysym。
- 支持：Enter、Backspace、Tab、Escape、Delete、方向键、Home/End、PageUp/Down、F1-F12、Shift/Ctrl/Alt、Space、ASCII 可打印字符。
- KeyDown 后自动发送 KeyUp（模拟按键释放）。

### 鼠标/触摸输入

| 事件 | 行为 |
|------|------|
| `onPointerDown` | 检测按钮（左/右/中键），发送 PointerEvent |
| `onPointerMove` | 发送鼠标移动 |
| `onPointerUp` | 释放所有按钮 |
| `onPointerSignal` (ScrollEvent) | 滚轮上(button 4)/下(button 5) |
| `onLongPressStart` (Android) | 长按模拟右键点击 |

- `_toVncCoords()`：将 Widget 局部坐标转换为 VNC 帧缓冲坐标（考虑等比缩放和居中偏移）。

### 连接状态 UI

| 状态 | UI |
|------|------|
| connecting | 加载动画 + "连接 VNC 服务器..." |
| failed / disconnected | 错误图标 + 错误信息 + "重试"按钮 |
| connected | `CustomPaint` 渲染帧缓冲 |

### 平台适配

| 平台 | 行为 |
|------|------|
| Windows | 自动获取焦点（`autofocus: true`），鼠标直接操作 |
| Android | 不自动获取焦点，长按模拟右键，触摸点击模拟左键 |

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `VncManager` | VNC 连接和帧缓冲 |
| `AppColors` | 主题色适配（连接状态 UI） |
| `dart:ui` | `Image`、`decodeImageFromPixels`、`PixelFormat` |

## 被引用位置

- `terminal_tabs.dart` — 通过 `session.type == TerminalType.vnc` 分发
