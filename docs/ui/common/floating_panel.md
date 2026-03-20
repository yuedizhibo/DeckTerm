# floating_panel.dart

> 路径：`lib/ui/common/floating_panel.dart`

## 职责

通用可拖拽毛玻璃浮动面板组件 + Android 兼容的模态 Dialog 包装函数。在 Windows 上作为非模态浮动卡片嵌入 Stack 使用，在 Android 上通过 `showPanelDialog()` 以模态 Dialog 形式展示。

## 核心内容

### `FloatingPanel` (StatefulWidget)

Windows 平台使用的非模态浮动面板，必须作为 Stack 的子组件（build 返回 `Positioned`）。

**参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| `title` | String | 标题栏文字 |
| `child` | Widget | 面板内容区域 |
| `width` / `height` | double | 面板尺寸，默认 560×640 |
| `onClose` | VoidCallback | 关闭回调 |
| `onTap` | VoidCallback? | 点击面板回调（用于提升 z 序） |
| `originRect` | Rect? | 动画起点矩形（按钮在 Stack 内的位置） |

**动画**：
- 280ms `easeOutCubic` 曲线。
- 有 `originRect` 时：从按钮位置（缩放 0.15）飞入到屏幕中央（缩放 1.0），同时淡入。
- 无 `originRect` 时：直接在中央显示。

**拖拽**：
- 标题栏区域支持 `onPanUpdate` 拖拽移动。
- 位置限制在 Stack 范围内（clamp），不允许拖出顶部。

**视觉效果**：
- `BackdropFilter` 毛玻璃模糊（sigma 24）。
- 半透明深色背景（`0xFF1A1F2E` 92% 不透明度）。
- 圆角 14px + 双层阴影 + 0.08 透明度白色边框。

### `_PanelCloseButton`

标题栏关闭按钮，hover 时变红色。

### `showPanelDialog<T>()`

Android 平台使用的模态 Dialog 包装函数。

- `showGeneralDialog` 实现，半透明黑色背景遮罩。
- 缩放（0.85→1.0）+ 淡入动画，280ms `easeOutCubic`。
- 小屏幕（宽<600）自适应 93% 宽 / 85% 高，大屏使用指定尺寸。
- 标题栏含关闭按钮（`Navigator.pop()`）。

## 依赖关系

| 依赖 | 用途 |
|------|------|
| `dart:ui` | `ImageFilter.blur`、`lerpDouble` |
| `flutter/material.dart` | Widget 基础 |

## 被引用

- `workflow.dart` — 在 Stack 中管理多个浮动面板实例
