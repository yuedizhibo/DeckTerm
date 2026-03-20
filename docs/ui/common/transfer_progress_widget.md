# transfer_progress_widget.dart

> 路径：`lib/ui/common/transfer_progress_widget.dart`

## 职责

文件传输进度条组件（轻量内嵌版）。监听 `TransferManager` 状态，实时展示指定类型（Upload/Download）的任务列表。

## 当前状态

**备用组件，当前无任何地方引用。** 已被 `TransferListDialog` 替代。

## 核心内容

### `TransferProgressWidget` (StatefulWidget)

| 参数 | 类型 | 说明 |
|------|------|------|
| `type` | `TransferType` | 仅显示指定类型的任务 |

- 最大高度 150px，顶部灰色边框分割。
- 每条任务显示：类型图标、文件名、进度百分比/大小、进度条（2px）。
- 无任务时隐藏（`SizedBox.shrink()`）。

## 依赖关系

- `TransferManager` — 任务数据源
