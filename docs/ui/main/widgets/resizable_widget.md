# resizable_widget.dart

> 路径：`lib/ui/main/widgets/resizable_widget.dart`

## 职责

可调整大小的分割面板组件。支持水平和垂直方向的拖拽调整，用于主界面的面板布局。

## 核心内容

### `ResizableWidget` (StatefulWidget)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `children` | `List<Widget>` | — | 必须恰好 2 个子组件 |
| `initialSize` | `double?` | null | 第一个子组件的初始像素大小 |
| `separatorWidth` | `double` | 4.0 | 分割线宽度（拖拽热区） |
| `separatorColor` | `Color` | transparent | 分割线颜色 |
| `direction` | `Axis` | horizontal | 分割方向 |
| `isResizable` | `bool` | true | 是否允许拖拽调整 |
| `onResizeEnd` | `ValueChanged<double>?` | null | 拖拽结束回调（返回第一个子组件像素尺寸） |

### 布局策略

- **第一个子组件**：固定像素大小（SizedBox）。
- **第二个子组件**：`Expanded` 占据剩余空间。
- 默认 `initialSize` 为总空间的 40%。
- 最小尺寸 1.0px（防止完全消失），最大尺寸为总空间减去分割线减 1.0px。

### 鼠标指针

- 水平分割：`resizeLeftRight`
- 垂直分割：`resizeUpDown`
- 锁定时：`basic`

## 被引用位置

- `workflow.dart` — 三层嵌套使用：水平分割左右面板，左侧垂直分割设备监控/文件树，右侧垂直分割终端/远程文件
